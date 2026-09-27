import CoreGraphics
import Foundation

nonisolated struct EditDocument: Codable, Equatable, Sendable {
    static let currentSchema = 1

    var schemaVersion = EditDocument.currentSchema
    var source: SourceInfo
    var patches: [PatchOp] = []
    var heal: [BrushStroke] = []
    var crop = CropSpec()
    var adjust = AdjustValues()
    var filter: FilterRef?
    var smoothSkin: Double = 0
    var redEye = false
    var reshape = ReshapeSpec()
    var cutout: CutoutSpec?
    var layers: [Layer] = []

    init(source: SourceInfo) {
        self.source = source
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        source = try c.decode(SourceInfo.self, forKey: .source)
        patches = try c.decodeIfPresent([PatchOp].self, forKey: .patches) ?? []
        heal = try c.decodeIfPresent([BrushStroke].self, forKey: .heal) ?? []
        crop = try c.decodeIfPresent(CropSpec.self, forKey: .crop) ?? CropSpec()
        adjust = try c.decodeIfPresent(AdjustValues.self, forKey: .adjust) ?? AdjustValues()
        filter = try c.decodeIfPresent(FilterRef.self, forKey: .filter)
        smoothSkin = try c.decodeIfPresent(Double.self, forKey: .smoothSkin) ?? 0
        redEye = try c.decodeIfPresent(Bool.self, forKey: .redEye) ?? false
        reshape = try c.decodeIfPresent(ReshapeSpec.self, forKey: .reshape) ?? ReshapeSpec()
        cutout = try c.decodeIfPresent(CutoutSpec.self, forKey: .cutout)
        layers = try c.decodeIfPresent([Layer].self, forKey: .layers) ?? []
    }

    var isUntouched: Bool {
        self == EditDocument(source: source)
    }
}

nonisolated struct SourceInfo: Codable, Equatable, Sendable {
    var filename: String
    /// Pixel size after EXIF orientation is applied.
    var pixelWidth: Int
    var pixelHeight: Int

    var size: CGSize { CGSize(width: pixelWidth, height: pixelHeight) }
}

// MARK: - Adjust

nonisolated enum AdjustKey: String, Codable, CodingKeyRepresentable, CaseIterable, Sendable {
    case exposure, brilliance, brightness, contrast, highlights, shadows
    case saturation, vibrance, warmth, tint, sharpness, vignette, grain

    var isBipolar: Bool {
        switch self {
        case .sharpness, .vignette, .grain: false
        default: true
        }
    }
}

nonisolated struct AdjustValues: Codable, Equatable, Sendable {
    var auto = false
    /// −100…100 (bipolar) or 0…100 (unipolar); missing = 0.
    var values: [AdjustKey: Double] = [:]

    subscript(key: AdjustKey) -> Double {
        get { values[key] ?? 0 }
        set { values[key] = newValue == 0 ? nil : newValue }
    }

    var isIdentity: Bool { !auto && values.isEmpty }
}

// MARK: - Filter

nonisolated struct FilterRef: Codable, Equatable, Sendable {
    var id: String
    var intensity: Double = 1
}

// MARK: - Crop

nonisolated struct CropSpec: Codable, Equatable, Sendable {
    /// Quarter turns counter-clockwise.
    var quarterTurns = 0
    var flipped = false
    /// Straighten, degrees, −45…45.
    var angle: Double = 0
    /// Normalized rect in the rotated+straightened image, origin top-left.
    var rect = CGRect(x: 0, y: 0, width: 1, height: 1)

    var isIdentity: Bool { self == CropSpec() }
}

// MARK: - Brush masks

nonisolated struct BrushStroke: Codable, Equatable, Sendable {
    /// Normalized to the source image, origin top-left.
    var points: [CGPoint]
    /// Fraction of the source's long edge.
    var radius: Double
}

