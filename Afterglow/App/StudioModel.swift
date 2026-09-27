import AVFoundation
import Combine
import MusicKit
import SwiftUI

@MainActor
final class StudioModel: ObservableObject {
    @Published var settings = VisualSettings()
    @Published private(set) var hasSavedPreferences = false
    @Published private(set) var preferenceStatus = "Save this setup to restore it at your next launch."
    @Published private(set) var source: AudioSource = .ambient
    @Published private(set) var tracks = LocalLibrary.read()
    @Published private(set) var selectedTrack: UUID?
    @Published private(set) var isPlaying = false
    @Published private(set) var position: Double = 0
    @Published private(set) var duration: Double = 0
    @Published private(set) var title = "Make room for the music."
    @Published private(set) var subtitle = "Choose a source. Find your visual."
    @Published private(set) var busy = false
    @Published private(set) var importing = false
    @Published var error: String?
    @Published var showSources = false
    @Published var showSettings = false
    @Published var showImporter = false
    @Published var immersive = false
    @Published var motionPaused = false
    @Published var volume: Double = 0.8 { didSet { local.volume = Float(volume) } }
    let apple = AppleMusicService()
    let analyzer = AudioAnalyzer()
    private lazy var local = LocalAudioPlayer(analyzer: analyzer)
    private lazy var microphone = MicrophoneCapture(analyzer: analyzer)
    #if os(macOS)
    private lazy var system = MacAudioCapture(analyzer: analyzer)
    #endif
    private var ticker: AnyCancellable?
    private var lifecycleObservers: [NSObjectProtocol] = []
    private var active = true
    private var sourceRevision = 0

