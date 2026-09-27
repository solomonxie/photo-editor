import Foundation

/// Vendors that can edit images. Data, not code paths: adding one = one entry + a client if its API shape is new.
nonisolated enum AIVendor: String, Codable, CaseIterable, Identifiable, Sendable {
    case openAI, gemini

    var id: String { rawValue }

    var name: String {
        switch self {
        case .openAI: "OpenAI"
        case .gemini: "Google Gemini"
        }
    }

    var shortName: String {
        switch self {
        case .openAI: "OpenAI"
        case .gemini: "Gemini"
        }
    }

    var keyPlaceholder: String {
        switch self {
        case .openAI: "sk-…"
        case .gemini: "AIza…"
        }
    }

    var keyPrefix: String {
        switch self {
        case .openAI: "sk-"
        case .gemini: "AIza"
        }
    }

    var consoleURL: URL {
        switch self {
        case .openAI: URL(string: "https://platform.openai.com/api-keys")!
        case .gemini: URL(string: "https://aistudio.google.com/apikey")!
        }
    }

    var imageModel: String {
        switch self {
        case .openAI: "gpt-image-1"
        case .gemini: "gemini-2.5-flash-image"
        }
    }

    var client: AIImageClient {
        switch self {
        case .openAI: OpenAIImageClient()
        case .gemini: GeminiImageClient()
        }
    }

    /// Non-blocking hint about a key that looks wrong.
    func hint(for key: String) -> String? {
        let k = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !k.isEmpty else { return nil }
        if k.contains(" ") { return "The key contains a space — check the paste." }
        if !k.hasPrefix(keyPrefix) { return "\(k.count) characters — \(shortName) keys usually start with \(keyPrefix)" }
        return nil
    }
}

nonisolated struct AIKeyInfo: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    var vendor: AIVendor
    var requests = 0
    var lastError: String?

    var keychainAccount: String { "ai.key.\(id.uuidString)" }
}

nonisolated enum AIStrategy: String, Codable, CaseIterable, Sendable {
    case sequential, roundRobin

    var title: String {
        switch self {
        case .sequential: "Sequential"
        case .roundRobin: "Round Robin"
        }
    }
}
