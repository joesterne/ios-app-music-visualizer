#if os(macOS)
import AVFoundation
import Combine
import CoreAudio
import ScreenCaptureKit

/// ScreenCaptureKit owns the system permission prompt. No audio or video is written to disk.
final class MacAudioCapture: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    private let analyzer: AudioAnalyzer
    private let queue = DispatchQueue(label: "com.afterglow.system-audio", qos: .userInteractive)
    @MainActor private var stream: SCStream?
    @MainActor var onStopped: ((String) -> Void)?
    init(analyzer: AudioAnalyzer) { self.analyzer = analyzer }

    @MainActor func start() async throws {
        await stop()
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        } catch {
            throw AfterglowError.message("System audio could not connect. Check Afterglow’s screen/system-audio recording permission in System Settings → Privacy & Security, then restart Afterglow and try again. \(error.localizedDescription)")
        }
        try Task.checkCancellation()
        guard let display = content.displays.first else {
            throw AfterglowError.message("No display is available for system audio capture.")
        }
        let ownApps = content.applications.filter { $0.bundleIdentifier == Bundle.main.bundleIdentifier }
        let filter = SCContentFilter(display: display, excludingApplications: ownApps, exceptingWindows: [])
        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = true
        config.sampleRate = 48000
        config.channelCount = 2
        config.width = 2; config.height = 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        config.queueDepth = 3
        config.showsCursor = false
        let next = SCStream(filter: filter, configuration: config, delegate: self)
        // A screen output prevents the framework's "no screen output" warning. Frames are discarded.
        try next.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
        try next.addStreamOutput(self, type: .audio, sampleHandlerQueue: queue)
        try await next.startCapture()
        if Task.isCancelled { try? await next.stopCapture(); throw CancellationError() }
        stream = next
    }
    @MainActor func stop() async {
        let previous = stream; stream = nil
        try? await previous?.stopCapture()
    }
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio, sampleBuffer.isValid else { return }
        try? sampleBuffer.withAudioBufferList { audioBufferList, _ in
            guard var description = sampleBuffer.formatDescription?.audioStreamBasicDescription,
                  let format = AVAudioFormat(streamDescription: &description),
                  let pcm = AVAudioPCMBuffer(pcmFormat: format, bufferListNoCopy: audioBufferList.unsafePointer) else { return }
            analyzer.consume(pcm)
        }
    }
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        Task { @MainActor [weak self] in
            guard let self, self.stream === stream else { return }
            self.stream = nil
            self.onStopped?(error.localizedDescription)
        }
    }
}

/// Reads and adjusts the current macOS output device's software volume when exposed.
@MainActor
final class MacOutputVolume: ObservableObject {
    @Published private(set) var volume: Double = 0
    @Published private(set) var isAvailable = false
    @Published private(set) var status = "Checking the current Mac output…"

    private var deviceID = kAudioObjectUnknown
    private var volumeAddresses: [AudioObjectPropertyAddress] = []
    private var channelVolumes: [Float32] = []
    private var hasMasterVolume = false

    func refresh() {
        var device = kAudioObjectUnknown
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let deviceStatus = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device
        )
        guard deviceStatus == noErr, device != kAudioObjectUnknown else {
            setUnavailable("Afterglow could not find the current Mac output device.")
            return
        }

        let addresses = writableVolumeAddresses(for: device)
        guard !addresses.isEmpty else {
            setUnavailable("This output device does not expose a software volume control to macOS.")
            return
        }

        var values: [Float32] = []
        for address in addresses {
            guard let scalar = scalarVolume(for: device, address: address) else {
                setUnavailable("Afterglow could not read the current output volume.")
                return
            }
            values.append(scalar)
        }

        deviceID = device
        volumeAddresses = addresses
        channelVolumes = values
        hasMasterVolume = addresses.count == 1 &&
            addresses[0].mElement == kAudioObjectPropertyElementMain
        volume = average(values)
        isAvailable = true
        status = "Controls the current macOS output device."
    }

    func setVolume(_ newValue: Double) {
        guard isAvailable, deviceID != kAudioObjectUnknown, !volumeAddresses.isEmpty else { return }
        let requested = Float32(min(1, max(0, newValue.isFinite ? newValue : volume)))
        let nextVolumes: [Float32]

        if hasMasterVolume || channelVolumes.count <= 1 {
            nextVolumes = [requested]
        } else {
            let current = Float32(average(channelVolumes))
            // Scale each channel rather than assigning an identical value, retaining balance.
            let multiplier = current > 0 ? requested / current : requested
            nextVolumes = channelVolumes.map { min(1, max(0, $0 * multiplier)) }
        }

        for (index, address) in volumeAddresses.enumerated() {
            var address = address
            var scalar = nextVolumes[index]
            let result = AudioObjectSetPropertyData(
                deviceID, &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &scalar
            )
            guard result == noErr else {
                setUnavailable("The current output device did not accept this volume change.")
                return
            }
        }
        channelVolumes = nextVolumes
        volume = average(nextVolumes)
    }

    private func writableVolumeAddresses(for device: AudioDeviceID) -> [AudioObjectPropertyAddress] {
        let master = volumeAddress(for: kAudioObjectPropertyElementMain, device: device)
        if isWritable(master, for: device) { return [master] }

        let channelCount = outputChannelCount(for: device)
        guard channelCount > 0 else { return [] }
        let addresses = (1...channelCount).compactMap {
            let address = volumeAddress(for: AudioObjectPropertyElement($0), device: device)
            return isWritable(address, for: device) ? address : nil
        }

        // Do not present a master-like slider unless every output channel is covered.
        return addresses.count == channelCount ? addresses : []
    }

    private func volumeAddress(
        for element: AudioObjectPropertyElement,
        device: AudioDeviceID
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: element
        )
    }

    private func isWritable(
        _ address: AudioObjectPropertyAddress,
        for device: AudioDeviceID
    ) -> Bool {
        var address = address
        guard AudioObjectHasProperty(device, &address) else { return false }
        var settable = DarwinBoolean(false)
        return AudioObjectIsPropertySettable(device, &address, &settable) == noErr &&
            settable.boolValue
    }

    private func outputChannelCount(for device: AudioDeviceID) -> Int {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(device, &address, 0, nil, &size) == noErr,
              size > 0 else { return 0 }

        let raw = UnsafeMutableRawPointer.allocate(
            byteCount: max(Int(size), MemoryLayout<AudioBufferList>.size),
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { raw.deallocate() }

        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, raw) == noErr else {
            return 0
        }
        let list = raw.bindMemory(to: AudioBufferList.self, capacity: 1)
        return UnsafeMutableAudioBufferListPointer(list).reduce(0) {
            $0 + Int($1.mNumberChannels)
        }
    }

    private func scalarVolume(
        for device: AudioDeviceID,
        address: AudioObjectPropertyAddress
    ) -> Float32? {
        var address = address
        var scalar: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &scalar) == noErr,
              scalar.isFinite else { return nil }
        return min(1, max(0, scalar))
    }

    private func average(_ values: [Float32]) -> Double {
        guard !values.isEmpty else { return 0 }
        return Double(values.reduce(0, +) / Float32(values.count))
    }

    private func setUnavailable(_ message: String) {
        deviceID = kAudioObjectUnknown
        volumeAddresses = []
        channelVolumes = []
        hasMasterVolume = false
        isAvailable = false
        status = message
    }
}

#endif
