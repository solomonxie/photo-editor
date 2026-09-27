import Foundation
import Observation

/// Ordered AI keys. Secrets in the Keychain (this device only); vendor/order/counters in UserDefaults.
@Observable
final class AIKeyStore {
    static let shared = AIKeyStore()

    private(set) var keys: [AIKeyInfo] = []
    var strategy: AIStrategy {
        didSet { defaults.set(strategy.rawValue, forKey: Self.strategyKey) }
    }
    private var roundRobinCursor = 0

    private let defaults: UserDefaults
    private static let listKey = "ai.keys"
    private static let strategyKey = "ai.strategy"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        strategy = defaults.string(forKey: Self.strategyKey).flatMap(AIStrategy.init) ?? .sequential
        if let data = defaults.data(forKey: Self.listKey),
           let list = try? JSONDecoder().decode([AIKeyInfo].self, from: data) {
            keys = list
        }
        migrateLegacy()
    }

    var hasKeys: Bool { !keys.isEmpty }

    func add(vendor: AIVendor, secret: String) {
        let info = AIKeyInfo(vendor: vendor)
        KeychainStore.save(secret, forKey: info.keychainAccount)
        keys.append(info)
        persist()
    }

    func delete(_ id: UUID) {
        guard let info = keys.first(where: { $0.id == id }) else { return }
        KeychainStore.delete(forKey: info.keychainAccount)
        keys.removeAll { $0.id == id }
        persist()
    }

    func move(_ id: UUID, by offset: Int) {
        guard let i = keys.firstIndex(where: { $0.id == id }) else { return }
        let j = i + offset
        guard keys.indices.contains(j) else { return }
        keys.swapAt(i, j)
        persist()
    }

    func secret(for info: AIKeyInfo) -> String? {
        KeychainStore.load(forKey: info.keychainAccount)
    }

    /// Keys in the order to try for one call.
    func attemptOrder() -> [AIKeyInfo] {
        guard strategy == .roundRobin, keys.count > 1 else { return keys }
        let start = roundRobinCursor % keys.count
        roundRobinCursor += 1
        return Array(keys[start...] + keys[..<start])
    }

    func recordSuccess(_ id: UUID) {
        guard let i = keys.firstIndex(where: { $0.id == id }) else { return }
        keys[i].requests += 1
        keys[i].lastError = nil
        persist()
    }

    func recordFailure(_ id: UUID, message: String) {
        guard let i = keys.firstIndex(where: { $0.id == id }) else { return }
        keys[i].requests += 1
        keys[i].lastError = message
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(keys) {
            defaults.set(data, forKey: Self.listKey)
        }
    }

    private func migrateLegacy() {
        guard let legacy = KeychainStore.load(forKey: KeychainStore.legacyAIKey), !legacy.isEmpty else { return }
        let vendor: AIVendor? = legacy.hasPrefix("AIza") ? .gemini : (legacy.hasPrefix("sk-") ? .openAI : nil)
        if let vendor {
            add(vendor: vendor, secret: legacy)
        }
        KeychainStore.delete(forKey: KeychainStore.legacyAIKey)
    }
}
