import SwiftUI

struct SettingsView: View {
    @State private var keys = AIKeyStore.shared
    @State private var store = ProjectStore.shared
    @AppStorage(AppSettings.exportFormatKey) private var format: ExportFormat = .heic
    @AppStorage(AppSettings.keepLocationKey) private var keepLocation = true
    @State private var showAddKey = false
    @State private var showInfo = false
    @State private var confirmDeleteAll = false
    @State private var totalSize: Int64?

    var body: some View {
        Form {
            aiSection
            Section("Export") {
                Picker("Default format", selection: $format) {
                    Text("HEIC").tag(ExportFormat.heic)
                    Text("JPEG").tag(ExportFormat.jpeg)
                }
                .pickerStyle(.segmented)
                .listRowSeparator(.hidden, edges: .top)
                Toggle("Keep location data", isOn: $keepLocation)
            }
            Section {
                NavigationLink {
                    StorageView()
                } label: {
                    LabeledContent("Saved edits", value: "\(store.projects.count)")
                }
                Button("Delete All Edits…", role: .destructive) { confirmDeleteAll = true }
                    .disabled(store.projects.isEmpty)
            } header: {
                HStack {
                    Text("Storage")
                    Spacer()
                    if let totalSize {
                        Text(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))
                    }
                }
            }
            Section("About") {
                NavigationLink("Privacy") { PrivacyView() }
                LabeledContent("Version", value: Self.version)
            }
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $showAddKey) {
            AddKeySheet()
                .presentationDetents([.medium])
        }
        .alert("Delete all \(store.projects.count) edits?", isPresented: $confirmDeleteAll) {
            Button("Cancel", role: .cancel) {}
            Button("Delete All", role: .destructive) {
                store.deleteAll()
                refreshSize()
            }
        } message: {
            Text("Originals in Photos aren't affected. This can't be undone.")
        }
        .task { refreshSize() }
    }

    private var aiSection: some View {
        Section {
            ForEach(Array(keys.keys.enumerated()), id: \.element.id) { i, info in
                HStack(spacing: 6) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(info.vendor.name)
                        if let err = info.lastError {
                            Label("\(err) · \(info.requests) requests", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        } else {
                            Text("\(info.requests) requests")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if keys.keys.count > 1 {
                        Button { keys.move(info.id, by: -1) } label: { Image(systemName: "arrow.up") }
                            .disabled(i == 0)
                            .accessibilityLabel("Move up")
                        Button { keys.move(info.id, by: 1) } label: { Image(systemName: "arrow.down") }
                            .disabled(i == keys.keys.count - 1)
                            .accessibilityLabel("Move down")
                    }
                    Menu {
                        Button("Delete", systemImage: "trash", role: .destructive) { keys.delete(info.id) }
                    } label: {
                        Image(systemName: "ellipsis").frame(width: 28, height: 28)
                    }
                    .accessibilityLabel("More")
                }
                .buttonStyle(.borderless)
            }
            Button {
                showAddKey = true
            } label: {
                Text("Add AI Key").frame(maxWidth: .infinity)
            }
        } header: {
            HStack {
                Text("AI Keys")
                Button {
                    showInfo = true
                } label: {
                    Image(systemName: "info.circle")
                }
                .accessibilityLabel("About AI keys")
                .popover(isPresented: $showInfo) {
                    Text("Keys stay in this iPhone's Keychain and never sync or leave it, except to call that vendor. Only the photo and prompt you run are sent, and the vendor bills your account. Order = fallback order.")
                        .font(.footnote)
                        .padding()
                        .frame(width: 300)
                        .presentationCompactAdaptation(.popover)
                }
                Spacer()
                Menu {
                    Picker("Strategy", selection: $keys.strategy) {
                        ForEach(AIStrategy.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                } label: {
                    HStack(spacing: 2) {
                        Text(keys.strategy.title)
                        Image(systemName: "chevron.up.chevron.down").font(.caption2)
                    }
                    .textCase(nil)
                }
                .disabled(keys.keys.count < 2)
            }
        } footer: {
            Text("Only for Magic Erase and Restyle.")
        }
    }

    private func refreshSize() {
        let store = store
        Task.detached {
            let size = store.totalSize()
            await MainActor.run { totalSize = size }
        }
    }

    static var version: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(v) (\(b))"
    }
}

struct StorageView: View {
    @State private var store = ProjectStore.shared
    @State private var sizes: [UUID: Int64] = [:]

    var body: some View {
        List {
            ForEach(store.projects) { p in
                HStack(spacing: 12) {
                    ProjectThumbnail(project: p)
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    Text(p.modified.formatted(date: .abbreviated, time: .shortened))
                    Spacer()
                    if let s = sizes[p.id] {
                        Text(ByteCountFormatter.string(fromByteCount: s, countStyle: .file))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
            .onDelete { idx in
                idx.map { store.projects[$0] }.forEach(store.delete)
            }
        }
        .overlay {
            if store.projects.isEmpty {
                ContentUnavailableView("No saved edits", systemImage: "photo.stack")
            }
        }
        .navigationTitle("Saved Edits")
        .task {
            for p in store.projects {
                let s = await Task.detached { ProjectStore.folderSize(p.folder) }.value
                sizes[p.id] = s
            }
        }
    }
}

struct PrivacyView: View {
    var body: some View {
        List {
            Section {
                Text("Photo Editor has no account, no analytics and no ads. Your photos and edits stay on this iPhone.")
            }
            Section("What leaves the device") {
                Text("Only when you tap Erase or Restyle: a copy of the photo (up to 1536 px), the painted area and your prompt, sent directly to the AI vendor whose key you added.")
            }
            Section("Photos access") {
                Text("Photos are picked with the system picker, so the app never sees your library. Saving asks for add-only access.")
            }
            Section("AI keys") {
                Text("Stored in this iPhone's Keychain, never synced to iCloud and never included in backups of the app's data.")
            }
        }
        .navigationTitle("Privacy")
    }
}
