import SwiftUI

/// A horizontally scrolling row of text chips; the selected one is bold with an underline.
struct ChipRow<Item: Identifiable & Hashable>: View {
    let items: [Item]
    @Binding var selection: Item?
    let title: (Item) -> String
    var changed: (Item) -> Bool = { _ in false }
    var leading: AnyView? = nil

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 18) {
                    if let leading { leading }
                    ForEach(items) { item in
                        let selected = item == selection
                        Button {
                            withAnimation(.snappy(duration: 0.2)) { selection = item }
                        } label: {
                            VStack(spacing: 4) {
                                HStack(spacing: 3) {
                                    Text(title(item))
                                        .font(.subheadline.weight(selected ? .semibold : .regular))
                                    if changed(item) {
                                        Circle().fill(Color.accentColor).frame(width: 5, height: 5)
                                    }
                                }
                                Capsule()
                                    .fill(selected ? Color.accentColor : .clear)
                                    .frame(height: 2)
                            }
                            .foregroundStyle(selected ? .primary : .secondary)
                            .fixedSize()
                        }
                        .buttonStyle(.plain)
                        .id(item)
                    }
                }
                .padding(.horizontal, 16)
            }
            .onChange(of: selection) { _, new in
                if let new { withAnimation { proxy.scrollTo(new, anchor: .center) } }
            }
        }
    }
}

/// A pill-style segmented control that reads well on the dark editor.
struct Segmented<T: Hashable>: View {
    let options: [T]
    @Binding var selection: T
    let title: (T) -> String

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { option in
                let selected = option == selection
                Button {
                    withAnimation(.snappy(duration: 0.2)) { selection = option }
                } label: {
                    Text(title(option))
                        .font(.footnote.weight(selected ? .semibold : .regular))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .frame(maxWidth: .infinity)
                        .background(selected ? Color.white.opacity(0.18) : .clear, in: Capsule())
                        .foregroundStyle(selected ? .primary : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Color.white.opacity(0.07), in: Capsule())
    }
}

struct ToolPanel<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 12) {
            content
        }
        .frame(maxWidth: .infinity)
        .frame(height: ToolPanelMetrics.height, alignment: .center)
    }
}

enum ToolPanelMetrics {
    static let height: CGFloat = 136
}

struct ToastView: View {
    let toast: ToastMessage

    var body: some View {
        HStack(spacing: 14) {
            Text(toast.text)
                .font(.subheadline.weight(.medium))
            if let title = toast.actionTitle, let action = toast.action {
                Button(title, action: action)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.25), radius: 8, y: 2)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

struct ColorSwatches: View {
    @Binding var color: RGBA
    var palette: [RGBA] = RGBA.palette

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(palette, id: \.self) { c in
                    Button {
                        color = c
                    } label: {
                        Circle()
                            .fill(Color(red: c.r, green: c.g, blue: c.b))
                            .frame(width: 28, height: 28)
                            .overlay(Circle().strokeBorder(.white.opacity(color == c ? 1 : 0.25), lineWidth: color == c ? 2.5 : 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Color")
                }
                ColorPicker("", selection: Binding(
                    get: { Color(red: color.r, green: color.g, blue: color.b) },
                    set: { c in
                        let ui = UIColor(c)
                        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
                        color = RGBA(r: r, g: g, b: b)
                    }
                ), supportsOpacity: false)
                .labelsHidden()
            }
            .padding(.horizontal, 16)
        }
    }
}
