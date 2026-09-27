import Foundation
import Observation

@Observable
final class CompressModel {
    enum Status: Equatable {
        case pending, working, done(Int64), skipped, failed(String)
    }

    struct Settings: Sendable {
        var photoSize: ExportSize
        var quality: ExportQuality
        var videoSize: VideoSize
    }

    private(set) var items: [LibraryItem] = []
    private(set) var status: [String: Status] = [:]
    private(set) var running = false
    private var task: Task<Void, Never>?

    var pendingCount: Int { items.count { status[$0.id] != .skipped && !isDone($0) } }
    var doneIDs: [String] { items.filter(isDone).map(\.id) }
    var finishedCount: Int {
        items.count {
            switch status[$0.id] {
            case .done, .skipped, .failed: true
            default: false
            }
        }
    }

    var savedBytes: Int64 {
        items.reduce(0) { sum, item in
            guard case .done(let new) = status[item.id], let old = item.bytes else { return sum }
            return sum + max(0, old - new)
        }
    }

    private func isDone(_ item: LibraryItem) -> Bool {
        if case .done = status[item.id] { true } else { false }
    }

    func load(_ ids: [String]) async {
        let found = await Self.fetch(ids)
        items = found
        status = Dictionary(uniqueKeysWithValues: found.map { ($0.id, .pending) })
    }

    @concurrent
    private static func fetch(_ ids: [String]) async -> [LibraryItem] {
        MediaLibrary.items(ids)
    }

    func start(_ settings: Settings) {
        running = true
        task = Task {
            for item in items where !isDone(item) && status[item.id] != .skipped {
                if Task.isCancelled { break }
                status[item.id] = .working
                do {
                    status[item.id] = try await compress(item, settings)
                } catch is CancellationError {
                    status[item.id] = .pending
                } catch {
                    status[item.id] = Task.isCancelled ? .pending : .failed(error.localizedDescription)
                }
            }
            running = false
        }
    }

    func cancel() {
        task?.cancel()
    }

    func deleteOriginals() async throws {
        let ids = doneIDs
        try await MediaLibrary.delete(ids)
        items.removeAll { ids.contains($0.id) }
        ids.forEach { status[$0] = nil }
    }

    func clear() {
        items = []
        status = [:]
    }

    private func compress(_ item: LibraryItem, _ s: Settings) async throws -> Status {
        if item.isVideo {
            let url = MediaCompressor.temporaryVideoURL()
            defer { try? FileManager.default.removeItem(at: url) }
            try await MediaLibrary.exportVideo(item.id, preset: s.videoSize.preset, to: url)
            let new = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
            guard new > 0, new < Self.worthIt(item.bytes) else { return .skipped }
            try await MediaLibrary.addCopy(of: item.id, video: url)
            return .done(new)
        } else {
            let data = try await MediaLibrary.imageData(item.id)
            let out = try await Self.photo(data, s)
            let old = item.bytes ?? Int64(data.count)
            guard Int64(out.count) < Self.worthIt(old) else { return .skipped }
            try await MediaLibrary.addCopy(of: item.id, photo: out)
            return .done(Int64(out.count))
        }
    }

    /// A copy has to be at least 10% smaller to be worth keeping.
    private static func worthIt(_ bytes: Int64?) -> Int64 {
        bytes.map { $0 * 9 / 10 } ?? .max
    }

    @concurrent
    private static func photo(_ data: Data, _ s: Settings) async throws -> Data {
        try MediaCompressor.photo(data, maxEdge: s.photoSize.maxLongEdge, quality: s.quality)
    }
}
