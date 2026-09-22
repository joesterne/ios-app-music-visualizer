import SwiftUI
import UniformTypeIdentifiers

struct StudioView: View {
    @EnvironmentObject private var model: StudioModel
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        GeometryReader { geometry in
            let wide = geometry.size.width > 1000
            ZStack {
                StudioTheme.background.ignoresSafeArea()
                if model.immersive {
                    ImmersiveView()
                } else {
                    VStack(spacing: 0) {
                        topBar(wide: wide)
                        Rectangle().fill(StudioTheme.line).frame(height: 1)
                        HStack(spacing: 0) {
                            if wide {
                                SourceSidebar().frame(width: 220)
                                Rectangle().fill(StudioTheme.line).frame(width: 1)
                            }
                            ScrollView {
                                VStack(alignment: .leading, spacing: 24) {
                                    stageHeader
                                    visualStage(height: wide ? max(270, min(530, geometry.size.height - 360)) : min(430, max(260, geometry.size.width * 0.84)))
                                    if model.settings.style == .tron { TronControls() }
                                    gallery
                                }
                                .padding(wide ? 28 : 20)
                            }
                            if geometry.size.width > 1350 {
                                Rectangle().fill(StudioTheme.line).frame(width: 1)
                                ScrollView { InspectorView().padding(24) }.frame(width: 260)
                            }
                        }
                        Rectangle().fill(StudioTheme.line).frame(height: 1)
                        PlayerBar(compact: geometry.size.width < 650)
                    }
                }
            }
            .tint(model.settings.accent)
            .preferredColorScheme(.dark)
            .fileImporter(isPresented: $model.showImporter, allowedContentTypes: [.audio], allowsMultipleSelection: true) { result in
                switch result {
                case .success(let urls): Task { await model.importFiles(urls) }
                case .failure(let error): model.error = error.localizedDescription
                }
            }
            .sheet(isPresented: $model.showSources) { SourceSheet() }
            .sheet(isPresented: $model.showSettings) { SettingsSheet() }
            .alert("Afterglow", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
                Button("OK") { model.error = nil }
            } message: { Text(model.error ?? "") }
            .onChange(of: scenePhase) { _, phase in Task { await model.setActive(phase == .active) } }
            .onChange(of: model.immersive) { _, _ in Task { await model.setActive(scenePhase == .active) } }
        }
    }
    private func topBar(wide: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform.path").font(.system(size: 24, weight: .light)).foregroundStyle(model.settings.accent)
            Text("afterglow").font(.system(size: 23, weight: .semibold, design: .rounded)).tracking(-0.8)
            if wide {
                Text("A SPACE FOR SOUND").font(.system(size: 9, weight: .semibold, design: .monospaced)).tracking(2.5)
                    .foregroundStyle(StudioTheme.muted).padding(.leading, 20)
            }
            Spacer()
            if !wide {
                Button { model.showSources = true } label: {
                    Image(systemName: model.source.symbol).frame(width: 36, height: 36)
                }.buttonStyle(.plain).accessibilityLabel("Music sources")
            }
            Button { model.showSettings = true } label: {
                Image(systemName: "slider.horizontal.3").frame(width: 36, height: 36)
            }.buttonStyle(.plain).accessibilityLabel("Visual settings")
        }
        .padding(.horizontal, 24).padding(.vertical, 18)
    }
    private var stageHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 5) {
                Text("YOUR LISTENING ROOM").font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(2)
                    .foregroundStyle(StudioTheme.muted)
                Text("Find your frequency.").font(.system(size: 27, weight: .medium, design: .rounded)).tracking(-0.7)
            }
            Spacer(minLength: 8)
            Button { model.showSources = true } label: {
                Image(systemName: "plus").font(.system(size: 16, weight: .medium))
                    .frame(width: 40, height: 40).background(StudioTheme.raised, in: Circle())
            }.buttonStyle(.plain).accessibilityLabel("Add music")
        }
    }
    private func visualStage(height: Double) -> some View {
        ZStack {
            VisualizerCanvas(style: model.settings.style, palette: model.settings.palette, frame: model.frame,
                             reactive: model.source.reactive, settings: model.settings, paused: model.motionPaused)
            VStack(alignment: .leading) {
                HStack {
                    SignalBadge()
                    Spacer()
                    Button { model.toggleFavorite(model.settings.style) } label: {
                        Image(systemName: model.settings.favorites.contains(model.settings.style) ? "heart.fill" : "heart")
                            .foregroundStyle(model.settings.accent).frame(width: 36, height: 36)
                    }.buttonStyle(.plain).accessibilityLabel("Toggle favorite visualizer")
                }
                Spacer()
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(model.settings.visualTitle).font(.system(size: 30, weight: .light, design: .rounded))
                        Text(model.settings.visualSubtitle).font(.system(size: 11)).foregroundStyle(StudioTheme.muted)
                    }
                    Spacer()
                    Button { model.immersive = true } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right").frame(width: 40, height: 40)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }.buttonStyle(.plain).accessibilityLabel("Expand visualizer")
                }
            }.padding(22)
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(StudioTheme.line, lineWidth: 1))
    }
    private var gallery: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Text("VISUALIZERS").font(.system(size: 10, weight: .semibold, design: .monospaced)).tracking(2)
                Spacer()
                Text(String(format: "%02d / CHOOSE YOUR MOOD", VisualizerStyle.allCases.count)).font(.system(size: 8, design: .monospaced)).tracking(1).foregroundStyle(StudioTheme.muted)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(VisualizerStyle.allCases) { style in VisualizerCard(style: style) }
                }.padding(.bottom, 3)
            }
        }
    }
}

