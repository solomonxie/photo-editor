import CoreImage

nonisolated extension RenderPipeline {
    func applyLayers(_ img: CIImage) -> CIImage {
        var out = img
        for layer in document.layers where !layer.isHidden {
            if let rendered = layerImage(layer, canvas: img.extent.size) {
                out = rendered.composited(over: out)
            }
        }
        return out
    }

    /// The layer placed on a canvas of `canvas` pixels, CI coordinates.
    func layerImage(_ layer: Layer, canvas: CGSize) -> CIImage? {
        let pixelWidth = max(1, layer.width * canvas.width)
        guard case .image(let asset, _) = layer.content, var image = session.assetImage(asset) else { return nil }
        image = image.transformed(by: CGAffineTransform(translationX: -image.extent.minX, y: -image.extent.minY))
        let s = pixelWidth / image.extent.width
        let center = CGPoint(x: layer.center.x * canvas.width, y: (1 - layer.center.y) * canvas.height)
        let t = CGAffineTransform(translationX: -image.extent.width / 2, y: -image.extent.height / 2)
            .concatenating(CGAffineTransform(scaleX: s, y: s))
            .concatenating(CGAffineTransform(rotationAngle: -layer.rotation))
            .concatenating(CGAffineTransform(translationX: center.x, y: center.y))
        image = image.transformed(by: t, highQualityDownsample: true)
        if layer.opacity < 1 {
            image = image.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: layer.opacity, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: layer.opacity, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: layer.opacity, w: 0),
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: layer.opacity),
            ])
        }
        return image
    }
}