    init() {
        if let saved = PreferenceStore.load() {
            hasSavedPreferences = true
            settings = saved.settings; volume = saved.volume; motionPaused = saved.motionPaused
            preferenceStatus = "Loaded preferences saved on this device."
        } else { settings = VisualSettings.load() }
        local.volume = Float(volume)
        local.onFinished = { [weak self] in Task { @MainActor in await self?.advanceLocal(forward: true, auto: true) } }
        #if os(macOS)
        system.onStopped = { [weak self] message in
            guard let self, self.source == .systemAudio else { return }
            self.error = "System audio capture stopped: \(message)"
            self.isPlaying = false; self.analyzer.reset()
        }
        #else
        lifecycleObservers.append(NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] notification in
            let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            guard raw == AVAudioSession.InterruptionType.began.rawValue else { return }
            Task { @MainActor in await self?.handleAudioInterruption() }
        })
        lifecycleObservers.append(NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main
        ) { [weak self] notification in
            let raw = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            guard raw == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue else { return }
            Task { @MainActor in await self?.handleAudioInterruption() }
        })
        #endif
    }
    var modeLabel: String { source.reactive ? (isPlaying ? "LIVE AUDIO" : "AUDIO IDLE") : "AMBIENT MOTION" }
    var hasPlayableQueue: Bool {
        source == .local ? selectedTrack != nil && !tracks.isEmpty : source == .appleMusic && apple.hasCurrentEntry
    }
    var modeDescription: String {
        source.reactive ? "Measured audio • 64 frequency bands" : "Independent animation • not beat-synced"
    }
    @Published private(set) var artworkURL: URL?

    func changeSource(_ next: AudioSource) async {
        guard !busy, next != source else { return }
        busy = true; defer { busy = false; refreshMetadata() }
        do { try await prepareSource(next) }
        catch { self.error = error.localizedDescription; source = .ambient; isPlaying = false }
    }
    private func prepareSource(_ next: AudioSource) async throws {
        guard next != source else { return }
        sourceRevision += 1
        local.stop(); apple.pause(); microphone.stop()
        #if os(macOS)
        await system.stop()
        #endif
        analyzer.reset()
        source = next; isPlaying = false; position = 0; duration = 0
            switch next {
            case .microphone:
                try await microphone.start(); isPlaying = true
            case .systemAudio:
                #if os(macOS)
                try await system.start(); isPlaying = true
                #endif
            default: break
            }
        #if os(iOS)
        if !active { microphone.stop(); isPlaying = false }
        #endif
    }
    func importFiles(_ urls: [URL]) async {
        guard !importing else { return }
        let revision = sourceRevision
        importing = true; defer { importing = false }
        var first: LocalTrack?
        var failures: [String] = []
        for url in urls {
            do {
                let track = try await LocalLibrary.importFile(url)
                tracks.append(track); if first == nil { first = track }
            } catch { failures.append(error.localizedDescription) }
        }
        do { try LocalLibrary.save(tracks) } catch { failures.append(error.localizedDescription) }
        if let first, revision == sourceRevision { await playLocal(first) }
        if !failures.isEmpty { error = failures.joined(separator: "\n\n") }
    }
    func playLocal(_ track: LocalTrack) async {
        guard !busy else { return }
        sourceRevision += 1
        busy = true; defer { busy = false; refreshMetadata() }
        do {
            try await prepareSource(.local)
            analyzer.reset()
            try local.load(track.url)
            selectedTrack = track.id
            try local.play()
            #if os(iOS)
            if !active { local.pause() }
            #endif
        } catch { local.clear(); selectedTrack = nil; self.error = error.localizedDescription }
    }
    func removeTrack(_ track: LocalTrack) {
        guard !busy, !importing else { return }
        if selectedTrack == track.id { local.clear(); selectedTrack = nil; isPlaying = false }
        do {
            try LocalLibrary.remove(track)
            tracks.removeAll { $0.id == track.id }
            try LocalLibrary.save(tracks)
        } catch { self.error = error.localizedDescription }
        refreshMetadata()
    }
    func playApple(_ song: Song, queue: [Song], catalog: Bool) async {
        guard !busy else { return }
        sourceRevision += 1
        busy = true; defer { busy = false; refreshMetadata() }
        do {
            try await prepareSource(.appleMusic)
            try await apple.play(song, within: queue, fromCatalog: catalog)
            #if os(iOS)
            if !active { apple.pause() }
            #endif
        }
        catch { self.error = error.localizedDescription }
        refreshMetadata()
    }
    func togglePlayback() async {
        guard !busy else { return }
        sourceRevision += 1
        if source == .appleMusic && (!apple.configured || !apple.authorized || !apple.hasCurrentEntry) {
            showSources = true; return
        }
        if source == .local && selectedTrack == nil {
            if let track = tracks.first { await playLocal(track) }
            else { showImporter = true }
            return
        }
        busy = true; defer { busy = false; refreshMetadata() }
        do {
            switch source {
            case .local:
                if tracks.isEmpty { showImporter = true; return }
                if local.isPlaying { local.pause(); analyzer.reset() }
                else { try local.play() }
            case .appleMusic: try await apple.toggle()
            case .microphone, .systemAudio:
                if isPlaying {
                    microphone.stop()
                    #if os(macOS)
                    await system.stop()
                    #endif
                    isPlaying = false; analyzer.reset()
                } else {
                    if source == .microphone { try await microphone.start() }
                    else {
                        #if os(macOS)
                        try await system.start()
                        #endif
                    }
                    isPlaying = true
                    #if os(iOS)
                    if !active { microphone.stop(); isPlaying = false }
                    #endif
                }
            default: motionPaused.toggle()
            }
        } catch { self.error = error.localizedDescription }
        refreshMetadata()
    }
    func skip(forward: Bool) async {
        guard !busy else { return }
        if source == .local { await advanceLocal(forward: forward, auto: false) }
        else if source == .appleMusic {
            guard apple.authorized else { showSources = true; return }
            busy = true; defer { busy = false; refreshMetadata() }
            do { try await apple.skip(forward: forward) } catch { self.error = error.localizedDescription }
        }
    }
    private func advanceLocal(forward: Bool, auto: Bool) async {
        guard source == .local, let index = tracks.firstIndex(where: { $0.id == selectedTrack }) else { return }
        let next = index + (forward ? 1 : -1)
        if tracks.indices.contains(next) { await playLocal(tracks[next]) }
        else if !auto, !tracks.isEmpty { await playLocal(forward ? tracks[0] : tracks[tracks.count - 1]) }
        else { analyzer.reset(); refreshMetadata() }
    }
    func seek(_ seconds: Double) {
        guard !busy, seconds.isFinite else { return }
        do {
            if source == .local { try local.seek(to: seconds) }
            else if source == .appleMusic { apple.seek(to: seconds) }
        } catch { self.error = error.localizedDescription }
    }
    func setActive(_ value: Bool) async {
        active = value
        #if os(iOS)
        if !value {
            // This foreground visualizer intentionally does not request background microphone capture.
            if source == .microphone { microphone.stop(); isPlaying = false }
            local.pause(); apple.pause()
            analyzer.reset()
        }
        UIApplication.shared.isIdleTimerDisabled = value && immersive
        #endif
        refreshMetadata()
    }
    private func handleAudioInterruption() async {
        local.pause(); apple.pause()
        if source == .microphone { microphone.stop(); isPlaying = false }
        analyzer.reset()
        refreshMetadata()
    }
    // Only playback metadata polls the model. Audio snapshots belong to the
    // visualizer's timeline, so they cannot invalidate the entire studio.
    private func updateTicker() {
        let needed = active && (source == .local || source == .appleMusic)
        guard needed else { ticker?.cancel(); ticker = nil; return }
        guard ticker == nil else { return }
        ticker = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect().sink { [weak self] _ in
            self?.refreshMetadata()
        }
    }
    private func assign<Value: Equatable>(_ value: Value, to keyPath: ReferenceWritableKeyPath<StudioModel, Value>) {
        if self[keyPath: keyPath] != value { self[keyPath: keyPath] = value }
    }
    private func refreshMetadata() {
        updateTicker()
        assign(source == .appleMusic ? apple.artworkURL : nil, to: \.artworkURL)
        switch source {
        case .local:
            assign(local.isPlaying, to: \.isPlaying); assign(local.position, to: \.position); assign(local.duration, to: \.duration)
            assign(tracks.first(where: { $0.id == selectedTrack })?.title ?? "Import your first track", to: \.title)
            assign("Local audio • measured spectrum", to: \.subtitle)
        case .appleMusic:
            assign(apple.isPlaying, to: \.isPlaying); assign(apple.position, to: \.position); assign(apple.duration, to: \.duration)
            assign(apple.title, to: \.title); assign(apple.artist, to: \.subtitle)
        case .microphone: assign("The sound around you", to: \.title); assign("Live input • no recording saved", to: \.subtitle)
        case .systemAudio: assign("Your Mac, in color", to: \.title); assign("System audio • no recording saved", to: \.subtitle)
        case .spotify: assign("Spotify companion", to: \.title); assign("Playback stays in Spotify • ambient visuals", to: \.subtitle)
        case .other: assign("Bring your own soundtrack", to: \.title); assign("Playback stays in your music app", to: \.subtitle)
        case .ambient: assign("Make room for the music.", to: \.title); assign("Choose a source. Find your visual.", to: \.subtitle)
        }
    }
    func toggleFavorite(_ style: VisualizerStyle) {
        if settings.favorites.contains(style) { settings.favorites.removeAll { $0 == style } }
        else { settings.favorites.append(style) }
    }

    func savePreferences() {
        do {
            try PreferenceStore.save(SavedPreferences(settings: settings, volume: volume, motionPaused: motionPaused))
            hasSavedPreferences = true
            preferenceStatus = "Preferences saved locally. They will load at your next launch."
        } catch { preferenceStatus = "Could not save preferences: \(error.localizedDescription)" }
    }
    func restorePreferences() {
        guard let saved = PreferenceStore.load() else {
            hasSavedPreferences = false; preferenceStatus = "No valid saved preferences on this device."; return
        }
        settings = saved.settings; volume = saved.volume; motionPaused = saved.motionPaused
        preferenceStatus = "Restored your locally saved preferences."
    }
    func resetPreferences() {
        settings = .init(); volume = 0.8; motionPaused = false
        preferenceStatus = "Defaults restored. Your saved preferences are unchanged."
    }
    func forgetPreferences() {
        PreferenceStore.forget(); hasSavedPreferences = false
        preferenceStatus = "Saved preferences removed. Current settings and audio files are unchanged."
    }
}
