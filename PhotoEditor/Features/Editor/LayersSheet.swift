import SwiftUI

struct LayersSheet: View {
    let model: EditorModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(model.document.layers.reversed()) { layer in
                        row(layer)
                    }
                    .onMove(perform: move)
                    baseRow
                } footer: {
                    if model.document.layers.isEmpty {
                        Text("Copy a cutout as a sticker to get layers.")
                    }
                }
                if let layer = model.selectedLayer {
                    Section("Opacity") {
                        HStack {
                            Slider(value: Binding(
                                get: { layer.opacity * 100 },
                                set: { v in model.updateLayer(layer.id, live: true) { $0.opacity = v / 100 } }
                            ), in: 0...100) { editing in
                                editing ? model.beginGesture() : model.endGesture()
                            }
                            Text("\(Int((layer.opacity * 100).rounded()))%")
                                .monospacedDigit()
                                .frame(width: 48, alignment: .trailing)
                        }
                    }
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Layers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func row(_ layer: Layer) -> some View {
        let selected = model.selectedLayerID == layer.id
        return HStack(spacing: 12) {
            LayerThumb(content: layer.content)
            Text(layer.displayName)
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(layer.isHidden ? .secondary : .primary)
            Spacer()
            Button {
                model.updateLayer(layer.id) { $0.isHidden.toggle() }
            } label: {
                Image(systemName: layer.isHidden ? "eye.slash" : "eye")
                    .foregroundStyle(layer.isHidden ? .secondary : .primary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(layer.isHidden ? "Show layer" : "Hide layer")
            Menu {
                Button("Duplicate", systemImage: "plus.square.on.square") { duplicate(layer) }
                Button("Bring to Front", systemImage: "square.3.layers.3d.top.filled") { reorder(layer, toFront: true) }
                Button("Send to Back", systemImage: "square.3.layers.3d.bottom.filled") { reorder(layer, toFront: false) }
                Divider()
                Button("Delete", systemImage: "trash", role: .destructive) { model.deleteLayer(layer.id) }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 32, height: 32)
            }
            .accessibilityLabel("More")
        }
        .contentShape(Rectangle())
        .onTapGesture { model.selectedLayerID = layer.id }
        .listRowBackground(selected ? Color.accentColor.opacity(0.18) : nil)
    }

    private var baseRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "photo")
                .frame(width: 36, height: 36)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
            Text("Photo")
            Spacer()
            Image(systemName: "lock.fill").foregroundStyle(.secondary)
        }
        .moveDisabled(true)
    }

    private func move(from: IndexSet, to: Int) {
        // The list is front-first; the document is back-first.
        model.update { doc in
            var reversed = Array(doc.layers.reversed())
            reversed.move(fromOffsets: from, toOffset: min(to, reversed.count))
            doc.layers = reversed.reversed()
        }
    }

    private func duplicate(_ layer: Layer) {
        var copy = layer
        copy.id = UUID()
        copy.center.x = min(0.95, copy.center.x + 0.04)
        copy.center.y = min(0.95, copy.center.y + 0.04)
        model.addLayer(copy)
    }

    private func reorder(_ layer: Layer, toFront: Bool) {
        model.update { doc in
            guard let i = doc.layers.firstIndex(where: { $0.id == layer.id }) else { return }
            let l = doc.layers.remove(at: i)
            if toFront { doc.layers.append(l) } else { doc.layers.insert(l, at: 0) }
        }
    }
}

struct LayerThumb: View {
    let content: Layer.Content

    var body: some View {
        Image(systemName: "person.crop.rectangle")
        .frame(width: 36, height: 36)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
    }
}
