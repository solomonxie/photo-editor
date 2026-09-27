import SwiftUI

/// Save sends one real cheap request and only stores the key if it works.
struct AddKeySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var vendor: AIVendor = .openAI
    @State private var key = ""
    @State private var reveal = false
    @State private var testing = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Vendor", selection: $vendor) {
                        ForEach(AIVendor.allCases) { Text($0.name).tag($0) }
                    }
                    HStack {
                        Group {
                            if reveal {
                                TextField(vendor.keyPlaceholder, text: $key)
                            } else {
                                SecureField(vendor.keyPlaceholder, text: $key)
                            }
                        }
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.password)
                        .font(.body.monospaced())
                        Button {
                            reveal.toggle()
                        } label: {
                            Image(systemName: reveal ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(reveal ? "Hide key" : "Show key")
                    }
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        if testing {
                            HStack(spacing: 6) {
                                ProgressView()
                                Text("Testing the key…")
                            }
                        } else if let error {
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                        } else if let hint = vendor.hint(for: key) {
                            Label(hint, systemImage: "info.circle")
                        }
                        Button("Need a key? Get one from \(vendor.shortName) →") {
                            openURL(vendor.consoleURL)
                        }
                        .font(.footnote)
                    }
                }
            }
            .navigationTitle("Add AI Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(testing || cleaned.isEmpty)
                }
            }
            .onChange(of: vendor) { error = nil }
        }
    }

    /// Strips what paste and smart punctuation add.
    private var cleaned: String {
        key.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\u{201C}", with: "")
            .replacingOccurrences(of: "\u{201D}", with: "")
            .replacingOccurrences(of: "\"", with: "")
    }

    private func save() async {
        testing = true
        error = nil
        defer { testing = false }
        let secret = cleaned
        do {
            try await vendor.client.test(key: secret)
            AIKeyStore.shared.add(vendor: vendor, secret: secret)
            dismiss()
        } catch let e as AIError {
            error = e.status.map { "\(vendor.shortName) said: \(e.code ?? e.message) (\($0))" } ?? e.localizedDescription
        } catch {
            self.error = error.localizedDescription
        }
    }
}
