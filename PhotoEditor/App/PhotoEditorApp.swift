import SwiftUI

@main
struct PhotoEditorApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

struct RootView: View {
    @State private var editor: EditorModel?
    @State private var loadingError: String?

    var body: some View {
        NavigationStack {
            HomeView(open: open)
        }
        .fullScreenCover(item: $editor) { model in
            EditorView(model: model) {
                model.discard()
                editor = nil
            }
        }
        .alert("Couldn't open this edit", isPresented: Binding(get: { loadingError != nil }, set: { if !$0 { loadingError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(loadingError ?? "")
        }
        #if DEBUG
        .task { await DebugLaunch.run(open: open) }
        #endif
    }

    private func open(_ project: Project) {
        Task {
            do {
                editor = try await EditorModel.open(project)
            } catch {
                loadingError = "The photo for this edit is missing or damaged."
            }
        }
    }
}

extension EditorModel: Identifiable {
    var id: UUID { project.id }
}
