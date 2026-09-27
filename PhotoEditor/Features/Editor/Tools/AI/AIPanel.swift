import Network
import SwiftUI

@Observable
final class NetworkStatus {
    static let shared = NetworkStatus()
    private(set) var isOnline = true
    private let monitor = NWPathMonitor()

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in self?.isOnline = online }
        }
        monitor.start(queue: DispatchQueue(label: "network.status"))
    }
}

struct AIPanel: View {
    let model: EditorModel
    @State private var mode: Mode = .erase
    @State private var prompt = ""
    @State private var running: Task<Void, Never>?
    @State private var startedAt: Date?
    @State private var error: AIRunner.Failure?
    @State private var showAddKey = false
    @State private var keys = AIKeyStore.shared
    @State private var network = NetworkStatus.shared
    @AppStorage(BrushOverlay.brushSizeKey) private var brushSize: Double = 28
    @FocusState private var promptFocused: Bool

    enum Mode: String, CaseIterable {
        case erase, fill, restyle

        var title: String {
            switch self {
            case .erase: "Magic Erase"
            case .fill: "Fill"
            case .restyle: "Restyle"
            }
        }

        var usesBrush: Bool { self != .restyle }
    }

    static let presets = ["Watercolor", "Anime", "Oil painting", "Pixel art", "Pencil sketch", "90s film"]
    static let fillPresets = ["Fuller hair", "Add bangs", "Neat beard", "Clear skin", "Blue sky", "Remove glasses"]

    var body: some View {
        ToolPanel {
            if !keys.hasKeys {
                noKey
            } else if let started = startedAt {
                runningView(started)
            } else {
                switch mode {
                case .erase: eraseControls
                case .fill: fillControls
                case .restyle: restyleControls
                }
                footer
            }
            if keys.hasKeys, startedAt == nil {
                Segmented(options: Mode.allCases, selection: $mode) { $0.title }
                    .padding(.horizontal, 40)
            }
        }
        .onChange(of: mode) { _, _ in prompt = "" }
        .onChange(of: mode, initial: true) { _, m in
            model.selectedLayerID = nil
            model.brushTarget = (m.usesBrush && keys.hasKeys) ? .magicErase : nil
        }
        .onChange(of: keys.hasKeys) { _, has in
            model.brushTarget = (mode.usesBrush && has) ? .magicErase : nil
        }
        .onDisappear {
            model.brushTarget = nil
            model.brushPreview = []
        }
        .sheet(isPresented: $showAddKey) {
            AddKeySheet()
                .presentationDetents([.medium])
        }
    }

    private var noKey: some View {
        VStack(spacing: 10) {
            Text("Magic Erase, Fill and Restyle use your own AI key.")
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

    private var eraseControls: some View {
        VStack(spacing: 8) {
            HStack {
                Text(model.brushPreview.isEmpty ? "Paint over what to remove." : "Paint more, or tap Erase.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Clear") { model.brushPreview = [] }
                    .font(.subheadline.weight(.medium))
                    .disabled(model.brushPreview.isEmpty)
            }
            BrushSizeSlider(size: $brushSize)
        }
        .padding(.horizontal, 20)
    }

    private var fillControls: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                TextField(model.brushPreview.isEmpty ? "Paint an area, then describe it" : "e.g. fuller hair, a hat…", text: $prompt)
                    .textFieldStyle(.roundedBorder)
                    .focused($promptFocused)
                    .submitLabel(.go)
                    .onSubmit { if canRun { run() } }
                Button("Clear") { model.brushPreview = [] }
                    .font(.subheadline.weight(.medium))
                    .disabled(model.brushPreview.isEmpty)
            }
            .padding(.horizontal, 16)
            presetRow(Self.fillPresets)
        }
    }

    private func presetRow(_ items: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items, id: \.self) { p in
                    Button(p) { prompt = p.lowercased() }
                        .font(.footnote)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.1), in: Capsule())
                        .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var restyleControls: some View {
        VStack(spacing: 8) {
            TextField("Describe a style, e.g. watercolor, 90s film…", text: $prompt)
                .textFieldStyle(.roundedBorder)
                .focused($promptFocused)
                .submitLabel(.go)
                .onSubmit { run() }
                .padding(.horizontal, 16)
            presetRow(Self.presets)
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
            } else if let first = keys.keys.first {
                Text("via \(first.vendor.name) · your account is billed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(mode == .erase ? "Erase" : (mode == .fill ? "Fill" : "Restyle")) { run() }
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
        guard network.isOnline else { return false }
        switch mode {
        case .erase: return !model.brushPreview.isEmpty
        case .fill: return !model.brushPreview.isEmpty && !prompt.trimmingCharacters(in: .whitespaces).isEmpty
        case .restyle: return !prompt.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    private func runningView(_ started: Date) -> some View {
        HStack(spacing: 12) {
            ProgressView()
            TimelineView(.periodic(from: started, by: 1)) { ctx in
                Text("\(mode == .erase ? "Erasing" : (mode == .fill ? "Filling" : "Restyling"))… (\(Int(ctx.date.timeIntervalSince(started))) s)")
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

    private func run() {
        promptFocused = false
        error = nil
        let kind: AIImageJob.Kind = switch mode {
        case .erase: .erase
        case .fill: .fill
        case .restyle: .restyle
        }
        let strokes = mode.usesBrush ? model.brushPreview : nil
        let text = prompt
        startedAt = Date()
        model.brushTarget = nil
        running = Task {
            defer {
                startedAt = nil
                running = nil
                if mode.usesBrush { model.brushTarget = .magicErase }
            }
            do {
                let outcome = try await AIRunner.run(kind: kind, prompt: text, strokes: strokes, model: model, keys: keys)
                try Task.checkCancellation()
                model.update { $0.patches.append(outcome.patch) }
                model.brushPreview = []
                if let from = outcome.fellBackFrom {
                    model.showToast("\(from.shortName) failed — used \(outcome.vendor.shortName)")
                } else {
                    model.showToast(kind == .erase ? "Erased" : (kind == .fill ? "Filled" : "Restyled"), action: "Undo") { [model] in model.undo() }
                }
            } catch let f as AIRunner.Failure {
                error = f
            } catch {}
        }
    }
}
