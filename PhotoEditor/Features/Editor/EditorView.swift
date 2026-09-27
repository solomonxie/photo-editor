import SwiftUI

struct EditorView: View {
    @State var model: EditorModel
    let onClose: () -> Void

    @State private var showLayers = false
    @State private var showSave = false
    @State private var confirmDiscard = false

    var body: some View {
        VStack(spacing: 0) {
            topBar
            canvas
            panel
            Divider().overlay(Color.white.opacity(0.08))
            toolBar
        }
        .background(Color(red: 0.07, green: 0.07, blue: 0.075).ignoresSafeArea())
        .ignoresSafeArea(.keyboard)
        .overlay(alignment: .bottom) {
            if let toast = model.toast {
                ToastView(toast: toast)
                    .padding(.bottom, ToolPanelMetrics.height + 80)
            }
        }
        .animation(.snappy, value: model.toast)
        .overlay {
            if let id = model.editingTextLayerID {
                TextEditOverlay(model: model, layerID: id)
            }
        }
        .sheet(isPresented: $showLayers) {
            LayersSheet(model: model)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSave) {
            SaveSheet(model: model)
                .presentationDetents([.height(430)])
                .presentationDragIndicator(.visible)
        }
        .preferredColorScheme(.dark)
        #if DEBUG
        .task {
            if let name = DebugLaunch.value("-exportTo") {
                let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                if let data = try? await Exporter.export(document: model.document, session: model.session, format: .jpeg,
                                                         size: .full, keepLocation: false) {
                    try? data.write(to: docs.appendingPathComponent(name))
                    model.showToast("Exported \(name)")
                }
            }
            if DebugLaunch.has("-close") { confirmDiscard = model.hasUnsavedChanges }
            switch DebugLaunch.sheet {
            case "save": showSave = true
            case "layers": showLayers = true
            default: break
            }
        }
        #endif
    }

    // MARK: top bar

    private var topBar: some View {
        HStack(spacing: 4) {
            Button {
                if model.hasUnsavedChanges { confirmDiscard = true } else { onClose() }
            } label: {
                Image(systemName: "xmark")
                    .frame(width: 40, height: 40)
            }
            .accessibilityLabel("Close")
            .confirmationDialog("Discard changes?", isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button("Discard Changes", role: .destructive, action: onClose)
                Button("Save…") { showSave = true }
                Button("Keep Editing", role: .cancel) {}
            } message: {
                Text("Your edits haven't been saved.")
            }

            Button { model.undo() } label: {
                Image(systemName: "arrow.uturn.backward").frame(width: 40, height: 40)
            }
            .disabled(!model.history.canUndo)
            .accessibilityLabel("Undo")

            Button { model.redo() } label: {
                Image(systemName: "arrow.uturn.forward").frame(width: 40, height: 40)
            }
            .disabled(!model.history.canRedo)
            .accessibilityLabel("Redo")

            Spacer()

            Image(systemName: "square.split.2x1")
                .frame(width: 40, height: 40)
                .foregroundStyle(model.isComparing ? Color.accentColor : .primary)
                .contentShape(Rectangle())
                .onLongPressGesture(minimumDuration: 0, maximumDistance: 60) {
                } onPressingChanged: { pressing in
                    model.isComparing = pressing
                }
                .accessibilityLabel("Hold to compare with original")
                .accessibilityAddTraits(.isButton)

            Button { showLayers = true } label: {
                Image(systemName: "square.3.layers.3d")
                    .frame(width: 40, height: 40)
                    .overlay(alignment: .topTrailing) {
                        if model.document.layers.count > 0 {
                            Text("\(model.document.layers.count + 1)")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 4)
                                .background(Color.accentColor, in: Capsule())
                                .foregroundStyle(.white)
                                .offset(x: -2, y: 4)
                        }
                    }
            }
            .accessibilityLabel("Layers")

            Button { showSave = true } label: {
                Text("Save")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.accentColor, in: Capsule())
                    .foregroundStyle(.white)
            }
            .padding(.leading, 6)
        }
        .font(.system(size: 17, weight: .medium))
        .foregroundStyle(.primary)
        .padding(.horizontal, 16)
        .frame(height: 48)
        .padding(.top, 8)
    }

    // MARK: canvas

    private var canvas: some View {
        ZStack {
            CanvasView(
                viewport: model.viewport,
                version: model.renderVersion,
                checkerboard: model.hasTransparency,
                image: { [model] px in model.canvasImage(pixelWidth: px) },
                gesturesEnabled: model.brushTarget == nil,
                onTap: { [model] p in model.handleTap(at: p) },
                onCompare: { [model] on in model.isComparing = on }
            )
            CanvasOverlays(model: model)
            if model.isComparing {
                VStack {
                    Text("Original")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(12)
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .allowsHitTesting(false)
            }
        }
        .clipped()
        .frame(maxHeight: .infinity)
    }

    // MARK: panel

    @ViewBuilder
    private var panel: some View {
        if let tool = model.activeTool {
            Group {
                switch tool {
                case .adjust: AdjustPanel(model: model)
                case .filters: FiltersPanel(model: model)
                case .crop: CropPanel(model: model)
                case .retouch: RetouchPanel(model: model)
                case .reshape: ReshapePanel(model: model)
                case .text: TextPanel(model: model)
                case .stickers: StickersPanel(model: model)
                case .cutout: CutoutPanel(model: model)
                case .ai: AIPanel(model: model)
                }
            }
            .transition(.opacity)
            .id(tool)
        }
    }

    // MARK: tool bar

    private var toolBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(EditorTool.allCases) { tool in
                    let active = model.activeTool == tool
                    Button {
                        withAnimation(.snappy(duration: 0.25)) {
                            model.activeTool = active ? nil : tool
                        }
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: tool.systemImage)
                                .font(.system(size: 20))
                                .frame(height: 24)
                            Text(tool.title)
                                .font(.caption2.weight(active ? .semibold : .regular))
                        }
                        .frame(width: 58, height: 54)
                        .foregroundStyle(active ? Color.accentColor : .primary.opacity(0.85))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(active ? .isSelected : [])
                }
            }
            .padding(.horizontal, 12)
        }
        .padding(.top, 6)
        .padding(.bottom, 12)
    }
}
