import SwiftUI

struct TronControls: View {
    @EnvironmentObject private var model: StudioModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("TRON", systemImage: "cpu")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced)).tracking(2)
                    .foregroundStyle(model.settings.tronPalette.color)
                Spacer()
                Picker("Tron animation", selection: $model.settings.tronMode) {
                    ForEach(TronMode.allCases) { mode in Text(mode.title).tag(mode) }
                }.pickerStyle(.menu).labelsHidden().accessibilityLabel("Tron animation")
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { colorButtons }
                VStack(alignment: .leading, spacing: 4) { colorButtons }
            }
        }
        .padding(16)
        .background(StudioTheme.panel, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(model.settings.tronPalette.color.opacity(0.2)))
    }

    @ViewBuilder private var colorButtons: some View {
        ForEach(TronPalette.allCases) { palette in
            let selected = model.settings.tronPalette == palette
            Button { model.settings.tronPalette = palette } label: {
                HStack(spacing: 7) {
                    Circle().fill(palette.color).frame(width: 12, height: 12)
                    Text(palette.title).font(.system(size: 11, weight: selected ? .semibold : .regular))
                    if selected { Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)) }
                }
                .padding(.horizontal, 10).frame(minHeight: 44)
                .foregroundStyle(selected ? .white : StudioTheme.muted)
                .background(selected ? palette.color.opacity(0.14) : .clear, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Tron color, \(palette.title)")
            .accessibilityAddTraits(selected ? .isSelected : [])
        }
    }
}
