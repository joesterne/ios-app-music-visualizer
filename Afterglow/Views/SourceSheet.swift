import MusicKit
import SwiftUI
import UniformTypeIdentifiers

struct SourceSheet: View {
    @EnvironmentObject private var model: StudioModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var importPresented = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Bring the soundtrack.").font(.system(size: 28, weight: .medium, design: .rounded))
                        Text("Choose where your sound comes from.").foregroundStyle(StudioTheme.muted)
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 12)], spacing: 12) {
                        ForEach(AudioSource.available) { source in
                            Button { Task { await model.changeSource(source) } } label: {
                                VStack(alignment: .leading, spacing: 9) {
                                    Image(systemName: source.symbol).font(.system(size: 22, weight: .light))
                                    Text(source.title).font(.system(size: 12, weight: .medium))
                                    Text(source.reactive ? "AUDIO REACTIVE" : "AMBIENT").font(.system(size: 8, design: .monospaced)).tracking(1)
                                        .foregroundStyle(StudioTheme.muted)
                                }.frame(maxWidth: .infinity, minHeight: 85, alignment: .leading).padding(16)
                                    .background(model.source == source ? model.settings.palette.accent.opacity(0.12) : StudioTheme.panel,
                                                in: RoundedRectangle(cornerRadius: 14))
                                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(model.source == source ? model.settings.palette.accent : StudioTheme.line))
                            }.buttonStyle(.plain).disabled(model.busy)
                        }
                    }
                    if model.busy { ProgressView("Preparing audio…").frame(maxWidth: .infinity) }
                    Text(model.source.detail).font(.system(size: 13)).foregroundStyle(StudioTheme.muted)
                    sourceDetail
                }.padding(24)
            }
            .background(StudioTheme.background)
            .navigationTitle("Music sources")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .fileImporter(isPresented: $importPresented, allowedContentTypes: [.audio], allowsMultipleSelection: true) { result in
                switch result {
                case .success(let urls): Task { await model.importFiles(urls) }
                case .failure(let error): model.error = error.localizedDescription
                }
            }
        }
        .tint(model.settings.palette.accent).preferredColorScheme(.dark)
        #if os(macOS)
        .frame(minWidth: 600, idealWidth: 700, minHeight: 650)
        #endif
    }
    @ViewBuilder private var sourceDetail: some View {
        switch model.source {
        case .local:
            Button { importPresented = true } label: { Label(model.importing ? "Importing…" : "Import audio files", systemImage: "plus") }
                .buttonStyle(.borderedProminent).disabled(model.importing)
            if model.tracks.isEmpty {
                ContentUnavailableView("Your collection starts here", systemImage: "music.note.list",
                                       description: Text("Choose unprotected WAV, MP3, AAC, AIFF, or ALAC files. Imports stay on this device."))
            } else {
                VStack(spacing: 0) {
                    ForEach(model.tracks) { track in
                        HStack(spacing: 12) {
                            Button { Task { await model.playLocal(track) } } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: model.selectedTrack == track.id && model.isPlaying ? "waveform" : "play.circle")
                                        .foregroundStyle(model.settings.palette.accent)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(track.title).font(.system(size: 13, weight: .medium)).lineLimit(2)
                                        Text("\(Int(track.duration) / 60):\(String(format: "%02d", Int(track.duration) % 60)) • Local file")
                                            .font(.system(size: 10)).foregroundStyle(StudioTheme.muted)
                                    }
                                    Spacer()
                                }.contentShape(Rectangle())
                            }.buttonStyle(.plain).disabled(model.busy)
                            Menu {
                                Button("Remove imported copy", role: .destructive) { model.removeTrack(track) }
                            } label: { Image(systemName: "ellipsis").frame(width: 32, height: 40) }
                            .menuStyle(.borderlessButton).fixedSize()
                        }.padding(.vertical, 12)
                        Divider()
                    }
                }
            }
        case .appleMusic:
            AppleMusicPanel(service: model.apple)
        case .spotify:
            VStack(alignment: .leading, spacing: 16) {
                Text("Your Spotify session stays in Spotify. Start your music there, return to Afterglow, and choose a visual. The animation runs independently of the track.")
                    .font(.system(size: 13)).foregroundStyle(StudioTheme.muted)
                Button { openURL(URL(string: "https://open.spotify.com/")!) } label: {
                    Label("Open Spotify", systemImage: "arrow.up.right")
                }.buttonStyle(.borderedProminent)
                Text("No Spotify login, playback control, or audio analysis is performed by this companion mode.")
                    .font(.system(size: 11)).foregroundStyle(StudioTheme.muted)
            }
        case .other:
            VStack(spacing: 10) {
                ForEach(ExternalService.all) { service in
                    Link(destination: service.url) {
                        HStack { Text(service.name); Spacer(); Image(systemName: "arrow.up.right") }
                            .font(.system(size: 13)).padding(16).background(StudioTheme.panel, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                Text("Playback stays in the selected service. Use ambient visuals here, or live input for sound played through speakers. Capturable system audio is also available on Mac.")
                    .font(.system(size: 11)).foregroundStyle(StudioTheme.muted).padding(.top, 8)
            }
        case .microphone:
            VStack(alignment: .leading, spacing: 15) {
                Text("Afterglow listens to the selected system input. There is no audio monitoring, recording, or upload. On iPhone, this hears music in your room; it cannot read another app’s digital audio or music in headphones.")
                    .font(.system(size: 13)).foregroundStyle(StudioTheme.muted)
                captureButton
                LevelMeter(level: Double(model.frame.rms) * 4)
            }
        case .systemAudio:
            VStack(alignment: .leading, spacing: 15) {
                Text("Allow Screen & System Audio Recording when macOS asks. Play audio in another app, then return here. Protected content may provide silence. Afterglow excludes its own playback and discards screen frames; it saves no capture.")
                    .font(.system(size: 13)).foregroundStyle(StudioTheme.muted)
                captureButton
                LevelMeter(level: Double(model.frame.rms) * 4)
            }
        case .ambient:
            VStack(alignment: .leading, spacing: 15) {
                Text("An always-ready visual playground. Ambient motion is generated locally and is not synchronized to music.")
                    .font(.system(size: 13)).foregroundStyle(StudioTheme.muted)
                Button("Explore visualizers") { dismiss() }.buttonStyle(.borderedProminent)
            }
        }
    }
    private var captureButton: some View {
        Button { Task { await model.togglePlayback() } } label: {
            Label(model.isPlaying ? "Stop listening" : "Start listening", systemImage: model.isPlaying ? "stop.fill" : "mic.fill")
        }.buttonStyle(.borderedProminent).disabled(model.busy)
    }
}

