import Foundation

/// Demo mode (Settings): a separate project store filled from the bundled `demo/` folder.
/// Real edits, Photos library and exports are left alone.
enum AppData {
    nonisolated static let demoKey = "demo.on"

    nonisolated static var isDemo: Bool { UserDefaults.standard.bool(forKey: demoKey) }

    static func setDemo(_ on: Bool) {
        guard on != isDemo else { return }
        if on, ProjectStore.demo.projects.isEmpty { DemoSeed.seed() }
        UserDefaults.standard.set(on, forKey: demoKey)
    }

    nonisolated struct DemoBlocked: LocalizedError {
        var errorDescription: String? { "Demo mode doesn't write to your Photos library." }
    }
}

nonisolated enum StoreRegion: String {
    case us, cn
}

/// App Store region this install was built for (`make ios STORE=cn`); `us` covers Canada/US.
/// `cn` turns off the AI vendors (`AIVendor.available`).
nonisolated func storeRegion(_ bundle: Bundle = .main) -> StoreRegion {
    StoreRegion(rawValue: bundle.object(forInfoDictionaryKey: "AppStoreRegion") as? String ?? "") ?? .us
}

/// `demo/projects.json`: `[{ "photo": "x.jpg", "modified": "@today-1 19:40", "edits": { …EditDocument fields } }]`,
/// photos in `demo/photos/`. Missing photos are skipped.
enum DemoSeed {
    static func seed(bundle: Bundle = .main, now: Date = .now) {
        let store = ProjectStore.demo
        store.deleteAll()
        guard let url = bundle.url(forResource: "projects", withExtension: "json", subdirectory: "demo"),
              let data = try? Data(contentsOf: url),
              let entries = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return }
        for entry in entries {
            guard let name = entry["photo"] as? String,
                  let photoURL = bundle.url(forResource: name, withExtension: nil, subdirectory: "demo/photos"),
                  let photo = try? Data(contentsOf: photoURL),
                  let project = try? ProjectStore.makeProject(from: photo, in: store.root) else { continue }
            if let edits = entry["edits"] as? [String: Any], let doc = try? ProjectStore.load(project) {
                try? ProjectStore.save(merged(doc, edits), to: project)
            }
            let modified = (entry["modified"] as? String).flatMap { date($0, now: now) } ?? now
            try? FileManager.default.setAttributes([.modificationDate: modified], ofItemAtPath: project.documentURL.path)
        }
        store.reload()
    }

    private static func merged(_ doc: EditDocument, _ edits: [String: Any]) -> EditDocument {
        guard let base = (try? JSONEncoder().encode(doc)).flatMap({ try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }),
              let out = try? JSONSerialization.data(withJSONObject: base.merging(edits) { $1 }),
              let result = try? JSONDecoder().decode(EditDocument.self, from: out) else { return doc }
        return result
    }

    /// `@today-1 19:40`, `@today 09:12`.
    static func date(_ text: String, now: Date, calendar: Calendar = .current) -> Date? {
        guard let m = text.wholeMatch(of: #/@today([+-]\d+)?(?: (\d{1,2}):(\d{2}))?/#),
              let day = calendar.date(byAdding: .day, value: m.1.flatMap { Int($0) } ?? 0, to: calendar.startOfDay(for: now)) else { return nil }
        guard let h = m.2.flatMap({ Int($0) }), let min = m.3.flatMap({ Int($0) }) else { return day }
        return calendar.date(bySettingHour: h, minute: min, second: 0, of: day)
    }
}