nonisolated struct PatchOp: Codable, Equatable, Sendable, Identifiable {
    var id = UUID()
    var kind: Kind
    /// Result image in the project's `assets/`, covering the full source frame.
    var asset: String
    /// Region to take from the result; nil = whole frame.
    var mask: [BrushStroke]?

    enum Kind: String, Codable, Sendable { case magicErase, fill, restyle }
}

// MARK: - Reshape

nonisolated enum FaceShapeKey: String, Codable, CodingKeyRepresentable, CaseIterable, Sendable {
    case slim, jaw, eyes, nose, forehead
}

nonisolated enum BodyShapeKey: String, Codable, CodingKeyRepresentable, CaseIterable, Sendable {
    case waist, hips, chest, legs, shoulders, arms
}

nonisolated struct ManualWarp: Codable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable { case push, grow, shrink }
    var kind: Kind
    /// Source-normalized, top-left origin.
    var center: CGPoint
    /// Push direction, source-normalized.
    var vector: CGVector = .zero
    /// Fraction of the source's height.
    var radius: Double
}

nonisolated struct ReshapeSpec: Codable, Equatable, Sendable {
    /// −100…100 each.
    var face: [FaceShapeKey: Double] = [:]
    var body: [BodyShapeKey: Double] = [:]
    var manual: [ManualWarp] = []

    var isIdentity: Bool { face.isEmpty && body.isEmpty && manual.isEmpty }
}

// MARK: - Cutout

nonisolated struct CutoutSpec: Codable, Equatable, Sendable {
    /// Selected Vision instance indices (1-based, as Vision reports them).
    var subjects: [Int]
    var background: Background = .keep
    var blur: Double = 60
    var color: RGBA = RGBA(r: 1, g: 1, b: 1)

    enum Background: String, Codable, CaseIterable, Sendable { case keep, remove, blur, color }
}

// MARK: - Layers

nonisolated struct Layer: Codable, Equatable, Sendable, Identifiable {
    var id = UUID()
    var content: Content
    /// Centre, normalized to the output (cropped) canvas.
    var center = CGPoint(x: 0.5, y: 0.5)
    /// Width as a fraction of the output canvas width.
    var width: Double = 0.6
    /// Radians, clockwise.
    var rotation: Double = 0
    var opacity: Double = 1
    var isHidden = false

    enum Content: Codable, Equatable, Sendable {
        case text(TextSpec)
        case emoji(String)
        case image(asset: String, aspect: Double)
    }

    var displayName: String {
        switch content {
        case .text(let t): t.string.isEmpty ? "Text" : t.string
        case .emoji(let e): "Sticker \(e)"
        case .image: "Image"
        }
    }
}

nonisolated struct TextSpec: Codable, Equatable, Sendable {
    var string: String
    var font: TextFont = .system
    var color: RGBA = RGBA(r: 1, g: 1, b: 1)
    var style: Style = .plain
    var alignment: Alignment = .center

    enum Style: String, Codable, CaseIterable, Sendable { case plain, outline, background, shadow }
    enum Alignment: String, Codable, CaseIterable, Sendable { case leading, center, trailing }
}

nonisolated enum TextFont: String, Codable, CaseIterable, Sendable {
    case system, serif, rounded, marker, mono

    var displayName: String {
        switch self {
        case .system: "SF Pro"
        case .serif: "New York"
        case .rounded: "Rounded"
        case .marker: "Marker"
        case .mono: "Mono"
        }
    }
}

nonisolated struct RGBA: Codable, Equatable, Hashable, Sendable {
    var r: Double, g: Double, b: Double, a: Double = 1

    static let palette: [RGBA] = [
        RGBA(r: 1, g: 1, b: 1), RGBA(r: 0, g: 0, b: 0),
        RGBA(r: 1, g: 0.23, b: 0.19), RGBA(r: 1, g: 0.58, b: 0),
        RGBA(r: 1, g: 0.8, b: 0), RGBA(r: 0.2, g: 0.78, b: 0.35),
        RGBA(r: 0, g: 0.48, b: 1), RGBA(r: 0.69, g: 0.32, b: 0.87),
    ]
}
