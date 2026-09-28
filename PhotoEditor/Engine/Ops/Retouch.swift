import CoreImage
import Foundation
import Vision

/// Faces found on the proxy, normalized (Vision coordinates: origin bottom-left).
nonisolated struct FaceAnalysis: Sendable {
    struct Feature: Sendable {
        var center: CGPoint
        /// Fraction of image width.
        var width: Double
    }

    struct Face: Sendable {
        var bounds: CGRect
        var holes: [[CGPoint]]
        var contour: [CGPoint] = []
        var leftEye: Feature?
        var rightEye: Feature?
        var nose: Feature?
        var pupils: [CGPoint] = []
        var regions: [Region: [CGPoint]] = [:]

        var width: Double { bounds.width }
    }

    enum Region: Sendable {
        case leftEye, rightEye, leftBrow, rightBrow, outerLips, innerLips, noseCrest, contour
    }
    var faces: [Face]

    static func run(on cg: CGImage) -> FaceAnalysis {
        let request = VNDetectFaceLandmarksRequest()
        try? VNImageRequestHandler(cgImage: cg).perform([request])
        let faces = (request.results ?? []).map { obs in
            let lm = obs.landmarks
            let holeRegions = [lm?.leftEye, lm?.rightEye, lm?.outerLips, lm?.leftEyebrow, lm?.rightEyebrow].compactMap { $0 }
            let holes = holeRegions.map { region in
                region.normalizedPoints.map { p in
                    CGPoint(x: obs.boundingBox.minX + p.x * obs.boundingBox.width,
                            y: obs.boundingBox.minY + p.y * obs.boundingBox.height)
                }
            }
            func image(_ region: VNFaceLandmarkRegion2D?) -> [CGPoint] {
                (region?.normalizedPoints ?? []).map { p in
                    CGPoint(x: obs.boundingBox.minX + p.x * obs.boundingBox.width,
                            y: obs.boundingBox.minY + p.y * obs.boundingBox.height)
                }
            }
            func feature(_ region: VNFaceLandmarkRegion2D?) -> Feature? {
                let pts = image(region)
                guard pts.count > 1 else { return nil }
                let xs = pts.map(\.x), ys = pts.map(\.y)
                return Feature(center: CGPoint(x: xs.reduce(0, +) / Double(xs.count), y: ys.reduce(0, +) / Double(ys.count)),
                               width: xs.max()! - xs.min()!)
            }
            let regions: [Region: [CGPoint]] = [
                .leftEye: image(lm?.leftEye), .rightEye: image(lm?.rightEye),
                .leftBrow: image(lm?.leftEyebrow), .rightBrow: image(lm?.rightEyebrow),
                .outerLips: image(lm?.outerLips), .innerLips: image(lm?.innerLips),
                .noseCrest: image(lm?.noseCrest), .contour: image(lm?.faceContour),
            ]
            return Face(bounds: obs.boundingBox, holes: holes, contour: image(lm?.faceContour),
                        leftEye: feature(lm?.leftEye), rightEye: feature(lm?.rightEye), nose: feature(lm?.nose),
                        pupils: image(lm?.leftPupil) + image(lm?.rightPupil), regions: regions)
        }
        return FaceAnalysis(faces: faces)
    }

    /// Soft skin mask in source space of `size` (CI coordinates).
    func mask(size: CGSize) -> CIImage {
        MaskPainter.paint(size: size, feather: 0.008) { ctx, sx, sy in
            for face in faces {
                let b = face.bounds
                // Face oval, stretched up to take in the forehead.
                let oval = CGRect(x: b.minX * sx, y: b.minY * sy - b.height * sy * 0.05,
                                  width: b.width * sx, height: b.height * sy * 1.3)
                ctx.setFillColor(gray: 1, alpha: 1)
                ctx.fillEllipse(in: oval)
                ctx.setFillColor(gray: 0, alpha: 1)
                for hole in face.holes where hole.count > 2 {
                    MaskPainter.fill(hole, in: ctx, sx: sx, sy: sy)
                }
            }
        }
    }
}

