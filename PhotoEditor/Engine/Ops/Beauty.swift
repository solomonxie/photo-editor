import CoreImage
import Foundation

/// Beauty ops on the face masks, in output space.
nonisolated extension RenderPipeline {
    func faceMask(_ name: String, feather: CGFloat = 0.008,
                  _ draw: @escaping (FaceAnalysis.Face, CGContext, CGFloat, CGFloat) -> Void) -> CIImage {
        let key = "facemask:\(name):\(Int(sourceSize.width))"
        let source: CIImage = session.cached(key) {
            MaskPainter.paint(size: sourceSize, feather: feather) { ctx, sx, sy in
                for face in faces.faces { draw(face, ctx, sx, sy) }
            }
        }
        return toOutput(source)
    }

    /// Face ovals × "looks like this face's skin", so hair, brows and background inside the oval are left alone.
    func skinMask(for img: CIImage) -> CIImage {
        let key = "skinmask:\(Int(sourceSize.width))"
        let oval = toOutput(session.cached(key) { faces.mask(size: sourceSize) })
        guard let cube = skinCube else { return oval }
        let likely = img.applyingFilter("CIColorCubeWithColorSpace", parameters: [
            "inputCubeDimension": SkinTone.cubeSize,
            "inputCubeData": cube,
            "inputColorSpace": CGColorSpace(name: CGColorSpace.sRGB)!,
        ])
        .applyingGaussianBlur(sigma: max(1, faceWidthPx * 0.006))
        .cropped(to: img.extent)
        return likely.applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: oval])
    }

    private var skinCube: Data? {
        session.cached("skincube") { SkinTone.sample(faces, proxy: session.proxy).map(SkinTone.cube) }
    }

    func applyBeauty(_ img: CIImage) -> CIImage {
        let v = document.beauty
        guard !v.isEmpty, !faces.faces.isEmpty else { return img }
        let extent = img.extent
        var out = img
        let skinMask = skinMask(for: img)
        func amount(_ k: BeautyKey) -> Double? {
            guard let a = v[k], a > 0 else { return nil }
            return a / 100
        }

        if let a = amount(.whiten) {
            let lifted = out
                .applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: 0.55 * a])
                .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 1 - 0.3 * a])
                .applyingFilter("CITemperatureAndTint", parameters: [
                    "inputNeutral": CIVector(x: 6500, y: 0), "inputTargetNeutral": CIVector(x: 6500 + 900 * a, y: 0),
                ])
            out = Self.blend(out, lifted, mask: skinMask)
        }
        if let a = amount(.evenTone) {
            let sigma = faceWidthPx * 0.05
            let blurred = out.clampedToExtent().applyingGaussianBlur(sigma: sigma).cropped(to: extent)
            // Colour of the blur, luminance (texture) of the original.
            let even = blurred.applyingFilter("CIColorBlendMode", parameters: [kCIInputBackgroundImageKey: out])
            out = Self.blend(out, even, mask: scaled(skinMask, a))
        }
        if let a = amount(.deShine) {
            let matte = out.applyingFilter("CIHighlightShadowAdjust", parameters: [
                "inputHighlightAmount": 1 - 0.8 * a, "inputRadius": faceWidthPx * 0.02,
            ])
            out = Self.blend(out, matte, mask: skinMask)
        }
        if let a = amount(.darkCircles) {
            let mask = faceMask("undereye", feather: 0.006) { face, ctx, sx, sy in
                for eye in [face.leftEye, face.rightEye].compactMap({ $0 }) {
                    let w = eye.width * sx
                    let c = CGPoint(x: eye.center.x * sx, y: eye.center.y * sy - w * 0.42)
                    ctx.fillEllipse(in: CGRect(x: c.x - w * 0.6, y: c.y - w * 0.22, width: w * 1.2, height: w * 0.44))
                }
            }
            let lifted = out
                .applyingFilter("CIHighlightShadowAdjust", parameters: ["inputShadowAmount": 0.9 * a])
                .applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: 0.35 * a])
            out = Self.blend(out, lifted, mask: mask)
        }
        if let a = amount(.brightEyes) {
            let eyes = faceMask("eyepolys", feather: 0.002) { face, ctx, sx, sy in
                for r in [FaceAnalysis.Region.leftEye, .rightEye] {
                    MaskPainter.fill(face.regions[r] ?? [], in: ctx, sx: sx, sy: sy)
                }
            }
            let bright = out
                .applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: 0.45 * a])
                .applyingFilter("CISharpenLuminance", parameters: [kCIInputSharpnessKey: 1.2 * a, kCIInputRadiusKey: 2.0 * max(1, scale)])
                .applyingFilter("CIVibrance", parameters: ["inputAmount": 0.4 * a])
            out = Self.blend(out, bright, mask: eyes)
        }
        if let a = amount(.teeth) {
            let mouth = faceMask("teeth", feather: 0.002) { face, ctx, sx, sy in
                MaskPainter.fill(face.regions[.innerLips] ?? [], in: ctx, sx: sx, sy: sy)
            }
            let white = out
                .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 1 - 0.75 * a])
                .applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: 0.4 * a])
            out = Self.blend(out, white, mask: mouth)
        }
        return out.cropped(to: extent)
    }

    /// Widest face, in render pixels.
    var faceWidthPx: CGFloat {
        (faces.faces.map(\.bounds.width).max() ?? 0.2) * sourceSize.width
    }

    func scaled(_ mask: CIImage, _ k: Double) -> CIImage {
        mask.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: k, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: k, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: k, w: 0),
        ])
    }
}

