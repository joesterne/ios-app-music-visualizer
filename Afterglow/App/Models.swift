import SwiftUI

enum AudioSource: String, CaseIterable, Identifiable {
    case ambient, local, appleMusic, spotify, microphone, systemAudio, other
    var id: String { rawValue }
    static var available: [AudioSource] {
        #if os(macOS)
        allCases
        #else
        allCases.filter { $0 != .systemAudio }
        #endif
    }
    var title: String {
        switch self {
        case .ambient: "Ambient studio"
        case .local: "Your audio files"
        case .appleMusic: "Apple Music"
        case .spotify: "Spotify companion"
        case .microphone: "Microphone / input"
        case .systemAudio: "Mac system audio"
        case .other: "Other music apps"
        }
    }
    var symbol: String {
        switch self {
        case .ambient: "sparkles"
        case .local: "folder.fill"
        case .appleMusic: "music.note"
        case .spotify: "arrow.up.forward.app"
        case .microphone: "mic.fill"
        case .systemAudio: "desktopcomputer"
        case .other: "square.stack.3d.up"
        }
    }
    var reactive: Bool { self == .local || self == .microphone || self == .systemAudio }
    var detail: String {
        switch self {
        case .ambient: "Explore every visual without connecting music."
        case .local: "Import unprotected audio for a live spectrum and waveform."
        case .appleMusic: "Search and play with MusicKit. Visuals use ambient motion."
        case .spotify: "Open Spotify and return here for independent ambient visuals."
        case .microphone: "React to your room, speakers, or an external audio input."
        case .systemAudio: "React to audio macOS allows this app to capture."
        case .other: "Launch another service and enjoy ambient visuals."
        }
    }
}

enum VisualizerStyle: String, CaseIterable, Identifiable, Codable {
    case aurora, spectrum, orbit, waveform, tunnel, constellation, terrain, bloom
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var subtitle: String {
        switch self {
        case .aurora: "Ribbons of light"
        case .spectrum: "Every frequency, in color"
        case .orbit: "Sound in circular motion"
        case .waveform: "The shape of a moment"
        case .tunnel: "An infinite escape"
        case .constellation: "A sky of connections"
        case .terrain: "Ride the frequency landscape"
        case .bloom: "Let the sound unfold"
        }
    }
    var symbol: String {
        switch self {
        case .aurora: "wind"
        case .spectrum: "chart.bar.xaxis"
        case .orbit: "circle.hexagongrid"
        case .waveform: "waveform.path"
        case .tunnel: "square.stack.3d.down.forward"
        case .constellation: "sparkles"
        case .terrain: "mountain.2"
        case .bloom: "camera.macro"
        }
    }
}

enum VisualPalette: String, CaseIterable, Identifiable, Codable {
    case ultraviolet, glacier, ember, candy, monochrome
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var colors: [Color] {
        switch self {
        case .ultraviolet: [Color(hex: 0x91A1FF), Color(hex: 0xCB79FF), Color(hex: 0xF3B0E6)]
        case .glacier: [Color(hex: 0x55DCD9), Color(hex: 0x68B2FF), Color(hex: 0xC6FFF2)]
        case .ember: [Color(hex: 0xFF9760), Color(hex: 0xF25D86), Color(hex: 0xFFE0A3)]
        case .candy: [Color(hex: 0xFF80C7), Color(hex: 0x868BFF), Color(hex: 0x57EEE0)]
        case .monochrome: [Color(hex: 0xD1D7E6), Color(hex: 0xFFFFFF), Color(hex: 0x737F99)]
        }
    }
    var accent: Color { colors[0] }
}

struct VisualSettings: Codable, Equatable {
    var style: VisualizerStyle = .aurora
    var palette: VisualPalette = .ultraviolet
    var sensitivity: Double = 1.25
    var speed: Double = 0.65
    var glow: Double = 0.6
    var detail: Double = 0.65
    var fps: Double = 60
    var favorites: [VisualizerStyle] = [.aurora, .orbit]
    static func load() -> VisualSettings {
        guard let data = UserDefaults.standard.data(forKey: "visualSettings.v1"),
              var value = try? JSONDecoder().decode(Self.self, from: data) else { return .init() }
        value.sensitivity = value.sensitivity.isFinite ? min(3, max(0.2, value.sensitivity)) : 1.25
        value.speed = value.speed.isFinite ? min(2, max(0.1, value.speed)) : 0.65
        value.glow = value.glow.isFinite ? min(1, max(0, value.glow)) : 0.6
        value.detail = value.detail.isFinite ? min(1, max(0.2, value.detail)) : 0.65
        value.fps = value.fps == 30 ? 30 : 60
        return value
    }
    func save() { if let data = try? JSONEncoder().encode(self) { UserDefaults.standard.set(data, forKey: "visualSettings.v1") } }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 255) / 255,
                  green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1)
    }
}
enum StudioTheme {
    static let background = Color(hex: 0x090B13)
    static let panel = Color(hex: 0x11141F)
    static let raised = Color(hex: 0x1A1E2D)
    static let muted = Color(hex: 0x939BAC)
    static let line = Color.white.opacity(0.08)
}
