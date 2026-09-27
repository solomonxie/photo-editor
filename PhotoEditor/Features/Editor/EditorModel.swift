import CoreImage
import Observation
import SwiftUI

enum EditorTool: String, CaseIterable, Identifiable {
    case adjust, filters, crop, retouch, reshape, text, stickers, cutout, ai

    var id: String { rawValue }

    var title: String {
        switch self {
        case .adjust: "Adjust"
        case .filters: "Filters"
        case .crop: "Crop"
        case .retouch: "Beauty"
        case .reshape: "Reshape"
        case .text: "Text"
        case .stickers: "Stickers"
        case .cutout: "Cutout"
        case .ai: "AI"
        }
    }

    var systemImage: String {
        switch self {
        case .adjust: "slider.horizontal.3"
        case .filters: "camera.filters"
        case .crop: "crop.rotate"
        case .retouch: "wand.and.rays"
        case .reshape: "figure.arms.open"
        case .text: "textformat"
        case .stickers: "face.smiling"
        case .cutout: "person.crop.rectangle"
        case .ai: "sparkles"
        }
    }
}

struct ToastMessage: Equatable, Identifiable {
    let id = UUID()
    var text: String
    var actionTitle: String?
    var action: (() -> Void)?

    static func == (a: ToastMessage, b: ToastMessage) -> Bool { a.id == b.id }
}

@Observable
final class EditorModel {
    let project: Project
    let session: RenderSession
    let viewport = Viewport()

    private(set) var document: EditDocument
    private(set) var history = EditHistory()
    private(set) var renderVersion = 0

    var activeTool: EditorTool? = .adjust {
        didSet { toolChanged(from: oldValue) }
    }
    var selectedLayerID: UUID? {
        didSet { if oldValue != selectedLayerID { redraw() } }
    }
    var editingTextLayerID: UUID?
    var isComparing = false {
        didSet { redraw() }
    }
    var toast: ToastMessage?
    var brushPreview: [BrushStroke] = []
    var brushTarget: BrushTarget?
    var cropAspect: CropAspect = .free

    enum BrushTarget: Equatable { case heal, magicErase, reshape(ManualWarp.Kind) }
    var reshapeKind: ManualWarp.Kind = .push

    private var savedDocument: EditDocument

    var hasUnsavedChanges: Bool { document != savedDocument }

    init(project: Project, document: EditDocument, session: RenderSession) {
        self.project = project
        #if DEBUG
        self.document = DebugLaunch.patched(DebugLaunch.has("-fresh") ? EditDocument(source: document.source) : document)
        #else
        self.document = document
        #endif
        self.savedDocument = document
        self.session = session
        updateViewportImage()
        #if DEBUG
        if let tool = DebugLaunch.tool { activeTool = tool }
        if let i = DebugLaunch.value("-select").flatMap(Int.init), self.document.layers.indices.contains(i) {
            selectedLayerID = self.document.layers[i].id
        }
        #endif
    }

    static func open(_ project: Project) async throws -> EditorModel {
        let screenLong = 2532.0
        let (doc, session) = try await Task.detached(priority: .userInitiated) {
            let doc = try ProjectStore.load(project)
            let session = try RenderSession(originalURL: project.originalURL(doc), assetsURL: project.assetsURL,
                                            proxyMaxPixel: Int(screenLong * 1.25))
            return (doc, session)
        }.value
        return EditorModel(project: project, document: doc, session: session)
    }

    // MARK: editing

    /// A discrete change: one undo step.
    func update(_ change: (inout EditDocument) -> Void) {
        let before = document
        change(&document)
        guard document != before else { return }
        history.record(before)
        documentChanged()
    }

    /// Part of a continuous gesture; wrap with begin/endGesture.
    func live(_ change: (inout EditDocument) -> Void) {
        let before = document
        change(&document)
        guard document != before else { return }
        documentChanged()
    }

    func beginGesture() {
        history.beginGesture(document)
    }

    func endGesture() {
        history.endGesture(document)
    }

    func undo() {
        guard let doc = history.undo(document) else { return }
        document = doc
        documentChanged()
    }

