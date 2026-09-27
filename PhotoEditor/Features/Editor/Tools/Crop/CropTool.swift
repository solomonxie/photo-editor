import SwiftUI

enum CropAspect: String, CaseIterable, Identifiable {
    case free, original, square, portrait45, story, wide, portrait34

    var id: String { rawValue }

    var title: String {
        switch self {
        case .free: "Free"
        case .original: "Original"
        case .square: "1:1"
        case .portrait45: "4:5"
        case .story: "9:16"
        case .wide: "16:9"
        case .portrait34: "3:4"
        }
    }

    /// Width / height in pixels, nil = unconstrained.
    func ratio(original: CGSize) -> CGFloat? {
        switch self {
        case .free: nil
        case .original: original.width / original.height
        case .square: 1
        case .portrait45: 4.0 / 5
        case .story: 9.0 / 16
        case .wide: 16.0 / 9
        case .portrait34: 3.0 / 4
        }
    }
}

struct CropPanel: View {
    let model: EditorModel

    var body: some View {
        ToolPanel {
            StraightenDial(angle: Binding(
                get: { model.document.crop.angle },
                set: { a in model.live { $0.crop.angle = a } }
            ), onBegin: model.beginGesture, onEnd: model.endGesture)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(CropAspect.allCases) { a in
                        Button {
                            model.cropAspect = a
                            applyAspect(a)
                        } label: {
                            Text(a.title)
                                .font(.footnote.weight(model.cropAspect == a ? .semibold : .regular))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(model.cropAspect == a ? Color.white.opacity(0.2) : Color.white.opacity(0.06), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }

            HStack(spacing: 22) {
                Button {
                    model.update {
                        $0.crop.quarterTurns = ($0.crop.quarterTurns + 1) % 4
                        $0.crop.rect = CGRect(x: 0, y: 0, width: 1, height: 1)
                    }
                    if model.cropAspect != .free, model.cropAspect != .original { applyAspect(model.cropAspect) }
                } label: {
                    Label("Rotate", systemImage: "rotate.left")
                }
                Button {
                    model.update {
                        $0.crop.flipped.toggle()
                        let r = $0.crop.rect
                        $0.crop.rect.origin.x = 1 - r.maxX
                    }
                } label: {
                    Label("Flip", systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right")
                }
                Spacer()
                Button("Reset") {
                    model.cropAspect = .free
                    model.update { $0.crop = CropSpec() }
                }
                .disabled(model.document.crop.isIdentity)
            }
            .font(.footnote.weight(.medium))
            .padding(.horizontal, 16)
        }
    }

    private func applyAspect(_ a: CropAspect) {
        let size = model.geometry.rotatedSize
        guard let ratio = a.ratio(original: a == .original ? model.document.source.size : size) else { return }
        model.update { doc in
            doc.crop.rect = CropMath.fit(ratio: ratio, in: doc.crop.rect, imageSize: size)
        }
    }
}

enum CropMath {
    /// Largest rect of `ratio` (px) centred in `rect` (normalized).
    static func fit(ratio: CGFloat, in rect: CGRect, imageSize: CGSize) -> CGRect {
        let px = CGRect(x: rect.minX * imageSize.width, y: rect.minY * imageSize.height,
                        width: rect.width * imageSize.width, height: rect.height * imageSize.height)
        var w = px.width, h = px.width / ratio
        if h > px.height {
            h = px.height
            w = h * ratio
        }
        let r = CGRect(x: px.midX - w / 2, y: px.midY - h / 2, width: w, height: h)
        return CGRect(x: r.minX / imageSize.width, y: r.minY / imageSize.height,
                      width: r.width / imageSize.width, height: r.height / imageSize.height)
    }
}

struct StraightenDial: View {
    @Binding var angle: Double
    var onBegin: () -> Void
    var onEnd: () -> Void
    @State private var start: Double?

    var body: some View {
        VStack(spacing: 2) {
            GeometryReader { geo in
                let spacing: CGFloat = 8
                let mid = geo.size.width / 2
                Canvas { ctx, size in
                    for i in -45...45 {
                        let x = mid + CGFloat(Double(i) - angle) * spacing
                        guard x > -2, x < size.width + 2 else { continue }
                        let major = i % 5 == 0
                        let h: CGFloat = major ? 12 : 6
                        var p = Path()
                        p.move(to: CGPoint(x: x, y: size.height / 2 - h / 2))
                        p.addLine(to: CGPoint(x: x, y: size.height / 2 + h / 2))
                        ctx.stroke(p, with: .color(.white.opacity(i == 0 ? 0.9 : (major ? 0.5 : 0.25))), lineWidth: 1)
                    }
                    var c = Path()
                    c.move(to: CGPoint(x: mid, y: 0))
                    c.addLine(to: CGPoint(x: mid, y: size.height))
                    ctx.stroke(c, with: .color(.accentColor), lineWidth: 2)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { g in
                            if start == nil {
                                start = angle
                                onBegin()
                            }
                            var a = (start ?? 0) - Double(g.translation.width / spacing)
                            a = min(45, max(-45, a))
                            if abs(a) < 0.4 { a = 0 }
                            if (a == 0) != (angle == 0) { UISelectionFeedbackGenerator().selectionChanged() }
                            angle = (a * 10).rounded() / 10
                        }
                        .onEnded { _ in
                            start = nil
                            onEnd()
                        }
                )
                .onTapGesture(count: 2) {
                    onBegin()
                    angle = 0
                    onEnd()
                }
            }
            .frame(height: 24)
            Text(String(format: "%.1f°", angle))
                .font(.caption.monospacedDigit())
                .foregroundStyle(angle == 0 ? .secondary : .primary)
        }
        .padding(.horizontal, 16)
        .accessibilityElement()
        .accessibilityLabel("Straighten")
        .accessibilityValue(String(format: "%.1f degrees", angle))
        .accessibilityAdjustableAction { dir in
            onBegin()
            angle = min(45, max(-45, angle + (dir == .increment ? 1 : -1)))
            onEnd()
        }
    }
}

struct CropOverlay: View {
    let model: EditorModel
    @State private var startRect: CGRect?
    @State private var dragging = false

    private enum Handle: CaseIterable {
        case topLeft, topRight, bottomLeft, bottomRight, top, bottom, left, right, move
    }

    var body: some View {
        let frame = model.viewport.imageFrame
        let r = model.document.crop.rect
        let rect = CGRect(x: frame.minX + r.minX * frame.width, y: frame.minY + r.minY * frame.height,
                          width: r.width * frame.width, height: r.height * frame.height)
        ZStack {
            // Dim outside the crop.
            Path { p in
                p.addRect(frame)
                p.addRect(rect)
            }
            .fill(Color.black.opacity(0.55), style: FillStyle(eoFill: true))
            .allowsHitTesting(false)

            Path { p in
                for i in 1...2 {
                    let x = rect.minX + rect.width * CGFloat(i) / 3
                    let y = rect.minY + rect.height * CGFloat(i) / 3
                    p.move(to: CGPoint(x: x, y: rect.minY)); p.addLine(to: CGPoint(x: x, y: rect.maxY))
                    p.move(to: CGPoint(x: rect.minX, y: y)); p.addLine(to: CGPoint(x: rect.maxX, y: y))
                }
            }
            .stroke(.white.opacity(dragging ? 0.6 : 0.25), lineWidth: 0.75)
            .allowsHitTesting(false)

            Rectangle()
                .stroke(.white, lineWidth: 1.5)
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
                .allowsHitTesting(false)

            corners(rect)
                .allowsHitTesting(false)

            Color.clear
                .contentShape(Rectangle())
                .gesture(dragGesture(frame: frame, rect: rect))
        }
    }

    private func corners(_ rect: CGRect) -> some View {
        Path { p in
            let l: CGFloat = 20
            for (pt, dx, dy) in [(CGPoint(x: rect.minX, y: rect.minY), 1.0, 1.0), (CGPoint(x: rect.maxX, y: rect.minY), -1.0, 1.0),
                                 (CGPoint(x: rect.minX, y: rect.maxY), 1.0, -1.0), (CGPoint(x: rect.maxX, y: rect.maxY), -1.0, -1.0)] {
                p.move(to: CGPoint(x: pt.x + l * dx, y: pt.y))
                p.addLine(to: pt)
                p.addLine(to: CGPoint(x: pt.x, y: pt.y + l * dy))
            }
        }
        .stroke(.white, style: StrokeStyle(lineWidth: 4, lineCap: .square))
    }

    @State private var activeHandle: Handle?

    private func handle(at p: CGPoint, rect: CGRect) -> Handle {
        let t: CGFloat = 36
        let nearL = abs(p.x - rect.minX) < t, nearR = abs(p.x - rect.maxX) < t
        let nearT = abs(p.y - rect.minY) < t, nearB = abs(p.y - rect.maxY) < t
        switch (nearL, nearR, nearT, nearB) {
        case (true, _, true, _): return .topLeft
        case (_, true, true, _): return .topRight
        case (true, _, _, true): return .bottomLeft
        case (_, true, _, true): return .bottomRight
        case (_, _, true, _) where p.x > rect.minX && p.x < rect.maxX: return .top
        case (_, _, _, true) where p.x > rect.minX && p.x < rect.maxX: return .bottom
        case (true, _, _, _): return .left
        case (_, true, _, _): return .right
        default: return .move
        }
    }

    private func dragGesture(frame: CGRect, rect: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { g in
                if startRect == nil {
                    startRect = model.document.crop.rect
                    activeHandle = handle(at: g.startLocation, rect: rect)
                    dragging = true
                    model.beginGesture()
                }
                guard let start = startRect, let h = activeHandle else { return }
                let dx = g.translation.width / frame.width
                let dy = g.translation.height / frame.height
                let ratio = model.cropAspect.ratio(original: model.cropAspect == .original ? model.document.source.size : model.geometry.rotatedSize)
                let imgAspect = model.geometry.rotatedSize.width / model.geometry.rotatedSize.height
                let new = Self.adjust(start, handle: h, dx: dx, dy: dy, ratio: ratio.map { $0 / imgAspect })
                model.live { $0.crop.rect = new }
            }
            .onEnded { _ in
                startRect = nil
                activeHandle = nil
                dragging = false
                model.endGesture()
            }
    }

    /// `ratio` is width/height in normalized units.
    private static func adjust(_ r: CGRect, handle: Handle, dx: CGFloat, dy: CGFloat, ratio: CGFloat?) -> CGRect {
        let minSize: CGFloat = 0.08
        var minX = r.minX, minY = r.minY, maxX = r.maxX, maxY = r.maxY
        switch handle {
        case .move:
            let x = min(1 - r.width, max(0, r.minX + dx))
            let y = min(1 - r.height, max(0, r.minY + dy))
            return CGRect(x: x, y: y, width: r.width, height: r.height)
        case .topLeft: minX += dx; minY += dy
        case .topRight: maxX += dx; minY += dy
        case .bottomLeft: minX += dx; maxY += dy
        case .bottomRight: maxX += dx; maxY += dy
        case .top: minY += dy
        case .bottom: maxY += dy
        case .left: minX += dx
        case .right: maxX += dx
        }
        minX = max(0, min(minX, maxX - minSize))
        maxX = min(1, max(maxX, minX + minSize))
        minY = max(0, min(minY, maxY - minSize))
        maxY = min(1, max(maxY, minY + minSize))
        var out = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        if let ratio {
            // Keep the ratio, anchored on the opposite corner/edge.
            var w = out.width, h = out.width / ratio
            if handle == .top || handle == .bottom {
                h = out.height
                w = h * ratio
            }
            if h > 1 { h = 1; w = h * ratio }
            if w > 1 { w = 1; h = w / ratio }
            let anchorX: CGFloat = [.topLeft, .bottomLeft, .left].contains(handle) ? r.maxX : ([.top, .bottom].contains(handle) ? r.midX : r.minX)
            let anchorY: CGFloat = [.topLeft, .topRight, .top].contains(handle) ? r.maxY : ([.left, .right].contains(handle) ? r.midY : r.minY)
            var x: CGFloat = [.topLeft, .bottomLeft, .left].contains(handle) ? anchorX - w : ([.top, .bottom].contains(handle) ? anchorX - w / 2 : anchorX)
            var y: CGFloat = [.topLeft, .topRight, .top].contains(handle) ? anchorY - h : ([.left, .right].contains(handle) ? anchorY - h / 2 : anchorY)
            x = min(1 - w, max(0, x))
            y = min(1 - h, max(0, y))
            out = CGRect(x: x, y: y, width: w, height: h)
        }
        return out
    }
}
