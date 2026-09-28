import CoreImage
import Foundation

nonisolated enum AssetWriter {
    struct Written {
        var name: String
        var aspect: Double
        /// Trimmed bounds in the input image's space.
        var bounds: CGRect
    }

    /// Writes `image` cropped to the opaque bounds of `alphaSource`.
    static func writeTrimmedPNG(_ image: CIImage, alphaSource: CIImage, to folder: URL) -> Written? {
        let ctx = RenderEngine.context
        var bounds = image.extent
        if let cg = ctx.createCGImage(alphaSource, from: alphaSource.extent, format: .L8, colorSpace: CGColorSpaceCreateDeviceGray()),
           let b = opaqueBounds(cg) {
            bounds = b.offsetBy(dx: alphaSource.extent.minX, dy: alphaSource.extent.minY)
        }
        let trimmed = image.cropped(to: bounds)
        let name = "\(UUID().uuidString).png"
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        do {
            try ctx.writePNGRepresentation(of: trimmed, to: folder.appendingPathComponent(name), format: .RGBA8,
                                           colorSpace: RenderEngine.outputSpace)
        } catch {
            return nil
        }
        return Written(name: name, aspect: bounds.height / bounds.width, bounds: bounds)
    }

    static func opaqueBounds(_ cg: CGImage) -> CGRect? {
        let w = cg.width, h = cg.height
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                                  space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue),
              let data = ctx.data else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        let px = data.assumingMemoryBound(to: UInt8.self)
        var minX = w, minY = h, maxX = -1, maxY = -1
        for y in 0..<h {
            let row = y * w
            for x in 0..<w where px[row + x] > 24 {
                if x < minX { minX = x }
                if x > maxX { maxX = x }
                if y < minY { minY = y }
                if y > maxY { maxY = y }
            }
        }
        guard maxX >= minX else { return nil }
        // Row 0 in memory is the top; CI's y axis points up.
        return CGRect(x: minX, y: h - 1 - maxY, width: maxX - minX + 1, height: maxY - minY + 1)
    }
}
