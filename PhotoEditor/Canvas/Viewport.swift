import CoreGraphics
import Observation

/// Where the image sits inside the canvas view, in points. Shared by the Metal view and overlays.
@Observable
final class Viewport {
    var viewSize: CGSize = .zero
    var imageSize: CGSize = CGSize(width: 1, height: 1)
    var zoom: CGFloat = 1
    var offset: CGSize = .zero
    var padding: CGFloat = 12

    static let maxZoom: CGFloat = 16

    var fitRect: CGRect {
        let avail = CGRect(origin: .zero, size: viewSize).insetBy(dx: padding, dy: padding)
        guard avail.width > 0, avail.height > 0, imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let s = min(avail.width / imageSize.width, avail.height / imageSize.height)
        let size = CGSize(width: imageSize.width * s, height: imageSize.height * s)
        return CGRect(x: avail.midX - size.width / 2, y: avail.midY - size.height / 2, width: size.width, height: size.height)
    }

    var imageFrame: CGRect {
        let fit = fitRect
        let size = CGSize(width: fit.width * zoom, height: fit.height * zoom)
        return CGRect(x: fit.midX - size.width / 2 + offset.width,
                      y: fit.midY - size.height / 2 + offset.height,
                      width: size.width, height: size.height)
    }

    /// View point → normalized image point (origin top-left).
    func normalized(_ p: CGPoint) -> CGPoint {
        let f = imageFrame
        guard f.width > 0, f.height > 0 else { return .zero }
        return CGPoint(x: (p.x - f.minX) / f.width, y: (p.y - f.minY) / f.height)
    }

    func viewPoint(_ n: CGPoint) -> CGPoint {
        let f = imageFrame
        return CGPoint(x: f.minX + n.x * f.width, y: f.minY + n.y * f.height)
    }

    func reset() {
        zoom = 1
        offset = .zero
    }

    func setZoom(_ z: CGFloat, anchor: CGPoint) {
        let clamped = min(Self.maxZoom, max(1, z))
        let before = normalized(anchor)
        zoom = clamped
        let after = viewPoint(before)
        offset.width += anchor.x - after.x
        offset.height += anchor.y - after.y
        clampOffset()
    }

    func pan(by d: CGSize) {
        offset.width += d.width
        offset.height += d.height
        clampOffset()
    }

    func clampOffset() {
        guard zoom > 1 else {
            offset = .zero
            return
        }
        let fit = fitRect
        let size = CGSize(width: fit.width * zoom, height: fit.height * zoom)
        let maxX = max(0, (size.width - viewSize.width) / 2 + padding)
        let maxY = max(0, (size.height - viewSize.height) / 2 + padding)
        let centerDX = CGRect(origin: .zero, size: viewSize).midX - fit.midX
        let centerDY = CGRect(origin: .zero, size: viewSize).midY - fit.midY
        offset.width = min(maxX + centerDX, max(-maxX + centerDX, offset.width))
        offset.height = min(maxY + centerDY, max(-maxY + centerDY, offset.height))
    }
}
