import CoreImage
import SwiftUI

struct FiltersPanel: View {
    let model: EditorModel
    @State private var thumbs: [String: UIImage] = [:]
    @State private var showIntensity = false

    private static let original = "original"

    var body: some View {
        ToolPanel {
            if showIntensity, let ref = model.document.filter, let preset = FilterCatalog.preset(ref.id) {
                ValueSlider(
                    title: preset.name,
                    value: Binding(
                        get: { ref.intensity * 100 },
                        set: { v in model.live { $0.filter?.intensity = max(0, v) / 100 } }
                    ),
                    bipolar: false,
                    suffix: "%",
                    onBegin: model.beginGesture,
                    onEnd: model.endGesture
                )
                .padding(.horizontal, 20)
                .transition(.opacity)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    tile(id: Self.original, name: "Original")
                    ForEach(FilterCatalog.presets) { p in
                        tile(id: p.id, name: p.name)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .task { await renderThumbs() }
    }

    private func tile(id: String, name: String) -> some View {
        let selected = (model.document.filter?.id ?? Self.original) == id
        return Button {
            select(id)
        } label: {
            VStack(spacing: 5) {
                ZStack {
                    if let img = thumbs[id] {
                        Image(uiImage: img).resizable().scaledToFill()
                    } else {
                        Rectangle().fill(Color.white.opacity(0.08))
                    }
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(selected ? Color.accentColor : .clear, lineWidth: 2.5))
                Text(name)
                    .font(.caption2.weight(selected ? .semibold : .regular))
                    .foregroundStyle(selected ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func select(_ id: String) {
        if id == Self.original {
            showIntensity = false
            model.update { $0.filter = nil }
        } else if model.document.filter?.id == id {
            withAnimation { showIntensity.toggle() }
        } else {
            model.update { $0.filter = FilterRef(id: id, intensity: 1) }
        }
    }

    /// Thumbs of this photo (with adjust + crop, without filter), rendered once per open.
    private func renderThumbs() async {
        var doc = model.document
        doc.filter = nil
        doc.layers = []
        let base = model.pipeline(doc).image()
        let s = 150 / min(base.extent.width, base.extent.height)
        let small = base.transformed(by: CGAffineTransform(scaleX: s, y: s), highQualityDownsample: true)
        let side = 150.0
        let square = small.cropped(to: CGRect(x: (small.extent.width - side) / 2, y: (small.extent.height - side) / 2,
                                              width: side, height: side))
        guard let cg = RenderEngine.context.createCGImage(square, from: square.extent) else { return }
        let seed = CIImage(cgImage: cg)
        let items = [(Self.original, seed)] + FilterCatalog.presets.map { ($0.id, $0.apply(seed)) }
        for (id, img) in items {
            let rendered = await Self.render(img)
            if let rendered { thumbs[id] = rendered }
        }
    }

    @concurrent
    private static func render(_ img: CIImage) async -> UIImage? {
        RenderEngine.context.createCGImage(img, from: img.extent, format: .RGBA8,
                                           colorSpace: RenderEngine.outputSpace).map(UIImage.init(cgImage:))
    }
}
