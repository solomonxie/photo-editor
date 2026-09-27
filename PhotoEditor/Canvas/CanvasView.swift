import CoreImage
import MetalKit
import SwiftUI

/// Metal-backed canvas. Draws on demand whenever `version` changes or the viewport moves.
struct CanvasView: UIViewRepresentable {
    let viewport: Viewport
    let version: Int
    let checkerboard: Bool
    /// Returns the image in output space, rendered for about `pixelWidth` pixels.
    let image: (_ pixelWidth: CGFloat) -> CIImage?
    var gesturesEnabled = true
    var onTap: ((CGPoint) -> Void)?
    var onCompare: ((Bool) -> Void)?

    func makeUIView(context: Context) -> CanvasMTKView {
        let view = CanvasMTKView(viewport: viewport)
        view.image = image
        view.onTap = onTap
        view.onCompare = onCompare
        view.checkerboard = checkerboard
        return view
    }

    func updateUIView(_ view: CanvasMTKView, context: Context) {
        view.image = image
        view.onTap = onTap
        view.onCompare = onCompare
        view.checkerboard = checkerboard
        view.setGesturesEnabled(gesturesEnabled)
        if view.version != version {
            view.version = version
            view.setNeedsDisplay()
        }
    }
}

final class CanvasMTKView: MTKView, MTKViewDelegate {
    let viewport: Viewport
    var image: ((CGFloat) -> CIImage?)?
    var onTap: ((CGPoint) -> Void)?
    var onCompare: ((Bool) -> Void)?
    var checkerboard = false
    var version = -1

    private let queue: MTLCommandQueue
    static let background = CIColor(red: 0.07, green: 0.07, blue: 0.075)
    private var gestureRecognizersList: [UIGestureRecognizer] = []

    init(viewport: Viewport) {
        self.viewport = viewport
        queue = RenderEngine.device.makeCommandQueue()!
        super.init(frame: .zero, device: RenderEngine.device)
        delegate = self
        framebufferOnly = false
        isPaused = true
        enableSetNeedsDisplay = true
        autoResizeDrawable = true
        colorPixelFormat = .bgra8Unorm
        (layer as? CAMetalLayer)?.colorspace = RenderEngine.outputSpace
        backgroundColor = UIColor(red: 0.07, green: 0.07, blue: 0.075, alpha: 1)
        isOpaque = true
        setupGestures()
        observeViewport()
    }

    required init(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        if viewport.viewSize != bounds.size {
            viewport.viewSize = bounds.size
            viewport.clampOffset()
        }
        setNeedsDisplay()
    }

    private func observeViewport() {
        withObservationTracking {
            _ = viewport.imageFrame
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.setNeedsDisplay()
                self?.observeViewport()
            }
        }
    }

    // MARK: draw

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let drawable = currentDrawable, let buffer = queue.makeCommandBuffer() else { return }
        let scale = contentScaleFactor
        let drawableSize = CGSize(width: drawable.texture.width, height: drawable.texture.height)
        let bounds = CGRect(origin: .zero, size: drawableSize)
        var output = CIImage(color: Self.background).cropped(to: bounds)

        let frame = viewport.imageFrame
        if frame.width > 0, let img = image?(frame.width * scale), img.extent.width > 0 {
            let s = frame.width * scale / img.extent.width
            let tx = frame.minX * scale
            let ty = (bounds.height / scale - frame.maxY) * scale
            let placed = img
                .transformed(by: CGAffineTransform(translationX: -img.extent.minX, y: -img.extent.minY))
                .transformed(by: CGAffineTransform(scaleX: s, y: s).concatenating(CGAffineTransform(translationX: tx, y: ty)),
                             highQualityDownsample: true)
            if checkerboard {
                let board = CIFilter(name: "CICheckerboardGenerator", parameters: [
                    "inputColor0": CIColor(red: 0.8, green: 0.8, blue: 0.8),
                    "inputColor1": CIColor(red: 0.6, green: 0.6, blue: 0.6),
                    "inputWidth": 10 * scale,
                ])!.outputImage!.cropped(to: placed.extent)
                output = board.composited(over: output)
            }
            output = placed.composited(over: output)
        }

        let state = RenderEngine.signposter.beginInterval("frame")
        let destination = CIRenderDestination(mtlTexture: drawable.texture, commandBuffer: buffer)
        destination.colorSpace = RenderEngine.outputSpace
        _ = try? RenderEngine.context.startTask(toRender: output, to: destination)
        buffer.present(drawable)
        buffer.commit()
        RenderEngine.signposter.endInterval("frame", state)
    }

    // MARK: gestures

    private func setupGestures() {
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch))
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        pan.minimumNumberOfTouches = 1
        pan.maximumNumberOfTouches = 2
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
        doubleTap.numberOfTapsRequired = 2
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tap.require(toFail: doubleTap)
        let hold = UILongPressGestureRecognizer(target: self, action: #selector(handleHold))
        hold.minimumPressDuration = 0.25
        gestureRecognizersList = [pinch, pan, doubleTap, tap, hold]
        for g in gestureRecognizersList {
            g.delegate = self
            addGestureRecognizer(g)
        }
    }

    func setGesturesEnabled(_ enabled: Bool) {
        gestureRecognizersList.forEach { $0.isEnabled = enabled }
    }

    private var lastPinchScale: CGFloat = 1
    @objc private func handlePinch(_ g: UIPinchGestureRecognizer) {
        if g.state == .began { lastPinchScale = 1 }
        let factor = g.scale / lastPinchScale
        lastPinchScale = g.scale
        viewport.setZoom(viewport.zoom * factor, anchor: g.location(in: self))
        if g.state == .ended, viewport.zoom < 1.05 {
            UIView.animate(withDuration: 0.2) { self.viewport.reset() }
        }
    }

    @objc private func handlePan(_ g: UIPanGestureRecognizer) {
        guard viewport.zoom > 1 else { return }
        let t = g.translation(in: self)
        viewport.pan(by: CGSize(width: t.x, height: t.y))
        g.setTranslation(.zero, in: self)
    }

    @objc private func handleDoubleTap(_ g: UITapGestureRecognizer) {
        if viewport.zoom > 1.01 {
            viewport.reset()
        } else {
            viewport.setZoom(2.5, anchor: g.location(in: self))
        }
    }

    @objc private func handleTap(_ g: UITapGestureRecognizer) {
        let n = viewport.normalized(g.location(in: self))
        onTap?(n)
    }

    @objc private func handleHold(_ g: UILongPressGestureRecognizer) {
        switch g.state {
        case .began: onCompare?(true)
        case .ended, .cancelled, .failed: onCompare?(false)
        default: break
        }
    }
}

extension CanvasMTKView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        (g is UIPinchGestureRecognizer && other is UIPanGestureRecognizer)
            || (g is UIPanGestureRecognizer && other is UIPinchGestureRecognizer)
    }

    override func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool {
        if g is UIPanGestureRecognizer { return viewport.zoom > 1 }
        return true
    }
}
