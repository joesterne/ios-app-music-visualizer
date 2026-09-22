#if os(macOS)
import AVFoundation
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
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
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
#endif
