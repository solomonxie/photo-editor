import CoreImage
import Foundation
import ImageIO
import UniformTypeIdentifiers

nonisolated enum ExportFormat: String, CaseIterable, Codable, Sendable {
    case heic, jpeg, png

    var label: String { rawValue.uppercased() }
    var utType: UTType {
        switch self {
        case .heic: .heic
        case .jpeg: .jpeg
        case .png: .png
        }
    }
}

nonisolated enum ExportSize: String, CaseIterable, Sendable {
    case full, uhd, qhd

    var label: String {
        switch self {
        case .full: "Full"
        case .uhd: "4K"
        case .qhd: "2K"
        }
    }

    var maxLongEdge: CGFloat? {
        switch self {
        case .full: nil
        case .uhd: 3840
        case .qhd: 2048
        }
    }
}

nonisolated enum Exporter {
    enum Failure: LocalizedError {
        case original, encode
        var errorDescription: String? {
            switch self {
            case .original: "The original photo couldn't be read."
            case .encode: "The photo couldn't be encoded."
            }
        }
    }

    static func outputSize(_ doc: EditDocument, size: ExportSize) -> CGSize {
        let out = CropGeometry(crop: doc.crop, sourceSize: doc.source.size).outputSize
        guard let limit = size.maxLongEdge, max(out.width, out.height) > limit else { return out }
        let s = limit / max(out.width, out.height)
        return CGSize(width: round(out.width * s), height: round(out.height * s))
    }

    static func hasTransparency(_ doc: EditDocument) -> Bool {
        doc.cutout?.background == .remove
    }

    /// Renders the document at full resolution and encodes it. Runs off the main actor.
    @concurrent
    static func export(document: EditDocument, session: RenderSession, format: ExportFormat,
                       size: ExportSize, keepLocation: Bool) async throws -> Data {
        let state = RenderEngine.signposter.beginInterval("export")
        defer { RenderEngine.signposter.endInterval("export", state) }

        guard let full = session.fullResolution() else { throw Failure.original }
        var source = full
        let fullOut = CropGeometry(crop: document.crop, sourceSize: document.source.size).outputSize
        let target = outputSize(document, size: size)
        if target.width < fullOut.width {
            let s = target.width / fullOut.width
            source = full.transformed(by: CGAffineTransform(scaleX: s, y: s), highQualityDownsample: true)
        }
        let image = RenderPipeline(session: session, document: document, source: source).image()
        try Task.checkCancellation()

        let ctx = RenderEngine.exportContext
        let alpha = format == .png && hasTransparency(document)
        guard let cg = ctx.createCGImage(image, from: image.extent,
                                         format: alpha ? .RGBA8 : .RGBX8,
                                         colorSpace: RenderEngine.outputSpace) else { throw Failure.encode }
        try Task.checkCancellation()

        var props = originalProperties(session.originalURL)
        props[kCGImagePropertyOrientation] = 1
        props[kCGImagePropertyPixelWidth] = nil
        props[kCGImagePropertyPixelHeight] = nil
        if !keepLocation { props[kCGImagePropertyGPSDictionary] = nil }
        if format != .png {
            props[kCGImageDestinationLossyCompressionQuality] = 0.92
        }
        var tiff = props[kCGImagePropertyTIFFDictionary] as? [CFString: Any] ?? [:]
        tiff[kCGImagePropertyTIFFOrientation] = 1
        tiff[kCGImagePropertyTIFFSoftware] = "Photo Editor"
        props[kCGImagePropertyTIFFDictionary] = tiff

        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, format.utType.identifier as CFString, 1, nil) else {
            throw Failure.encode
        }
        CGImageDestinationAddImage(dest, cg, props as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { throw Failure.encode }
        return data as Data
    }

    private static func originalProperties(_ url: URL) -> [CFString: Any] {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              var props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any] else { return [:] }
        props[kCGImagePropertyMakerAppleDictionary] = nil
        return props
    }
}
