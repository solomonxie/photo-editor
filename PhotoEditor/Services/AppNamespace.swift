import Foundation

/// Reverse-DNS prefix shared by Keychain items and signposts; fed from APP_NAMESPACE in Config/*.xcconfig.
nonisolated enum AppNamespace {
    static let value: String = {
        if let s = Bundle.main.object(forInfoDictionaryKey: "AppNamespace") as? String, !s.isEmpty { return s }
        return (Bundle.main.bundleIdentifier! as NSString).deletingPathExtension
    }()
}