private struct ExternalService: Identifiable {
    var name: String
    var address: String
    var id: String { name }
    var url: URL { URL(string: address)! }
    static let all = [
        Self(name: "YouTube Music", address: "https://music.youtube.com/"),
        Self(name: "TIDAL", address: "https://listen.tidal.com/"),
        Self(name: "SoundCloud", address: "https://soundcloud.com/"),
        Self(name: "Amazon Music", address: "https://music.amazon.com/"),
        Self(name: "Bandcamp", address: "https://bandcamp.com/")
    ]
}

private struct AppleMusicPanel: View {
    @EnvironmentObject private var model: StudioModel
    @ObservedObject var service: AppleMusicService
    @State private var query = ""
    private var songs: [Song] { query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? service.library : service.results }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !service.authorized {
                Text(service.configured ? "Connect your Apple Music account to browse your library and search the catalog." : "Apple Music needs a signed MusicKit build. Enable it with the setup steps in the project’s README; all other modes work without it.")
                    .font(.system(size: 13)).foregroundStyle(StudioTheme.muted)
                Button(service.configured ? "Connect Apple Music" : "Show setup requirements") { Task { await service.connect() } }
                    .buttonStyle(.borderedProminent).disabled(service.busy)
            } else {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(StudioTheme.muted)
                    TextField("Search Apple Music", text: $query).textFieldStyle(.plain)
                    if !query.isEmpty { Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain) }
                }.padding(14).background(StudioTheme.panel, in: RoundedRectangle(cornerRadius: 12))
                HStack {
                    Text(query.isEmpty ? "YOUR LIBRARY" : "CATALOG • TOP 25").font(.system(size: 9, design: .monospaced)).tracking(1.5)
                    Spacer()
                    Button("Disconnect") { service.clearSession() }.font(.system(size: 11))
                }
                if service.busy { ProgressView() }
                if songs.isEmpty && !service.busy {
                    Text(query.isEmpty ? "Your library is empty. Search for a song above." : "No results yet. Try a title or artist.")
                        .font(.system(size: 13)).foregroundStyle(StudioTheme.muted).padding(.vertical, 20)
                }
                ForEach(songs, id: \.id) { song in
                    Button { Task { await model.playApple(song, queue: songs, catalog: !query.isEmpty) } } label: {
                        HStack(spacing: 12) {
                            if let artwork = song.artwork { ArtworkImage(artwork, width: 44, height: 44).clipShape(RoundedRectangle(cornerRadius: 6)) }
                            else { Image(systemName: "music.note").frame(width: 44, height: 44).background(StudioTheme.panel) }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(song.title).font(.system(size: 13, weight: .medium)).lineLimit(1)
                                Text(song.artistName).font(.system(size: 11)).foregroundStyle(StudioTheme.muted).lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "play.circle").foregroundStyle(model.settings.palette.accent)
                        }.contentShape(Rectangle()).padding(.vertical, 4)
                    }.buttonStyle(.plain).disabled(model.busy)
                }
                if query.isEmpty && service.hasMoreLibrary {
                    Button("Load more songs") { Task { await service.loadMoreLibrary() } }.disabled(service.busy)
                }
            }
            Text("Apple Music playback uses ambient visuals. MusicKit does not provide PCM samples to this app’s analyzer.")
                .font(.system(size: 11)).foregroundStyle(StudioTheme.muted)
        }
        .task(id: query) {
            do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
            await service.search(query)
        }
        .alert("Apple Music", isPresented: Binding(get: { service.error != nil }, set: { if !$0 { service.error = nil } })) {
            Button("OK") { service.error = nil }
        } message: { Text(service.error ?? "") }
    }
}

struct LevelMeter: View {
    var level: Double
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<32, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2).fill(Double(index) / 32 < level ? Color(hex: 0x7DE0B9) : StudioTheme.raised)
                    .frame(height: 18)
            }
        }.accessibilityLabel("Audio level \(Int(min(1, max(0, level)) * 100)) percent")
    }
}