/// Rasterizes soft masks at ≤1024 px and scales them to `size`. Points are normalized, origin bottom-left.
nonisolated enum MaskPainter {
    static func paint(size: CGSize, feather: CGFloat, _ draw: (CGContext, CGFloat, CGFloat) -> Void) -> CIImage {
        let longEdge = max(size.width, size.height)
        let rs = min(1, 1024 / longEdge)
        let w = max(1, Int(size.width * rs)), h = max(1, Int(size.height * rs))
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else {
            return CIImage.empty()
        }
        ctx.setFillColor(gray: 0, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.setFillColor(gray: 1, alpha: 1)
        ctx.setStrokeColor(gray: 1, alpha: 1)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        let sx = CGFloat(w), sy = CGFloat(h)
        draw(ctx, sx, sy)
        guard let cg = ctx.makeImage() else { return CIImage.empty() }
        var img = CIImage(cgImage: cg)
        if feather > 0 {
            img = img.clampedToExtent()
                .applyingGaussianBlur(sigma: max(sx, sy) * feather)
                .cropped(to: CGRect(x: 0, y: 0, width: w, height: h))
        }
        return img.transformed(by: CGAffineTransform(scaleX: size.width / sx, y: size.height / sy))
    }

    static func fill(_ pts: [CGPoint], in ctx: CGContext, sx: CGFloat, sy: CGFloat) {
        guard pts.count > 2 else { return }
        ctx.move(to: CGPoint(x: pts[0].x * sx, y: pts[0].y * sy))
        pts.dropFirst().forEach { ctx.addLine(to: CGPoint(x: $0.x * sx, y: $0.y * sy)) }
        ctx.closePath()
        ctx.fillPath()
    }

    static func stroke(_ pts: [CGPoint], width: CGFloat, in ctx: CGContext, sx: CGFloat, sy: CGFloat) {
        guard pts.count > 1 else { return }
        ctx.setLineWidth(width)
        ctx.move(to: CGPoint(x: pts[0].x * sx, y: pts[0].y * sy))
        pts.dropFirst().forEach { ctx.addLine(to: CGPoint(x: $0.x * sx, y: $0.y * sy)) }
        ctx.strokePath()
    }
}

nonisolated extension RenderPipeline {
    var faces: FaceAnalysis {
        session.cached("faces") { FaceAnalysis.run(on: session.proxyCGImage) }
    }

    func applySmoothSkin(_ img: CIImage) -> CIImage {
        let amount = document.smoothSkin / 100
        guard amount > 0, !faces.faces.isEmpty else { return img }
        let mask = skinMask(for: img)

        // Only run the expensive kernel over the faces.
        let faceRect = faces.faces
            .map { CGRect(x: $0.bounds.minX * sourceSize.width, y: $0.bounds.minY * sourceSize.height,
                          width: $0.bounds.width * sourceSize.width, height: $0.bounds.height * sourceSize.height * 1.3) }
            .map { $0.insetBy(dx: 0, dy: -$0.height * 0.08) }
            .reduce(CGRect.null) { $0.union($1) }
            .insetBy(dx: -20 * scale, dy: -20 * scale)
            .intersection(img.extent)
        guard !faceRect.isNull, !faceRect.isEmpty else { return img }

        // Edge-preserving smoothing: shrink the face area, then upsample guided by the full-detail image.
        let faceWidth = (faces.faces.map(\.bounds.width).max() ?? 0.2) * sourceSize.width
        let factor = max(4, min(24, faceWidth / 40)) * (0.6 + 0.4 * amount)
        let region = img.cropped(to: faceRect)
        let small = region.transformed(by: CGAffineTransform(scaleX: 1 / factor, y: 1 / factor), highQualityDownsample: true)
        let smoothed = region.applyingFilter("CIEdgePreserveUpsampleFilter", parameters: [
            "inputSmallImage": small,
            "inputSpatialSigma": 5.0,
            "inputLumaSigma": 0.1 + 0.08 * amount,
        ]).cropped(to: faceRect)

        let strength = mask.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: amount * 0.85, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: amount * 0.85, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: amount * 0.85, w: 0),
        ])
        let smoothedFull = smoothed.composited(over: img)
        return Self.blend(img, smoothedFull, mask: strength).cropped(to: img.extent)
    }
}

nonisolated extension RenderPipeline {
    /// Core Image's red-eye correction, detected on the image being rendered (its parameters are pixel-based).
    func applyRedEye(_ img: CIImage) -> CIImage {
        guard document.redEye, !faces.faces.isEmpty else { return img }
        let filters: [CIFilter] = session.cached("redeye:\(Int(img.extent.width))") {
            img.autoAdjustmentFilters(options: [.enhance: false, .redEye: true])
        }
        var out = img
        for f in filters {
            guard let copy = f.copy() as? CIFilter else { continue }
            copy.setValue(out, forKey: kCIInputImageKey)
            out = copy.outputImage ?? out
        }
        return out
    }
}
