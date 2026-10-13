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
            VisualizerCustomizationControls()
            Divider()
            control("Sensitivity", value: $model.settings.sensitivity, range: 0.2...3, display: String(format: "%.1f×", model.settings.sensitivity))
            if !model.settings.style.supportsCustomization {
                control("Motion speed", value: $model.settings.speed, range: 0.1...2, display: String(format: "%.1f×", model.settings.speed))
            }
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
            VStack(alignment: .leading, spacing: 12) {
                sectionLabel("LOCAL PREFERENCES")
                Button("Save preferences locally") { model.savePreferences() }.buttonStyle(.borderedProminent)
                Button("Restore saved preferences") { model.restorePreferences() }
                    .buttonStyle(.bordered).disabled(!model.hasSavedPreferences)
                Button("Reset to defaults") { model.resetPreferences() }.buttonStyle(.bordered)
                Button("Forget saved preferences", role: .destructive) { model.forgetPreferences() }
                    .disabled(!model.hasSavedPreferences)
                Text(model.preferenceStatus).font(.footnote).foregroundStyle(StudioTheme.muted)
                Text("Saves your visual, palette, favorites, sliders, frame rate, volume, and motion pause on this device. Press Save again to keep later changes. Audio files and accounts are not part of this preset.")
                    .font(.caption).foregroundStyle(StudioTheme.muted)
            }
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

/// A separate preset for each abstract/themed visualizer; all layouts share the model.
struct VisualizerCustomizationControls: View {
    @EnvironmentObject private var model: StudioModel
    @Environment(\.self) private var environment
    private var current: VisualizerCustomization { model.settings.customization(for: model.settings.style) }
    private func update(_ change: (inout VisualizerCustomization) -> Void) {
        var value = current; change(&value)
        model.settings.customizations[model.settings.style.rawValue] = value.validated()
    }
    private func hex(_ color: Color) -> UInt32 {
        let value = color.resolve(in: environment)
        func byte(_ component: Float) -> UInt32 { UInt32((min(1, max(0, component)) * 255).rounded()) }
        return byte(value.red) << 16 | byte(value.green) << 8 | byte(value.blue)
    }
    private var defaults: [UInt32] { model.settings.defaultColors(for: model.settings.style).map(hex) }
    var body: some View {
        if model.settings.style.supportsCustomization {
            VStack(alignment: .leading, spacing: 12) {
                Text("Customize \(model.settings.style.title)").font(.headline)
                Toggle("Custom colors", isOn: Binding(get: { current.colors != nil }, set: { enabled in
                    update { $0.colors = enabled ? defaults : nil }
                }))
                if current.colors != nil {
                    ForEach(0..<(model.settings.style == .tron ? 1 : 3), id: \.self) { index in
                        ColorPicker(["Primary color", "Secondary color", "Highlight color"][index], selection: Binding(get: {
                            Color(hex: (current.colors ?? defaults)[index])
                        }, set: { color in update { $0.colors = $0.colors ?? defaults; $0.colors?[index] = hex(color) } }), supportsOpacity: false)
                    }
                }
                HStack { Text("Scene speed"); Spacer(); Text(String(format: "%.2f×", model.settings.motionSpeed)).monospacedDigit() }
                Slider(value: $model.settings.motionSpeed, in: 0.1...2, step: 0.05).accessibilityLabel("Scene speed")
                HStack { Text("Scene size"); Spacer(); Text("\(Int(current.size * 100))%").monospacedDigit() }
                Slider(value: Binding(get: { current.size }, set: { size in update { $0.size = size } }), in: 0.5...1.5, step: 0.05)
                    .accessibilityLabel("Scene size")
                Text("Size zooms the scene around its center. Larger scenes may extend beyond the edges.")
                    .font(.caption).foregroundStyle(StudioTheme.muted)
                Button("Reset \(model.settings.style.title) customization") {
                    model.settings.customizations.removeValue(forKey: model.settings.style.rawValue)
                }.buttonStyle(.bordered)
                Text("Only this visualizer changes. Use Save preferences locally to keep your setup.")
                    .font(.caption).foregroundStyle(StudioTheme.muted)
            }
        }
    }
}