    func redo() {
        guard let doc = history.redo(document) else { return }
        document = doc
        documentChanged()
    }

    private func documentChanged() {
        if let id = selectedLayerID, !document.layers.contains(where: { $0.id == id }) {
            selectedLayerID = nil
        }
        updateViewportImage()
        redraw()
    }

    func redraw() {
        renderVersion &+= 1
    }

    private func toolChanged(from old: EditorTool?) {
        if old == .cutout || activeTool == .cutout {
            redraw()
        }
        if old == .crop || activeTool == .crop {
            viewport.reset()
            updateViewportImage()
            redraw()
        }
        if activeTool != .retouch && activeTool != .ai && activeTool != .reshape {
            brushTarget = nil
        }
    }

    // MARK: geometry

    var isCropping: Bool { activeTool == .crop }

    var geometry: CropGeometry {
        CropGeometry(crop: document.crop, sourceSize: document.source.size)
    }

    private func updateViewportImage() {
        let size = isCropping ? geometry.rotatedSize : geometry.outputSize
        if viewport.imageSize != size {
            viewport.imageSize = size
            viewport.clampOffset()
        }
    }

    /// Output-normalized point (top-left origin) → source-normalized point.
    func sourcePoint(fromOutput n: CGPoint) -> CGPoint {
        let out = geometry.outputSize
        let src = document.source.size
        let p = CGPoint(x: n.x * out.width, y: (1 - n.y) * out.height)
            .applying(geometry.outputTransform.inverted())
        return CGPoint(x: p.x / src.width, y: 1 - p.y / src.height)
    }

    /// Converts a brush radius in view points into a fraction of the source's long edge.
    func sourceRadius(points: CGFloat) -> Double {
        let frame = viewport.imageFrame
        guard frame.width > 0 else { return 0.02 }
        let outPx = points / frame.width * geometry.outputSize.width
        let fill = CropGeometry.fillScale(size: geometry.rotatedSize, angle: document.crop.angle * .pi / 180)
        return outPx / fill / max(document.source.size.width, document.source.size.height)
    }

    // MARK: rendering

    func pipeline(_ doc: EditDocument? = nil, source: CIImage? = nil) -> RenderPipeline {
        RenderPipeline(session: session, document: doc ?? document, source: source ?? session.proxy)
    }

    /// The canvas image for about `pixelWidth` output pixels.
    func canvasImage(pixelWidth: CGFloat) -> CIImage {
        let geo = CropGeometry(crop: document.crop, sourceSize: session.proxy.extent.size)
        let outWidth = isCropping ? geo.rotatedSize.width : geo.outputSize.width
        let needed = min(1, pixelWidth / max(1, outWidth))
        let source = scaledProxy(needed)

        var doc = document
        if !brushPreview.isEmpty, brushTarget == .heal {
            doc.heal += brushPreview
        }
        if isComparing {
            let original = pipeline(doc, source: source).image(RenderOptions(mode: .original))
            return CropGeometry(crop: document.crop, sourceSize: source.extent.size).apply(original)
        }
        if isCropping {
            return pipeline(doc, source: source).image(RenderOptions(mode: .straightenOnly))
        }
        if editingTextLayerID != nil {
            doc.layers.removeAll { $0.id == editingTextLayerID }
        }
        return pipeline(doc, source: source).image(RenderOptions(highlightSubjects: activeTool == .cutout))
    }

    private func scaledProxy(_ s: CGFloat) -> CIImage {
        guard s < 0.9 else { return session.proxy }
        let bucket = (s * 20).rounded(.up) / 20
        return session.cached("proxy:\(bucket)") {
            let scaled = session.proxy.transformed(by: CGAffineTransform(scaleX: bucket, y: bucket), highQualityDownsample: true)
            guard let cg = RenderEngine.context.createCGImage(scaled, from: scaled.extent, format: .RGBA8,
                                                             colorSpace: RenderEngine.outputSpace) else { return scaled }
            return CIImage(cgImage: cg)
        }
    }

    var hasTransparency: Bool {
        document.cutout?.background == .remove && !isComparing
    }

