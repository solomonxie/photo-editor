import SwiftUI

private enum AITool: String, CaseIterable, Identifiable {
    case enhance = "Enhance"
    case backgroundRemove = "Background Remove"
    case generateVariation = "Generate Variation"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .enhance: return "wand.and.stars"
        case .backgroundRemove: return "person.crop.rectangle.badge.xmark"
        case .generateVariation: return "arrow.triangle.branch"
        }
    }
}

struct AIToolsView: View {
    @State private var activeTool: AITool?

    var body: some View {
        NavigationStack {
            List(AITool.allCases) { tool in
                Button {
                    activeTool = tool
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
        }
    }
}

#Preview {
    AIToolsView()
}
