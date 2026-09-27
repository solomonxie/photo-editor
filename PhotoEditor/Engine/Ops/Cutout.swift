import CoreImage
import CoreVideo
import Vision

/// Vision foreground instances found on the proxy.
nonisolated final class SubjectAnalysis: @unchecked Sendable {
    let observation: VNInstanceMaskObservation?
    let handler: VNImageRequestHandler
    let instances: [Int]

    init(cgImage: CGImage) {
        handler = VNImageRequestHandler(cgImage: cgImage)
        let request = VNGenerateForegroundInstanceMaskRequest()
        try? handler.perform([request])
        observation = request.results?.first
        instances = observation.map { Array($0.allInstances).sorted() } ?? []
    }

    /// Instance label under a normalized point (origin top-left), 0 = background.
    func instance(at point: CGPoint) -> Int {
        guard let buffer = observation?.instanceMask else { return 0 }
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        let w = CVPixelBufferGetWidth(buffer), h = CVPixelBufferGetHeight(buffer)
        let x = min(w - 1, max(0, Int(point.x * CGFloat(w))))
        let y = min(h - 1, max(0, Int(point.y * CGFloat(h))))
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return 0 }
        let row = base.advanced(by: y * CVPixelBufferGetBytesPerRow(buffer)).assumingMemoryBound(to: UInt8.self)
        return Int(row[x])
    }

    /// Soft mask of the chosen instances, sized to the proxy (CI coordinates).
    func mask(for subjects: [Int]) -> CIImage? {
        guard let obs = observation, !subjects.isEmpty,
              let buffer = try? obs.generateScaledMaskForImage(forInstances: IndexSet(subjects), from: handler) else { return nil }
        return CIImage(cvPixelBuffer: buffer)
    }
}

nonisolated extension RenderPipeline {
    var subjects: SubjectAnalysis {
        session.cached("subjects") { SubjectAnalysis(cgImage: session.proxyCGImage) }
    }

    /// Subject mask in source space (render resolution).
    func subjectMask(_ spec: CutoutSpec) -> CIImage? {
        let key = "cutout:\(spec.subjects):\(Int(sourceSize.width))"
        let mask: CIImage? = session.cached(key) {
            guard let m = subjects.mask(for: spec.subjects) else { return nil }
            return m.transformed(by: CGAffineTransform(
                scaleX: sourceSize.width / m.extent.width, y: sourceSize.height / m.extent.height),
                highQualityDownsample: true)
        }
        return mask
    }

    /// While choosing subjects: dim everything that isn't selected.
    func highlightSubjects(_ img: CIImage) -> CIImage {
        guard let spec = document.cutout, let sourceMask = subjectMask(spec) else { return img }
        let dimmed = img.applyingFilter("CIColorControls", parameters: [kCIInputBrightnessKey: -0.35, kCIInputSaturationKey: 0.4])
        return Self.blend(dimmed, img, mask: toOutput(sourceMask)).cropped(to: img.extent)
    }

    func applyCutout(_ img: CIImage) -> CIImage {
        guard let spec = document.cutout, spec.background != .keep, let sourceMask = subjectMask(spec) else { return img }
        let mask = toOutput(sourceMask)
        let extent = img.extent
        let background: CIImage
        switch spec.background {
        case .keep:
            return img
        case .remove:
            background = CIImage.clear
        case .blur:
            let sigma = max(1, spec.blur / 100 * 0.02 * max(extent.width, extent.height))
            background = img.clampedToExtent().applyingGaussianBlur(sigma: sigma)
        case .color:
            let c = spec.color
            background = CIImage(color: CIColor(red: c.r, green: c.g, blue: c.b, alpha: c.a, colorSpace: RenderEngine.outputSpace)!)
        }
        return Self.blend(background.cropped(to: extent), img, mask: mask).cropped(to: extent)
    }
}