    // MARK: persistence

    @concurrent
    private static func persist(_ doc: EditDocument, _ project: Project) async {
        try? ProjectStore.save(doc, to: project)
    }

    /// Writes the edit to disk; called only after the user saves or shares.
    func commit() async {
        let doc = document
        let project = project
        let image = pipeline().image()
        await Self.persist(doc, project)
        await Self.writeThumb(image, project)
        savedDocument = doc
        ProjectStore.shared.didSave(project)
        ProjectStore.shared.thumbnailUpdated(project)
    }

    /// Drops unsaved edits; a photo that was never saved leaves no trace.
    func discard() {
        ProjectStore.shared.discardIfUnsaved(project)
    }

    @concurrent
    private static func writeThumb(_ image: CIImage, _ project: Project) async {
        ProjectStore.writeThumbnail(image, to: project.thumbnailURL)
    }

    // MARK: layers

    var selectedLayer: Layer? {
        document.layers.first { $0.id == selectedLayerID }
    }

    func addLayer(_ layer: Layer) {
        update { $0.layers.append(layer) }
        selectedLayerID = layer.id
    }

    func updateLayer(_ id: UUID, live: Bool = false, _ change: (inout Layer) -> Void) {
        let apply: (inout EditDocument) -> Void = { doc in
            guard let i = doc.layers.firstIndex(where: { $0.id == id }) else { return }
            change(&doc.layers[i])
        }
        live ? self.live(apply) : update(apply)
    }

    func deleteLayer(_ id: UUID) {
        update { $0.layers.removeAll { $0.id == id } }
        showToast("Layer deleted", action: "Undo") { [weak self] in self?.undo() }
    }

    func layerAspect(_ layer: Layer) -> Double {
        session.cached("aspect:\(layer.id):\(Self.contentHash(layer.content))") {
            LayerRasterizer.aspect(layer.content)
        }
    }

    private static func contentHash(_ c: Layer.Content) -> Int {
        (try? JSONEncoder().encode(c))?.hashValue ?? 0
    }

    /// Topmost visible layer under an output-normalized point.
    func layer(at n: CGPoint) -> Layer? {
        let out = geometry.outputSize
        for layer in document.layers.reversed() where !layer.isHidden {
            let w = layer.width * out.width
            let h = w * layerAspect(layer)
            let p = CGPoint(x: (n.x - layer.center.x) * out.width, y: (n.y - layer.center.y) * out.height)
            let c = cos(-layer.rotation), s = sin(-layer.rotation)
            let local = CGPoint(x: p.x * c - p.y * s, y: p.x * s + p.y * c)
            let slop = max(w, h) * 0.08
            if abs(local.x) <= w / 2 + slop, abs(local.y) <= h / 2 + slop { return layer }
        }
        return nil
    }

    func handleTap(at n: CGPoint) {
        if activeTool == .cutout {
            toggleSubject(at: n)
            return
        }
        if let layer = layer(at: n) {
            if selectedLayerID == layer.id, case .text = layer.content {
                editingTextLayerID = layer.id
            } else {
                selectedLayerID = layer.id
            }
        } else {
            selectedLayerID = nil
        }
    }

    // MARK: cutout

    func toggleSubject(at n: CGPoint) {
        guard var spec = document.cutout else { return }
        let src = sourcePoint(fromOutput: n)
        let label = pipeline().subjects.instance(at: src)
        guard label > 0 else { return }
        if spec.subjects.contains(label) {
            guard spec.subjects.count > 1 else { return }
            spec.subjects.removeAll { $0 == label }
        } else {
            spec.subjects.append(label)
            spec.subjects.sort()
        }
        update { $0.cutout = spec }
    }

    // MARK: toast

    func showToast(_ text: String, action: String? = nil, _ handler: (() -> Void)? = nil) {
        let t = ToastMessage(text: text, actionTitle: action, action: handler)
        toast = t
        Task {
            try? await Task.sleep(for: .seconds(action == nil ? 2 : 4))
            if toast == t { toast = nil }
        }
    }
}
