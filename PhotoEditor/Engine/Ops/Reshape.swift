import CoreImage
import Foundation
import Vision

/// People's joints on the proxy, top-left normalized.
nonisolated struct BodyAnalysis: Sendable {
    struct Body: Sendable {
        var leftShoulder: CGPoint, rightShoulder: CGPoint
        var leftHip: CGPoint, rightHip: CGPoint
        var leftElbow: CGPoint?, rightElbow: CGPoint?
        var leftKnee: CGPoint?, rightKnee: CGPoint?
        var leftAnkle: CGPoint?, rightAnkle: CGPoint?
    }
    var bodies: [Body]

    static func run(on cg: CGImage) -> BodyAnalysis {
        let request = VNDetectHumanBodyPoseRequest()
        try? VNImageRequestHandler(cgImage: cg).perform([request])
        let bodies: [Body] = (request.results ?? []).compactMap { obs in
            guard let pts = try? obs.recognizedPoints(.all) else { return nil }
            func p(_ j: VNHumanBodyPoseObservation.JointName) -> CGPoint? {
                guard let v = pts[j], v.confidence > 0.25 else { return nil }
                return CGPoint(x: v.location.x, y: 1 - v.location.y)
            }
            guard let ls = p(.leftShoulder), let rs = p(.rightShoulder), let lh = p(.leftHip), let rh = p(.rightHip) else { return nil }
            return Body(leftShoulder: ls, rightShoulder: rs, leftHip: lh, rightHip: rh,
                        leftElbow: p(.leftElbow), rightElbow: p(.rightElbow),
                        leftKnee: p(.leftKnee), rightKnee: p(.rightKnee),
                        leftAnkle: p(.leftAnkle), rightAnkle: p(.rightAnkle))
        }
        return BodyAnalysis(bodies: bodies)
    }
}

nonisolated extension RenderPipeline {
    var bodies: BodyAnalysis {
        session.cached("bodies") { BodyAnalysis.run(on: session.proxyCGImage) }
    }
}

