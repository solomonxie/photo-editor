import CoreImage
import Foundation

/// Prepares an AI job from the photo, runs it through the keys in fallback order,
/// and turns the result into a full-frame patch asset.
enum AIRunner {
    struct Outcome {
        var patch: PatchOp
        var vendor: AIVendor
        var fellBackFrom: AIVendor?
    }

    enum Failure: LocalizedError {
        case noKeys
        case all([AIError])

        var errorDescription: String? {
            switch self {
            case .noKeys:
                return "Add an AI key first."
            case .all(let errors):
                if errors.count > 1, let last = errors.last {
                    return "\(last.localizedDescription) Tried \(errors.count) keys."
                }
                return errors.first?.localizedDescription ?? "The AI request failed."
            }
        }

        var firstAuthError: Bool {
            if case .all(let e) = self { return e.contains { $0.isAuth } }
            return false
        }
    }

    nonisolated static let maxLongEdge: CGFloat = 1536

    static func run(kind: AIImageJob.Kind, prompt: String, strokes: [BrushStroke]?,
                    model: EditorModel, keys: AIKeyStore) async throws -> Outcome {
        let order = keys.attemptOrder()
        guard !order.isEmpty else { throw Failure.noKeys }

        // The photo with existing patches and heal applied.
        var doc = model.document
        doc.smoothSkin = 0
        doc.cutout = nil
        doc.layers = []
        let base = model.pipeline(doc).image()
        let assets = model.project.assetsURL
        let sourceSize = model.document.source.size

        var errors: [AIError] = []
        for info in order {
            guard let secret = keys.secret(for: info) else { continue }
            let vendor = info.vendor
            do {
                let job = try await prepare(kind: kind, prompt: prompt, base: base, strokes: strokes, vendor: vendor)
                let result = try await vendor.client.run(job.job, key: secret)
                keys.recordSuccess(info.id)
                let name = try await store(result, placement: job.placement, sourceSize: sourceSize, assets: assets)
                let patchKind: PatchOp.Kind = switch kind {
                case .erase: .magicErase
                case .fill: .fill
                case .restyle: .restyle
                }
                let patch = PatchOp(kind: patchKind, asset: name, mask: strokes)
                return Outcome(patch: patch, vendor: vendor, fellBackFrom: errors.first?.vendor)
            } catch let e as AIError {
                keys.recordFailure(info.id, message: e.rowSummary)
                errors.append(e)
                if !e.shouldFallback { break }
            }
        }
        throw Failure.all(errors)
    }

    struct Prepared: Sendable {
        var job: AIImageJob
        /// Where the photo sits inside the sent canvas (pixels, CI coordinates).
        var placement: CGRect
        var canvas: CGSize
    }

