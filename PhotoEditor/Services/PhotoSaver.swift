import Photos
import UIKit

enum PhotoSaver {
    enum Failure: LocalizedError {
        case denied, failed(String)

        var errorDescription: String? {
            switch self {
            case .denied: "Photo Editor isn't allowed to add photos."
            case .failed(let m): m
            }
        }
    }

    static func save(_ data: Data) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { throw Failure.denied }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.forAsset().addResource(with: .photo, data: data, options: nil)
            }
        } catch {
            throw Failure.failed(error.localizedDescription)
        }
    }

    static func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

enum AppSettings {
    static let exportFormatKey = "export.format"
    static let keepLocationKey = "export.keepLocation"
}
