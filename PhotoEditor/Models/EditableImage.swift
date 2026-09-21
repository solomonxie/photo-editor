import Foundation

struct EditableImage: Identifiable, Hashable {
    let id: UUID
    let assetIdentifier: String

    init(id: UUID = UUID(), assetIdentifier: String) {
        self.id = id
        self.assetIdentifier = assetIdentifier
    }
}
