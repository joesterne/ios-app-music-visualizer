import AVFoundation

@MainActor
final class MicrophoneCapture {
    private var engine: AVAudioEngine?
    private let analyzer: AudioAnalyzer
    init(analyzer: AudioAnalyzer) { self.analyzer = analyzer }

    func start() async throws {
        let granted: Bool
        #if os(iOS)
        granted = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
        }
        #else
        granted = await AVCaptureDevice.requestAccess(for: .audio)
        #endif
        guard granted else {
            throw AfterglowError.message("Microphone access is off. Enable it for Afterglow in system privacy settings, then try again.")
        }
        try Task.checkCancellation()
        stop()
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement,
                                options: [.mixWithOthers, .defaultToSpeaker, .allowBluetooth])
        try session.setActive(true)
        #endif
        let next = AVAudioEngine()
        let input = next.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw AfterglowError.message("No microphone or audio input is available. Connect an input and try again.")
        }
        let sink = analyzer
        input.installTap(onBus: 0, bufferSize: 2048, format: format) { buffer, _ in sink.consume(buffer) }
        do {
            try next.start()
            engine = next
        } catch {
            input.removeTap(onBus: 0)
            throw error
        }
    }
    func stop() {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop(); engine = nil
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }
}
