import SwiftUI

private enum EditorTool: String, CaseIterable, Identifiable {
    case filters = "Filters"
    case adjust = "Adjust"
    case crop = "Crop"
    case text = "Text"
    case ai = "AI"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .filters: return "camera.filters"
        case .adjust: return "slider.horizontal.3"
        case .crop: return "crop"
        case .text: return "textformat"
        case .ai: return "sparkles"
        }
    }
}

struct EditorView: View {
    @State private var activeTool: EditorTool = .filters

    var body: some View {
        VStack(spacing: 0) {
            // Placeholder canvas. TODO: wire a real Core Image pipeline
            // (CIFilter chain rendered into this canvas) once tool panels do
            // real work.
            ContentUnavailableView(
                "Image Canvas",
                systemImage: "photo",
                description: Text("Selected photo will render here.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            ToolPanel(tool: activeTool)
                .frame(height: 120)

            Divider()

            HStack {
                ForEach(EditorTool.allCases) { tool in
                    Button {
                        activeTool = tool
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: tool.systemImage)
                            Text(tool.rawValue)
                                .font(.caption2)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(activeTool == tool ? Color.accentColor : .primary)
                }
            }
            .padding(.vertical, 8)
        }
        .navigationTitle("Editor")
    }
}

private struct ToolPanel: View {
    let tool: EditorTool

    var body: some View {
        ContentUnavailableView(
            tool.rawValue,
            systemImage: tool.systemImage,
            description: Text("\(tool.rawValue) tools coming soon.")
        )
    }
}

#Preview {
    NavigationStack { EditorView() }
}
