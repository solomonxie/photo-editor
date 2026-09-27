import SwiftUI

/// Editor slider: bipolar (−100…100, centre detent) or unipolar (0…100).
/// Double-tap resets; a haptic ticks when passing the default.
struct ValueSlider: View {
    let title: String
    @Binding var value: Double
    var bipolar = true
    var suffix = ""
    var onBegin: () -> Void = {}
    var onEnd: () -> Void = {}

    @State private var dragStart: Double?
    private var range: ClosedRange<Double> { bipolar ? -100...100 : 0...100 }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(label)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(value == 0 ? .secondary : .primary)
            }
            GeometryReader { geo in
                track(width: geo.size.width)
            }
            .frame(height: 28)
        }
        .accessibilityElement()
        .accessibilityLabel(title)
        .accessibilityValue(label)
        .accessibilityAdjustableAction { dir in
            onBegin()
            value = min(range.upperBound, max(range.lowerBound, value + (dir == .increment ? 5 : -5)))
            onEnd()
        }
    }

    private var label: String {
        let v = Int(value.rounded())
        return bipolar && v > 0 ? "+\(v)\(suffix)" : "\(v)\(suffix)"
    }

    private func track(width: CGFloat) -> some View {
        let span = range.upperBound - range.lowerBound
        let x = CGFloat((value - range.lowerBound) / span) * width
        let origin = bipolar ? width / 2 : 0
        return ZStack(alignment: .leading) {
            Capsule().fill(.white.opacity(0.18)).frame(height: 3)
            Rectangle()
                .fill(Color.accentColor)
                .frame(width: abs(x - origin), height: 3)
                .offset(x: min(x, origin))
            if bipolar {
                Rectangle().fill(.white.opacity(0.5)).frame(width: 1.5, height: 10).offset(x: width / 2 - 0.75)
            }
            Circle()
                .fill(.white)
                .frame(width: 22, height: 22)
                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                .offset(x: x - 11)
        }
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { g in
                    if dragStart == nil {
                        dragStart = value
                        onBegin()
                    }
                    // Relative drag so grabbing off-centre doesn't jump the value.
                    let delta = Double(g.translation.width / width) * span
                    var new = (dragStart ?? value) + delta
                    new = min(range.upperBound, max(range.lowerBound, new))
                    let defaultValue = 0.0
                    if abs(new - defaultValue) < span * 0.012 { new = defaultValue }
                    if (value - defaultValue).sign != (new - defaultValue).sign || (new == defaultValue && value != defaultValue) {
                        UISelectionFeedbackGenerator().selectionChanged()
                    }
                    value = new.rounded()
                }
                .onEnded { _ in
                    dragStart = nil
                    onEnd()
                }
        )
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                onBegin()
                value = 0
                onEnd()
            }
        )
    }
}
