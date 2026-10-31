import AVFoundation
import Combine
import MusicKit
import SwiftUI

// Compile the production StudioModel against deterministic audio/account doubles.
// No account, microphone permission, audio device, or user's library is accessed.
@MainActor final class AppleMusicService: ObservableObject {
    var authorized = true
    let configured = true
    var hasCurrentEntry = true
    var currentEntryID: String? = "entry-1"
    var isPlaying = false
    var title = "Test song", artist = "Test artist"
    var position = 12.0, duration = 180.0
    var artworkURL: URL? = nil
    var lastMicrophoneActive = false
    func play(_ song: Song, within songs: [Song], fromCatalog: Bool, microphoneActive: Bool = false) async throws {
        lastMicrophoneActive = microphoneActive; isPlaying = true
    }
    func toggle(microphoneActive: Bool = false) async throws {
        lastMicrophoneActive = microphoneActive; isPlaying.toggle()
    }
    func prepareAudioSession(microphoneActive: Bool) throws { lastMicrophoneActive = microphoneActive }
    func pause() { isPlaying = false }
    func skip(forward: Bool) async throws {}
    func seek(to value: Double) { position = value }
    func clearSession() { authorized = false; isPlaying = false; hasCurrentEntry = false; currentEntryID = nil }
}
@MainActor final class MicrophoneCapture {
    static var running = false
    static var alongsidePlayback = false
    static var deny = false
    static var holdPermission = false
    static var pending: CheckedContinuation<Void, Never>?
    static var deactivatedSession = false
    static var starts = 0
    init(analyzer: AudioAnalyzer) {}
    func start(alongsidePlayback: Bool = false, isCurrent: () -> Bool = { true }) async throws {
        Self.alongsidePlayback = alongsidePlayback
        if Self.holdPermission { await withCheckedContinuation { Self.pending = $0 } }
        if Self.deny { throw AfterglowError.message("Microphone denied") }
        guard isCurrent() else { throw CancellationError() }
        Self.starts += 1
        Self.running = true
    }
    func stop(deactivateSession: Bool = true) {
        Self.running = false; Self.deactivatedSession = deactivateSession
    }
}
@MainActor final class LocalAudioPlayer {
    init(analyzer: AudioAnalyzer) {}
    var onFinished: (() -> Void)?
    var volume: Float = 0.8
    var isPlaying = false
    var position = 0.0, duration = 0.0
    func stop() { isPlaying = false }
    func pause() { isPlaying = false }
    func clear() { isPlaying = false }
    func load(_ url: URL) throws {}
    func play() throws { isPlaying = true }
    func seek(to value: Double) throws {}
}
@MainActor final class MacAudioCapture {
    init(analyzer: AudioAnalyzer) {}
    var onStopped: ((String) -> Void)?
    func stop() async {}
    func start() async throws {}
}
struct LocalTrack: Identifiable {
    let id: UUID
    let title: String
    let url: URL
}
enum LocalLibrary {
    static func read() -> [LocalTrack] { [] }
    static func save(_ tracks: [LocalTrack]) throws {}
    static func remove(_ track: LocalTrack) throws {}
    static func importFile(_ url: URL) async throws -> LocalTrack {
        LocalTrack(id: UUID(), title: "Test file", url: url)
    }
}
enum AfterglowError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case let .message(text) = self { return text }; return nil }
}

