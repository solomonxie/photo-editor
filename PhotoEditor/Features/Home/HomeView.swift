import PhotosUI
import SwiftUI

struct HomeView: View {
    let open: (Project) -> Void
    @State private var store = ProjectStore.shared
    @State private var pickerItem: PhotosPickerItem?
    @State private var showPicker = false
    @State private var opening = false
    @State private var error: String?
    @State private var toDelete: Project?
    @State private var showSettings = false
    @State private var showCompress = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)

    var body: some View {
        ZStack(alignment: .bottom) {
            if store.projects.isEmpty {
                empty
            } else {
                grid
            }
            if !store.projects.isEmpty {
                openButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
            }
        }
        .navigationTitle("Photo Editor")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    CompressView()
                } label: {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                }
                .accessibilityLabel("Compress photos and videos")
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings")
            }
        }
        .navigationDestination(isPresented: $showSettings) { SettingsView() }
        .navigationDestination(isPresented: $showCompress) { CompressView() }
        #if DEBUG
        .task {
            if DebugLaunch.has("-settings") { showSettings = true }
            if DebugLaunch.has("-compress") { showCompress = true }
        }
        #endif
        .photosPicker(isPresented: $showPicker, selection: $pickerItem, matching: .images, preferredItemEncoding: .current)
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            pickerItem = nil
            Task { await create(from: item) }
        }
        .overlay {
            if opening {
                ZStack {
                    Color.black.opacity(0.25).ignoresSafeArea()
                    ProgressView("Opening photo…")
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                }
            }
        }
        .overlay(alignment: .bottom) {
            if let error {
                Text(error)
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.bottom, 90)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task {
                        try? await Task.sleep(for: .seconds(3))
                        withAnimation { self.error = nil }
                    }
            }
        }
        .alert("Delete this edit?", isPresented: Binding(get: { toDelete != nil }, set: { if !$0 { toDelete = nil } })) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let p = toDelete { store.delete(p) }
            }
        } message: {
            Text("The original in Photos isn't affected.")
        }
    }

    private var grid: some View {
        ScrollView {
            HStack {
                Text("Recent")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Text(store.projects.count == 1 ? "1 edit" : "\(store.projects.count) edits")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(store.projects) { project in
                    Button {
                        open(project)
                    } label: {
                        Color.clear
                            .aspectRatio(1, contentMode: .fit)
                            .overlay { ProjectThumbnail(project: project) }
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Duplicate", systemImage: "plus.square.on.square") { try? store.duplicate(project) }
                        Divider()
                        Button("Delete", systemImage: "trash", role: .destructive) { toDelete = project }
                    }
                    .accessibilityLabel("Edit from \(project.modified.formatted(date: .abbreviated, time: .shortened))")
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
    }

    private var empty: some View {
        VStack(spacing: 14) {
            Image(systemName: "photo.badge.plus")
                .font(.system(size: 54, weight: .light))
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)
            Text("Edit your first photo")
                .font(.title2.weight(.semibold))
            Text("Everything stays on this iPhone.\nNo account, no watermark.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            openButton
                .frame(width: 240)
                .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 60)
    }

    private var openButton: some View {
        Button {
            showPicker = true
        } label: {
            Label("Open Photo", systemImage: "plus")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
    }

    private func create(from item: PhotosPickerItem) async {
        opening = true
        defer { opening = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { throw ImageDecoder.Error.unreadable }
            let project = try await store.create(from: data)
            open(project)
        } catch {
            withAnimation { self.error = "Couldn't open that photo. Try another one." }
        }
    }
}

struct ProjectThumbnail: View {
    let project: Project
    @State private var image: UIImage?
    @State private var failed = false
    @State private var store = ProjectStore.shared

    var body: some View {
        ZStack {
            Rectangle().fill(Color.secondary.opacity(0.15))
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else if failed {
                Label("Can't load", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: store.thumbnailVersion[project.id, default: 0]) {
            let url = project.thumbnailURL
            let loaded = await Task.detached { ImageDecoder.downsampled(url: url, maxPixel: 400) }.value
            if let loaded {
                image = UIImage(cgImage: loaded)
            } else {
                failed = true
            }
        }
    }
}
