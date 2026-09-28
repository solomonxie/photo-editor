import CoreImage
import Metal
import UIKit
import XCTest
@testable import PhotoEditor

/// Measures the DESIGN.md targets on a synthetic 48 MP photo. Numbers are printed as `PERF …`.
final class PerformanceTests: XCTestCase {
    static let url: URL = {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("perf-48mp.heic")
        guard !FileManager.default.fileExists(atPath: url.path) else { return url }
        let size = CGRect(x: 0, y: 0, width: 8064, height: 6048)
        let noise = CIFilter(name: "CIRandomGenerator")!.outputImage!.cropped(to: size)
        let gradient = CIFilter(name: "CILinearGradient", parameters: [
            "inputPoint0": CIVector(x: 0, y: 0), "inputPoint1": CIVector(x: 8064, y: 6048),
            "inputColor0": CIColor(red: 0.2, green: 0.4, blue: 0.8), "inputColor1": CIColor(red: 0.9, green: 0.6, blue: 0.3),
        ])!.outputImage!.cropped(to: size)
        let img = noise.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0, kCIInputContrastKey: 0.2])
            .applyingFilter("CIOverlayBlendMode", parameters: [kCIInputBackgroundImageKey: gradient])
        try! RenderEngine.exportContext.writeHEIFRepresentation(of: img, to: url, format: .RGBA8, colorSpace: RenderEngine.outputSpace)
        return url
    }()

    private func time(_ label: String, _ body: () throws -> Void) rethrows -> Double {
        let start = CFAbsoluteTimeGetCurrent()
        try body()
        let ms = (CFAbsoluteTimeGetCurrent() - start) * 1000
        print(String(format: "PERF %@: %.0f ms", label, ms))
        return ms
    }

    private func document() -> EditDocument {
        var doc = EditDocument(source: SourceInfo(filename: "perf-48mp.heic", pixelWidth: 8064, pixelHeight: 6048))
        doc.smoothSkin = 50
        doc.beauty[.whiten] = 40
        doc.reshape.manual = [ManualWarp(kind: .grow, center: CGPoint(x: 0.5, y: 0.5), radius: 0.1)]
        return doc
    }

    func testOpenRenderExport() async throws {
        let url = Self.url
        var session: RenderSession!
        let open = try time("open 48MP → proxy") {
            session = try RenderSession(originalURL: url, assetsURL: FileManager.default.temporaryDirectory, proxyMaxPixel: 3165)
        }
        let doc = document()
        // Screen-fit frame on iPhone 14: ~1170 px wide.
        let s = 1170 / session.proxy.extent.width
        let source = session.proxy.transformed(by: CGAffineTransform(scaleX: s, y: s))
        let cg = RenderEngine.context.createCGImage(source, from: source.extent)!
        let fitted = CIImage(cgImage: cg)
        let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: Int(fitted.extent.width),
                                                            height: Int(fitted.extent.height), mipmapped: false)
        desc.usage = [.shaderWrite, .renderTarget, .shaderRead]
        let texture = RenderEngine.device.makeTexture(descriptor: desc)!
        let queue = RenderEngine.device.makeCommandQueue()!
        var frames: [Double] = []
        for i in 0..<20 {
            var d = doc
            d.beauty[.whiten] = Double(i)
            let img = RenderPipeline(session: session, document: d, source: fitted).image()
            let ms = time("frame \(i)") {
                let buffer = queue.makeCommandBuffer()!
                let dst = CIRenderDestination(mtlTexture: texture, commandBuffer: buffer)
                _ = try? RenderEngine.context.startTask(toRender: img, to: dst)
                buffer.commit()
                buffer.waitUntilCompleted()
            }
            frames.append(ms)
        }
        let median = frames.dropFirst(2).sorted()[frames.count / 2 - 1]
        print(String(format: "PERF slider frame median: %.1f ms", median))

        let start = CFAbsoluteTimeGetCurrent()
        let data = try await Exporter.export(document: doc, session: session, format: .heic, size: .full, keepLocation: false)
        let exportMs = (CFAbsoluteTimeGetCurrent() - start) * 1000
        print(String(format: "PERF export 48MP HEIC: %.0f ms (%.1f MB)", exportMs, Double(data.count) / 1e6))

        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        _ = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count) }
        }
        print(String(format: "PERF footprint after export: %.0f MB", Double(info.phys_footprint) / 1e6))

        XCTAssertLessThan(open, 1500)
        XCTAssertLessThan(median, 33)
        XCTAssertLessThan(exportMs, 8000)
    }
}
