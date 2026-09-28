import SwiftUI

/// Add, thicken or recolour hair, or add a beard, on the chosen face. Runs as an AI Fill on the user's key.
struct HairPanel: View {
    let model: EditorModel
    @State private var mode: HairMode = .hair
    @State private var style: HairStyle? = .addHair
    @State private var running: Task<Void, Never>?
    @State private var startedAt: Date?
    @State private var error: AIRunner.Failure?
    @State private var showAddKey = false
    @State private var keys = AIKeyStore.shared
    @State private var network = NetworkStatus.shared

    var body: some View {
        ToolPanel {
            if !keys.hasKeys {
                noKey
            } else if let started = startedAt {
                runningView(started)
            } else if model.reshapeTargets == nil {
                ProgressView().frame(height: 60)
            } else if model.selectedPerson == nil {
                Text("No faces found in this photo.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(height: 60)
            } else {
                ChipRow(items: HairStyle.all(mode), selection: $style, title: \.title)
                footer
            }
            if keys.hasKeys, startedAt == nil {
                Segmented(options: HairMode.allCases, selection: $mode) { $0.rawValue.capitalized }
                    .padding(.horizontal, 50)
            }
        }
        .onChange(of: mode) { _, m in style = HairStyle.all(m).first }
        .onChange(of: style) { _, _ in updatePreview() }
        .onChange(of: model.selectedFace) { _, _ in updatePreview() }
        .task {
            model.selectedLayerID = nil
            await model.analyzePeople()
            updatePreview()
        }
        .onDisappear {
            running?.cancel()
            model.brushPreview = []
        }
        .sheet(isPresented: $showAddKey) {
            AddKeySheet()
                .presentationDetents([.medium])
        }
    }

    private var noKey: some View {
        VStack(spacing: 10) {
            Text("Hair and beard use your own AI key.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                showAddKey = true
            } label: {
                Text("Add AI Key")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 9)
                    .background(Color.accentColor, in: Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if let error {
                Label(error.localizedDescription, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .lineLimit(2)
                if error.firstAuthError {
                    Button("Fix key") { showAddKey = true }
                        .font(.caption.weight(.semibold))
                }
            } else if !network.isOnline {
                Text("You're offline.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(model.reshapePeople.count > 1 ? "Tap a face to choose who." : "Red shows the area that changes.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Apply") { run() }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(canRun ? Color.accentColor : Color.white.opacity(0.1), in: Capsule())
                .foregroundStyle(canRun ? .white : .secondary)
                .buttonStyle(.plain)
                .disabled(!canRun)
        }
        .padding(.horizontal, 16)
    }

    private var canRun: Bool {
        network.isOnline && style != nil && !model.brushPreview.isEmpty
    }

    private func runningView(_ started: Date) -> some View {
        HStack(spacing: 12) {
            ProgressView()
            TimelineView(.periodic(from: started, by: 1)) { ctx in
                Text("Working… (\(Int(ctx.date.timeIntervalSince(started))) s)")
                    .font(.subheadline.monospacedDigit())
            }
            Button("Cancel") {
                running?.cancel()
                running = nil
                startedAt = nil
            }
            .font(.subheadline.weight(.medium))
        }
    }

    /// Shows the auto mask for the chosen face and style.
    private func updatePreview() {
        guard let style, let person = model.selectedPerson,
              let face = model.pipeline().faces.faces.min(by: { $0.anchor.distance(to: person.anchor) < $1.anchor.distance(to: person.anchor) })
        else {
            model.brushPreview = []
            return
        }
        let lips = (face.regions[.outerLips] ?? []).map { CGPoint(x: $0.x, y: 1 - $0.y) }
        model.brushPreview = style.strokes(frame: face.frame, lips: lips, size: model.document.source.size)
    }

    private func run() {
        guard let style else { return }
        error = nil
        let strokes = model.brushPreview
        startedAt = Date()
        running = Task {
            defer {
                startedAt = nil
                running = nil
            }
            do {
                let outcome = try await AIRunner.run(kind: .fill, prompt: style.prompt, strokes: strokes, model: model, keys: keys)
                try Task.checkCancellation()
                model.update { $0.patches.append(outcome.patch) }
                if let from = outcome.fellBackFrom {
                    model.showToast("\(from.shortName) failed — used \(outcome.vendor.shortName)")
                } else {
                    model.showToast(style.title, action: "Undo") { [model] in model.undo() }
                }
            } catch let f as AIRunner.Failure {
                error = f
            } catch {}
        }
    }
}
