import CoreImage
import UIKit

nonisolated enum LayerRasterizer {
    static let referenceSize: CGFloat = 200

    static func uiFont(_ font: TextFont, size: CGFloat) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: .bold)
        switch font {
        case .system:
            return base
        case .serif:
            return UIFont(descriptor: base.fontDescriptor.withDesign(.serif) ?? base.fontDescriptor, size: size)
        case .rounded:
            return UIFont(descriptor: base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor, size: size)
        case .mono:
            return UIFont.monospacedSystemFont(ofSize: size, weight: .bold)
        case .marker:
            return UIFont(name: "MarkerFelt-Wide", size: size) ?? base
        }
    }

    static func attributed(_ spec: TextSpec, size: CGFloat) -> NSAttributedString {
        let para = NSMutableParagraphStyle()
        para.alignment = switch spec.alignment {
        case .leading: .left
        case .center: .center
        case .trailing: .right
        }
        let color = UIColor(red: spec.color.r, green: spec.color.g, blue: spec.color.b, alpha: spec.color.a)
        var attrs: [NSAttributedString.Key: Any] = [
            .font: uiFont(spec.font, size: size),
            .foregroundColor: color,
            .paragraphStyle: para,
        ]
        switch spec.style {
        case .outline:
            attrs[.strokeColor] = contrasting(spec.color)
            attrs[.strokeWidth] = -4
        case .shadow:
            let shadow = NSShadow()
            shadow.shadowColor = UIColor.black.withAlphaComponent(0.55)
            shadow.shadowBlurRadius = size * 0.08
            shadow.shadowOffset = CGSize(width: 0, height: size * 0.03)
            attrs[.shadow] = shadow
        case .plain, .background:
            break
        }
        let string = spec.string.isEmpty ? " " : spec.string
        return NSAttributedString(string: string, attributes: attrs)
    }

    static func contrasting(_ c: RGBA) -> UIColor {
        (c.r * 0.3 + c.g * 0.59 + c.b * 0.11) > 0.6 ? .black : .white
    }

    /// Height / width of the layer's content box.
    static func aspect(_ content: Layer.Content) -> Double {
        switch content {
        case .text(let spec):
            let size = textSize(spec, fontSize: referenceSize)
            return size.height / size.width
        case .emoji:
            return 1
        case .image(_, let aspect):
            return aspect
        }
    }

    private static func textSize(_ spec: TextSpec, fontSize: CGFloat) -> CGSize {
        let str = attributed(spec, size: fontSize)
        let bounds = str.boundingRect(with: CGSize(width: 100_000, height: 100_000),
                                      options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        let pad = spec.style == .background ? fontSize * 0.5 : fontSize * 0.12
        return CGSize(width: ceil(bounds.width) + pad * 2, height: ceil(bounds.height) + pad * (spec.style == .background ? 1 : 2))
    }

    /// Renders text/emoji at `pixelWidth`.
    static func image(_ content: Layer.Content, pixelWidth: CGFloat) -> CIImage? {
        switch content {
        case .text(let spec):
            let natural = textSize(spec, fontSize: referenceSize)
            let fontSize = referenceSize * pixelWidth / natural.width
            let size = textSize(spec, fontSize: fontSize)
            let pad = spec.style == .background ? fontSize * 0.5 : fontSize * 0.12
            let vpad = spec.style == .background ? fontSize * 0.25 : fontSize * 0.12
            return draw(size: size) { ctx in
                if spec.style == .background {
                    let bg = UIColor(red: spec.color.r, green: spec.color.g, blue: spec.color.b, alpha: 1)
                    bg.setFill()
                    UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: fontSize * 0.3).fill()
                    var inverted = spec
                    let c = contrasting(spec.color)
                    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                    c.getRed(&r, green: &g, blue: &b, alpha: &a)
                    inverted.color = RGBA(r: r, g: g, b: b)
                    attributed(inverted, size: fontSize).draw(with: CGRect(x: pad, y: vpad, width: size.width - pad * 2, height: size.height),
                                                              options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
                } else {
                    attributed(spec, size: fontSize).draw(with: CGRect(x: pad, y: vpad, width: size.width - pad * 2, height: size.height),
                                                          options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
                }
            }
        case .emoji(let e):
            let side = max(8, pixelWidth)
            let str = NSAttributedString(string: e, attributes: [.font: UIFont.systemFont(ofSize: side * 0.8)])
            return draw(size: CGSize(width: side, height: side)) { _ in
                let b = str.size()
                str.draw(at: CGPoint(x: (side - b.width) / 2, y: (side - b.height) / 2))
            }
        case .image:
            return nil
        }
    }

    private static func draw(size: CGSize, _ body: (CGContext) -> Void) -> CIImage? {
        let capped = CGSize(width: min(size.width, 6000), height: min(size.height, 6000))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        format.preferredRange = .extended
        let img = UIGraphicsImageRenderer(size: capped, format: format).image { ctx in
            if capped != size {
                ctx.cgContext.scaleBy(x: capped.width / size.width, y: capped.height / size.height)
            }
            body(ctx.cgContext)
        }
        return img.cgImage.map { CIImage(cgImage: $0) }
    }
}

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
        var content: CIImage?
        switch layer.content {
        case .image(let asset, _):
            content = session.assetImage(asset)
        default:
            // Bucket widths so a pinch doesn't re-rasterize every frame.
            let bucket = pow(2, ceil(log2(pixelWidth)))
            let key = "layer:\(layer.id):\(Self.contentKey(layer.content)):\(Int(bucket))"
            content = session.cached(key) { LayerRasterizer.image(layer.content, pixelWidth: bucket) }
        }
        guard var image = content else { return nil }
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

    private static func contentKey(_ content: Layer.Content) -> Int {
        (try? JSONEncoder().encode(content))?.hashValue ?? 0
    }
}
