import CoreGraphics
import CoreImage
import Foundation

nonisolated enum StrokeMask {
    static func key(_ strokes: [BrushStroke]) -> Int {
        (try? JSONEncoder().encode(strokes))?.hashValue ?? 0
    }

    /// Grayscale mask (white = painted) covering `size`, CI coordinates.
    static func image(strokes: [BrushStroke], size: CGSize, feather: CGFloat = 0) -> CIImage {
        let longEdge = max(size.width, size.height)
        // Masks are soft; 2048 px is plenty and keeps export memory flat.
        let rasterScale = min(1, 2048 / longEdge)
        let w = max(1, Int(size.width * rasterScale)), h = max(1, Int(size.height * rasterScale))
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else {
            return CIImage.empty()
        }
        ctx.setFillColor(gray: 0, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.setStrokeColor(gray: 1, alpha: 1)
        ctx.setFillColor(gray: 1, alpha: 1)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        let rasterLong = CGFloat(max(w, h))
        for stroke in strokes {
            let r = stroke.radius * rasterLong
            let pts = stroke.points.map { CGPoint(x: $0.x * CGFloat(w), y: (1 - $0.y) * CGFloat(h)) }
            if pts.count == 1, let p = pts.first {
                ctx.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r))
            } else if let first = pts.first {
                ctx.setLineWidth(2 * r)
                ctx.move(to: first)
                for p in pts.dropFirst() { ctx.addLine(to: p) }
                ctx.strokePath()
            }
        }
        guard let cg = ctx.makeImage() else { return CIImage.empty() }
        var img = CIImage(cgImage: cg)
            .transformed(by: CGAffineTransform(scaleX: size.width / CGFloat(w), y: size.height / CGFloat(h)))
        if feather > 0 {
            img = img.clampedToExtent().applyingGaussianBlur(sigma: feather).cropped(to: CGRect(origin: .zero, size: size))
        }
        return img.cropped(to: CGRect(origin: .zero, size: size))
    }
}

nonisolated extension RenderPipeline {
    /// Heal = normalized-convolution fill: blur the surroundings with the hole weighted out.
    func applyHeal(_ img: CIImage) -> CIImage {
        guard !document.heal.isEmpty else { return img }
        let key = "heal:\(StrokeMask.key(document.heal)):\(Int(sourceSize.width))"
        let mask: CIImage = session.cached(key) {
            StrokeMask.image(strokes: document.heal, size: sourceSize, feather: 1.5 * max(1, scale))
        }
        let maxRadius = document.heal.map(\.radius).max() ?? 0.01
        let sigma = max(2, maxRadius * max(sourceSize.width, sourceSize.height) * 0.9)
        let extent = img.extent
        let keep = mask.applyingFilter("CIColorInvert")
        let weighted = img.applyingFilter("CIBlendWithAlphaMask", parameters: [
            kCIInputBackgroundImageKey: CIImage.clear.cropped(to: extent),
            kCIInputMaskImageKey: keep.applyingFilter("CIMaskToAlpha"),
        ])
        let filled = weighted.clampedToExtent()
            .applyingGaussianBlur(sigma: sigma)
            .unpremultiplyingAlpha()
            .settingAlphaOne(in: extent)
            .cropped(to: extent)
        return Self.blend(img, filled, mask: mask)
    }

    func applyPatches(_ img: CIImage) -> CIImage {
        var out = img
        for patch in document.patches {
            guard let asset = session.assetImage(patch.asset) else { continue }
            let fitted = asset.transformed(by: CGAffineTransform(
                scaleX: sourceSize.width / asset.extent.width,
                y: sourceSize.height / asset.extent.height), highQualityDownsample: true)
            if let strokes = patch.mask {
                let key = "patch:\(patch.id):\(Int(sourceSize.width))"
                let mask: CIImage = session.cached(key) {
                    StrokeMask.image(strokes: strokes, size: sourceSize, feather: 6 * max(1, scale))
                }
                out = Self.blend(out, fitted, mask: mask)
            } else {
                out = fitted.cropped(to: img.extent)
            }
        }
        return out
    }
}