    @concurrent
    private static func prepare(kind: AIImageJob.Kind, prompt: String, base: CIImage, strokes: [BrushStroke]?,
                                vendor: AIVendor) async throws -> Prepared {
        let ctx = RenderEngine.exportContext
        let size = base.extent.size
        let s = min(1, maxLongEdge / max(size.width, size.height))
        let scaled = base.transformed(by: CGAffineTransform(scaleX: s, y: s), highQualityDownsample: true)
        let photoSize = CGSize(width: round(size.width * s), height: round(size.height * s))

        // OpenAI only returns fixed sizes, so letterbox into one with edge pixels.
        let canvas = vendor == .openAI ? OpenAIImageClient.canvasSize(for: photoSize) : photoSize
        let fit = min(canvas.width / photoSize.width, canvas.height / photoSize.height)
        let placedSize = CGSize(width: round(photoSize.width * fit), height: round(photoSize.height * fit))
        let placement = CGRect(x: floor((canvas.width - placedSize.width) / 2), y: floor((canvas.height - placedSize.height) / 2),
                               width: placedSize.width, height: placedSize.height)
        let placed = scaled
            .transformed(by: CGAffineTransform(scaleX: fit, y: fit).concatenating(CGAffineTransform(translationX: placement.minX, y: placement.minY)))
        let frame = CGRect(origin: .zero, size: canvas)
        let image = placed.clampedToExtent().cropped(to: frame)

        guard let imagePNG = ctx.pngRepresentation(of: image, format: .RGBA8, colorSpace: RenderEngine.outputSpace) else {
            throw AIError(vendor: vendor, status: nil, code: nil, message: "Couldn't encode the photo.")
        }

        var alphaMask: Data?
        var highlighted: Data?
        if let strokes, !strokes.isEmpty {
            let sourceMask = StrokeMask.image(strokes: strokes, size: size, feather: 0)
                .transformed(by: CGAffineTransform(scaleX: s * fit, y: s * fit).concatenating(CGAffineTransform(translationX: placement.minX, y: placement.minY)))
            let mask = sourceMask.composited(over: CIImage(color: .black).cropped(to: frame)).cropped(to: frame)
            // Transparent where painted.
            let alpha = CIImage(color: .white).cropped(to: frame)
                .applyingFilter("CIBlendWithMask", parameters: [
                    kCIInputBackgroundImageKey: CIImage.clear.cropped(to: frame),
                    kCIInputMaskImageKey: mask.applyingFilter("CIColorInvert"),
                ])
            alphaMask = ctx.pngRepresentation(of: image.applyingFilter("CIBlendWithAlphaMask", parameters: [
                kCIInputBackgroundImageKey: CIImage.clear.cropped(to: frame),
                kCIInputMaskImageKey: alpha,
            ]), format: .RGBA8, colorSpace: RenderEngine.outputSpace)
            let red = CIImage(color: CIColor(red: 1, green: 0, blue: 0)).cropped(to: frame)
            highlighted = ctx.pngRepresentation(of: red.applyingFilter("CIBlendWithMask", parameters: [
                kCIInputBackgroundImageKey: image,
                kCIInputMaskImageKey: mask,
            ]), format: .RGBA8, colorSpace: RenderEngine.outputSpace)
        }

        let fullPrompt: String
        switch kind {
        case .erase:
            fullPrompt = "Remove the objects in the masked area and fill it in so it blends seamlessly with the surrounding scene. Photorealistic; match lighting, texture and grain."
        case .fill:
            fullPrompt = "In the masked area: \(prompt). Photorealistic; match the photo's lighting, perspective, texture and grain so it blends seamlessly."
        case .restyle:
            fullPrompt = "Restyle this photo as \(prompt). Keep the same composition and subjects."
        }
        let job = AIImageJob(kind: kind, image: imagePNG, imageSize: canvas, alphaMask: alphaMask,
                             highlighted: highlighted, prompt: fullPrompt)
        return Prepared(job: job, placement: placement, canvas: canvas)
    }

    /// Crops the letterbox away and saves the result at the source's aspect.
    @concurrent
    private static func store(_ png: Data, placement: CGRect, sourceSize: CGSize, assets: URL) async throws -> String {
        guard var result = CIImage(data: png) else {
            throw AIError(vendor: .openAI, status: 200, code: "bad_image", message: "The returned image couldn't be read.")
        }
        result = result.transformed(by: CGAffineTransform(translationX: -result.extent.minX, y: -result.extent.minY))
        // The vendor may return a different pixel size than we sent; map the placement proportionally.
        let canvasW = placement.maxX + placement.minX
        let canvasH = placement.maxY + placement.minY
        let sx = result.extent.width / canvasW, sy = result.extent.height / canvasH
        let crop = CGRect(x: placement.minX * sx, y: placement.minY * sy, width: placement.width * sx, height: placement.height * sy)
        var photo = result.cropped(to: crop)
        photo = photo.transformed(by: CGAffineTransform(translationX: -crop.minX, y: -crop.minY))
        // Store at source aspect, capped for disk.
        let longEdge = min(2048, max(sourceSize.width, sourceSize.height))
        let k = longEdge / max(sourceSize.width, sourceSize.height)
        let target = CGSize(width: round(sourceSize.width * k), height: round(sourceSize.height * k))
        photo = photo.transformed(by: CGAffineTransform(scaleX: target.width / photo.extent.width, y: target.height / photo.extent.height))
        let name = "ai-\(UUID().uuidString).png"
        try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
        try RenderEngine.exportContext.writePNGRepresentation(of: photo.cropped(to: CGRect(origin: .zero, size: target)),
                                                             to: assets.appendingPathComponent(name),
                                                             format: .RGBA8, colorSpace: RenderEngine.outputSpace)
        return name
    }
}
