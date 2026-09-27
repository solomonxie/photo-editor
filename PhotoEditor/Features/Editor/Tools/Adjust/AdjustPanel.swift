import SwiftUI

extension AdjustKey: Identifiable {
    var id: String { rawValue }

    var title: String {
        switch self {
        case .exposure: "Exposure"
        case .brilliance: "Brilliance"
        case .brightness: "Brightness"
        case .contrast: "Contrast"
        case .highlights: "Highlights"
        case .shadows: "Shadows"
        case .saturation: "Saturation"
        case .vibrance: "Vibrance"
        case .warmth: "Warmth"
        case .tint: "Tint"
        case .sharpness: "Sharpness"
        case .vignette: "Vignette"
        case .grain: "Grain"
        }
    }
}

struct AdjustPanel: View {
    let model: EditorModel
    @State private var selected: AdjustKey? = .exposure

    var body: some View {
        ToolPanel {
            if let key = selected {
                ValueSlider(
                    title: key.title,
                    value: Binding(
                        get: { model.document.adjust[key] },
                        set: { v in model.live { $0.adjust[key] = v } }
                    ),
                    bipolar: key.isBipolar,
                    onBegin: model.beginGesture,
                    onEnd: model.endGesture
                )
                .padding(.horizontal, 20)
            }
            ChipRow(
                items: AdjustKey.allCases,
                selection: $selected,
                title: \.title,
                changed: { model.document.adjust[$0] != 0 },
                leading: AnyView(autoButton)
            )
        }
    }

    private var autoButton: some View {
        let on = model.document.adjust.auto
        return Button {
            model.update { $0.adjust.auto.toggle() }
        } label: {
            Label("Auto", systemImage: on ? "checkmark" : "wand.and.stars")
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(on ? Color.accentColor : Color.white.opacity(0.1), in: Capsule())
                .foregroundStyle(on ? .white : .primary)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
