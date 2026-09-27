import SwiftUI

struct RetouchPanel: View {
    let model: EditorModel
    @State private var mode: Mode = Self.initialMode
    @State private var faceCount: Int?
    @AppStorage(BrushOverlay.brushSizeKey) private var brushSize: Double = 28

    private static var initialMode: Mode {
        #if DEBUG
        if let m = DebugLaunch.value("-mode").flatMap(Mode.init(rawValue:)) { return m }
        #endif
        return .smooth
    }

    enum Mode: String, CaseIterable { case smooth, heal, redEye }

    var body: some View {
        ToolPanel {
            switch mode {
            case .smooth:
                if faceCount == 0 {
                    Text("No faces found in this photo.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(height: 50)
                } else if faceCount == nil {
                    ProgressView().frame(height: 50)
                } else {
                    ValueSlider(
                        title: "Smooth skin",
                        value: Binding(
                            get: { model.document.smoothSkin },
                            set: { v in model.live { $0.smoothSkin = v } }
                        ),
                        bipolar: false,
                        onBegin: model.beginGesture,
                        onEnd: model.endGesture
                    )
                    .padding(.horizontal, 20)
                }
            case .heal:
                VStack(spacing: 8) {
                    HStack {
                        Text("Tap a blemish or paint over a spot.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Clear") {
                            model.update { $0.heal = [] }
                        }
                        .font(.subheadline.weight(.medium))
                        .disabled(model.document.heal.isEmpty)
                    }
                    BrushSizeSlider(size: $brushSize)
                }
                .padding(.horizontal, 20)
            case .redEye:
                if faceCount == 0 {
                    Text("No faces found in this photo.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(height: 50)
                } else {
                    Toggle("Fix red eyes", isOn: Binding(
                        get: { model.document.redEye },
                        set: { v in model.update { $0.redEye = v } }
                    ))
                    .font(.subheadline.weight(.medium))
                    .tint(.accentColor)
                    .padding(.horizontal, 24)
                    .frame(height: 50)
                }
            }
            Segmented(options: Mode.allCases, selection: $mode) { m in
                switch m {
                case .smooth: "Smooth skin"
                case .heal: "Heal"
                case .redEye: "Red eye"
                }
            }
            .padding(.horizontal, 30)
        }
        .onChange(of: mode, initial: true) { _, m in
            model.selectedLayerID = nil
            model.brushTarget = m == .heal ? .heal : nil
        }
        .onDisappear { model.brushTarget = nil }
        .task {
            let session = model.session
            faceCount = await Self.countFaces(session)
        }
    }

    @concurrent
    private static func countFaces(_ session: RenderSession) async -> Int {
        session.cached("faces") { FaceAnalysis.run(on: session.proxyCGImage) }.faces.count
    }
}

struct BrushSizeSlider: View {
    @Binding var size: Double

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "circle.fill").font(.system(size: 6))
            Slider(value: $size, in: 8...70)
                .accessibilityLabel("Brush size")
            Image(systemName: "circle.fill").font(.system(size: 16))
        }
        .foregroundStyle(.secondary)
    }
}
