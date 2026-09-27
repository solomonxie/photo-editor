import SwiftUI

struct TextPanel: View {
    let model: EditorModel
    @State private var tab: Tab = .font

    enum Tab: String, CaseIterable { case font, color, style, align }

    private var textLayer: (Layer, TextSpec)? {
        guard let layer = model.selectedLayer, case .text(let spec) = layer.content else { return nil }
        return (layer, spec)
    }

    var body: some View {
        ToolPanel {
            if let (layer, spec) = textLayer {
                Group {
                    switch tab {
                    case .font: fontRow(layer, spec)
                    case .color:
                        ColorSwatches(color: Binding(get: { spec.color }, set: { c in edit(layer) { $0.color = c } }))
                    case .style:
                        Segmented(options: TextSpec.Style.allCases, selection: Binding(
                            get: { spec.style }, set: { s in edit(layer) { $0.style = s } }
                        )) { $0.rawValue.capitalized }
                        .padding(.horizontal, 16)
                    case .align:
                        Segmented(options: TextSpec.Alignment.allCases, selection: Binding(
                            get: { spec.alignment }, set: { a in edit(layer) { $0.alignment = a } }
                        )) { a in
                            switch a {
                            case .leading: "Left"
                            case .center: "Center"
                            case .trailing: "Right"
                            }
                        }
                        .padding(.horizontal, 60)
                    }
                }
                .frame(height: 50)
                HStack {
                    Segmented(options: Tab.allCases, selection: $tab) { $0.rawValue.capitalized }
                    Button {
                        model.editingTextLayerID = layer.id
                    } label: {
                        Image(systemName: "keyboard")
                            .frame(width: 36, height: 32)
                    }
                    .accessibilityLabel("Edit text")
                }
                .padding(.horizontal, 16)
            } else {
                Button {
                    addText()
                } label: {
                    Label("Add Text", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
                Text("Tap text on the photo to select it.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            if textLayer == nil, !model.document.layers.contains(where: { if case .text = $0.content { true } else { false } }) {
                addText()
            }
        }
    }

    private func fontRow(_ layer: Layer, _ spec: TextSpec) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TextFont.allCases, id: \.self) { f in
                    Button {
                        edit(layer) { $0.font = f }
                    } label: {
                        Text(f.displayName)
                            .font(Font(LayerRasterizer.uiFont(f, size: 15)))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(spec.font == f ? Color.white.opacity(0.22) : Color.white.opacity(0.07),
                                        in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func edit(_ layer: Layer, _ change: @escaping (inout TextSpec) -> Void) {
        model.updateLayer(layer.id) { l in
            guard case .text(var spec) = l.content else { return }
            change(&spec)
            l.content = .text(spec)
        }
    }

    private func addText() {
        let layer = Layer(content: .text(TextSpec(string: "Your text")), width: 0.5)
        model.addLayer(layer)
        model.editingTextLayerID = layer.id
    }
}

/// Full-screen text entry over a dimmed canvas.
struct TextEditOverlay: View {
    let model: EditorModel
    let layerID: UUID
    @State private var text = ""
    @FocusState private var focused: Bool

    private var spec: TextSpec? {
        guard let l = model.document.layers.first(where: { $0.id == layerID }), case .text(let s) = l.content else { return nil }
        return s
    }

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
                .overlay(Color.black.opacity(0.45).ignoresSafeArea())
                .onTapGesture { finish() }
            VStack {
                HStack {
                    Spacer()
                    Button("Done") { finish() }
                        .font(.headline)
                        .padding(.horizontal, 20)
                        .frame(height: 48)
                }
                Spacer()
                TextField("", text: $text, prompt: Text("Your text").foregroundStyle(.white.opacity(0.4)), axis: .vertical)
                    .font(Font(LayerRasterizer.uiFont(spec?.font ?? .system, size: 34)))
                    .foregroundStyle(spec.map { Color(red: $0.color.r, green: $0.color.g, blue: $0.color.b) } ?? .white)
                    .multilineTextAlignment(.center)
                    .focused($focused)
                    .padding(.horizontal, 24)
                Spacer()
            }
        }
        .onAppear {
            let current = spec?.string ?? ""
            text = current == "Your text" ? "" : current
            focused = true
        }
    }

    private func finish() {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty {
            model.update { $0.layers.removeAll { $0.id == layerID } }
        } else {
            model.updateLayer(layerID) { l in
                guard case .text(var s) = l.content else { return }
                s.string = value
                l.content = .text(s)
            }
        }
        model.editingTextLayerID = nil
        model.redraw()
    }
}
