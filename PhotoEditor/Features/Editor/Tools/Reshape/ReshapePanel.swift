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
    @State private var faceKey: FaceShapeKey? = .slim
    @State private var bodyKey: BodyShapeKey? = .waist
    @AppStorage(BrushOverlay.brushSizeKey) private var brushSize: Double = 28

    var body: some View {
        @Bindable var model = model
        ToolPanel {
            switch model.reshapeMode {
            case .face: faceControls
            case .body: bodyControls
            case .manual: manualControls
            }
            Segmented(options: ReshapeMode.allCases, selection: $model.reshapeMode) { $0.rawValue.capitalized }
                .padding(.horizontal, 50)
        }
        .onChange(of: model.reshapeMode, initial: true) { _, m in
            model.selectedLayerID = nil
            model.brushTarget = m == .manual ? .reshape(model.reshapeKind) : nil
        }
        .onDisappear { model.brushTarget = nil }
        .task {
            #if DEBUG
            if let m = DebugLaunch.value("-mode").flatMap(ReshapeMode.init(rawValue:)) { model.reshapeMode = m }
            #endif
            guard model.reshapeTargets == nil else { return }
            let targets = await Self.analyze(model.session)
            model.reshapeTargets = targets
            if targets.faces.isEmpty, !targets.bodies.isEmpty, model.reshapeMode == .face { model.reshapeMode = .body }
        }
    }

    @concurrent
    private static func analyze(_ session: RenderSession) async -> (faces: [ReshapeTarget], bodies: [ReshapeTarget]) {
        let faces = session.cached("faces") { FaceAnalysis.run(on: session.proxyCGImage) }.faces
            .map { ReshapeTarget(anchor: $0.anchor, frame: $0.frame, reach: $0.reach) }
        let bodies = session.cached("bodies") { BodyAnalysis.run(on: session.proxyCGImage) }.bodies
            .map { ReshapeTarget(anchor: $0.anchor, frame: $0.frame, reach: $0.reach) }
        let bySize: (ReshapeTarget, ReshapeTarget) -> Bool = { $0.frame.width * $0.frame.height > $1.frame.width * $1.frame.height }
        return (faces.sorted(by: bySize), bodies.sorted(by: bySize))
    }

    @ViewBuilder
    private var faceControls: some View {
        if model.reshapeTargets == nil {
            ProgressView().frame(height: 60)
        } else if let person = model.selectedPerson {
            let values = ReshapeSpec.values(model.document.reshape.faces, at: person.anchor, within: person.reach)
            if let key = faceKey {
                ValueSlider(title: key.title + whoSuffix, value: Binding(
                    get: { values[key] ?? 0 },
                    set: { v in model.live { ReshapeSpec.set(&$0.reshape.faces, anchor: person.anchor, key: key, value: v, reach: person.reach) } }
                ), onBegin: model.beginGesture, onEnd: model.endGesture)
                .padding(.horizontal, 20)
            }
            ChipRow(items: FaceShapeKey.allCases, selection: $faceKey, title: \.title,
                    changed: { values[$0] != nil })
        } else {
            unavailable("No faces found. Try Manual to reshape by hand.")
        }
    }

    @ViewBuilder
    private var bodyControls: some View {
        if model.reshapeTargets == nil {
            ProgressView().frame(height: 60)
        } else if let person = model.selectedPerson {
            let values = ReshapeSpec.values(model.document.reshape.bodies, at: person.anchor, within: person.reach)
            if let key = bodyKey {
                ValueSlider(title: "\(key.title) · + \(key.positiveMeaning)" + whoSuffix, value: Binding(
                    get: { values[key] ?? 0 },
                    set: { v in model.live { ReshapeSpec.set(&$0.reshape.bodies, anchor: person.anchor, key: key, value: v, reach: person.reach) } }
                ), onBegin: model.beginGesture, onEnd: model.endGesture)
                .padding(.horizontal, 20)
            }
            ChipRow(items: BodyShapeKey.allCases, selection: $bodyKey, title: \.title,
                    changed: { values[$0] != nil })
        } else {
            unavailable("No full body found. Try Manual to reshape by hand.")
        }
    }

    /// "· 2 of 3" when there's more than one person to choose from.
    private var whoSuffix: String {
        let n = model.reshapePeople.count
        guard n > 1 else { return "" }
        return " · \(model.selectedIndex + 1) of \(n)"
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
        let src = model.viewport.normalized(p)
        let srcPrev = model.viewport.normalized(prev)
        let size = model.document.source.size
        let radius = model.sourceRadius(points: brushSize * 1.6) * max(size.width, size.height) / size.height
        let warp = ManualWarp(kind: kind, center: srcPrev,
                              vector: CGVector(dx: src.x - srcPrev.x, dy: src.y - srcPrev.y),
                              radius: radius)
        model.live { $0.reshape.manual.append(warp) }
    }
}

/// Outlines the people Reshape can target when there's a choice; tap one to pick it.
struct ReshapeTargetsOverlay: View {
    let model: EditorModel

    var body: some View {
        let people = model.reshapePeople
        let selected = model.selectedIndex
        ZStack {
            if people.count > 1 {
                ForEach(people.indices, id: \.self) { i in
                    let a = model.viewport.viewPoint(people[i].frame.origin)
                    let b = model.viewport.viewPoint(CGPoint(x: people[i].frame.maxX, y: people[i].frame.maxY))
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(i == selected ? Color.accentColor : .white.opacity(0.7),
                                style: StrokeStyle(lineWidth: i == selected ? 2.5 : 1.5, dash: i == selected ? [] : [5, 4]))
                        .shadow(color: .black.opacity(0.5), radius: 1)
                        .frame(width: b.x - a.x, height: b.y - a.y)
                        .position(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
                }
            }
        }
        .allowsHitTesting(false)
    }
}
