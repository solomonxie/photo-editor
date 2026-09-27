import CoreImage
import Metal

/// GPU remap: output(p) = input(p − D(p)), where D comes from a displacement-field image.
/// Compiled from source at runtime so the build needs no Metal toolchain.
nonisolated final class WarpProcessor: CIImageProcessorKernel {
    private static let source = """
    #include <metal_stdlib>
    using namespace metal;
    kernel void warp(texture2d<float, access::sample> src [[texture(0)]],
                     texture2d<float, access::sample> field [[texture(1)]],
                     texture2d<float, access::write> dst [[texture(2)]],
                     constant float4 &p [[buffer(0)]],
                     constant float4 &q [[buffer(1)]],
                     uint2 gid [[thread_position_in_grid]]) {
        if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
        constexpr sampler s(coord::pixel, filter::linear, address::clamp_to_edge);
        float2 pos = float2(gid) + 0.5;
        float2 d = field.sample(s, pos + q.xy).xy;
        float2 disp = float2(d.x * p.z, d.y * p.w * q.z);
        dst.write(src.sample(s, pos + p.xy - disp), gid);
    }
    """

    static let pipeline: MTLComputePipelineState? = {
        guard let lib = try? RenderEngine.device.makeLibrary(source: source, options: nil),
              let fn = lib.makeFunction(name: "warp") else { return nil }
        return try? RenderEngine.device.makeComputePipelineState(function: fn)
    }()

    /// Whether processor textures store the top row first (verified by WarpTests).
    static let topRowFirst = true

    override class var outputFormat: CIFormat { .RGBAh }

    override class func formatForInput(at input: Int32) -> CIFormat {
        // Half float: 32-bit float textures aren't filterable on iPhone GPUs.
        .RGBAh
    }

    override class func roi(forInput input: Int32, arguments: [String: Any]?, outputRect: CGRect) -> CGRect {
        guard input == 0 else { return outputRect }
        let m = CGFloat((arguments?["margin"] as? NSNumber)?.doubleValue ?? 0)
        return outputRect.insetBy(dx: -m, dy: -m)
    }

    override class func process(with inputs: [any CIImageProcessorInput]?, arguments: [String: Any]?,
                                 output: any CIImageProcessorOutput) throws {
        guard let pipeline, let inputs, inputs.count == 2,
              let src = inputs[0].metalTexture, let field = inputs[1].metalTexture,
              let dst = output.metalTexture, let buffer = output.metalCommandBuffer,
              let encoder = buffer.makeComputeCommandEncoder() else { return }
        let w = (arguments?["width"] as? NSNumber)?.floatValue ?? 1
        let h = (arguments?["height"] as? NSNumber)?.floatValue ?? 1
        let out = output.region, inR = inputs[0].region, fR = inputs[1].region
        var p: SIMD4<Float>, q: SIMD4<Float>
        if topRowFirst {
            p = SIMD4(Float(out.minX - inR.minX), Float(inR.maxY - out.maxY), w, h)
            q = SIMD4(Float(out.minX - fR.minX), Float(fR.maxY - out.maxY), -1, 0)
        } else {
            p = SIMD4(Float(out.minX - inR.minX), Float(out.minY - inR.minY), w, h)
            q = SIMD4(Float(out.minX - fR.minX), Float(out.minY - fR.minY), 1, 0)
        }
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(src, index: 0)
        encoder.setTexture(field, index: 1)
        encoder.setTexture(dst, index: 2)
        encoder.setBytes(&p, length: MemoryLayout<SIMD4<Float>>.size, index: 0)
        encoder.setBytes(&q, length: MemoryLayout<SIMD4<Float>>.size, index: 1)
        let tg = MTLSize(width: 16, height: 16, depth: 1)
        let grid = MTLSize(width: (dst.width + 15) / 16, height: (dst.height + 15) / 16, depth: 1)
        encoder.dispatchThreadgroups(grid, threadsPerThreadgroup: tg)
        encoder.endEncoding()
    }
}