struct VisualizerCard: View {
    @EnvironmentObject private var model: StudioModel
    var style: VisualizerStyle
    var body: some View {
        Button { model.settings.style = style } label: {
            VStack(alignment: .leading, spacing: 9) {
                VisualizerCanvas(style: style, palette: model.settings.palette, frame: .silent, reactive: false,
                                 settings: model.settings, preview: true)
                    .frame(width: 132, height: 77).clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(
                        model.settings.style == style ? model.settings.accent.opacity(0.8) : StudioTheme.line,
                        lineWidth: model.settings.style == style ? 1.5 : 1))
                HStack {
                    Text(style.title).font(.system(size: 11, weight: model.settings.style == style ? .semibold : .regular))
                    Spacer()
                    if model.settings.favorites.contains(style) { Image(systemName: "heart.fill").font(.system(size: 8)) }
                }.foregroundStyle(model.settings.style == style ? .white : StudioTheme.muted)
            }.frame(width: 132)
        }.buttonStyle(.plain).accessibilityLabel("\(style.title), \(style.subtitle)")
            .accessibilityAddTraits(model.settings.style == style ? .isSelected : [])
    }
}

struct SourceSidebar: View {
    @EnvironmentObject private var model: StudioModel
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("SOUND SOURCES").font(.system(size: 9, weight: .medium, design: .monospaced))
                .tracking(2).foregroundStyle(StudioTheme.muted).padding(.horizontal, 12)
            VStack(spacing: 6) {
                ForEach(AudioSource.available) { source in
                    Button {
                        Task {
                            await model.changeSource(source)
                            if source == .local || source == .appleMusic || source == .spotify || source == .other { model.showSources = true }
                        }
                    } label: {
                        HStack(spacing: 11) {
                            Image(systemName: source.symbol).frame(width: 20)
                            Text(source.title).font(.system(size: 12))
                            Spacer(minLength: 0)
                            if model.source == source { Circle().fill(model.settings.accent).frame(width: 5, height: 5) }
                        }
                        .padding(.horizontal, 12).padding(.vertical, 13)
                        .background(model.source == source ? StudioTheme.raised : .clear, in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(model.source == source ? .white : StudioTheme.muted)
                    }.buttonStyle(.plain).disabled(model.busy)
                }
            }
            Divider().overlay(StudioTheme.line)
            Text("FAVORITES").font(.system(size: 9, weight: .medium, design: .monospaced))
                .tracking(2).foregroundStyle(StudioTheme.muted).padding(.horizontal, 12)
            ForEach(model.settings.favorites) { style in
                Button { model.settings.style = style } label: {
                    Label(style.title, systemImage: style.symbol).font(.system(size: 12)).foregroundStyle(StudioTheme.muted)
                }.buttonStyle(.plain).padding(.horizontal, 12)
            }
            Spacer()
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "headphones").font(.system(size: 19, weight: .light)).foregroundStyle(model.settings.accent)
                Text("Less noise.\nMore feeling.").font(.system(size: 17, weight: .light, design: .rounded))
                Text("Your music. Your atmosphere.").font(.system(size: 10)).foregroundStyle(StudioTheme.muted)
            }.padding(14)
        }.padding(.horizontal, 14).padding(.vertical, 27).background(StudioTheme.panel.opacity(0.45))
    }
}

