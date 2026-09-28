#if DEBUG
import CoreImage
import Foundation
import UIKit

/// Launch arguments for reviewing screens on a device without tapping:
///   -demo <file in Documents>|synthetic   open that photo in the Editor
///   -tool <retouch|reshape|…>             initial tool
///   -sheet <export|layers>                present a sheet on open
///   -settings                             push Settings from Home
///   -compress                             push Compress from Home
///   -patch '<json>'                       merge into the document on open (not saved)
///   -select <index>                       select that layer
enum DebugLaunch {
    static func value(_ flag: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    static func has(_ flag: String) -> Bool {
        ProcessInfo.processInfo.arguments.contains(flag)
    }

    static var tool: EditorTool? { value("-tool").flatMap(EditorTool.init) }

    static func patched(_ doc: EditDocument) -> EditDocument {
        guard let json = value("-patch"), let patch = try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any],
              let data = try? JSONEncoder().encode(doc),
              let base = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return doc }
        let merged = merge(base, patch)
        guard let out = try? JSONSerialization.data(withJSONObject: merged),
              let result = try? JSONDecoder().decode(EditDocument.self, from: out) else { return doc }
        return result
    }

    private static func merge(_ a: [String: Any], _ b: [String: Any]) -> [String: Any] {
        var out = a
        for (k, v) in b {
            if let dv = v as? [String: Any], let da = a[k] as? [String: Any] {
                out[k] = merge(da, dv)
            } else {
                out[k] = v
            }
        }
        return out
    }
    static var sheet: String? { value("-sheet") }

    static func run(open: (Project) -> Void) async {
        guard let name = value("-demo") else { return }
        let store = ProjectStore.shared
        let marker = "debug-demo-\(name)"
        if let existing = store.projects.first(where: {
            FileManager.default.fileExists(atPath: $0.folder.appendingPathComponent(marker).path)
        }) {
            open(existing)
            return
        }
        guard let data = demoData(name), let project = try? await store.create(from: data) else { return }
        FileManager.default.createFile(atPath: project.folder.appendingPathComponent(marker).path, contents: nil)
        open(project)
    }

    private static func demoData(_ name: String) -> Data? {
        if name != "synthetic" {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            return try? Data(contentsOf: docs.appendingPathComponent(name))
        }
        let size = CGSize(width: 4032, height: 3024)
        let img = UIGraphicsImageRenderer(size: size).image { ctx in
            let c = ctx.cgContext
            let colors = [UIColor(red: 0.35, green: 0.55, blue: 0.85, alpha: 1).cgColor,
                          UIColor(red: 0.95, green: 0.75, blue: 0.55, alpha: 1).cgColor] as CFArray
            let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
            c.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: size.height * 0.65), options: [])
            UIColor(red: 1, green: 0.85, blue: 0.4, alpha: 1).setFill()
            c.fillEllipse(in: CGRect(x: 2700, y: 700, width: 520, height: 520))
            UIColor(red: 0.2, green: 0.35, blue: 0.25, alpha: 1).setFill()
            c.fill(CGRect(x: 0, y: size.height * 0.65, width: size.width, height: size.height * 0.35))
            UIColor(red: 0.15, green: 0.25, blue: 0.2, alpha: 1).setFill()
            let hill = UIBezierPath()
            hill.move(to: CGPoint(x: 0, y: size.height * 0.7))
            hill.addQuadCurve(to: CGPoint(x: size.width, y: size.height * 0.62), controlPoint: CGPoint(x: size.width * 0.4, y: size.height * 0.35))
            hill.addLine(to: CGPoint(x: size.width, y: size.height))
            hill.addLine(to: CGPoint(x: 0, y: size.height))
            hill.fill()
        }
        return img.jpegData(compressionQuality: 0.9)
    }
}
#endif
