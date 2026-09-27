import AVFoundation
import Photos
import UIKit

nonisolated struct LibraryItem: Identifiable, Hashable, Sendable {
    let id: String
    let isVideo: Bool
    let isLive: Bool
    let pixelSize: CGSize
    let duration: TimeInterval
    let bytes: Int64?
}

/// Read/write access to the user's library, used only by Compress.
nonisolated enum MediaLibrary {
    enum Failure: LocalizedError {
        case denied, missing, failed(String)
        var errorDescription: String? {
            switch self {
            case .denied: "Photo Editor isn't allowed to access your library."
            case .missing: "This item is no longer in your library."
            case .failed(let m): m
            }
        }
    }

    static func requestAccess() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        return status == .authorized || status == .limited
    }

    private static func asset(_ id: String) -> PHAsset? {
        PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject
    }

    static func items(_ ids: [String]) -> [LibraryItem] {
        let result = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        var byID: [String: LibraryItem] = [:]
        result.enumerateObjects { a, _, _ in
            let resources = PHAssetResource.assetResources(for: a)
            let main = resources.first { $0.type == .video || $0.type == .photo } ?? resources.first
            byID[a.localIdentifier] = LibraryItem(
                id: a.localIdentifier,
                isVideo: a.mediaType == .video,
                isLive: a.mediaSubtypes.contains(.photoLive),
                pixelSize: CGSize(width: a.pixelWidth, height: a.pixelHeight),
                duration: a.duration,
                bytes: main?.value(forKey: "fileSize") as? Int64
            )
        }
        return ids.compactMap { byID[$0] }
    }

    static func thumbnail(_ id: String, side: CGFloat) async -> UIImage? {
        guard let a = asset(id) else { return nil }
        let opts = PHImageRequestOptions()
        opts.deliveryMode = .opportunistic
        opts.resizeMode = .fast
        opts.isNetworkAccessAllowed = true
        return await withCheckedContinuation { cont in
            var resumed = false
            PHImageManager.default().requestImage(for: a, targetSize: CGSize(width: side, height: side),
                                                  contentMode: .aspectFill, options: opts) { image, info in
                let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                guard !resumed, !degraded || image == nil else { return }
                resumed = true
                cont.resume(returning: image)
            }
        }
    }

    static func imageData(_ id: String) async throws -> Data {
        guard let a = asset(id) else { throw Failure.missing }
        let opts = PHImageRequestOptions()
        opts.version = .current
        opts.deliveryMode = .highQualityFormat
        opts.isNetworkAccessAllowed = true
        return try await withCheckedThrowingContinuation { cont in
            PHImageManager.default().requestImageDataAndOrientation(for: a, options: opts) { data, _, _, info in
                if let data {
                    cont.resume(returning: data)
                } else {
                    let error = info?[PHImageErrorKey] as? Error
                    cont.resume(throwing: Failure.failed(error?.localizedDescription ?? "Couldn't load this photo."))
                }
            }
        }
    }

    /// Transcodes the video to `url` with an export preset.
    static func exportVideo(_ id: String, preset: String, to url: URL) async throws {
        guard let a = asset(id) else { throw Failure.missing }
        let opts = PHVideoRequestOptions()
        opts.version = .current
        opts.deliveryMode = .highQualityFormat
        opts.isNetworkAccessAllowed = true
        let box: SessionBox = try await withCheckedThrowingContinuation { cont in
            PHImageManager.default().requestExportSession(forVideo: a, options: opts, exportPreset: preset) { session, info in
                if let session {
                    cont.resume(returning: SessionBox(session: session))
                } else {
                    let error = info?[PHImageErrorKey] as? Error
                    cont.resume(throwing: Failure.failed(error?.localizedDescription ?? "Couldn't load this video."))
                }
            }
        }
        let session = box.session
        session.shouldOptimizeForNetworkUse = true
        try await withTaskCancellationHandler {
            if #available(iOS 18, *) {
                try await session.export(to: url, as: .mov)
            } else {
                try await legacyExport(box, to: url)
            }
        } onCancel: {
            box.session.cancelExport()
        }
    }

    private static func legacyExport(_ box: SessionBox, to url: URL) async throws {
        box.session.outputURL = url
        box.session.outputFileType = .mov
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            box.session.exportAsynchronously {
                if box.session.status == .completed {
                    cont.resume()
                } else {
                    cont.resume(throwing: box.session.error ?? Failure.failed("Couldn't compress this video."))
                }
            }
        }
    }

    private struct SessionBox: @unchecked Sendable {
        let session: AVAssetExportSession
    }

    /// Adds a copy dated and located like the original.
    static func addCopy(of id: String, photo: Data? = nil, video: URL? = nil) async throws {
        guard let a = asset(id) else { throw Failure.missing }
        let date = a.creationDate
        let location = a.location
        let favorite = a.isFavorite
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                if let photo {
                    request.addResource(with: .photo, data: photo, options: nil)
                } else if let video {
                    let o = PHAssetResourceCreationOptions()
                    o.shouldMoveFile = true
                    request.addResource(with: .video, fileURL: video, options: o)
                }
                request.creationDate = date
                request.location = location
                request.isFavorite = favorite
            }
        } catch {
            throw Failure.failed(error.localizedDescription)
        }
    }

    /// iOS asks the user to confirm; deleted items go to Recently Deleted.
    static func delete(_ ids: [String]) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil))
        }
    }
}
