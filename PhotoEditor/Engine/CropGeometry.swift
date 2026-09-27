import CoreGraphics
import CoreImage

/// Maps source pixel space → straightened space → cropped output. CI coordinates (y up).
nonisolated struct CropGeometry {
    let crop: CropSpec
    let sourceSize: CGSize

    /// Size after quarter turns (and straighten, which keeps the frame).
    var rotatedSize: CGSize {
        crop.quarterTurns % 2 == 0 ? sourceSize : CGSize(width: sourceSize.height, height: sourceSize.width)
    }

    /// Crop rect in rotated space, CI coordinates.
    var cropRect: CGRect {
        let s = rotatedSize
        let r = crop.rect
        return CGRect(x: r.minX * s.width, y: (1 - r.maxY) * s.height,
                      width: r.width * s.width, height: r.height * s.height).integral
            .intersection(CGRect(origin: .zero, size: s))
    }

    var outputSize: CGSize { cropRect.size }

    /// Source space → rotated+straightened space (frame = 0,0,rotatedSize).
    var straightenTransform: CGAffineTransform {
        let w = sourceSize.width, h = sourceSize.height
        let turns = ((crop.quarterTurns % 4) + 4) % 4
        var t = CGAffineTransform.identity
        switch turns {
        case 1: t = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: h, ty: 0)
        case 2: t = CGAffineTransform(a: -1, b: 0, c: 0, d: -1, tx: w, ty: h)
        case 3: t = CGAffineTransform(a: 0, b: -1, c: 1, d: 0, tx: 0, ty: w)
        default: break
        }
        let rs = rotatedSize
        if crop.flipped {
            t = t.concatenating(CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: rs.width, ty: 0))
        }
        if crop.angle != 0 {
            let theta = crop.angle * .pi / 180
            let s = Self.fillScale(size: rs, angle: theta)
            let cx = rs.width / 2, cy = rs.height / 2
            t = t.concatenating(CGAffineTransform(translationX: -cx, y: -cy))
                .concatenating(CGAffineTransform(rotationAngle: -theta))
                .concatenating(CGAffineTransform(scaleX: s, y: s))
                .concatenating(CGAffineTransform(translationX: cx, y: cy))
        }
        return t
    }

    /// Scale that keeps a rotated image covering its original frame.
    static func fillScale(size: CGSize, angle: Double) -> Double {
        let c = abs(cos(angle)), s = abs(sin(angle))
        let w = size.width, h = size.height
        return max((w * c + h * s) / w, (w * s + h * c) / h)
    }

    /// Full source-space → output-space transform (output origin at 0).
    var outputTransform: CGAffineTransform {
        let r = cropRect
        return straightenTransform.concatenating(CGAffineTransform(translationX: -r.minX, y: -r.minY))
    }

    func applyStraighten(_ image: CIImage) -> CIImage {
        image.transformed(by: straightenTransform, highQualityDownsample: true)
            .cropped(to: CGRect(origin: .zero, size: rotatedSize))
    }

    func apply(_ image: CIImage) -> CIImage {
        image.transformed(by: outputTransform, highQualityDownsample: true)
            .cropped(to: CGRect(origin: .zero, size: outputSize))
    }
}
