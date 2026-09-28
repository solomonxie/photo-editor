import CoreGraphics

enum HairMode: String, CaseIterable { case hair, beard, colour }

/// A one-tap hair or beard change: an AI Fill with a prompt and a mask placed from face landmarks.
enum HairStyle: String, CaseIterable, Identifiable, Hashable {
    case addHair, thicken, bangs
    case stubble, shortBeard, fullBeard, goatee, mustache
    case black, darkBrown, chestnut, blonde, ash, silver, red, rose, blue, purple

    var id: String { rawValue }

    static func all(_ mode: HairMode) -> [HairStyle] {
        switch mode {
        case .hair: [.addHair, .thicken, .bangs]
        case .beard: [.stubble, .shortBeard, .fullBeard, .goatee, .mustache]
        case .colour: [.black, .darkBrown, .chestnut, .blonde, .ash, .silver, .red, .rose, .blue, .purple]
        }
    }

    var title: String {
        switch self {
        case .addHair: "Add Hair"
        case .thicken: "Thicken"
        case .bangs: "Bangs"
        case .stubble: "Stubble"
        case .shortBeard: "Short Beard"
        case .fullBeard: "Full Beard"
        case .goatee: "Goatee"
        case .mustache: "Mustache"
        case .black: "Black"
        case .darkBrown: "Dark Brown"
        case .chestnut: "Chestnut"
        case .blonde: "Blonde"
        case .ash: "Ash"
        case .silver: "Silver"
        case .red: "Red"
        case .rose: "Rose Pink"
        case .blue: "Blue"
        case .purple: "Purple"
        }
    }

    var prompt: String {
        let keep = "Keep this person's identity, face, skin and everything else unchanged"
        switch self {
        case .addHair:
            return "natural hair filling any bald, receding or thinning areas on the top of the head and the hairline, matching this person's existing hair colour, texture and style. \(keep)"
        case .thicken:
            return "this person's existing hair made noticeably thicker, fuller and denser, same colour, length and style. \(keep)"
        case .bangs:
            return "natural bangs across the forehead that match this person's hair colour and texture. Keep the eyes and eyebrows visible. \(keep)"
        case .stubble:
            return "light, natural stubble on the jaw, chin and upper lip, matching this person's hair colour. \(keep)"
        case .shortBeard:
            return "a neat, short, well-groomed beard and mustache, matching this person's hair colour. \(keep)"
        case .fullBeard:
            return "a full, thick, natural beard and mustache, matching this person's hair colour. \(keep)"
        case .goatee:
            return "a neat goatee around the mouth and on the chin, matching this person's hair colour. \(keep)"
        case .mustache:
            return "a natural, well-groomed mustache on the upper lip, matching this person's hair colour. \(keep)"
        default:
            return "only the hair recoloured to a natural-looking \(title.lowercased()) hair colour, keeping the same hairstyle, strands, shine and lighting. Nothing but the hair changes colour. \(keep)"
        }
    }

    /// Mask strokes for one face. `frame` is the face box and `lips` the outer lips, both
    /// source-normalized top-left; `size` is the source in pixels.
    func strokes(frame: CGRect, lips: [CGPoint], size: CGSize) -> [BrushStroke] {
        let px = CGRect(x: frame.minX * size.width, y: frame.minY * size.height,
                        width: frame.width * size.width, height: frame.height * size.height)
        let cx = px.midX, top = px.minY, bottom = px.maxY, w = px.width, h = px.height
        let longEdge = max(size.width, size.height)
        let mouthTop = lips.isEmpty ? top + 0.72 * h : lips.map { $0.y * size.height }.min()!

        func line(_ pts: [CGPoint], _ r: Double) -> BrushStroke {
            BrushStroke(points: pts.map { CGPoint(x: $0.x / size.width, y: $0.y / size.height) }, radius: r * h / longEdge)
        }
        func row(_ y: Double, half: Double, _ r: Double) -> BrushStroke {
            line([CGPoint(x: cx - half * w, y: y), CGPoint(x: cx + half * w, y: y)], r)
        }
        func sides(from y0: Double, to y1: Double, x: Double, _ r: Double) -> [BrushStroke] {
            [-1.0, 1].map { s in line([CGPoint(x: cx + s * x * w, y: y0), CGPoint(x: cx + s * x * w, y: y1)], r) }
        }
        let crown = [row(top - 0.05 * h, half: 0.55, 0.16), row(top - 0.28 * h, half: 0.5, 0.16), row(top - 0.5 * h, half: 0.35, 0.16)]
        let jaw: BrushStroke = {
            let pts = stride(from: 0.0, through: 1.0, by: 0.1).map { t -> CGPoint in
                let a = Double.pi * t
                return CGPoint(x: cx - cos(a) * 0.5 * w, y: top + 0.5 * h + sin(a) * (bottom - top - 0.5 * h))
            }
            return line(pts, 0.1)
        }()
        let upperLip = row(mouthTop - 0.04 * h, half: 0.2, 0.05)
        let chin = [row(bottom - 0.1 * h, half: 0.18, 0.12), row(mouthTop + 0.12 * h, half: 0.2, 0.08)]

        switch self {
        case .addHair: return crown
        case .thicken: return crown + sides(from: top - 0.1 * h, to: top + 0.5 * h, x: 0.6, 0.13)
        case .bangs: return [row(top + 0.02 * h, half: 0.42, 0.1), row(top - 0.15 * h, half: 0.45, 0.12)]
        case .stubble, .shortBeard, .fullBeard: return [jaw, upperLip] + chin
        case .goatee: return [upperLip] + chin + sides(from: mouthTop, to: bottom - 0.1 * h, x: 0.2, 0.06)
        case .mustache: return [upperLip]
        default: return crown + sides(from: top - 0.1 * h, to: top + 1.6 * h, x: 0.68, 0.2)
        }
    }
}
