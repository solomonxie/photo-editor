import PhotosUI
import SwiftUI

struct CompressView: View {
    @State private var model = CompressModel()
    @State private var picks: [PhotosPickerItem] = []
    @State private var showPicker = false
    @State private var showDenied = false
    @State private var errorMessage: String?
    @State private var note: String?
    @AppStorage("compress.photoSize") private var photoSize: ExportSize = .qhd
    @AppStorage("compress.quality") private var quality: ExportQuality = .medium
    @AppStorage("compress.videoSize") private var videoSize: VideoSize = .fhd

    var body: some View {
        Group {
            if model.items.isEmpty {
                empty
            } else {
                list
            }
        }
        .navigationTitle("Compress")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if !model.items.isEmpty { actions }
        }
        .photosPicker(isPresented: $showPicker, selection: $picks, maxSelectionCount: nil, selectionBehavior: .ordered,
                      matching: .any(of: [.images, .videos]), photoLibrary: .shared())
        .onChange(of: picks) { _, new in
            let ids = new.compactMap(\.itemIdentifier)
            guard !ids.isEmpty else { return }
            picks = []
            note = nil
            Task { await model.load(ids) }
        }
        .alert("Allow access to Photos", isPresented: $showDenied) {
            Button("Cancel", role: .cancel) {}
            Button("Open Settings") { PhotoSaver.openAppSettings() }
        } message: {
            Text("Compress needs to read the items you choose and add smaller copies.")
        }
        .alert("Couldn't delete", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .onDisappear { model.cancel() }
    }

    private var empty: some View {
        VStack(spacing: 14) {
            Image(systemName: "arrow.down.right.and.arrow.up.left")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)
            Text(note ?? "Make photos and videos smaller")
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
            Text("Smaller copies are added to your library with the same date and place. You choose whether to delete the originals.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(action: choose) {
                Label("Choose Photos & Videos", systemImage: "plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            .frame(width: 280)
            .padding(.top, 10)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 60)
    }

    private var list: some View {
        List {
            Section {
                settingRow("Photos") {
                    Segmented(options: ExportSize.allCases, selection: $photoSize) { $0.label }.frame(width: 220)
                }
                settingRow("Quality") {
                    Segmented(options: ExportQuality.allCases, selection: $quality) { $0.label }.frame(width: 220)
                }
                settingRow("Videos") {
                    Segmented(options: VideoSize.allCases, selection: $videoSize) { $0.label }.frame(width: 220)
                }
            } footer: {
                Text("Photos become HEIC, videos HEVC. Live Photos are saved as still photos. A copy is kept only if it's at least 10% smaller.")
            }
            .disabled(model.running)

            Section {
                ForEach(model.items) { item in
                    ItemRow(item: item, status: model.status[item.id] ?? .pending)
                }
            } header: {
                Text(model.items.count == 1 ? "1 item" : "\(model.items.count) items")
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            if model.running {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Compressing \(min(model.finishedCount + 1, model.items.count)) of \(model.items.count)…")
                        .monospacedDigit()
                    Spacer()
                    Button("Stop") { model.cancel() }
                        .font(.subheadline.weight(.semibold))
                }
                .frame(height: 50)
            } else if model.pendingCount > 0 {
                primary(model.pendingCount == 1 ? "Compress 1 Item" : "Compress \(model.pendingCount) Items") {
                    model.start(.init(photoSize: photoSize, quality: quality, videoSize: videoSize))
                }
            } else if !model.doneIDs.isEmpty {
                Text("Copies saved · \(ByteCountFormatter.string(fromByteCount: model.savedBytes, countStyle: .file)) smaller")
                    .font(.subheadline.weight(.medium))
                primary(model.doneIDs.count == 1 ? "Delete Original" : "Delete \(model.doneIDs.count) Originals",
                        role: .destructive) { deleteOriginals() }
            }
            if !model.running {
                Button("Choose Again", action: choose)
                    .font(.subheadline.weight(.medium))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.bar)
    }

    private func primary(_ title: String, role: ButtonRole? = nil, action: @escaping () -> Void) -> some View {
        Button(role: role, action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(role == .destructive ? Color.red : Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(.white)
        }
    }

    private func settingRow(_ title: String, @ViewBuilder trailing: () -> some View) -> some View {
        HStack {
            Text(title)
            Spacer()
            trailing()
        }
    }

    private func choose() {
        Task {
            if await MediaLibrary.requestAccess() {
                showPicker = true
            } else {
                showDenied = true
            }
        }
    }

    private func deleteOriginals() {
        Task {
            let saved = model.savedBytes
            do {
                try await model.deleteOriginals()
                if model.items.isEmpty {
                    note = "Freed \(ByteCountFormatter.string(fromByteCount: saved, countStyle: .file))"
                }
            } catch {
                let code = (error as NSError).code
                if code != PHPhotosError.userCancelled.rawValue && code != 3072 {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

private struct ItemRow: View {
    let item: LibraryItem
    let status: CompressModel.Status
    @State private var thumb: UIImage?

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                if let thumb {
                    Image(uiImage: thumb).resizable().scaledToFill()
                } else {
                    Color.white.opacity(0.08)
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(alignment: .bottomLeading) {
                if item.isVideo {
                    Image(systemName: "video.fill").font(.caption2).padding(3).foregroundStyle(.white)
                        .shadow(radius: 1)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline)
                Text(verbatim: "\(Int(item.pixelSize.width))×\(Int(item.pixelSize.height))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            trailing
        }
        .task { thumb = await MediaLibrary.thumbnail(item.id, side: 144) }
    }

    private var title: String {
        guard item.isVideo else { return item.isLive ? "Live Photo" : "Photo" }
        let d = Duration.seconds(item.duration)
        return "Video · " + d.formatted(.time(pattern: item.duration >= 3600 ? .hourMinuteSecond : .minuteSecond))
    }

    private func size(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    @ViewBuilder
    private var trailing: some View {
        let original = item.bytes.map(size) ?? "—"
        switch status {
        case .pending:
            Text(original).font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
        case .working:
            ProgressView()
        case .done(let new):
            VStack(alignment: .trailing, spacing: 2) {
                Text(size(new)).font(.subheadline.weight(.semibold).monospacedDigit()).foregroundStyle(.green)
                Text(original).font(.caption.monospacedDigit()).strikethrough().foregroundStyle(.secondary)
            }
        case .skipped:
            Text("Already small").font(.caption).foregroundStyle(.secondary)
        case .failed(let message):
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .accessibilityLabel(message)
        }
    }
}
