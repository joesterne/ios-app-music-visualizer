import SwiftUI

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView { InspectorView().padding(24) }.background(StudioTheme.background)
                .navigationTitle("Make it yours")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }.preferredColorScheme(.dark)
        #if os(macOS)
        .frame(width: 430, height: 710)
        #endif
    }
}

struct InspectorView: View {
    @EnvironmentObject private var model: StudioModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("ATMOSPHERE")
                Text("Make it yours.").font(.system(size: 22, weight: .light, design: .rounded))
            }
            if model.settings.style == .tron {
                TronControls()
            } else {
                VStack(alignment: .leading, spacing: 13) {
                    sectionLabel("COLOR PALETTE")
                    ForEach(VisualPalette.allCases) { palette in
                        Button { model.settings.palette = palette } label: {
                            HStack(spacing: 10) {
                                HStack(spacing: -4) {
                                    ForEach(0..<3, id: \.self) { index in Circle().fill(palette.colors[index]).frame(width: 15, height: 15) }
                                }
                                Text(palette.title).font(.system(size: 12))
                                Spacer()
                                if model.settings.palette == palette { Image(systemName: "checkmark").font(.system(size: 10)) }
                            }.foregroundStyle(model.settings.palette == palette ? .white : StudioTheme.muted)
                        }.buttonStyle(.plain)
                    }
                }
            }
            Divider()
            control("Sensitivity", value: $model.settings.sensitivity, range: 0.2...3, display: String(format: "%.1f×", model.settings.sensitivity))
            control("Motion speed", value: $model.settings.speed, range: 0.1...2, display: String(format: "%.1f×", model.settings.speed))
            control("Glow", value: $model.settings.glow, range: 0...1, display: "\(Int(model.settings.glow * 100))%")
            control("Detail", value: $model.settings.detail, range: 0.2...1, display: "\(Int(model.settings.detail * 100))%")
            VStack(alignment: .leading, spacing: 12) {
                sectionLabel("FRAME RATE")
                Picker("Frame rate", selection: $model.settings.fps) {
                    Text("30 fps").tag(30.0)
                    Text("60 fps").tag(60.0)
                }.pickerStyle(.segmented)
                Text("30 fps uses less power. Lower glow and detail for a lighter render.")
                    .font(.system(size: 10)).foregroundStyle(StudioTheme.muted)
            }
            Toggle("Pause visual motion", isOn: $model.motionPaused).font(.system(size: 12))
            if reduceMotion { Text("System Reduce Motion is on. Continuous movement is paused.").font(.system(size: 11)).foregroundStyle(StudioTheme.muted) }
            Divider()
            Text(model.modeDescription).font(.system(size: 11)).foregroundStyle(StudioTheme.muted)
            Button("Reset visual settings") { model.settings = .init() }.font(.system(size: 11)).buttonStyle(.bordered)
            Text("Audio stays on your device. Afterglow has no analytics, ads, or account server.")
                .font(.system(size: 10)).foregroundStyle(StudioTheme.muted)
        }
    }
    private func sectionLabel(_ text: String) -> some View {
        Text(text).font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(1.8).foregroundStyle(StudioTheme.muted)
    }
    private func control(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, display: String) -> some View {
        VStack(spacing: 10) {
            HStack {
                Text(title).font(.system(size: 12))
                Spacer()
                Text(display).font(.system(size: 10, design: .monospaced)).foregroundStyle(StudioTheme.muted)
            }
            Slider(value: value, in: range).accessibilityLabel(title)
        }
    }
}
