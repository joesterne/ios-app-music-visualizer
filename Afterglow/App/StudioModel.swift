import AVFoundation
import Combine
import MusicKit
import SwiftUI

@MainActor
final class StudioModel: ObservableObject {
    @Published var settings = VisualSettings.load() { didSet { settings.save() } }
    @Published private(set) var source: AudioSource = .ambient
    @Published private(set) var frame = AudioFrame.silent
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
    private let analyzer = AudioAnalyzer()
    private lazy var local = LocalAudioPlayer(analyzer: analyzer)
    private lazy var microphone = MicrophoneCapture(analyzer: analyzer)
    #if os(macOS)
    private lazy var system = MacAudioCapture(analyzer: analyzer)
    #endif
    private var ticker: AnyCancellable?
    private var lifecycleObservers: [NSObjectProtocol] = []
    private var active = true
    private var ticks = 0

    init() {
        local.onFinished = { [weak self] in Task { @MainActor in await self?.advanceLocal(forward: true, auto: true) } }
        #if os(macOS)
        system.onStopped = { [weak self] message in
            guard let self, self.source == .systemAudio else { return }
            self.error = "System audio capture stopped: \(message)"
            self.isPlaying = false; self.frame = .silent
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
        ticker = Timer.publish(every: 1.0 / 30, on: .main, in: .common).autoconnect().sink { [weak self] _ in
            self?.refresh()
        }
    }
    var modeLabel: String { source.reactive ? (isPlaying ? "LIVE AUDIO" : "AUDIO IDLE") : "AMBIENT MOTION" }
    var modeDescription: String {
        source.reactive ? "Measured audio • 64 frequency bands" : "Independent animation • not beat-synced"
    }
    var artworkURL: URL? { source == .appleMusic ? apple.artworkURL : nil }

    func changeSource(_ next: AudioSource) async {
        guard !busy, next != source else { return }
        busy = true; defer { busy = false }
        local.stop(); apple.pause(); microphone.stop()
        #if os(macOS)
        await system.stop()
        #endif
        analyzer.reset(); frame = .silent
        source = next; isPlaying = false; position = 0; duration = 0
        do {
            switch next {
            case .microphone:
                try await microphone.start(); isPlaying = true
            case .systemAudio:
                #if os(macOS)
                try await system.start(); isPlaying = true
                #endif
            default: break
            }
        } catch {
            self.error = error.localizedDescription
            source = .ambient
        }
        refreshMetadata()
    }
    func importFiles(_ urls: [URL]) async {
        guard !importing else { return }
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
        if let first { await playLocal(first) }
        if !failures.isEmpty { error = failures.joined(separator: "\n\n") }
    }
    func playLocal(_ track: LocalTrack) async {
        guard !busy else { return }
        await changeSource(.local)
        do {
            analyzer.reset()
            try local.load(track.url)
            selectedTrack = track.id
            try local.play()
            refreshMetadata()
        } catch { self.error = error.localizedDescription }
    }
    func removeTrack(_ track: LocalTrack) {
        if selectedTrack == track.id { local.clear(); selectedTrack = nil; isPlaying = false; frame = .silent }
        do {
            try LocalLibrary.remove(track)
            tracks.removeAll { $0.id == track.id }
            try LocalLibrary.save(tracks)
        } catch { self.error = error.localizedDescription }
        refreshMetadata()
    }
    func playApple(_ song: Song, queue: [Song], catalog: Bool) async {
        guard !busy else { return }
        await changeSource(.appleMusic)
        busy = true; defer { busy = false }
        do { try await apple.play(song, within: queue, fromCatalog: catalog) }
        catch { error = error.localizedDescription }
        refreshMetadata()
    }
    func togglePlayback() async {
        guard !busy else { return }
        do {
            switch source {
            case .local:
                if tracks.isEmpty { showImporter = true; return }
                if selectedTrack == nil, let track = tracks.first { await playLocal(track) }
                else if local.isPlaying { local.pause(); analyzer.reset(); frame = .silent }
                else { try local.play() }
            case .appleMusic: try await apple.toggle()
            case .microphone, .systemAudio:
                if isPlaying {
                    microphone.stop()
                    #if os(macOS)
                    await system.stop()
                    #endif
                    isPlaying = false; analyzer.reset(); frame = .silent
                } else {
                    busy = true; defer { busy = false }
                    if source == .microphone { try await microphone.start() }
                    else {
                        #if os(macOS)
                        try await system.start()
                        #endif
                    }
                    isPlaying = true
                }
            default: motionPaused.toggle()
            }
        } catch { self.error = error.localizedDescription }
        refreshMetadata()
    }
    func skip(forward: Bool) async {
        if source == .local { await advanceLocal(forward: forward, auto: false) }
        else if source == .appleMusic {
            do { try await apple.skip(forward: forward) } catch { self.error = error.localizedDescription }
        }
    }
    private func advanceLocal(forward: Bool, auto: Bool) async {
        guard source == .local, let index = tracks.firstIndex(where: { $0.id == selectedTrack }) else { return }
        let next = index + (forward ? 1 : -1)
        if tracks.indices.contains(next) { await playLocal(tracks[next]) }
        else if !auto, !tracks.isEmpty { await playLocal(forward ? tracks[0] : tracks[tracks.count - 1]) }
        else { analyzer.reset(); frame = .silent; refreshMetadata() }
    }
    func seek(_ seconds: Double) {
        do {
            if source == .local { try local.seek(to: seconds) }
            else if source == .appleMusic { apple.seek(to: seconds) }
        } catch { error = error.localizedDescription }
    }
    func setActive(_ value: Bool) async {
        active = value
        #if os(iOS)
        if !value {
            // This foreground visualizer intentionally does not request background microphone capture.
            if source == .microphone { microphone.stop(); isPlaying = false; frame = .silent }
            local.pause(); apple.pause()
            analyzer.reset(); frame = .silent
        }
        UIApplication.shared.isIdleTimerDisabled = value && immersive
        #endif
    }
    private func handleAudioInterruption() async {
        local.pause(); apple.pause()
        if source == .microphone { microphone.stop(); isPlaying = false }
        analyzer.reset(); frame = .silent
        refreshMetadata()
    }
    private func refresh() {
        guard active else { return }
        if source.reactive && isPlaying { frame = analyzer.snapshot() }
        ticks += 1
        if ticks % 6 == 0 { refreshMetadata() }
    }
    private func refreshMetadata() {
        switch source {
        case .local:
            isPlaying = local.isPlaying; position = local.position; duration = local.duration
            title = tracks.first(where: { $0.id == selectedTrack })?.title ?? "Import your first track"
            subtitle = "Local audio • measured spectrum"
        case .appleMusic:
            isPlaying = apple.isPlaying; position = apple.position; duration = apple.duration
            title = apple.title; subtitle = apple.artist
        case .microphone: title = "The sound around you"; subtitle = "Live input • no recording saved"
        case .systemAudio: title = "Your Mac, in color"; subtitle = "System audio • no recording saved"
        case .spotify: title = "Spotify companion"; subtitle = "Playback stays in Spotify • ambient visuals"
        case .other: title = "Bring your own soundtrack"; subtitle = "Playback stays in your music app"
        case .ambient: title = "Make room for the music."; subtitle = "Choose a source. Find your visual."
        }
    }
    func toggleFavorite(_ style: VisualizerStyle) {
        if settings.favorites.contains(style) { settings.favorites.removeAll { $0 == style } }
        else { settings.favorites.append(style) }
    }
}
