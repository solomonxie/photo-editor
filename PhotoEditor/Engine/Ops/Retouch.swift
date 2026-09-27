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
    }
    var faces: [Face]

    static func run(on cg: CGImage) -> FaceAnalysis {
        let request = VNDetectFaceLandmarksRequest()
        try? VNImageRequestHandler(cgImage: cg).perform([request])
        let faces = (request.results ?? []).map { obs in
            let lm = obs.landmarks
            let regions = [lm?.leftEye, lm?.rightEye, lm?.outerLips, lm?.leftEyebrow, lm?.rightEyebrow].compactMap { $0 }
            let holes = regions.map { region in
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
            return Face(bounds: obs.boundingBox, holes: holes, contour: image(lm?.faceContour),
                        leftEye: feature(lm?.leftEye), rightEye: feature(lm?.rightEye), nose: feature(lm?.nose),
                        pupils: image(lm?.leftPupil) + image(lm?.rightPupil))
        }
        return FaceAnalysis(faces: faces)
    }

    /// Soft skin mask in source space of `size` (CI coordinates).
    func mask(size: CGSize) -> CIImage {
        let longEdge = max(size.width, size.height)
        let rs = min(1, 1024 / longEdge)
        let w = max(1, Int(size.width * rs)), h = max(1, Int(size.height * rs))
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else {
            return CIImage.empty()
        }
        ctx.setFillColor(gray: 0, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        let sx = CGFloat(w), sy = CGFloat(h)
        for face in faces {
            let b = face.bounds
            // Face oval, stretched up to take in the forehead.
            let oval = CGRect(x: b.minX * sx, y: b.minY * sy - b.height * sy * 0.05,
                              width: b.width * sx, height: b.height * sy * 1.3)
            ctx.setFillColor(gray: 1, alpha: 1)
            ctx.fillEllipse(in: oval)
            ctx.setFillColor(gray: 0, alpha: 1)
            for hole in face.holes where hole.count > 2 {
                let pts = hole.map { CGPoint(x: $0.x * sx, y: $0.y * sy) }
                ctx.move(to: pts[0])
                pts.dropFirst().forEach { ctx.addLine(to: $0) }
                ctx.closePath()
                ctx.fillPath()
            }
        }
        guard let cg = ctx.makeImage() else { return CIImage.empty() }
        let feather = max(sx, sy) * 0.008
        return CIImage(cgImage: cg)
            .clampedToExtent()
            .applyingGaussianBlur(sigma: feather)
            .cropped(to: CGRect(x: 0, y: 0, width: w, height: h))
            .transformed(by: CGAffineTransform(scaleX: size.width / sx, y: size.height / sy))
    }
}

nonisolated extension RenderPipeline {
    var faces: FaceAnalysis {
        session.cached("faces") { FaceAnalysis.run(on: session.proxyCGImage) }
    }

    func applySmoothSkin(_ img: CIImage, unedited: CIImage) -> CIImage {
        let amount = document.smoothSkin / 100
        guard amount > 0, !faces.faces.isEmpty else { return img }
        let key = "skinmask:\(Int(sourceSize.width))"
        let sourceMask: CIImage = session.cached(key) { faces.mask(size: sourceSize) }
        let mask = toOutput(sourceMask)

        // Only run the expensive kernel over the faces.
        let faceRect = faces.faces
            .map { CGRect(x: $0.bounds.minX * sourceSize.width, y: $0.bounds.minY * sourceSize.height,
                          width: $0.bounds.width * sourceSize.width, height: $0.bounds.height * sourceSize.height * 1.3) }
            .reduce(CGRect.null) { $0.union($1) }
            .applying(geometry.outputTransform)
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
