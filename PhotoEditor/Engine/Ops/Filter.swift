import CoreImage
import Foundation
import simd

nonisolated struct FilterPreset: Identifiable, Sendable {
    let id: String
    let name: String
    let recipe: Recipe

    enum Recipe: Sendable {
        case builtIn(String)
        case cube(@Sendable (SIMD3<Float>) -> SIMD3<Float>)
    }

    func apply(_ img: CIImage) -> CIImage {
        switch recipe {
        case .builtIn(let name):
            return img.applyingFilter(name)
        case .cube:
            return img.applyingFilter("CIColorCubeWithColorSpace", parameters: [
                "inputCubeDimension": FilterCatalog.cubeSize,
                "inputCubeData": FilterCatalog.cubeData(for: self),
                "inputColorSpace": CGColorSpace(name: CGColorSpace.displayP3)!,
            ])
        }
    }
}

nonisolated enum FilterCatalog {
    static let cubeSize = 32

    static let presets: [FilterPreset] = [
        FilterPreset(id: "vivid", name: "Vivid", recipe: .cube { c in
            saturate(curve(c, lift: 0, gamma: 0.95, gain: 1.03), 1.35)
        }),
        FilterPreset(id: "warm", name: "Warm", recipe: .cube { c in
            saturate(c * SIMD3(1.07, 1.0, 0.88), 1.08)
        }),
        FilterPreset(id: "cool", name: "Cool", recipe: .cube { c in
            c * SIMD3(0.92, 1.0, 1.08)
        }),
        FilterPreset(id: "film", name: "Film", recipe: .cube { c in
            let faded = curve(c, lift: 0.06, gamma: 1.02, gain: 0.95)
            return saturate(faded * SIMD3(1.03, 1.0, 0.94), 0.85)
        }),
        FilterPreset(id: "tealorange", name: "Cinema", recipe: .cube { c in
            let l = luma(c)
            let shadowTint = SIMD3<Float>(0.9, 1.0, 1.1)
            let highTint = SIMD3<Float>(1.1, 1.0, 0.86)
            let tint = shadowTint + (highTint - shadowTint) * l
            return saturate(curve(c * tint, lift: 0.02, gamma: 1.0, gain: 1.0), 1.1)
        }),
        FilterPreset(id: "pastel", name: "Pastel", recipe: .cube { c in
            saturate(curve(c, lift: 0.1, gamma: 0.9, gain: 1.0), 0.75)
        }),
        FilterPreset(id: "golden", name: "Golden", recipe: .cube { c in
            saturate(curve(c * SIMD3(1.1, 1.02, 0.8), lift: 0.03, gamma: 0.95, gain: 1.0), 1.12)
        }),
        FilterPreset(id: "chrome", name: "Chrome", recipe: .builtIn("CIPhotoEffectChrome")),
        FilterPreset(id: "fade", name: "Fade", recipe: .builtIn("CIPhotoEffectFade")),
        FilterPreset(id: "instant", name: "Instant", recipe: .builtIn("CIPhotoEffectInstant")),
        FilterPreset(id: "process", name: "Process", recipe: .builtIn("CIPhotoEffectProcess")),
        FilterPreset(id: "transfer", name: "Transfer", recipe: .builtIn("CIPhotoEffectTransfer")),
        FilterPreset(id: "mono", name: "Mono", recipe: .builtIn("CIPhotoEffectMono")),
        FilterPreset(id: "tonal", name: "Tonal", recipe: .builtIn("CIPhotoEffectTonal")),
        FilterPreset(id: "noir", name: "Noir", recipe: .builtIn("CIPhotoEffectNoir")),
        FilterPreset(id: "sepia", name: "Sepia", recipe: .cube { c in
            let l = luma(curve(c, lift: 0.04, gamma: 1, gain: 0.96))
            return SIMD3(l * 1.07, l * 0.95, l * 0.78)
        }),
    ]

    static func preset(_ id: String) -> FilterPreset? {
        presets.first { $0.id == id }
    }

    private static let cubeCache = CubeCache()

    static func cubeData(for preset: FilterPreset) -> Data {
        cubeCache.data(for: preset)
    }

    private final class CubeCache: @unchecked Sendable {
        private let lock = NSLock()
        private var store: [String: Data] = [:]

        func data(for preset: FilterPreset) -> Data {
            lock.lock()
            defer { lock.unlock() }
            if let d = store[preset.id] { return d }
            guard case .cube(let fn) = preset.recipe else { return Data() }
            let n = FilterCatalog.cubeSize
            var floats = [Float]()
            floats.reserveCapacity(n * n * n * 4)
            for b in 0..<n {
                for g in 0..<n {
                    for r in 0..<n {
                        let c = SIMD3<Float>(Float(r), Float(g), Float(b)) / Float(n - 1)
                        let o = simd_clamp(fn(c), SIMD3(repeating: 0), SIMD3(repeating: 1))
                        floats.append(contentsOf: [o.x, o.y, o.z, 1])
                    }
                }
            }
            let d = floats.withUnsafeBufferPointer { Data(buffer: $0) }
            store[preset.id] = d
            return d
        }
    }

    // MARK: color helpers

    static func luma(_ c: SIMD3<Float>) -> Float {
        c.x * 0.2126 + c.y * 0.7152 + c.z * 0.0722
    }

    static func saturate(_ c: SIMD3<Float>, _ amount: Float) -> SIMD3<Float> {
        let l = luma(c)
        return SIMD3(repeating: l) + (c - SIMD3(repeating: l)) * amount
    }

    static func curve(_ c: SIMD3<Float>, lift: Float, gamma: Float, gain: Float) -> SIMD3<Float> {
        let clamped = simd_clamp(c, SIMD3(repeating: 0), SIMD3(repeating: 1))
        let g = SIMD3<Float>(pow(clamped.x, gamma), pow(clamped.y, gamma), pow(clamped.z, gamma))
        return SIMD3(repeating: lift) + g * (gain - lift)
    }
}

nonisolated extension RenderPipeline {
    func applyFilter(_ img: CIImage) -> CIImage {
        guard let ref = document.filter, let preset = FilterCatalog.preset(ref.id) else { return img }
        let filtered = preset.apply(img)
        guard ref.intensity < 1 else { return filtered }
        return img.applyingFilter("CIDissolveTransition", parameters: [
            kCIInputTargetImageKey: filtered,
            kCIInputTimeKey: ref.intensity,
        ])
    }
}