/// Turns reshape sliders + landmarks into one displacement field.
nonisolated enum ReshapeBuilder {
    static func key(_ spec: ReshapeSpec) -> Int {
        (try? JSONEncoder().encode(spec))?.hashValue ?? 0
    }

    static func build(_ spec: ReshapeSpec, faces: FaceAnalysis, bodies: BodyAnalysis, sourceSize: CGSize) -> WarpField {
        let aspect = sourceSize.width / sourceSize.height
        var field = WarpField(aspect: aspect)
        if !spec.face.isEmpty {
            for face in faces.faces { applyFace(face, spec.face, aspect: aspect, into: &field) }
        }
        if !spec.body.isEmpty {
            for body in bodies.bodies { applyBody(body, spec.body, aspect: aspect, into: &field) }
        }
        for m in spec.manual {
            switch m.kind {
            case .push: field.translate(at: m.center, by: m.vector, radius: m.radius)
            case .grow: field.bulge(at: m.center, radius: m.radius, strength: 0.18)
            case .shrink: field.bulge(at: m.center, radius: m.radius, strength: -0.18)
            }
        }
        return field
    }

    /// Vision face coords (origin bottom-left) → top-left.
    private static func tl(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x, y: 1 - p.y) }

    private static func applyFace(_ face: FaceAnalysis.Face, _ v: [FaceShapeKey: Double], aspect: Double, into f: inout WarpField) {
        let b = face.bounds
        let faceW = b.width * aspect // in height units
        let center = tl(CGPoint(x: b.midX, y: b.midY))

        if let slim = v[.slim], slim != 0, face.contour.count >= 5 {
            // Pull the cheeks and jaw towards the face's centre line.
            let k = slim / 100 * 0.11
            let lower = face.contour.map(tl).filter { $0.y > center.y - b.height * 0.15 }
            for p in lower {
                let dir = CGVector(dx: (center.x - p.x), dy: (center.y - p.y) * 0.25)
                f.translate(at: p, by: CGVector(dx: dir.dx * k, dy: dir.dy * k), radius: faceW * 0.3)
            }
        }
        if let jaw = v[.jaw], jaw != 0, let chin = face.contour.map(tl).max(by: { $0.y < $1.y }) {
            // Positive = longer, pointier chin.
            f.translate(at: chin, by: CGVector(dx: 0, dy: jaw / 100 * b.height * 0.07), radius: faceW * 0.3)
        }
        if let eyes = v[.eyes], eyes != 0 {
            for e in [face.leftEye, face.rightEye].compactMap({ $0 }) {
                f.bulge(at: tl(e.center), radius: max(0.01, e.width * aspect * 0.95), strength: eyes / 100 * 0.35)
            }
        }
        if let nose = v[.nose], nose != 0, let n = face.nose {
            f.bulge(at: tl(n.center), radius: max(0.01, n.width * aspect * 1.1), strength: -nose / 100 * 0.3)
        }
        if let fh = v[.forehead], fh != 0 {
            let top = CGPoint(x: center.x, y: center.y - b.height * 0.62)
            f.translate(at: top, by: CGVector(dx: 0, dy: fh / 100 * b.height * 0.06), radius: faceW * 0.45)
        }
    }

    private static func applyBody(_ body: BodyAnalysis.Body, _ v: [BodyShapeKey: Double], aspect: Double, into f: inout WarpField) {
        // Work in height units along x.
        func X(_ p: CGPoint) -> Double { p.x * aspect }
        let hipL = body.leftHip, hipR = body.rightHip
        let shL = body.leftShoulder, shR = body.rightShoulder
        let hipMid = CGPoint(x: (hipL.x + hipR.x) / 2, y: (hipL.y + hipR.y) / 2)
        let shMid = CGPoint(x: (shL.x + shR.x) / 2, y: (shL.y + shR.y) / 2)
        let hipW = abs(X(hipL) - X(hipR))
        let shW = abs(X(shL) - X(shR))
        let torso = max(0.02, hipMid.y - shMid.y)
        // Joint on the image's left vs right side.
        let (hl, hr) = hipL.x < hipR.x ? (hipL, hipR) : (hipR, hipL)
        let (sl, sr) = shL.x < shR.x ? (shL, shR) : (shR, shL)

        func sideways(_ p: CGPoint, towards cx: Double, by amount: Double, radius: Double) {
            let dir = p.x < cx ? 1.0 : -1.0
            f.translate(at: p, by: CGVector(dx: dir * amount / aspect, dy: 0), radius: radius)
        }

        if let waist = v[.waist], waist != 0 {
            let y = hipMid.y - torso * 0.28
            let half = max(hipW, shW * 0.8) * 0.62
            let amount = waist / 100 * half * 0.28
            for x in [hipMid.x - half / aspect, hipMid.x + half / aspect] {
                sideways(CGPoint(x: x, y: y), towards: hipMid.x, by: amount, radius: torso * 0.42)
            }
        }
        if let hips = v[.hips], hips != 0 {
            // Positive = wider hips.
            let half = hipW * 0.95
            let amount = -hips / 100 * half * 0.22
            let y = hipMid.y + torso * 0.08
            for x in [hipMid.x - half / aspect, hipMid.x + half / aspect] {
                sideways(CGPoint(x: x, y: y), towards: hipMid.x, by: amount, radius: torso * 0.45)
            }
        }
        if let chest = v[.chest], chest != 0 {
            let y = shMid.y + torso * 0.3
            let off = shW * 0.24 / aspect
            for x in [shMid.x - off, shMid.x + off] {
                f.bulge(at: CGPoint(x: x, y: y), radius: shW * 0.3, strength: chest / 100 * 0.3)
            }
        }
        if let shoulders = v[.shoulders], shoulders != 0 {
            let amount = -shoulders / 100 * shW * 0.12
            sideways(sl, towards: shMid.x, by: amount, radius: torso * 0.35)
            sideways(sr, towards: shMid.x, by: amount, radius: torso * 0.35)
        }
        if let arms = v[.arms], arms != 0 {
            // Slim upper arms: pull the midpoint of shoulder→elbow towards the bone line.
            for (s, e) in [(sl, body.leftElbow), (sr, body.rightElbow)] {
                guard let e else { continue }
                let mid = CGPoint(x: (s.x + e.x) / 2, y: (s.y + e.y) / 2)
                let outward = mid.x < shMid.x ? -1.0 : 1.0
                let edge = CGPoint(x: mid.x + outward * shW * 0.1 / aspect, y: mid.y)
                sideways(edge, towards: mid.x, by: arms / 100 * shW * 0.05, radius: torso * 0.22)
            }
        }
        if let legs = v[.legs], legs != 0 {
            let xs = [hl.x, hr.x] + [body.leftKnee?.x, body.rightKnee?.x, body.leftAnkle?.x, body.rightAnkle?.x].compactMap { $0 }
            let pad = hipW * 0.9 / aspect
            let range = (xs.min()! - pad)...(xs.max()! + pad)
            f.stretchBelow(y: hipMid.y + torso * 0.15, amount: legs / 100 * 0.12, xRange: range)
        }
        _ = (sl, sr, hl, hr)
    }
}