/// One-tap looks. They write ordinary values, so every slider stays editable afterwards.
nonisolated enum BeautyLook: String, CaseIterable, Sendable {
    case off, natural, soft, glam

    var title: String { rawValue.capitalized }

    private var values: (smooth: Double, beauty: [BeautyKey: Double], face: [FaceShapeKey: Double]) {
        switch self {
        case .off: (0, [:], [:])
        case .natural: (35, [.whiten: 20, .evenTone: 25, .darkCircles: 30, .brightEyes: 20], [.slim: 10, .eyes: 8])
        case .soft: (60, [.whiten: 35, .evenTone: 40, .deShine: 30, .darkCircles: 50, .brightEyes: 30], [.slim: 20, .eyes: 15])
        case .glam: (70, [.whiten: 45, .evenTone: 45, .deShine: 50, .darkCircles: 60, .brightEyes: 50, .teeth: 40],
                     [.slim: 30, .eyes: 25, .nose: 15, .jaw: 10])
        }
    }

    func apply(to doc: inout EditDocument) {
        let v = values
        doc.smoothSkin = v.smooth
        doc.beauty = v.beauty
        for key in [FaceShapeKey.slim, .eyes, .nose, .jaw] { doc.reshape.face[key] = v.face[key] }
    }

    static func current(_ doc: EditDocument) -> BeautyLook? {
        allCases.first { look in
            var copy = doc
            look.apply(to: &copy)
            return copy == doc
        }
    }
}

/// The face's own skin colour and a colour cube that scores how close any colour is to it.
nonisolated enum SkinTone {
    static let cubeSize = 32

    /// Average sRGB colour of the cheeks-and-nose band of the largest face.
    static func sample(_ faces: FaceAnalysis, proxy: CIImage) -> SIMD3<Float>? {
        guard let face = faces.faces.max(by: { $0.bounds.width < $1.bounds.width }) else { return nil }
        let b = face.bounds
        let size = proxy.extent.size
        let rect = CGRect(x: (b.minX + b.width * 0.25) * size.width, y: (b.minY + b.height * 0.3) * size.height,
                          width: b.width * 0.5 * size.width, height: b.height * 0.25 * size.height)
        let avg = proxy.cropped(to: rect).applyingFilter("CIAreaAverage", parameters: [kCIInputExtentKey: CIVector(cgRect: rect)])
        var px = [UInt8](repeating: 0, count: 4)
        RenderEngine.context.render(avg, toBitmap: &px, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                                    format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
        return SIMD3(Float(px[0]), Float(px[1]), Float(px[2])) / 255
    }

    static func ycc(_ c: SIMD3<Float>) -> SIMD3<Float> {
        let y = 0.299 * c.x + 0.587 * c.y + 0.114 * c.z
        return SIMD3(y, (c.z - y) * 0.564, (c.x - y) * 0.713)
    }

    static func cube(_ skin: SIMD3<Float>) -> Data {
        let n = cubeSize
        let s = ycc(skin)
        var data = [Float](repeating: 1, count: n * n * n * 4)
        for b in 0..<n {
            for g in 0..<n {
                for r in 0..<n {
                    let c = ycc(SIMD3(Float(r), Float(g), Float(b)) / Float(n - 1))
                    let d2 = (c.y - s.y) * (c.y - s.y) + (c.z - s.z) * (c.z - s.z)
                    let chroma = exp(-d2 / (2 * 0.045 * 0.045))
                    let luma = min(1, max(0, (c.x - s.x * 0.35) / max(0.01, s.x * 0.3)))
                    let v = chroma * luma
                    let i = ((b * n + g) * n + r) * 4
                    data[i] = v
                    data[i + 1] = v
                    data[i + 2] = v
                }
            }
        }
        return data.withUnsafeBytes { Data($0) }
    }
}
