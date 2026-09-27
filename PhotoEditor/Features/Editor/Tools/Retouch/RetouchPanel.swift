import SwiftUI

enum BeautyChip: String, CaseIterable, Identifiable {
    case auto, smooth, whiten, evenTone, deShine, darkCircles, brightEyes, teeth, heal, redEye

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto: "Auto"
        case .smooth: "Smooth"
        case .whiten: "Whiten"
        case .evenTone: "Even tone"
        case .deShine: "De-shine"
        case .darkCircles: "Dark circles"
        case .brightEyes: "Bright eyes"
        case .teeth: "Teeth"
        case .heal: "Heal"
        case .redEye: "Red eye"
        }
    }

    var beautyKey: BeautyKey? {
        switch self {
        case .whiten: .whiten
        case .evenTone: .evenTone
        case .deShine: .deShine
        case .darkCircles: .darkCircles
        case .brightEyes: .brightEyes
        case .teeth: .teeth
        default: nil
        }
    }

    var needsFace: Bool { self != .heal }
}

struct RetouchPanel: View {
    let model: EditorModel
    @State private var chip: BeautyChip? = Self.initialChip
    @State private var faceCount: Int?
    @AppStorage(BrushOverlay.brushSizeKey) private var brushSize: Double = 28

    private static var initialChip: BeautyChip {
        #if DEBUG
        if let m = DebugLaunch.value("-mode").flatMap(BeautyChip.init(rawValue:)) { return m }
        #endif
        return .auto
    }

    var body: some View {
        ToolPanel {
            control
                .frame(height: 56)
            ChipRow(items: BeautyChip.allCases, selection: $chip, title: \.title, changed: isChanged)
        }
        .onChange(of: chip, initial: true) { _, c in
            model.selectedLayerID = nil
            model.brushTarget = c == .heal ? .heal : nil
        }
        .onDisappear { model.brushTarget = nil }
        .task {
            let session = model.session
            faceCount = await Self.countFaces(session)
        }
    }

    @ViewBuilder
    private var control: some View {
        let c = chip ?? .auto
        if c.needsFace, faceCount == nil {
            ProgressView()
        } else if c.needsFace, faceCount == 0 {
            Text("No faces found in this photo.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else {
            switch c {
            case .auto:
                Segmented(options: BeautyLook.allCases, selection: Binding(
                    get: { BeautyLook.current(model.document) ?? .off },
                    set: { look in model.update { look.apply(to: &$0) } }
                )) { $0.title }
                .padding(.horizontal, 30)
            case .smooth:
                slider("Smooth skin", get: { model.document.smoothSkin }, set: { v in model.live { $0.smoothSkin = v } })
            case .heal:
                VStack(spacing: 8) {
                    HStack {
                        Text("Tap a blemish or paint over a spot.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Clear") { model.update { $0.heal = [] } }
                            .font(.subheadline.weight(.medium))
                            .disabled(model.document.heal.isEmpty)
                    }
                    BrushSizeSlider(size: $brushSize)
                }
                .padding(.horizontal, 20)
            case .redEye:
                Toggle("Fix red eyes", isOn: Binding(
                    get: { model.document.redEye },
                    set: { v in model.update { $0.redEye = v } }
                ))
                .font(.subheadline.weight(.medium))
                .tint(.accentColor)
                .padding(.horizontal, 24)
            default:
                if let key = c.beautyKey {
                    slider(c.title, get: { model.document.beauty[key] ?? 0 },
                           set: { v in model.live { $0.beauty[key] = v == 0 ? nil : v } })
                }
            }
        }
    }

    private func slider(_ title: String, get: @escaping () -> Double, set: @escaping (Double) -> Void) -> some View {
        ValueSlider(title: title, value: Binding(get: get, set: set), bipolar: false,
                    onBegin: model.beginGesture, onEnd: model.endGesture)
            .padding(.horizontal, 20)
    }

    private func isChanged(_ c: BeautyChip) -> Bool {
        let d = model.document
        switch c {
        case .auto: return (BeautyLook.current(d) ?? .off) != .off
        case .smooth: return d.smoothSkin > 0
        case .heal: return !d.heal.isEmpty
        case .redEye: return d.redEye
        default: return c.beautyKey.map { d.beauty[$0] != nil } ?? false
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
