import SwiftUI

struct SaveSheet: View {
    let model: EditorModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppSettings.exportFormatKey) private var defaultFormat: ExportFormat = .heic
    @AppStorage(AppSettings.keepLocationKey) private var keepLocation = true

    @State private var format: ExportFormat = .heic
    @State private var size: ExportSize = .full
    @State private var working: Action?
    @State private var task: Task<Void, Never>?
    @State private var showDenied = false
    @State private var errorMessage: String?
    @State private var shareURL: URL?

    enum Action { case save, share }

    var body: some View {
        VStack(spacing: 18) {
            Text("Save")
                .font(.headline)
                .padding(.top, 22)

            VStack(spacing: 0) {
                row("Format") {
                    Segmented(options: ExportFormat.allCases, selection: $format) { $0.label }
                        .frame(width: 210)
                }
                Divider().padding(.leading, 16)
                row("Size") {
                    VStack(alignment: .trailing, spacing: 4) {
                        Segmented(options: ExportSize.allCases, selection: $size) { $0.label }
                            .frame(width: 210)
                        let px = Exporter.outputSize(model.document, size: size)
                        Text(verbatim: "\(Int(px.width))×\(Int(px.height))")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }

            if working != nil {
                HStack(spacing: 12) {
                    ProgressView()
                    Text(working == .save ? "Exporting…" : "Preparing…")
                    Button("Cancel") {
                        task?.cancel()
                        working = nil
                    }
                    .padding(.leading, 8)
                }
                .frame(height: 50)
            } else {
                Button {
                    run(.save)
                } label: {
                    Text("Save to Photos")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal)
                Button("Share…") { run(.share) }
                    .font(.subheadline.weight(.medium))
            }
            Spacer(minLength: 0)
        }
        .onAppear {
            format = Exporter.hasTransparency(model.document) ? .png : defaultFormat
        }
        .alert("Allow adding to Photos", isPresented: $showDenied) {
            Button("Cancel", role: .cancel) {}
            Button("Open Settings") { PhotoSaver.openAppSettings() }
        } message: {
            Text("Photo Editor can only add new photos. It can't see your library.")
        }
        .sheet(item: $shareURL) { url in
            ShareSheet(items: [url])
                .presentationDetents([.medium, .large])
        }
        .preferredColorScheme(.dark)
    }

    private func row(_ title: String, @ViewBuilder trailing: () -> some View) -> some View {
        HStack {
            Text(title)
            Spacer()
            trailing()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func run(_ action: Action) {
        errorMessage = nil
        working = action
        let doc = model.document
        let session = model.session
        let format = format, size = size, keep = keepLocation
        task = Task {
            do {
                let data = try await Exporter.export(document: doc, session: session, format: format, size: size, keepLocation: keep)
                try Task.checkCancellation()
                switch action {
                case .save:
                    try await PhotoSaver.save(data)
                    await model.commit()
                    working = nil
                    dismiss()
                    model.showToast("Saved to Photos")
                case .share:
                    let url = FileManager.default.temporaryDirectory
                        .appendingPathComponent("Photo Editor \(Self.stamp()).\(format.utType.preferredFilenameExtension ?? "jpg")")
                    try data.write(to: url)
                    await model.commit()
                    working = nil
                    shareURL = url
                }
            } catch is CancellationError {
                working = nil
            } catch PhotoSaver.Failure.denied {
                working = nil
                showDenied = true
            } catch {
                working = nil
                errorMessage = error.localizedDescription
            }
        }
    }

    private static func stamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return f.string(from: Date())
    }
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
