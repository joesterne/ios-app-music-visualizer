import SwiftUI

struct PlayerBar: View {
    @EnvironmentObject private var model: StudioModel
    var compact: Bool
    @State private var seekPosition: Double = 0
    @State private var isSeeking = false
    private var hasTransport: Bool { model.source == .local || model.source == .appleMusic }
    private var playing: Bool { model.source.reactive || model.source == .appleMusic ? model.isPlaying : !model.motionPaused }
    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 14) {
                artwork
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.title).font(.system(size: 12, weight: .medium)).lineLimit(1)
                    Text(model.subtitle).font(.system(size: 10)).foregroundStyle(StudioTheme.muted).lineLimit(1)
                }.frame(maxWidth: .infinity, alignment: .leading)
                if !compact { Spacer(minLength: 20) }
                transport
                if !compact {
                    Spacer(minLength: 20)
                    if model.source == .local {
                        Image(systemName: "speaker.wave.2").font(.system(size: 12)).foregroundStyle(StudioTheme.muted)
                        Slider(value: $model.volume, in: 0...1).frame(width: 95).accessibilityLabel("Local playback volume")
                    } else {
                        Text(model.source.reactive ? (model.isPlaying ? "LIVE INPUT" : "INPUT STOPPED") : "AMBIENT").font(.system(size: 8, design: .monospaced))
                            .tracking(1).foregroundStyle(StudioTheme.muted)
                    }
                    #if os(macOS)
                    Button { model.showVolumeMixer = true } label: {
                        Image(systemName: "slider.vertical.3")
                            .font(.system(size: 13))
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open Mac volume mixer")
                    #endif
                }
            }
            if hasTransport && model.duration > 0 {
                HStack(spacing: 10) {
                    Text(time(isSeeking ? seekPosition : model.position))
                    Slider(value: Binding(get: { isSeeking ? seekPosition : model.position }, set: { seekPosition = $0 }),
                           in: 0...max(1, model.duration)) { editing in
                        if editing { seekPosition = model.position; isSeeking = true }
                        else { model.seek(seekPosition); isSeeking = false }
                    }.accessibilityLabel("Playback position")
                    Text(time(model.duration))
                }.font(.system(size: 9, design: .monospaced)).foregroundStyle(StudioTheme.muted)
            }
        }.padding(.horizontal, compact ? 20 : 28).padding(.vertical, compact ? 14 : 18)
            .background(StudioTheme.panel)
            #if os(macOS)
            .sheet(isPresented: $model.showVolumeMixer) {
                MacVolumeMixerSheet()
            }
            #endif
    }
    private var artwork: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10).fill(model.settings.palette.accent.opacity(0.12))
            if let url = model.artworkURL {
                AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { Image(systemName: "music.note") }
            } else { Image(systemName: model.source.symbol).font(.system(size: 18, weight: .light)).foregroundStyle(model.settings.palette.accent) }
        }.frame(width: 44, height: 44).clipShape(RoundedRectangle(cornerRadius: 10)).accessibilityHidden(true)
    }
    private var transport: some View {
        HStack(spacing: compact ? 8 : 20) {
            if hasTransport {
                Button { Task { await model.skip(forward: false) } } label: {
                    Image(systemName: "backward.end.fill").font(.system(size: 13)).frame(width: 30, height: 40)
                }.buttonStyle(.plain).accessibilityLabel("Previous track").disabled(model.busy || !model.hasPlayableQueue)
            }
            Button { Task { await model.togglePlayback() } } label: {
                Image(systemName: playing ? "pause.fill" : "play.fill").font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(StudioTheme.background).frame(width: 42, height: 42)
                    .background(model.settings.palette.accent, in: Circle())
            }.buttonStyle(.plain).disabled(model.busy)
                .accessibilityLabel(hasTransport ? (playing ? "Pause playback" : "Play") : model.source.reactive ? "Toggle audio capture" : "Toggle ambient motion")
            if hasTransport {
                Button { Task { await model.skip(forward: true) } } label: {
                    Image(systemName: "forward.end.fill").font(.system(size: 13)).frame(width: 30, height: 40)
                }.buttonStyle(.plain).accessibilityLabel("Next track").disabled(model.busy || !model.hasPlayableQueue)
            }
        }
    }
    private func time(_ value: Double) -> String {
        let seconds = value.isFinite ? max(0, Int(value)) : 0
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}


#if os(macOS)
private struct MacVolumeMixerSheet: View {
    @EnvironmentObject private var model: StudioModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var output = MacOutputVolume()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Volume mixer").font(.title3.weight(.semibold))
                    Text("Afterglow and your current Mac output")
                        .font(.subheadline)
                        .foregroundStyle(StudioTheme.muted)
                }
                Spacer()
                Button("Done") { dismiss() }
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Afterglow playback", systemImage: "music.note")
                        .font(.headline)
                    HStack(spacing: 12) {
                        Image(systemName: "speaker.fill")
                            .foregroundStyle(StudioTheme.muted)
                        Slider(value: $model.volume, in: 0...1)
                            .accessibilityLabel("Afterglow local playback volume")
                        Text(model.volume, format: .percent.precision(.fractionLength(0)))
                            .monospacedDigit()
                            .frame(width: 42, alignment: .trailing)
                    }
                    Text("Applies to audio files played inside Afterglow.")
                        .font(.caption)
                        .foregroundStyle(StudioTheme.muted)
                }
                .padding(.vertical, 4)
            } label: {
                Text("Afterglow")
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("Mac output", systemImage: "speaker.wave.3")
                            .font(.headline)
                        Spacer()
                        Button {
                            output.refresh()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Refresh Mac output volume")
                    }

                    if output.isAvailable {
                        HStack(spacing: 12) {
                            Image(systemName: "speaker.fill")
                                .foregroundStyle(StudioTheme.muted)
                            Slider(
                                value: Binding(
                                    get: { output.volume },
                                    set: { output.setVolume($0) }
                                ),
                                in: 0...1
                            )
                            .accessibilityLabel("Mac output volume")
                            Text(output.volume, format: .percent.precision(.fractionLength(0)))
                                .monospacedDigit()
                                .frame(width: 42, alignment: .trailing)
                        }
                    }

                    Text(output.status)
                        .font(.caption)
                        .foregroundStyle(StudioTheme.muted)
                }
                .padding(.vertical, 4)
            } label: {
                Text("Mac output")
            }

            Text("This adjusts the system volume for the selected macOS output device, not the volume of other individual apps.")
                .font(.caption)
                .foregroundStyle(StudioTheme.muted)
        }
        .padding(24)
        .frame(width: 410)
        .onAppear { output.refresh() }
    }
}
#endif
