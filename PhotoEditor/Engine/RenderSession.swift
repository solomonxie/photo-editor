import CoreImage
import Foundation
import ImageIO

/// Per-open-project render resources and caches. Safe to use from the export task too.
nonisolated final class RenderSession: @unchecked Sendable {
    let originalURL: URL
    let assetsURL: URL
    let proxy: CIImage
    let proxyCGImage: CGImage

    private let lock = NSLock()
    private var cache: [String: Any] = [:]

    init(originalURL: URL, assetsURL: URL, proxyMaxPixel: Int) throws {
        self.originalURL = originalURL
        self.assetsURL = assetsURL
        guard let cg = ImageDecoder.downsampled(url: originalURL, maxPixel: proxyMaxPixel) else {
            throw ImageDecoder.Error.unreadable
        }
        proxyCGImage = cg
        proxy = CIImage(cgImage: cg)
    }

    /// Full-resolution original, oriented, origin at 0.
    func fullResolution() -> CIImage? {
        guard let img = CIImage(contentsOf: originalURL, options: [.applyOrientationProperty: true]) else { return nil }
        return img.transformed(by: CGAffineTransform(translationX: -img.extent.minX, y: -img.extent.minY))
    }

    func cached<T>(_ key: String, _ make: () -> T) -> T {
        lock.lock()
        // Unwrap the entry first: `nil as? Optional<X>` would succeed and fake a hit.
        if let entry = cache[key], let hit = entry as? T {
            lock.unlock()
            return hit
        }
        lock.unlock()
        let value = make()
        lock.lock()
        cache[key] = value
        lock.unlock()
        return value
    }

    func invalidate(prefix: String) {
        lock.lock()
        cache = cache.filter { !$0.key.hasPrefix(prefix) }
        lock.unlock()
    }

    func assetImage(_ name: String) -> CIImage? {
        cached("asset:\(name)") {
            CIImage(contentsOf: assetsURL.appendingPathComponent(name))
        }
    }
}

nonisolated enum ImageDecoder {
    enum Error: Swift.Error { case unreadable }

    /// Oriented pixel size without decoding pixels.
    static func orientedSize(url: URL) -> CGSize? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int,
              let h = props[kCGImagePropertyPixelHeight] as? Int else { return nil }
        let orientation = props[kCGImagePropertyOrientation] as? UInt32 ?? 1
        return orientation >= 5 ? CGSize(width: h, height: w) : CGSize(width: w, height: h)
    }

    static func downsampled(url: URL, maxPixel: Int) -> CGImage? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary) else { return nil }
        return downsampled(source: src, maxPixel: maxPixel)
    }

    static func downsampled(data: Data, maxPixel: Int) -> CGImage? {
        guard let src = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else { return nil }
        return downsampled(source: src, maxPixel: maxPixel)
    }

    private static func downsampled(source: CGImageSource, maxPixel: Int) -> CGImage? {
        CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
            kCGImageSourceShouldCacheImmediately: true,
        ] as CFDictionary)
    }
}
