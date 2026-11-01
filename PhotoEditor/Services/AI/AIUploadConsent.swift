import SwiftUI

struct AIUploadConsent: ViewModifier {
    static let key = "aiUploadConsent"
    @Binding var isPresented: Bool
    let vendors: [AIVendor]
    let onSend: () -> Void
    @AppStorage(Self.key) private var granted = false

    func body(content: Content) -> some View {
        content.alert("Send this photo to \(names)?", isPresented: $isPresented) {
            Button("Send") {
                granted = true
                onSend()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("AI tools upload this photo and your request to \(names) with your own API key, under that provider's privacy policy. All other tools stay on this device.")
        }
    }

    private var names: String {
        var seen = Set<AIVendor>()
        let unique = vendors.filter { seen.insert($0).inserted }
        return unique.isEmpty ? "the AI provider" : unique.map(\.name).joined(separator: " or ")
    }
}

extension View {
    func aiUploadConsent(isPresented: Binding<Bool>, vendors: [AIVendor], onSend: @escaping () -> Void) -> some View {
        modifier(AIUploadConsent(isPresented: isPresented, vendors: vendors, onSend: onSend))
    }
}
