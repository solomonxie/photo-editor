import AVFoundation
import ImageIO
import UniformTypeIdentifiers

nonisolated enum VideoSize: String, CaseIterable, Sendable {
    case uhd, fhd, hd

    var label: String {
        switch self {
        case .uhd: "4K"
        case .fhd: "1080p"
        case .hd: "720p"
        }
    }

    var preset: String {
        switch self {
        case .uhd: AVAssetExportPresetHEVC3840x2160
        case .fhd: AVAssetExportPresetHEVC1920x1080
        case .hd: AVAssetExportPreset1280x720
        }
    }
}

nonisolated enum MediaCompressor {
    enum Failure: LocalizedError {
        case unreadable, encode
        var errorDescription: String? {
            switch self {
            case .unreadable: "Couldn't read this item."
            case .encode: "Couldn't compress this item."
            }
        }
    }

    /// Re-encodes as HEIC, no larger than `maxEdge`, keeping EXIF and GPS.
    static func photo(_ data: Data, maxEdge: CGFloat?, quality: ExportQuality) throws -> Data {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil),
              var props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? CGFloat,
              let h = props[kCGImagePropertyPixelHeight] as? CGFloat else { throw Failure.unreadable }
        let edge = min(max(w, h), maxEdge ?? .infinity)
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: edge,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(src, 0, options as CFDictionary) else { throw Failure.unreadable }

        props[kCGImagePropertyPixelWidth] = nil
        props[kCGImagePropertyPixelHeight] = nil
        props[kCGImagePropertyMakerAppleDictionary] = nil
        props[kCGImagePropertyOrientation] = 1
        var tiff = props[kCGImagePropertyTIFFDictionary] as? [CFString: Any] ?? [:]
        tiff[kCGImagePropertyTIFFOrientation] = 1
        props[kCGImagePropertyTIFFDictionary] = tiff
        props[kCGImageDestinationLossyCompressionQuality] = quality.compression

        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, UTType.heic.identifier as CFString, 1, nil) else {
            throw Failure.encode
        }
        CGImageDestinationAddImage(dest, image, props as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { throw Failure.encode }
        return out as Data
    }

    static func temporaryVideoURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("compress-\(UUID().uuidString).mov")
    }
}
