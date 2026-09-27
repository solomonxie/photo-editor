import CoreImage
import Metal
import os

nonisolated enum RenderEngine {
    static let device: MTLDevice = MTLCreateSystemDefaultDevice()!
    static let workingSpace = CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3)!
    static let outputSpace = CGColorSpace(name: CGColorSpace.displayP3)!

    static let context = CIContext(mtlDevice: device, options: [
        .workingColorSpace: workingSpace,
        .workingFormat: CIFormat.RGBAh,
        .cacheIntermediates: true,
        .name: "PhotoEditor.preview",
    ])

    static let exportContext = CIContext(mtlDevice: device, options: [
        .workingColorSpace: workingSpace,
        .workingFormat: CIFormat.RGBAh,
        .cacheIntermediates: false,
        .name: "PhotoEditor.export",
    ])

    static let signposter = OSSignposter(subsystem: "com.solomonxie.photoeditor", category: "render")
}

/// What to produce from a document.
nonisolated struct RenderOptions {
    enum Mode { case edited, original, straightenOnly }
    var mode: Mode = .edited
    var includeLayers = true
    var highlightSubjects = false
}

/// Builds the lazy CIImage graph for an EditDocument.
///
/// `source` may be a proxy or the full-res original; every pixel-sized parameter is
/// expressed in full-res pixels and multiplied by `scale`, so preview and export match.
nonisolated struct RenderPipeline {
    let session: RenderSession
    let document: EditDocument
    let source: CIImage

    var sourceSize: CGSize { source.extent.size }
    var scale: CGFloat { sourceSize.width / document.source.size.width }
    var geometry: CropGeometry { CropGeometry(crop: document.crop, sourceSize: sourceSize) }

    func image(_ options: RenderOptions = RenderOptions()) -> CIImage {
        let state = RenderEngine.signposter.beginInterval("graph")
        defer { RenderEngine.signposter.endInterval("graph", state) }

        if options.mode == .original { return source }

        var img = source
        img = applyPatches(img)
        img = applyHeal(img)
        img = applyRedEye(img)
        img = applyWarp(img)

        let preGeometry = img
        if options.mode == .straightenOnly {
            return geometry.applyStraighten(img)
        }
        img = geometry.apply(img)

        img = applyAdjust(img)
        img = applyFilter(img)
        img = applySmoothSkin(img, unedited: preGeometry)
        img = applyCutout(img)
        if options.highlightSubjects, document.cutout?.background == .keep {
            img = highlightSubjects(img)
        }
        if options.includeLayers {
            img = applyLayers(img)
        }
        return img.cropped(to: CGRect(origin: .zero, size: geometry.outputSize))
    }

    /// Renders a mask that lives in source space into output space.
    func toOutput(_ sourceSpaceMask: CIImage) -> CIImage {
        geometry.apply(sourceSpaceMask)
    }

    static func blend(_ base: CIImage, _ top: CIImage, mask: CIImage) -> CIImage {
        top.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: base,
            kCIInputMaskImageKey: mask,
        ])
    }
}
