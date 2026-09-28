import SwiftUI

struct CanvasOverlays: View {
    let model: EditorModel

    var body: some View {
        ZStack {
            if case .reshape(let kind) = model.brushTarget {
                ReshapeBrushOverlay(model: model, kind: kind)
            } else if model.activeTool == .reshape, !model.isComparing {
                ReshapeTargetsOverlay(model: model)
            } else if model.activeTool == .hair, !model.isComparing {
                MaskStrokesView(model: model)
                ReshapeTargetsOverlay(model: model)
            } else if let target = model.brushTarget {
                BrushOverlay(model: model, target: target)
            } else if let layer = model.selectedLayer, !model.isComparing {
                LayerSelectionOverlay(model: model, layer: layer)
            }
        }
        .coordinateSpace(name: "canvas")
    }
}

// MARK: - Layer selection

struct LayerSelectionOverlay: View {
    let model: EditorModel
    let layer: Layer

    @State private var dragStart: CGPoint?
    @State private var pinchStart: (width: Double, rotation: Double)?
    @State private var handleStart: (width: Double, rotation: Double, vector: CGVector)?

    var body: some View {
        let vp = model.viewport
        let frame = vp.imageFrame
        let w = layer.width * frame.width
        let h = w * model.layerAspect(layer)
        let center = vp.viewPoint(layer.center)

        ZStack {
            Rectangle()
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.5), radius: 1)
                .frame(width: w + 16, height: h + 16)
                .contentShape(Rectangle())
                .gesture(moveGesture(frame: frame).simultaneously(with: pinchRotate))
                .overlay(alignment: .topLeading) {
                    handleButton("xmark") { model.deleteLayer(layer.id) }
                        .offset(x: -14, y: -14)
                        .accessibilityLabel("Delete layer")
                }
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 28, height: 28)
                        .background(.white, in: Circle())
                        .foregroundStyle(.black)
                        .offset(x: 14, y: 14)
                        .gesture(scaleRotateHandle(center: center))
                        .accessibilityLabel("Resize and rotate")
                }
                .rotationEffect(.radians(layer.rotation))
                .position(center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func handleButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
                .frame(width: 28, height: 28)
                .background(.white, in: Circle())
                .foregroundStyle(.black)
        }
        .buttonStyle(.plain)
    }

    private func moveGesture(frame: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { g in
                if dragStart == nil {
                    dragStart = layer.center
                    model.beginGesture()
                }
                guard let start = dragStart else { return }
                var c = CGPoint(x: start.x + g.translation.width / frame.width,
                                y: start.y + g.translation.height / frame.height)
                // Snap to centre lines.
                if abs(c.x - 0.5) < 0.015 { c.x = 0.5 }
                if abs(c.y - 0.5) < 0.015 { c.y = 0.5 }
                model.updateLayer(layer.id, live: true) { $0.center = c }
            }
            .onEnded { _ in
                dragStart = nil
                model.endGesture()
            }
    }

    private var pinchRotate: some Gesture {
        MagnifyGesture().simultaneously(with: RotateGesture())
            .onChanged { v in
                if pinchStart == nil {
                    pinchStart = (layer.width, layer.rotation)
                    model.beginGesture()
                }
                guard let start = pinchStart else { return }
                let scale = v.first?.magnification ?? 1
                let rot = v.second?.rotation.radians ?? 0
                model.updateLayer(layer.id, live: true) {
                    $0.width = min(3, max(0.03, start.width * scale))
                    $0.rotation = start.rotation + rot
                }
            }
            .onEnded { _ in
                pinchStart = nil
                model.endGesture()
            }
    }

    private func scaleRotateHandle(center: CGPoint) -> some Gesture {
        DragGesture(coordinateSpace: .named("canvas"))
            .onChanged { g in
                let v = CGVector(dx: g.location.x - center.x, dy: g.location.y - center.y)
                if handleStart == nil {
                    let s = CGVector(dx: g.startLocation.x - center.x, dy: g.startLocation.y - center.y)
                    handleStart = (layer.width, layer.rotation, s)
                    model.beginGesture()
                }
                guard let start = handleStart else { return }
                let len0 = hypot(start.vector.dx, start.vector.dy)
                let len1 = hypot(v.dx, v.dy)
                guard len0 > 1 else { return }
                let angle0 = atan2(start.vector.dy, start.vector.dx)
                let angle1 = atan2(v.dy, v.dx)
                model.updateLayer(layer.id, live: true) {
                    $0.width = min(3, max(0.03, start.width * len1 / len0))
                    $0.rotation = start.rotation + (angle1 - angle0)
                }
            }
            .onEnded { _ in
                handleStart = nil
                model.endGesture()
            }
    }
}

// MARK: - Brush

struct BrushOverlay: View {
    let model: EditorModel
    let target: EditorModel.BrushTarget
    @State private var points: [CGPoint] = []
    @State private var viewPoints: [CGPoint] = []

    static let brushSizeKey = "brushSize"
    @AppStorage(BrushOverlay.brushSizeKey) private var brushSize: Double = 28

    var body: some View {
        ZStack {
            Color.clear
            Path { p in
                guard let first = viewPoints.first else { return }
                p.move(to: first)
                viewPoints.dropFirst().forEach { p.addLine(to: $0) }
                if viewPoints.count == 1 { p.addLine(to: first) }
            }
            .stroke(Color.red.opacity(0.5), style: StrokeStyle(lineWidth: brushSize * 2, lineCap: .round, lineJoin: .round))
            if target == .magicErase {
                MaskStrokesView(model: model)
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { g in
                    viewPoints.append(g.location)
                    let n = model.viewport.normalized(g.location)
                    points.append(n)
                }
                .onEnded { _ in
                    commit()
                }
        )
    }

    private func commit() {
        defer {
            points = []
            viewPoints = []
        }
        guard !points.isEmpty else { return }
        let stroke = BrushStroke(points: simplify(points), radius: model.sourceRadius(points: brushSize))
        switch target {
        case .heal:
            model.update { $0.heal.append(stroke) }
        case .magicErase:
            model.brushPreview.append(stroke)
        case .reshape:
            break
        }
    }

    private func simplify(_ pts: [CGPoint]) -> [CGPoint] {
        guard pts.count > 2 else { return pts }
        var out = [pts[0]]
        for p in pts.dropFirst() where hypot(p.x - out.last!.x, p.y - out.last!.y) > 0.002 {
            out.append(p)
        }
        if out.last != pts.last { out.append(pts.last!) }
        return out
    }
}

/// Shows the pending Magic Erase mask.
struct MaskStrokesView: View {
    let model: EditorModel

    var body: some View {
        let frame = model.viewport.imageFrame
        let src = model.document.source.size
        let longEdge = max(src.width, src.height)
        Canvas { ctx, _ in
            for stroke in model.brushPreview {
                let pts = stroke.points.map { model.viewport.viewPoint($0) }
                let r = stroke.radius * longEdge / src.width * frame.width
                var path = Path()
                if let first = pts.first {
                    path.move(to: first)
                    pts.dropFirst().forEach { path.addLine(to: $0) }
                    if pts.count == 1 { path.addLine(to: first) }
                }
                ctx.stroke(path, with: .color(.red.opacity(0.5)),
                           style: StrokeStyle(lineWidth: r * 2, lineCap: .round, lineJoin: .round))
            }
        }
        .allowsHitTesting(false)
    }
}
