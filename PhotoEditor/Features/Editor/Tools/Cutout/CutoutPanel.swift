import CoreImage
import SwiftUI

struct CutoutPanel: View {
    let model: EditorModel
    @State private var instances: [Int]?

    var body: some View {
        ToolPanel {
            if let instances {
                if instances.isEmpty {
                    Text("No clear subject found. Try a photo with a person, pet or object.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                } else if let spec = model.document.cutout {
                    controls(spec, total: instances.count)
                }
            } else {
                ProgressView("Finding subjects…")
                    .font(.subheadline)
            }
        }
        .task {
            model.selectedLayerID = nil
            let session = model.session
            let found = await Self.analyze(session)
            instances = found
            if !found.isEmpty, model.document.cutout == nil {
                model.update { $0.cutout = CutoutSpec(subjects: found, background: .keep) }
                model.redraw()
            }
        }
    }

    @ViewBuilder
    private func controls(_ spec: CutoutSpec, total: Int) -> some View {
        HStack {
            Text(total > 1 ? "\(spec.subjects.count) of \(total) subjects · tap to toggle" : "1 subject found")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Copy as Sticker") { copyAsSticker(spec) }
                .font(.footnote.weight(.semibold))
        }
        .padding(.horizontal, 20)

        switch spec.background {
        case .blur:
            ValueSlider(title: "Blur", value: Binding(
                get: { spec.blur },
                set: { v in model.live { $0.cutout?.blur = v } }
            ), bipolar: false, onBegin: model.beginGesture, onEnd: model.endGesture)
            .padding(.horizontal, 20)
        case .color:
            ColorSwatches(color: Binding(get: { spec.color }, set: { c in model.update { $0.cutout?.color = c } }))
        default:
            EmptyView()
        }

        Segmented(options: CutoutSpec.Background.allCases, selection: Binding(
            get: { spec.background },
            set: { b in model.update { $0.cutout?.background = b } }
        )) { $0.rawValue.capitalized }
        .padding(.horizontal, 16)
    }

    @concurrent
    private static func analyze(_ session: RenderSession) async -> [Int] {
        session.cached("subjects") { SubjectAnalysis(cgImage: session.proxyCGImage) }.instances
    }

    private func copyAsSticker(_ spec: CutoutSpec) {
        let pipeline = model.pipeline()
        guard let mask = pipeline.subjectMask(spec) else { return }
        var doc = model.document
        doc.cutout = nil
        doc.layers = []
        let base = model.pipeline(doc).image()
        let outMask = pipeline.toOutput(mask)
        let cut = base.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: CIImage.clear.cropped(to: base.extent),
            kCIInputMaskImageKey: outMask,
        ])
        guard let w = AssetWriter.writeTrimmedPNG(cut, alphaSource: outMask, to: model.project.assetsURL) else { return }
        let ext = base.extent
        let center = CGPoint(x: (w.bounds.midX - ext.minX) / ext.width, y: 1 - (w.bounds.midY - ext.minY) / ext.height)
        model.addLayer(Layer(content: .image(asset: w.name, aspect: w.aspect), center: center, width: w.bounds.width / ext.width))
        model.showToast("Copied as a sticker layer")
    }
}
