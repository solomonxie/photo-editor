import SwiftUI

private enum AIProvider: String, CaseIterable, Identifiable {
    case openAI = "OpenAI"
    case anthropic = "Anthropic"
    case other = "Other"

    var id: String { rawValue }
}

private let apiKeyStorageKey = "ai.api.key"

struct SettingsView: View {
    @State private var apiKey: String = KeychainStore.load(forKey: apiKeyStorageKey) ?? ""
    @State private var provider: AIProvider = .openAI

    var body: some View {
        NavigationStack {
            Form {
                Section("AI Provider") {
                    Picker("Provider", selection: $provider) {
                        ForEach(AIProvider.allCases) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    }
                }

                Section {
                    SecureField("API Key", text: $apiKey)
                        .onChange(of: apiKey) { _, newValue in
                            if newValue.isEmpty {
                                KeychainStore.delete(forKey: apiKeyStorageKey)
                            } else {
                                KeychainStore.save(newValue, forKey: apiKeyStorageKey)
                            }
                        }
                } header: {
                    Text("API Key")
                } footer: {
                    Text("Stored in the Keychain. AI Tools use this key to call your chosen provider directly — no bundled backend.")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}
