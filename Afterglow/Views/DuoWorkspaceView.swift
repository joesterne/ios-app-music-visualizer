import SwiftUI

#if os(iOS)
/// Xcode 27.1 SDK required. The OS owns fold/camera regions and pose transitions.
@available(iOS 27.1, *)
struct DuoWorkspaceView: View {
    @EnvironmentObject private var model: StudioModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    let clock: VisualizerClock

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                if horizontalSizeClass == .regular {
                    // Keep this outside a ScrollView: the arrangement follows the
                    // system's division regions in book and tabletop poses.
                    ArrangementView {
                        scene
                    } secondary: {
                        ScrollView { StudioControlDeck(focused: model.immersive).padding(16) }
                            .background(StudioTheme.panel)
                    }
                    .arrangementViewStyle(.split)
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            scene.frame(height: model.immersive
                                ? max(210, geometry.size.height - 100)
                                : max(180, min(400, geometry.size.width * (verticalSizeClass == .compact ? 0.42 : 0.76))))
                            if !model.immersive { StudioControlDeck(focused: false, includesPlayer: false) }
                        }.padding(12)
                    }
                    .safeAreaInset(edge: .bottom, spacing: 0) { PlayerBar(compact: true) }
                }
            }
            .background(StudioTheme.background)
            .navigationTitle("afterglow")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { model.showSources = true } label: { Image(systemName: "music.note.list") }
                        .accessibilityLabel("Music sources")
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { model.showSettings = true } label: { Image(systemName: "slider.horizontal.3") }
                        .accessibilityLabel("All visual settings")
                    Button { model.immersive.toggle() } label: {
                        Image(systemName: model.immersive ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                    }.accessibilityLabel(model.immersive ? "Exit focus mode" : "Focus on the visualizer")
                }
            }
        }
    }

    private var scene: some View {
        GeometryReader { _ in
            ZStack(alignment: .bottomLeading) {
                VisualizerCanvas(style: model.settings.style, palette: model.settings.palette,
                                 analyzer: model.analyzer, playing: model.isPlaying,
                                 reactive: model.source.reactive, settings: model.settings,
                                 paused: model.motionPaused, clock: clock)
                    .equatable()
                LinearGradient(colors: [.clear, .black.opacity(0.58)], startPoint: .center, endPoint: .bottom)
                    .allowsHitTesting(false)
                VStack(alignment: .leading, spacing: 5) {
                    Text(model.settings.visualTitle).font(.system(size: 30, weight: .light, design: .rounded))
                    Text(model.settings.visualSubtitle).font(.footnote).foregroundStyle(.white.opacity(0.8))
                }.padding(20).allowsHitTesting(false)
            }
            .overlay(alignment: .topLeading) { SignalBadge().padding(14) }
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .padding(8)
    }
}
#endif

/// The same settings and playback model are used by every layout.
struct StudioControlDeck: View {
    @EnvironmentObject private var model: StudioModel
    var focused = false
    var includesPlayer = true

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if includesPlayer { PlayerBar(compact: true).clipShape(RoundedRectangle(cornerRadius: 16)) }
            HStack {
                Text(focused ? "IN THE MOMENT" : "YOUR CONTROL DECK")
                    .font(.system(size: 10, weight: .medium, design: .monospaced)).tracking(1.8)
                    .foregroundStyle(StudioTheme.muted)
                Spacer()
                Button { model.motionPaused.toggle() } label: {
                    Image(systemName: model.motionPaused ? "play.fill" : "pause.fill").frame(width: 44, height: 44)
                }.buttonStyle(.bordered)
                    .accessibilityLabel(model.motionPaused ? "Resume visual motion" : "Pause visual motion")
            }
            if model.settings.style == .tron { TronControls() }
            if !focused {
                Text("Find your atmosphere.").font(.system(size: 24, weight: .light, design: .rounded))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(VisualizerStyle.allCases) { style in VisualizerCard(style: style) }
                    }.padding(.bottom, 4)
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { paletteButtons }
                    ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 8) { paletteButtons } }
                }
                slider("Motion", value: $model.settings.speed, range: 0.1...2)
                slider("Glow", value: $model.settings.glow, range: 0...1)
                Button { model.showSources = true } label: {
                    Label("Choose music", systemImage: "music.note.list").frame(maxWidth: .infinity, minHeight: 44)
                }.buttonStyle(.bordered)
                Text(model.modeDescription).font(.footnote).foregroundStyle(StudioTheme.muted)
            }
        }
    }
    private var paletteButtons: some View {
        ForEach(VisualPalette.allCases) { palette in
            Button { model.settings.palette = palette } label: {
                Circle().fill(palette.accent).frame(width: 22, height: 22)
                    .frame(width: 44, height: 44)
                    .background(model.settings.palette == palette ? Color.white.opacity(0.14) : .clear, in: Circle())
            }.buttonStyle(.plain).accessibilityLabel("\(palette.title) palette")
                .accessibilityAddTraits(model.settings.palette == palette ? .isSelected : [])
        }
    }
    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.subheadline)
                Spacer()
                Text(value.wrappedValue, format: .number.precision(.fractionLength(1)))
                    .font(.system(.caption, design: .monospaced)).foregroundStyle(StudioTheme.muted)
            }
            Slider(value: value, in: range).accessibilityLabel(title)
        }
    }
}
