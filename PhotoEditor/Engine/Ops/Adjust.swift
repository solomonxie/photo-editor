import CoreImage
import CoreImage.CIFilterBuiltins

nonisolated extension RenderPipeline {
    func applyAdjust(_ input: CIImage) -> CIImage {
        let a = document.adjust
        guard !a.isIdentity else { return input }
        let extent = input.extent
        var img = input

        if a.auto {
            img = autoAdjusted(img)
        }

        let exposure = a[.exposure] / 100
        if exposure != 0 {
            img = img.applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: exposure * 2])
        }

        let brilliance = a[.brilliance] / 100
        if brilliance != 0 {
            // Lift shadows and hold highlights (or the reverse), plus a touch of local contrast.
            img = img.applyingFilter("CIHighlightShadowAdjust", parameters: [
                "inputShadowAmount": brilliance * 0.6,
                "inputHighlightAmount": 1 - max(0, brilliance) * 0.4,
                kCIInputRadiusKey: 20 * scale,
            ])
            img = img.applyingFilter("CIColorControls", parameters: [kCIInputContrastKey: 1 + brilliance * 0.08])
        }

        let brightness = a[.brightness] / 100
        let contrast = a[.contrast] / 100
        let saturation = a[.saturation] / 100
        if brightness != 0 || contrast != 0 || saturation != 0 {
            img = img.applyingFilter("CIColorControls", parameters: [
                kCIInputBrightnessKey: brightness * 0.25,
                kCIInputContrastKey: 1 + contrast * 0.35,
                kCIInputSaturationKey: 1 + saturation,
            ])
        }

        let highlights = a[.highlights] / 100
        let shadows = a[.shadows] / 100
        if highlights != 0 || shadows != 0 {
            img = img.applyingFilter("CIToneCurve", parameters: [
                "inputPoint0": CIVector(x: 0, y: 0),
                "inputPoint1": CIVector(x: 0.25, y: 0.25 + shadows * 0.12),
                "inputPoint2": CIVector(x: 0.5, y: 0.5 + (shadows + highlights) * 0.03),
                "inputPoint3": CIVector(x: 0.75, y: 0.75 + highlights * 0.12),
                "inputPoint4": CIVector(x: 1, y: 1 + min(0, highlights) * 0.08),
            ])
        }

        let vibrance = a[.vibrance] / 100
        if vibrance != 0 {
            img = img.applyingFilter("CIVibrance", parameters: ["inputAmount": vibrance])
        }

        let warmth = a[.warmth] / 100
        let tint = a[.tint] / 100
        if warmth != 0 || tint != 0 {
            img = img.applyingFilter("CITemperatureAndTint", parameters: [
                "inputNeutral": CIVector(x: 6500 + warmth * (warmth > 0 ? 4500 : 2800), y: tint * 100),
                "inputTargetNeutral": CIVector(x: 6500, y: 0),
            ])
        }

        let sharpness = a[.sharpness] / 100
        if sharpness > 0 {
            img = img.applyingFilter("CISharpenLuminance", parameters: [
                kCIInputSharpnessKey: sharpness * 0.8,
                kCIInputRadiusKey: max(0.5, 1.8 * scale),
            ])
        }

        let vignette = a[.vignette] / 100
        if vignette > 0 {
            let radius = hypot(extent.width, extent.height) / 2
            img = img.applyingFilter("CIVignetteEffect", parameters: [
                kCIInputCenterKey: CIVector(x: extent.midX, y: extent.midY),
                kCIInputRadiusKey: radius * 0.95,
                kCIInputIntensityKey: vignette * 0.9,
                "inputFalloff": 0.6,
            ])
        }

        let grain = a[.grain] / 100
        if grain > 0 {
            img = applyGrain(img, amount: grain)
        }

        return img.cropped(to: extent)
    }

    private func autoAdjusted(_ img: CIImage) -> CIImage {
        let filters: [CIFilter] = session.cached("auto") {
            session.proxy.autoAdjustmentFilters(options: [.redEye: false, .crop: false, .level: false])
        }
        var out = img
        for f in filters {
            guard let copy = f.copy() as? CIFilter else { continue }
            copy.setValue(out, forKey: kCIInputImageKey)
            out = copy.outputImage ?? out
        }
        return out
    }

    private func applyGrain(_ img: CIImage, amount: Double) -> CIImage {
        let grainScale = max(1.0, 1.6 * scale)
        let noise = CIFilter.randomGenerator().outputImage!
            .transformed(by: CGAffineTransform(scaleX: grainScale, y: grainScale))
            .applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 0.33, y: 0.33, z: 0.33, w: 0),
                "inputGVector": CIVector(x: 0.33, y: 0.33, z: 0.33, w: 0),
                "inputBVector": CIVector(x: 0.33, y: 0.33, z: 0.33, w: 0),
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            ])
            .applyingFilter("CIColorControls", parameters: [
                kCIInputContrastKey: amount * 0.9,
                kCIInputBrightnessKey: 0,
            ])
            .cropped(to: img.extent)
        return noise.applyingFilter("CIOverlayBlendMode", parameters: [kCIInputBackgroundImageKey: img])
    }
}
