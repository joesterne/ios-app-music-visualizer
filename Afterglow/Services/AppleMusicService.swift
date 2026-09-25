import AVFoundation
import Combine
import MusicKit

@MainActor
final class AppleMusicService: ObservableObject {
    @Published private(set) var authorized = false
    @Published private(set) var busy = false
    @Published private(set) var results: [Song] = []
    @Published private(set) var library: [Song] = []
    @Published private(set) var canPlayCatalog = false
    @Published var error: String?
    private lazy var player = ApplicationMusicPlayer.shared
    private var requestGeneration = UUID()
    private var libraryOffset = 0
    @Published private(set) var hasMoreLibrary = true

    let configured = (Bundle.main.object(forInfoDictionaryKey: "AfterglowMusicKitEnabled") as? String) == "YES"
    var isPlaying: Bool { configured && authorized && player.state.playbackStatus == .playing }
    var title: String { configured ? (authorized ? player.queue.currentEntry?.title ?? "Choose a song" : "Connect Apple Music") : "Apple Music setup" }
    var artist: String { configured && authorized ? player.queue.currentEntry?.subtitle ?? "Apple Music" : "Open music sources to connect" }
    var position: Double { configured && authorized ? player.playbackTime : 0 }
    var duration: Double {
        guard configured, authorized, let item = player.queue.currentEntry?.item else { return 0 }
        if case let .song(song) = item { return song.duration ?? 0 }
        return 0
    }
    var artworkURL: URL? { configured && authorized ? player.queue.currentEntry?.artwork?.url(width: 160, height: 160) : nil }

    func connect() async {
        guard configured else {
            error = "Enable MusicKit in Config/App.xcconfig and on your Apple Developer App IDs. The README includes the exact steps."
            return
        }
        guard !busy else { return }
        busy = true; defer { busy = false }
        authorized = await MusicAuthorization.request() == .authorized
        guard authorized else {
            error = "Allow Afterglow access to Media & Apple Music in Settings, then reconnect."
            return
        }
        do {
            canPlayCatalog = try await MusicSubscription.current.canPlayCatalogContent
            try await fetchLibrary(reset: true)
        } catch { self.error = error.localizedDescription }
    }
    func search(_ text: String) async {
        guard authorized else { return }
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let token = UUID(); requestGeneration = token
        if query.isEmpty { results = []; return }
        do {
            var request = MusicCatalogSearchRequest(term: query, types: [Song.self])
            request.limit = 25
            let response = try await request.response()
            guard requestGeneration == token, !Task.isCancelled else { return }
            results = Array(response.songs)
        } catch {
            guard requestGeneration == token, !Task.isCancelled else { return }
            self.error = error.localizedDescription
        }
    }
    func loadMoreLibrary() async {
        guard authorized, !busy, hasMoreLibrary else { return }
        busy = true; defer { busy = false }
        do { try await fetchLibrary(reset: false) } catch { self.error = error.localizedDescription }
    }
    private func fetchLibrary(reset: Bool) async throws {
        if reset { libraryOffset = 0; library = [] }
        var request = MusicLibraryRequest<Song>()
        request.limit = 100; request.offset = libraryOffset
        let response = try await request.response()
        let page = Array(response.items)
        library.append(contentsOf: page)
        libraryOffset += page.count
        hasMoreLibrary = page.count == 100
    }
    func play(_ song: Song, within songs: [Song], fromCatalog: Bool) async throws {
        guard configured, authorized else { throw AfterglowError.message("Connect Apple Music first.") }
        if fromCatalog && !canPlayCatalog {
            throw AfterglowError.message("An active Apple Music subscription is required to play catalog songs.")
        }
        guard song.playParameters != nil else {
            throw AfterglowError.message("Apple Music can’t play this song with the current account or in this region.")
        }
        #if os(iOS)
        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
        try AVAudioSession.sharedInstance().setActive(true)
        #endif
        player.queue = ApplicationMusicPlayer.Queue(for: songs.isEmpty ? [song] : songs, startingAt: song)
        try await player.play()
    }
    func toggle() async throws {
        guard configured, authorized else { throw AfterglowError.message("Open Music Sources and connect Apple Music before using playback controls.") }
        if isPlaying { player.pause() } else { try await player.play() }
    }
    func skip(forward: Bool) async throws {
        guard configured, authorized else { throw AfterglowError.message("Open Music Sources and connect Apple Music before using playback controls.") }
        if forward { try await player.skipToNextEntry() } else { try await player.skipToPreviousEntry() }
    }
    func pause() { if configured { player.pause() } }
    func seek(to value: Double) { if configured { player.playbackTime = max(0, min(value, duration)) } }
    func clearSession() {
        pause(); results = []; library = []; authorized = false
        if configured { player.queue = ApplicationMusicPlayer.Queue(for: [Song]()) }
        requestGeneration = UUID(); libraryOffset = 0
    }
}
