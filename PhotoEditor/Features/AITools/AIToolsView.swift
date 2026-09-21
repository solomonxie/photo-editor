import SwiftUI

private enum AITool: String, CaseIterable, Identifiable {
    case removeBackground = "Remove Background"
    case enhance = "Enhance"
    case styleTransfer = "Style Transfer"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .removeBackground: return "person.crop.rectangle.badge.xmark"
        case .enhance: return "wand.and.stars"
        case .styleTransfer: return "paintpalette"
        }
    }
}

struct AIToolsView: View {
    @State private var activeTool: AITool?
    @State private var showMissingKeyAlert = false

    private var hasAPIKey: Bool {
        !(KeychainStore.load(forKey: KeychainStore.aiAPIKeyStorageKey) ?? "").isEmpty
    }

    var body: some View {
        NavigationStack {
            List(AITool.allCases) { tool in
                Button {
                    if hasAPIKey {
                        activeTool = tool
                    } else {
                        showMissingKeyAlert = true
                    }
                } label: {
                    Label(tool.rawValue, systemImage: tool.systemImage)
                }
            }
            .navigationTitle("AI Tools")
            .sheet(item: $activeTool) { tool in
                ContentUnavailableView(
                    tool.rawValue,
                    systemImage: "sparkles",
                    description: Text("Calls your configured AI provider using the API key from Settings. Not implemented yet.")
                )
            }
            .alert("AI API Key Needed", isPresented: $showMissingKeyAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Add your own AI API key in the Settings tab to use AI tools.")
            }
        }
    }
}

#Preview {
    AIToolsView()
}
