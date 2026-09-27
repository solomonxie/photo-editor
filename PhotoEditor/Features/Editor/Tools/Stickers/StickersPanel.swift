import PhotosUI
import SwiftUI

struct StickersPanel: View {
    let model: EditorModel
    @State private var showPicker = false

    var body: some View {
        ToolPanel {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(StickerCatalog.quick, id: \.self) { e in
                        Button { add(e) } label: {
                            Text(e).font(.system(size: 32)).frame(width: 46, height: 46)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
            Button {
                showPicker = true
            } label: {
                Label("More Stickers", systemImage: "square.grid.2x2")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.12), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showPicker) {
            StickerSheet(model: model) { showPicker = false }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private func add(_ emoji: String) {
        model.addLayer(Layer(content: .emoji(emoji), width: 0.28))
    }
}

struct StickerSheet: View {
    let model: EditorModel
    let dismiss: () -> Void
    @State private var tab: Tab = .emoji
    @State private var query = ""
    @State private var pickerItem: PhotosPickerItem?
    @State private var working = false

    enum Tab: String, CaseIterable { case emoji, shapes, photos }

    var body: some View {
        VStack(spacing: 12) {
            Segmented(options: Tab.allCases, selection: $tab) { t in
                switch t {
                case .emoji: "Emoji"
                case .shapes: "Shapes"
                case .photos: "From Photos"
                }
            }
            .padding(.horizontal)
            .padding(.top, 20)

            switch tab {
            case .emoji:
                TextField("Search emoji", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                grid(StickerCatalog.search(query))
            case .shapes:
                grid(StickerCatalog.shapes)
            case .photos:
                VStack(spacing: 14) {
                    Spacer()
                    Text("Lift a person, pet or object out of another photo.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    if working {
                        ProgressView("Lifting subject…")
                    } else {
                        PhotosPicker("Choose Photo", selection: $pickerItem, matching: .images)
                            .buttonStyle(.borderedProminent)
                    }
                    Spacer()
                }
                .padding()
            }
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task { await lift(item) }
        }
    }

    private func grid(_ items: [String]) -> some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 8) {
                ForEach(items, id: \.self) { e in
                    Button {
                        model.addLayer(Layer(content: .emoji(e), width: 0.28))
                        dismiss()
                    } label: {
                        Text(e).font(.system(size: 36)).frame(height: 50)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }

    private func lift(_ item: PhotosPickerItem) async {
        working = true
        defer { working = false }
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        let assets = model.project.assetsURL
        guard let (name, aspect) = await Self.liftSubject(data, assets: assets) else {
            model.showToast("No clear subject found in that photo.")
            dismiss()
            return
        }
        model.addLayer(Layer(content: .image(asset: name, aspect: aspect), width: 0.5))
        dismiss()
    }

    @concurrent
    private static func liftSubject(_ data: Data, assets: URL) async -> (String, Double)? {
        guard let cg = ImageDecoder.downsampled(data: data, maxPixel: 2048) else { return nil }
        let analysis = SubjectAnalysis(cgImage: cg)
        guard !analysis.instances.isEmpty, let mask = analysis.mask(for: analysis.instances) else { return nil }
        let image = CIImage(cgImage: cg)
        let cut = image.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: CIImage.clear.cropped(to: image.extent),
            kCIInputMaskImageKey: mask,
        ])
        return AssetWriter.writeTrimmedPNG(cut, alphaSource: mask, to: assets).map { ($0.name, $0.aspect) }
    }
}

nonisolated enum AssetWriter {
    struct Written {
        var name: String
        var aspect: Double
        /// Trimmed bounds in the input image's space.
        var bounds: CGRect
    }

    /// Writes `image` cropped to the opaque bounds of `alphaSource`.
    static func writeTrimmedPNG(_ image: CIImage, alphaSource: CIImage, to folder: URL) -> Written? {
        let ctx = RenderEngine.context
        var bounds = image.extent
        if let cg = ctx.createCGImage(alphaSource, from: alphaSource.extent, format: .L8, colorSpace: CGColorSpaceCreateDeviceGray()),
           let b = opaqueBounds(cg) {
            bounds = b.offsetBy(dx: alphaSource.extent.minX, dy: alphaSource.extent.minY)
        }
        let trimmed = image.cropped(to: bounds)
        let name = "\(UUID().uuidString).png"
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        do {
            try ctx.writePNGRepresentation(of: trimmed, to: folder.appendingPathComponent(name), format: .RGBA8,
                                           colorSpace: RenderEngine.outputSpace)
        } catch {
            return nil
        }
        return Written(name: name, aspect: bounds.height / bounds.width, bounds: bounds)
    }

    static func opaqueBounds(_ cg: CGImage) -> CGRect? {
        let w = cg.width, h = cg.height
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                                  space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue),
              let data = ctx.data else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        let px = data.assumingMemoryBound(to: UInt8.self)
        var minX = w, minY = h, maxX = -1, maxY = -1
        for y in 0..<h {
            let row = y * w
            for x in 0..<w where px[row + x] > 24 {
                if x < minX { minX = x }
                if x > maxX { maxX = x }
                if y < minY { minY = y }
                if y > maxY { maxY = y }
            }
        }
        guard maxX >= minX else { return nil }
        // Row 0 in memory is the top; CI's y axis points up.
        return CGRect(x: minX, y: h - 1 - maxY, width: maxX - minX + 1, height: maxY - minY + 1)
    }
}

nonisolated enum StickerCatalog {
    static let quick = ["😀", "😂", "🥹", "😍", "🤩", "😎", "🥳", "❤️", "🔥", "✨", "🌴", "🌸", "☀️", "⭐️", "👍", "🙌"]

    static let shapes = ["❤️", "🧡", "💛", "💚", "💙", "💜", "🖤", "🤍", "⭐️", "🌟", "✨", "💫", "⚡️", "🔥", "💥", "☁️",
                         "🌈", "☀️", "🌙", "💬", "💭", "🗯️", "➡️", "⬅️", "⬆️", "⬇️", "✅", "❌", "⭕️", "❗️", "❓", "💯"]

    /// Emoji with a few searchable words each.
    static let all: [(String, String)] = [
        ("😀", "smile happy grin"), ("😂", "laugh tears joy lol"), ("🥹", "touched tears"), ("😍", "love heart eyes"),
        ("🤩", "star struck wow"), ("😎", "cool sunglasses"), ("🥳", "party celebrate"), ("🤔", "think hmm"),
        ("😴", "sleep tired"), ("😭", "cry sad"), ("😡", "angry mad"), ("🤯", "mind blown"), ("😇", "angel halo"),
        ("🥰", "love hearts"), ("😘", "kiss"), ("🤪", "crazy silly"), ("🙃", "upside down"), ("😏", "smirk"),
        ("🙌", "hands celebrate yay"), ("👍", "thumbs up like ok"), ("👏", "clap"), ("🙏", "pray thanks please"),
        ("💪", "strong muscle"), ("✌️", "peace victory"), ("👋", "wave hi hello"), ("🤝", "handshake deal"),
        ("❤️", "heart love red"), ("💔", "broken heart"), ("🔥", "fire hot lit"), ("✨", "sparkles magic"),
        ("⭐️", "star"), ("🌟", "glowing star"), ("💯", "hundred perfect"), ("🎉", "party tada confetti"),
        ("🎂", "birthday cake"), ("🎁", "gift present"), ("🎈", "balloon"), ("🏆", "trophy win"),
        ("🌴", "palm tree beach summer"), ("🌸", "cherry blossom flower spring"), ("🌻", "sunflower"), ("🌹", "rose flower"),
        ("🍀", "clover luck"), ("🌈", "rainbow"), ("☀️", "sun sunny"), ("🌙", "moon night"), ("❄️", "snow winter"),
        ("🌊", "wave ocean sea"), ("⛰️", "mountain"), ("🏖️", "beach"), ("✈️", "plane travel"), ("🚗", "car"),
        ("🐶", "dog puppy"), ("🐱", "cat kitten"), ("🐻", "bear"), ("🐼", "panda"), ("🦊", "fox"), ("🐰", "rabbit bunny"),
        ("🦋", "butterfly"), ("🐝", "bee"), ("🍕", "pizza food"), ("🍔", "burger food"), ("🍣", "sushi food"),
        ("🍦", "ice cream"), ("☕️", "coffee"), ("🍷", "wine"), ("🍺", "beer"), ("🥂", "cheers toast"),
        ("📸", "camera photo"), ("🎵", "music note"), ("💡", "idea bulb"), ("📍", "pin location"), ("👑", "crown king queen"),
        ("💎", "diamond gem"), ("🕶️", "sunglasses"), ("🎀", "bow ribbon"), ("💋", "kiss lips"), ("👀", "eyes look"),
    ]

    static func search(_ q: String) -> [String] {
        let query = q.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return all.map(\.0) }
        return all.filter { $0.1.contains(query) }.map(\.0)
    }
}
