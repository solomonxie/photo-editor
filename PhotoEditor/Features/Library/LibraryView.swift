import SwiftUI
import PhotosUI

struct LibraryView: View {
    @State private var pickerItem: PhotosPickerItem?
    @State private var selectedImage: Image?
    @State private var showEditor = false

    var body: some View {
        NavigationStack {
            VStack {
                if let selectedImage {
                    selectedImage
                        .resizable()
                        .scaledToFit()
                        .padding()
                } else {
                    ContentUnavailableView(
                        "No Photo Selected",
                        systemImage: "photo.badge.plus",
                        description: Text("Pick a photo to start editing.")
                    )
                }

                PhotosPicker("Pick a Photo", selection: $pickerItem, matching: .images)
                    .buttonStyle(.borderedProminent)
                    .padding(.bottom)
            }
            .navigationTitle("Library")
            .navigationDestination(isPresented: $showEditor) {
                EditorView()
            }
            .onChange(of: pickerItem) { _, newItem in
                Task {
                    guard let data = try? await newItem?.loadTransferable(type: Data.self),
                          let uiImage = UIImage(data: data) else { return }
                    selectedImage = Image(uiImage: uiImage)
                    showEditor = true
                }
            }
        }
    }
}

#Preview {
    LibraryView()
}
