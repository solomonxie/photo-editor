import CoreGraphics
import Foundation

nonisolated struct EditDocument: Codable, Equatable, Sendable {
    static let currentSchema = 1

    var schemaVersion = EditDocument.currentSchema
    var source: SourceInfo
    var patches: [PatchOp] = []
    var heal: [BrushStroke] = []
    var smoothSkin: Double = 0
    var redEye = false
    var beauty: [BeautyKey: Double] = [:]
    var makeup: [MakeupPart: MakeupItem] = [:]
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
        smoothSkin = try c.decodeIfPresent(Double.self, forKey: .smoothSkin) ?? 0
        redEye = try c.decodeIfPresent(Bool.self, forKey: .redEye) ?? false
        beauty = try c.decodeIfPresent([BeautyKey: Double].self, forKey: .beauty) ?? [:]
        makeup = try c.decodeIfPresent([MakeupPart: MakeupItem].self, forKey: .makeup) ?? [:]
        reshape = try c.decodeIfPresent(ReshapeSpec.self, forKey: .reshape) ?? ReshapeSpec()
        cutout = try c.decodeIfPresent(CutoutSpec.self, forKey: .cutout)
        // Skips layer kinds that no longer exist (text, emoji).
        layers = (try c.decodeIfPresent([Lossy<Layer>].self, forKey: .layers) ?? []).compactMap(\.value)
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

// MARK: - Beauty & makeup

nonisolated enum BeautyKey: String, Codable, CodingKeyRepresentable, CaseIterable, Sendable {
    case whiten, evenTone, deShine, darkCircles, brightEyes, teeth
}

nonisolated enum MakeupPart: String, Codable, CodingKeyRepresentable, CaseIterable, Sendable {
    case lips, blush, brows, liner, contour, hair
}

nonisolated struct MakeupItem: Codable, Equatable, Sendable {
    var color: RGBA
    /// 0…100.
    var amount: Double
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

/// One person's sliders, −100…100 each.
nonisolated struct PersonShape<Key: Hashable & Codable & CodingKeyRepresentable & Sendable>: Codable, Equatable, Sendable {
    /// Face centre or torso centre, source-normalized top-left; nil = everyone (older edits).
    var anchor: CGPoint?
    var values: [Key: Double] = [:]
}

nonisolated struct ReshapeSpec: Codable, Equatable, Sendable {
    var faces: [PersonShape<FaceShapeKey>] = []
    var bodies: [PersonShape<BodyShapeKey>] = []
    var manual: [ManualWarp] = []

    var isIdentity: Bool { faces.isEmpty && bodies.isEmpty && manual.isEmpty }

    init() {}

    /// Face sliders applied to every face (Beauty looks).
    var allFaces: [FaceShapeKey: Double] {
        get { faces.first { $0.anchor == nil }?.values ?? [:] }
        set {
            faces.removeAll { $0.anchor == nil }
            if !newValue.isEmpty { faces.insert(PersonShape(values: newValue), at: 0) }
        }
    }

    private enum CodingKeys: String, CodingKey { case faces, bodies, manual }
    private enum LegacyKeys: String, CodingKey { case face, body }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        faces = try c.decodeIfPresent([PersonShape<FaceShapeKey>].self, forKey: .faces) ?? []
        bodies = try c.decodeIfPresent([PersonShape<BodyShapeKey>].self, forKey: .bodies) ?? []
        manual = try c.decodeIfPresent([ManualWarp].self, forKey: .manual) ?? []
        let legacy = try decoder.container(keyedBy: LegacyKeys.self)
        if let v = try legacy.decodeIfPresent([FaceShapeKey: Double].self, forKey: .face), !v.isEmpty {
            faces.append(PersonShape(values: v))
        }
        if let v = try legacy.decodeIfPresent([BodyShapeKey: Double].self, forKey: .body), !v.isEmpty {
            bodies.append(PersonShape(values: v))
        }
    }

    /// Values for the person at `anchor`: their own entry over any "everyone" entry.
    static func values<K>(_ shapes: [PersonShape<K>], at anchor: CGPoint, within reach: Double) -> [K: Double] {
        var out = shapes.first { $0.anchor == nil }?.values ?? [:]
        let own = shapes.filter { $0.anchor != nil }
            .min { $0.anchor!.distance(to: anchor) < $1.anchor!.distance(to: anchor) }
        if let own, own.anchor!.distance(to: anchor) <= reach {
            out.merge(own.values) { $1 }
        }
        return out
    }

    /// Sets one slider for the person at `anchor`, dropping entries that become empty.
    static func set<K>(_ shapes: inout [PersonShape<K>], anchor: CGPoint, key: K, value: Double, reach: Double) {
        let i = shapes.indices.filter { shapes[$0].anchor != nil }
            .min { shapes[$0].anchor!.distance(to: anchor) < shapes[$1].anchor!.distance(to: anchor) }
            .flatMap { shapes[$0].anchor!.distance(to: anchor) <= reach ? $0 : nil }
        if let i {
            shapes[i].values[key] = value == 0 ? nil : value
            if shapes[i].values.isEmpty { shapes.remove(at: i) }
        } else if value != 0 {
            shapes.append(PersonShape(anchor: anchor, values: [key: value]))
        }
    }
}

extension CGPoint {
    nonisolated func distance(to p: CGPoint) -> Double { hypot(x - p.x, y - p.y) }
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
    /// Centre, normalized to the canvas.
    var center = CGPoint(x: 0.5, y: 0.5)
    /// Width as a fraction of the canvas width.
    var width: Double = 0.6
    /// Radians, clockwise.
    var rotation: Double = 0
    var opacity: Double = 1
    var isHidden = false

    enum Content: Codable, Equatable, Sendable {
        case image(asset: String, aspect: Double)

        var aspect: Double {
            switch self {
            case .image(_, let aspect): aspect
            }
        }
    }

    var displayName: String { "Image" }
}

nonisolated struct Lossy<T: Decodable & Sendable>: Decodable, Sendable {
    let value: T?

    init(from decoder: Decoder) throws {
        value = try? T(from: decoder)
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