@main enum AudioResponseRegression {
    @MainActor static func main() async throws {
        let model = StudioModel()
        model.settings.audioReactive = false
        await model.changeSource(.appleMusic)
        assert(!model.visualsReactive && !model.visualAudioActive)
        await model.toggleMicrophoneResponse()
        assert(model.microphoneResponseActive && model.visualsReactive && model.visualAudioActive)
        assert(MicrophoneCapture.running && MicrophoneCapture.alongsidePlayback)
        assert(!model.isPlaying, "The microphone must work independently of MusicKit transport")
        assert(model.modeLabel == "LIVE MICROPHONE")
        await model.togglePlayback()
        assert(model.apple.isPlaying && model.apple.lastMicrophoneActive)
        await model.togglePlayback()
        assert(!model.apple.isPlaying && model.visualAudioActive)
        verifyMeasuredLevels(model.analyzer)
        await model.toggleMicrophoneResponse()
        assert(!model.visualAudioActive && !model.visualsReactive && !MicrophoneCapture.running)
        assert(!MicrophoneCapture.deactivatedSession, "Stopping microphone response must preserve Apple Music")
        assert(model.analyzer.snapshot().bands.allSatisfy { $0 == 0 })

        for source: AudioSource in [.spotify, .other] {
            await model.changeSource(source)
            await model.toggleMicrophoneResponse()
            assert(model.source == source && model.visualsReactive && model.visualAudioActive)
            assert(!model.isPlaying, "External playback has no app transport state")
            model.settings.audioReactive = false
            assert(!model.visualsReactive && model.visualAudioActive)
            await model.toggleMicrophoneResponse()
            assert(!MicrophoneCapture.running)
        }
        await model.changeSource(.spotify)
        MicrophoneCapture.deny = true
        await model.toggleMicrophoneResponse()
        assert(!model.microphoneResponseActive && !model.visualsReactive && model.error != nil)
        MicrophoneCapture.deny = false
        model.error = nil
        await model.toggleMicrophoneResponse()
        await model.changeSource(.ambient)
        assert(!MicrophoneCapture.running && !model.visualAudioActive)
        await model.toggleMicrophoneResponse()
        assert(!MicrophoneCapture.running, "Ambient must not start a microphone")

        await model.changeSource(.appleMusic)
        await model.toggleMicrophoneResponse()
        model.disconnectAppleMusic()
        assert(!MicrophoneCapture.running && !model.microphoneResponseActive)
        await model.changeSource(.spotify)
        await model.toggleMicrophoneResponse()
        await model.setActive(false)
        assert(!MicrophoneCapture.running && !model.microphoneResponseActive)
        await model.setActive(true)
        assert(!MicrophoneCapture.running, "Foregrounding must not silently resume capture")

        // A late permission response after leaving the app must not open an input.
        MicrophoneCapture.holdPermission = true
        let starts = MicrophoneCapture.starts
        let pending = Task { await model.toggleMicrophoneResponse() }
        while MicrophoneCapture.pending == nil { await Task.yield() }
        await model.updateScenePhase(.background)
        MicrophoneCapture.pending?.resume(); MicrophoneCapture.pending = nil
        await pending.value
        assert(MicrophoneCapture.starts == starts && !model.microphoneResponseActive)
        assert(model.error == nil)
        await model.setActive(true)

        // Inactive caused by the permission sheet itself is not a cancellation.
        let granted = Task { await model.toggleMicrophoneResponse() }
        while MicrophoneCapture.pending == nil { await Task.yield() }
        await model.updateScenePhase(.inactive)
        MicrophoneCapture.pending?.resume(); MicrophoneCapture.pending = nil
        await granted.value
        assert(model.microphoneResponseActive && model.visualAudioActive)
        MicrophoneCapture.holdPermission = false
        await model.changeSource(.ambient)
        print("PASS: streaming input routing; Apple playback/session flags; independent capture activity; denial; disconnect; source changes; background/permission races; measured amplitude and frequency response.")
    }
    static func verifyMeasuredLevels(_ analyzer: AudioAnalyzer) {
        let format = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 16384)!
        buffer.frameLength = buffer.frameCapacity
        func feed(_ frequency: Double, _ amplitude: Float) -> AudioFrame {
            for i in 0..<Int(buffer.frameLength) {
                buffer.floatChannelData![0][i] = amplitude * Float(sin(2 * Double.pi * frequency * Double(i) / 48000))
            }
            analyzer.consume(buffer)
            return analyzer.snapshot()
        }
        let quiet = feed(1000, 0.02)
        let loud = feed(1000, 0.5)
        assert(loud.rms > quiet.rms * 20)
        assert(loud.bands.max()! > quiet.bands.max()! + 0.3)
        analyzer.reset()
        let bass = feed(90, 0.5)
        analyzer.reset()
        let treble = feed(10000, 0.5)
        let peak: (AudioFrame) -> Int = { frame in frame.bands.indices.max(by: { frame.bands[$0] < frame.bands[$1] })! }
        assert(peak(treble) > peak(bass) + 30)
        for _ in 0..<8 { _ = feed(1000, 0) }
        assert(analyzer.snapshot().rms == 0)
        assert(analyzer.snapshot().bands.allSatisfy { $0 < 0.0001 })
    }
}
