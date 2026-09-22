import AVFoundation
import Foundation

@MainActor
final class LocalAudioPlayer {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var file: AVAudioFile?
    private var startFrame: AVAudioFramePosition = 0
    private var generation = UUID()
    private(set) var isPlaying = false
    var onFinished: (() -> Void)?
    var duration: Double { file.map { Double($0.length) / $0.processingFormat.sampleRate } ?? 0 }
    var position: Double {
        guard let file else { return 0 }
        let elapsed = player.lastRenderTime.flatMap { player.playerTime(forNodeTime: $0) }?.sampleTime ?? 0
        return min(duration, Double(startFrame + max(0, elapsed)) / file.processingFormat.sampleRate)
    }
    var volume: Float = 0.8 { didSet { player.volume = volume } }

    init(analyzer: AudioAnalyzer) {
        engine.attach(player)
        engine.mainMixerNode.installTap(onBus: 0, bufferSize: 2048, format: nil) { buffer, _ in
            analyzer.consume(buffer)
        }
        player.volume = volume
    }
    func load(_ url: URL) throws {
        stop()
        let next = try AVAudioFile(forReading: url)
        guard next.length > 0, next.processingFormat.sampleRate > 0 else {
            throw AfterglowError.message("This audio file has no playable samples.")
        }
        file = next
        engine.disconnectNodeOutput(player)
        engine.connect(player, to: engine.mainMixerNode, format: next.processingFormat)
        startFrame = 0
    }
    func play() throws {
        guard file != nil else { return }
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [])
        try session.setActive(true)
        #endif
        if !engine.isRunning { try engine.start() }
        if player.isPlaying { return }
        if isPlaying { return }
        // A stopped engine/player needs a new schedule; a paused player retains its schedule.
        if !hasSchedule { schedule(from: startFrame) }
        player.play()
        isPlaying = true
    }
    private var hasSchedule = false
    private func schedule(from frame: AVAudioFramePosition) {
        guard let file else { return }
        generation = UUID()
        let token = generation
        player.stop()
        startFrame = min(max(0, frame), max(0, file.length - 1))
        // AVAudioFrameCount is UInt32; very long files are played as successive segments.
        let count = AVAudioFrameCount(min(file.length - startFrame, Int64(UInt32.max)))
        let segmentEnd = startFrame + Int64(count)
        player.scheduleSegment(file, startingFrame: startFrame, frameCount: count, at: nil,
                               completionCallbackType: .dataPlayedBack) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.generation == token else { return }
                if segmentEnd < file.length {
                    self.schedule(from: segmentEnd)
                    self.player.play()
                } else {
                    self.isPlaying = false; self.hasSchedule = false
                    self.startFrame = 0; self.player.stop()
                    self.onFinished?()
                }
            }
        }
        hasSchedule = true
    }
    func pause() { player.pause(); isPlaying = false }
    func seek(to seconds: Double) throws {
        guard let file, seconds.isFinite else { return }
        let wasPlaying = isPlaying
        schedule(from: AVAudioFramePosition(max(0, min(seconds, duration)) * file.processingFormat.sampleRate))
        if wasPlaying { player.play() }
    }
    func stop() {
        generation = UUID(); isPlaying = false; hasSchedule = false
        player.stop(); engine.stop(); startFrame = 0
    }
    func clear() { stop(); file = nil }
}

enum AfterglowError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case let .message(text) = self { return text }; return nil }
}
