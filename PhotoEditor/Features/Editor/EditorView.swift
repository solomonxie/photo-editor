import SwiftUI

private enum EditorTool: String, CaseIterable, Identifiable {
    case crop = "Crop"
    case filters = "Filters"
    case adjust = "Adjust"
    case text = "Text & Stickers"
    case layers = "Layers"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .crop: return "crop"
        case .filters: return "camera.filters"
        case .adjust: return "slider.horizontal.3"
        case .text: return "textformat"
        case .layers: return "square.3.layers.3d"
        }
    }
}

struct EditorView: View {
    @State private var activeTool: EditorTool?

    var body: some View {
        List(EditorTool.allCases) { tool in
            Button {
                activeTool = tool
            } label: {
                Label(tool.rawValue, systemImage: tool.systemImage)
            }
        }
        .navigationTitle("Editor")
        .sheet(item: $activeTool) { tool in
            ComingSoonView(title: tool.rawValue)
        }
    }
}

struct ComingSoonView: View {
    let title: String

    var body: some View {
        ContentUnavailableView(
            title,
            systemImage: "hammer",
            description: Text("Coming soon.")
        )
    }
}

#Preview {
    NavigationStack { EditorView() }
}
