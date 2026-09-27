import CoreImage
import Foundation
import ImageIO
import Observation
import UniformTypeIdentifiers

nonisolated struct Project: Identifiable, Hashable, Sendable {
    let id: UUID
    let folder: URL
    var modified: Date

    var documentURL: URL { folder.appendingPathComponent("document.json") }
    var thumbnailURL: URL { folder.appendingPathComponent("thumb.jpg") }
    var assetsURL: URL { folder.appendingPathComponent("assets", isDirectory: true) }

    func originalURL(_ doc: EditDocument) -> URL {
        folder.appendingPathComponent(doc.source.filename)
    }
}

@Observable
final class ProjectStore {
    static let shared = ProjectStore()

    private(set) var projects: [Project] = []
    /// Bumps when a thumbnail changes so grids reload it.
    private(set) var thumbnailVersion: [UUID: Int] = [:]

    let root: URL

    init(root: URL? = nil) {
        self.root = root ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Projects", isDirectory: true)
        try? FileManager.default.createDirectory(at: self.root, withIntermediateDirectories: true)
        reload()
    }

    func reload() {
        let fm = FileManager.default
        let dirs = (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        projects = dirs.compactMap { dir -> Project? in
            guard let id = UUID(uuidString: dir.lastPathComponent) else { return nil }
            let docURL = dir.appendingPathComponent("document.json")
            let modified = (try? fm.attributesOfItem(atPath: docURL.path)[.modificationDate] as? Date) ?? .distantPast
            return Project(id: id, folder: dir, modified: modified)
        }
        .sorted { $0.modified > $1.modified }
    }

    // MARK: create

    nonisolated static func makeProject(from data: Data, in root: URL) throws -> Project {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil),
              let type = CGImageSourceGetType(src) as String?,
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int,
              let h = props[kCGImagePropertyPixelHeight] as? Int else {
            throw ImageDecoder.Error.unreadable
        }
        let orientation = props[kCGImagePropertyOrientation] as? UInt32 ?? 1
        let size = orientation >= 5 ? (h, w) : (w, h)
        let ext = UTType(type)?.preferredFilenameExtension ?? "jpg"
        let id = UUID()
        let folder = root.appendingPathComponent(id.uuidString, isDirectory: true)
        let fm = FileManager.default
        try fm.createDirectory(at: folder.appendingPathComponent("assets"), withIntermediateDirectories: true)
        let filename = "original.\(ext)"
        try data.write(to: folder.appendingPathComponent(filename))
        let doc = EditDocument(source: SourceInfo(filename: filename, pixelWidth: size.0, pixelHeight: size.1))
        let project = Project(id: id, folder: folder, modified: Date())
        try save(doc, to: project)
        if let thumb = ImageDecoder.downsampled(data: data, maxPixel: 600) {
            writeThumbnail(CIImage(cgImage: thumb), to: project.thumbnailURL)
        }
        return project
    }

    func create(from data: Data) async throws -> Project {
        let root = root
        let project = try await Task.detached(priority: .userInitiated) {
            try ProjectStore.makeProject(from: data, in: root)
        }.value
        projects.insert(project, at: 0)
        return project
    }

    // MARK: document IO

    nonisolated static func load(_ project: Project) throws -> EditDocument {
        let data = try Data(contentsOf: project.documentURL)
        return try JSONDecoder().decode(EditDocument.self, from: data)
    }

    nonisolated static func save(_ doc: EditDocument, to project: Project) throws {
        let data = try JSONEncoder().encode(doc)
        try data.write(to: project.documentURL, options: .atomic)
    }

    func didSave(_ project: Project) {
        guard let i = projects.firstIndex(where: { $0.id == project.id }) else { return }
        projects[i].modified = Date()
        let p = projects.remove(at: i)
        projects.insert(p, at: 0)
    }

    nonisolated static func writeThumbnail(_ image: CIImage, to url: URL) {
        let longEdge = max(image.extent.width, image.extent.height)
        let s = min(1, 600 / longEdge)
        let scaled = image.transformed(by: CGAffineTransform(scaleX: s, y: s), highQualityDownsample: true)
        let opaque = scaled.composited(over: CIImage(color: .white).cropped(to: scaled.extent))
        try? RenderEngine.context.writeJPEGRepresentation(of: opaque, to: url, colorSpace: RenderEngine.outputSpace,
                                                        options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 0.8])
    }

    func thumbnailUpdated(_ project: Project) {
        thumbnailVersion[project.id, default: 0] += 1
    }

    // MARK: manage

    func duplicate(_ project: Project) throws {
        let id = UUID()
        let dest = root.appendingPathComponent(id.uuidString, isDirectory: true)
        try FileManager.default.copyItem(at: project.folder, to: dest)
        try FileManager.default.setAttributes([.modificationDate: Date()],
                                              ofItemAtPath: dest.appendingPathComponent("document.json").path)
        projects.insert(Project(id: id, folder: dest, modified: Date()), at: 0)
    }

    func delete(_ project: Project) {
        try? FileManager.default.removeItem(at: project.folder)
        projects.removeAll { $0.id == project.id }
    }

    func deleteAll() {
        projects.forEach { try? FileManager.default.removeItem(at: $0.folder) }
        projects = []
    }

    nonisolated func size(of project: Project) -> Int64 {
        Self.folderSize(project.folder)
    }

    nonisolated func totalSize() -> Int64 {
        Self.folderSize(root)
    }

    nonisolated static func folderSize(_ url: URL) -> Int64 {
        let e = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.totalFileAllocatedSizeKey])
        var total: Int64 = 0
        while let file = e?.nextObject() as? URL {
            total += Int64((try? file.resourceValues(forKeys: [.totalFileAllocatedSizeKey]).totalFileAllocatedSize) ?? 0)
        }
        return total
    }
}
