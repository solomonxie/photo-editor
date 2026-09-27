import SwiftUI

extension FaceShapeKey: Identifiable {
    var id: String { rawValue }
    var title: String {
        switch self {
        case .slim: "Slim Face"
        case .jaw: "Chin"
        case .eyes: "Eyes"
        case .nose: "Nose"
        case .forehead: "Forehead"
        }
    }
}

extension BodyShapeKey: Identifiable {
    var id: String { rawValue }
    var title: String {
        switch self {
        case .waist: "Waist"
        case .hips: "Hips"
        case .chest: "Chest"
        case .legs: "Legs"
        case .shoulders: "Shoulders"
        case .arms: "Arms"
        }
    }

    /// What + means, shown as the slider's caption.
    var positiveMeaning: String {
        switch self {
        case .waist, .arms: "slimmer"
        case .hips, .chest, .shoulders: "fuller"
        case .legs: "longer"
        }
    }
}

struct ReshapePanel: View {
    let model: EditorModel
    @State private var mode: Mode = Self.initialMode
    @State private var faceKey: FaceShapeKey? = .slim
    @State private var bodyKey: BodyShapeKey? = .waist
    @State private var counts: (faces: Int, bodies: Int)?
    @AppStorage(BrushOverlay.brushSizeKey) private var brushSize: Double = 28

    private static var initialMode: Mode {
        #if DEBUG
        if let m = DebugLaunch.value("-mode").flatMap(Mode.init(rawValue:)) { return m }
        #endif
        return .face
    }

    enum Mode: String, CaseIterable { case face, body, manual }

    var body: some View {
        ToolPanel {
            switch mode {
            case .face: faceControls
            case .body: bodyControls
            case .manual: manualControls
            }
            Segmented(options: Mode.allCases, selection: $mode) { $0.rawValue.capitalized }
                .padding(.horizontal, 50)
        }
        .onChange(of: mode, initial: true) { _, m in
            model.selectedLayerID = nil
            model.brushTarget = m == .manual ? .reshape(model.reshapeKind) : nil
        }
        .onDisappear { model.brushTarget = nil }
        .task {
            let session = model.session
            counts = await Self.analyze(session)
            if counts?.faces == 0, (counts?.bodies ?? 0) > 0 { mode = .body }
        }
    }

    @concurrent
    private static func analyze(_ session: RenderSession) async -> (Int, Int) {
        let f = session.cached("faces") { FaceAnalysis.run(on: session.proxyCGImage) }.faces.count
        let b = session.cached("bodies") { BodyAnalysis.run(on: session.proxyCGImage) }.bodies.count
        return (f, b)
    }

    @ViewBuilder
    private var faceControls: some View {
        if counts == nil {
            ProgressView().frame(height: 60)
        } else if counts?.faces == 0 {
            unavailable("No faces found. Try Manual to reshape by hand.")
        } else {
            if let key = faceKey {
                ValueSlider(title: key.title, value: Binding(
                    get: { model.document.reshape.face[key] ?? 0 },
                    set: { v in model.live { $0.reshape.face[key] = v == 0 ? nil : v } }
                ), onBegin: model.beginGesture, onEnd: model.endGesture)
                .padding(.horizontal, 20)
            }
            ChipRow(items: FaceShapeKey.allCases, selection: $faceKey, title: \.title,
                    changed: { model.document.reshape.face[$0] != nil })
        }
    }

    @ViewBuilder
    private var bodyControls: some View {
        if counts == nil {
            ProgressView().frame(height: 60)
        } else if counts?.bodies == 0 {
            unavailable("No full body found. Try Manual to reshape by hand.")
        } else {
            if let key = bodyKey {
                ValueSlider(title: "\(key.title) · + \(key.positiveMeaning)", value: Binding(
                    get: { model.document.reshape.body[key] ?? 0 },
                    set: { v in model.live { $0.reshape.body[key] = v == 0 ? nil : v } }
                ), onBegin: model.beginGesture, onEnd: model.endGesture)
                .padding(.horizontal, 20)
            }
            ChipRow(items: BodyShapeKey.allCases, selection: $bodyKey, title: \.title,
                    changed: { model.document.reshape.body[$0] != nil })
        }
    }

    private var manualControls: some View {
        VStack(spacing: 8) {
            HStack {
                Segmented(options: [ManualWarp.Kind.push, .grow, .shrink], selection: Binding(
                    get: { model.reshapeKind },
                    set: { k in
                        model.reshapeKind = k
                        model.brushTarget = .reshape(k)
                    }
                )) { $0.rawValue.capitalized }
                Button("Clear") { model.update { $0.reshape.manual = [] } }
                    .font(.subheadline.weight(.medium))
                    .disabled(model.document.reshape.manual.isEmpty)
                    .padding(.leading, 8)
            }
            BrushSizeSlider(size: $brushSize)
        }
        .padding(.horizontal, 20)
    }

    private func unavailable(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(height: 60)
            .padding(.horizontal, 24)
    }
}

/// Push drags content along; Grow/Shrink bulge wherever the finger passes.
struct ReshapeBrushOverlay: View {
    let model: EditorModel
    let kind: ManualWarp.Kind
    @AppStorage(BrushOverlay.brushSizeKey) private var brushSize: Double = 28
    @State private var last: CGPoint?
    @State private var cursor: CGPoint?

    var body: some View {
        ZStack {
            Color.clear
            if let cursor {
                Circle()
                    .stroke(.white, lineWidth: 1.5)
                    .shadow(color: .black.opacity(0.6), radius: 1)
                    .frame(width: brushSize * 2 * 1.6, height: brushSize * 2 * 1.6)
                    .position(cursor)
                    .allowsHitTesting(false)
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { g in
                    cursor = g.location
                    if last == nil {
                        last = g.location
                        model.beginGesture()
                        if kind != .push { add(at: g.location, from: g.location) }
                        return
                    }
                    guard let prev = last else { return }
                    let step = hypot(g.location.x - prev.x, g.location.y - prev.y)
                    if step >= (kind == .push ? 6 : brushSize * 0.8) {
                        add(at: g.location, from: prev)
                        last = g.location
                    }
                }
                .onEnded { _ in
                    last = nil
                    cursor = nil
                    model.endGesture()
                }
        )
    }

    private func add(at p: CGPoint, from prev: CGPoint) {
        let src = model.sourcePoint(fromOutput: model.viewport.normalized(p))
        let srcPrev = model.sourcePoint(fromOutput: model.viewport.normalized(prev))
        let size = model.document.source.size
        let radius = model.sourceRadius(points: brushSize * 1.6) * max(size.width, size.height) / size.height
        let warp = ManualWarp(kind: kind, center: srcPrev,
                              vector: CGVector(dx: src.x - srcPrev.x, dy: src.y - srcPrev.y),
                              radius: radius)
        model.live { $0.reshape.manual.append(warp) }
    }
}