struct SignalBadge: View {
    @EnvironmentObject private var model: StudioModel
    var body: some View {
        HStack(spacing: 7) {
            Circle().fill(model.source.reactive && model.isPlaying ? Color(hex: 0x7DE0B9) : model.settings.accent)
                .frame(width: 5, height: 5)
            Text(model.modeLabel).font(.system(size: 8, weight: .medium, design: .monospaced)).tracking(1.2)
        }.padding(.horizontal, 11).padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .accessibilityLabel(model.modeDescription)
    }
}

struct ImmersiveView: View {
    @EnvironmentObject private var model: StudioModel
    @State private var showControls = true
    var body: some View {
        ZStack {
            VisualizerCanvas(style: model.settings.style, palette: model.settings.palette, frame: model.frame,
                             reactive: model.source.reactive, settings: model.settings, paused: model.motionPaused)
                .ignoresSafeArea().contentShape(Rectangle()).onTapGesture { showControls.toggle() }
            if showControls {
                VStack {
                    HStack {
                        SignalBadge()
                        Spacer()
                        Button { model.immersive = false } label: {
                            Image(systemName: "arrow.down.right.and.arrow.up.left").frame(width: 44, height: 44)
                                .background(.ultraThinMaterial, in: Circle())
                        }.buttonStyle(.plain).keyboardShortcut(.escape, modifiers: []).accessibilityLabel("Exit immersive mode")
                    }
                    Spacer()
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(model.title).font(.system(size: 19, weight: .medium)).lineLimit(1)
                            Text(model.modeDescription).font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Menu {
                            if model.settings.style == .tron {
                                Picker("Tron animation", selection: $model.settings.tronMode) {
                                    ForEach(TronMode.allCases) { mode in Text(mode.title).tag(mode) }
                                }
                                Picker("Tron color", selection: $model.settings.tronPalette) {
                                    ForEach(TronPalette.allCases) { palette in Text(palette.title).tag(palette) }
                                }
                                Divider()
                            }
                            ForEach(VisualizerStyle.allCases) { style in
                                Button(style.title) { model.settings.style = style }
                            }
                        } label: { Image(systemName: "square.grid.2x2").frame(width: 44, height: 44) }
                        Button { model.motionPaused.toggle() } label: {
                            Image(systemName: model.motionPaused ? "play.fill" : "pause.fill").frame(width: 44, height: 44)
                        }.buttonStyle(.plain).accessibilityLabel(model.motionPaused ? "Resume visual motion" : "Pause visual motion")
                    }.padding(18).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
                }.padding(24)
            } else {
                // A persistent exit remains available to keyboard and assistive technologies.
                VStack { HStack { Spacer(); Button("Show controls") { showControls = true }.keyboardShortcut(.escape, modifiers: []) }; Spacer() }
                    .padding().opacity(0.25)
            }
        }
    }
}