/// A displacement field over the source, top-left origin. Values are fractions of the source's
/// width/height to *pull from*: output(x) = input(x − D(x)).
nonisolated struct WarpField {
    let width: Int
    let height: Int
    var dx: [Float]
    var dy: [Float]
    /// Source aspect (w / h), so distances are measured in real proportions.
    let aspect: Double

    init(aspect: Double, longEdge: Int = 256) {
        self.aspect = aspect
        width = aspect >= 1 ? longEdge : max(8, Int(Double(longEdge) * aspect))
        height = aspect >= 1 ? max(8, Int(Double(longEdge) / aspect)) : longEdge
        dx = Array(repeating: 0, count: width * height)
        dy = Array(repeating: 0, count: width * height)
    }

    var isEmpty: Bool { !dx.contains { $0 != 0 } && !dy.contains { $0 != 0 } }

    /// Iterate cells within `radius` (in height units) of `c`; body gets the cell centre and falloff weight.
    private mutating func forEachCell(near c: CGPoint, radius r: Double, _ body: (Double, Double, Double, Int) -> (Double, Double)) {
        let rx = r / aspect
        let x0 = max(0, Int((c.x - rx) * Double(width))), x1 = min(width - 1, Int((c.x + rx) * Double(width)) + 1)
        let y0 = max(0, Int((c.y - r) * Double(height))), y1 = min(height - 1, Int((c.y + r) * Double(height)) + 1)
        guard x0 <= x1, y0 <= y1 else { return }
        for yi in y0...y1 {
            let y = (Double(yi) + 0.5) / Double(height)
            for xi in x0...x1 {
                let x = (Double(xi) + 0.5) / Double(width)
                let ddx = (x - c.x) * aspect, ddy = y - c.y
                let d2 = (ddx * ddx + ddy * ddy) / (r * r)
                guard d2 < 1 else { continue }
                let w = (1 - d2) * (1 - d2)
                let i = yi * width + xi
                let (vx, vy) = body(x, y, w, i)
                dx[i] += Float(vx)
                dy[i] += Float(vy)
            }
        }
    }

    /// Moves content at `c` by `v` (normalized x/y).
    mutating func translate(at c: CGPoint, by v: CGVector, radius r: Double) {
        forEachCell(near: c, radius: r) { _, _, w, _ in (v.dx * w, v.dy * w) }
    }

    /// strength > 0 enlarges, < 0 shrinks.
    mutating func bulge(at c: CGPoint, radius r: Double, strength s: Double) {
        forEachCell(near: c, radius: r) { x, y, w, _ in ((x - c.x) * s * w, (y - c.y) * s * w) }
    }

    /// Stretch (k > 0) or compress everything below `y` vertically, blended over `band`.
    mutating func stretchBelow(y line: Double, amount k: Double, xRange: ClosedRange<Double>) {
        let band = 0.06
        for yi in 0..<height {
            let y = (Double(yi) + 0.5) / Double(height)
            guard y > line - band else { continue }
            let t = min(1, max(0, (y - (line - band)) / band))
            let smooth = t * t * (3 - 2 * t)
            let pull = (y - line) * k / (1 + k)
            for xi in 0..<width {
                let x = (Double(xi) + 0.5) / Double(width)
                // Fade out sideways so the background around the legs bends less.
                let edge = 0.08
                let fx = x < xRange.lowerBound ? max(0, 1 - (xRange.lowerBound - x) / edge)
                    : (x > xRange.upperBound ? max(0, 1 - (x - xRange.upperBound) / edge) : 1)
                dy[yi * width + xi] += Float(max(0, pull) * smooth * fx)
            }
        }
    }

    var maxDisplacement: Double {
        let mx = dx.map { abs($0) }.max() ?? 0
        let my = dy.map { abs($0) }.max() ?? 0
        return Double(max(mx, my))
    }

    /// RGBAf image of the field, stretched over `size` (CI coordinates).
    func image(size: CGSize) -> CIImage {
        var data = [Float](repeating: 0, count: width * height * 4)
        for yi in 0..<height {
            for xi in 0..<width {
                // Row 0 of bitmap data is the top of the image.
                let i = yi * width + xi
                let o = (yi * width + xi) * 4
                data[o] = dx[i]
                data[o + 1] = -dy[i]
                data[o + 3] = 1
            }
        }
        let bytes = data.withUnsafeBufferPointer { Data(buffer: $0) }
        let img = CIImage(bitmapData: bytes, bytesPerRow: width * 16, size: CGSize(width: width, height: height),
                          format: .RGBAf, colorSpace: nil)
        return img.clampedToExtent()
            .transformed(by: CGAffineTransform(scaleX: size.width / CGFloat(width), y: size.height / CGFloat(height)))
            .samplingLinear()
            .cropped(to: CGRect(origin: .zero, size: size))
    }
}

nonisolated extension RenderPipeline {
    func applyWarp(_ img: CIImage) -> CIImage {
        let spec = document.reshape
        guard !spec.isIdentity else { return img }
        let key = "warp:\(ReshapeBuilder.key(spec))"
        let field: WarpField? = session.cached(key) {
            let f = ReshapeBuilder.build(spec, faces: faces, bodies: bodies, sourceSize: document.source.size)
            return f.isEmpty ? nil : f
        }
        guard let field else { return img }
        let size = img.extent.size
        let margin = CGFloat(field.maxDisplacement) * max(size.width, size.height) + 4
        let fieldImage = field.image(size: size)
        guard let out = try? WarpProcessor.apply(withExtent: img.extent, inputs: [img, fieldImage],
                                                 arguments: ["width": size.width, "height": size.height, "margin": margin]) else { return img }
        return out
    }
}
