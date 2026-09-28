import CoreImage
import XCTest
@testable import PhotoEditor

final class EditDocumentTests: XCTestCase {
    private func sampleDoc() -> EditDocument {
        var doc = EditDocument(source: SourceInfo(filename: "original.heic", pixelWidth: 4032, pixelHeight: 3024))
        doc.smoothSkin = 40
        doc.beauty[.whiten] = 30
        doc.heal = [BrushStroke(points: [CGPoint(x: 0.4, y: 0.4), CGPoint(x: 0.42, y: 0.41)], radius: 0.01)]
        doc.cutout = CutoutSpec(subjects: [1, 2], background: .blur)
        doc.layers = [
            Layer(content: .image(asset: "a.png", aspect: 1.5)),
        ]
        return doc
    }

    func testRoundTrip() throws {
        let doc = sampleDoc()
        let data = try JSONEncoder().encode(doc)
        XCTAssertEqual(try JSONDecoder().decode(EditDocument.self, from: data), doc)
    }

    func testDecodesMissingKeysAsDefaults() throws {
        let json = #"{"source":{"filename":"o.jpg","pixelWidth":10,"pixelHeight":20},"futureKey":42}"#
        let doc = try JSONDecoder().decode(EditDocument.self, from: Data(json.utf8))
        XCTAssertTrue(doc.isUntouched)
    }

    func testDropsRemovedLayerKinds() throws {
        let json = #"{"source":{"filename":"o.jpg","pixelWidth":10,"pixelHeight":20},"layers":[{"id":"8E1B6C1A-6A3E-4C1B-9A43-2B8D5E7F0A11","content":{"emoji":{"_0":"🌴"}},"center":[0.5,0.5],"width":0.2,"rotation":0,"opacity":1,"isHidden":false},{"id":"8E1B6C1A-6A3E-4C1B-9A43-2B8D5E7F0A12","content":{"image":{"asset":"a.png","aspect":1.5}},"center":[0.5,0.5],"width":0.6,"rotation":0,"opacity":1,"isHidden":false}]}"#
        let doc = try JSONDecoder().decode(EditDocument.self, from: Data(json.utf8))
        XCTAssertEqual(doc.layers.map(\.content), [.image(asset: "a.png", aspect: 1.5)])
    }
}

final class EditHistoryTests: XCTestCase {
    func testGestureFoldsIntoOneStep() {
        var history = EditHistory()
        var doc = EditDocument(source: SourceInfo(filename: "o.jpg", pixelWidth: 10, pixelHeight: 10))
        let original = doc
        history.beginGesture(doc)
        for v in stride(from: 1.0, through: 40, by: 1) {
            doc.smoothSkin = v
            history.record(doc) // ignored during a gesture
        }
        history.endGesture(doc)
        XCTAssertEqual(history.undoStack.count, 1)
        let undone = history.undo(doc)
        XCTAssertEqual(undone, original)
        XCTAssertEqual(history.redo(original), doc)
    }

    func testNewEditClearsRedo() {
        var history = EditHistory()
        var doc = EditDocument(source: SourceInfo(filename: "o.jpg", pixelWidth: 10, pixelHeight: 10))
        history.record(doc)
        doc.smoothSkin = 10
        _ = history.undo(doc)
        XCTAssertTrue(history.canRedo)
        history.record(doc)
        XCTAssertFalse(history.canRedo)
    }

    func testLimit() {
        var history = EditHistory(limit: 3)
        let doc = EditDocument(source: SourceInfo(filename: "o.jpg", pixelWidth: 10, pixelHeight: 10))
        for _ in 0..<10 { history.record(doc) }
        XCTAssertEqual(history.undoStack.count, 3)
    }
}

final class RenderTests: XCTestCase {
    private func render(_ doc: EditDocument, source: CIImage) throws -> [Float] {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("t-\(UUID()).png")
        try RenderEngine.context.writePNGRepresentation(of: source, to: url, format: .RGBA8, colorSpace: RenderEngine.outputSpace)
        let session = try RenderSession(originalURL: url, assetsURL: FileManager.default.temporaryDirectory, proxyMaxPixel: 64)
        let out = RenderPipeline(session: session, document: doc, source: session.proxy).image()
        var px = [Float](repeating: 0, count: 4)
        let center = CGRect(x: out.extent.midX, y: out.extent.midY, width: 1, height: 1)
        RenderEngine.context.render(out, toBitmap: &px, rowBytes: 16, bounds: center, format: .RGBAf, colorSpace: RenderEngine.outputSpace)
        return px
    }

    private var gray: CIImage {
        CIImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.5)).cropped(to: CGRect(x: 0, y: 0, width: 64, height: 48))
    }

    private var doc: EditDocument {
        EditDocument(source: SourceInfo(filename: "t.png", pixelWidth: 64, pixelHeight: 48))
    }

    func testIdentityIsNoOp() throws {
        let px = try render(doc, source: gray)
        XCTAssertEqual(px[0], 0.5, accuracy: 0.02)
    }
}

final class WarpTests: XCTestCase {
    /// Uniform field pulling from 0.25 above: the white top half must move down.
    func testTranslationDirection() throws {
        let w: CGFloat = 64, h: CGFloat = 64
        let white = CIImage(color: .white).cropped(to: CGRect(x: 0, y: h / 2, width: w, height: h / 2))
        let img = white.composited(over: CIImage(color: .black).cropped(to: CGRect(x: 0, y: 0, width: w, height: h)))
        var field = WarpField(aspect: 1, longEdge: 16)
        for i in field.dy.indices { field.dy[i] = 0.25 }
        let out = try WarpProcessor.apply(withExtent: img.extent, inputs: [img, field.image(size: img.extent.size)],
                                          arguments: ["width": w, "height": h, "margin": 20])
        var px = [Float](repeating: 0, count: 4)
        // Top-left y = 0.6 → CI y = 0.4h: was black, should now be white.
        RenderEngine.context.render(out, toBitmap: &px, rowBytes: 16, bounds: CGRect(x: 32, y: 0.4 * h, width: 1, height: 1),
                                    format: .RGBAf, colorSpace: nil)
        XCTAssertGreaterThan(px[0], 0.9, "\(px)")
        // Top-left y = 0.9 → still black.
        RenderEngine.context.render(out, toBitmap: &px, rowBytes: 16, bounds: CGRect(x: 32, y: 0.1 * h, width: 1, height: 1),
                                    format: .RGBAf, colorSpace: nil)
        XCTAssertLessThan(px[0], 0.1, "\(px)")
    }

    func testReshapeDocumentRoundTrips() throws {
        var doc = EditDocument(source: SourceInfo(filename: "o.jpg", pixelWidth: 10, pixelHeight: 10))
        doc.reshape.face[.eyes] = 30
        doc.reshape.body[.waist] = 40
        doc.reshape.manual = [ManualWarp(kind: .push, center: CGPoint(x: 0.5, y: 0.5), vector: CGVector(dx: 0.01, dy: 0), radius: 0.1)]
        doc.redEye = true
        XCTAssertEqual(try JSONDecoder().decode(EditDocument.self, from: JSONEncoder().encode(doc)), doc)
    }
}

final class AIErrorTests: XCTestCase {
    func testGeminiBadKeyIsAuth() {
        let body = #"{"error":{"code":400,"message":"API key not valid.","status":"INVALID_ARGUMENT","details":[{"reason":"API_KEY_INVALID"}]}}"#
        let (code, message) = HTTP.parseError(Data(body.utf8))
        let e = AIError(vendor: .gemini, status: 400, code: code, message: message ?? "")
        XCTAssertTrue(e.isAuth)
        XCTAssertTrue(e.shouldFallback)
    }

    func testOpenAIBadKeyIsAuth() {
        let body = #"{"error":{"message":"Incorrect API key","type":"invalid_request_error","code":"invalid_api_key"}}"#
        let (code, _) = HTTP.parseError(Data(body.utf8))
        XCTAssertEqual(code, "invalid_api_key")
        XCTAssertTrue(AIError(vendor: .openAI, status: 401, code: code, message: "").isAuth)
    }

    func testBadRequestDoesNotFallBack() {
        XCTAssertFalse(AIError(vendor: .openAI, status: 400, code: "invalid_value", message: "").shouldFallback)
    }
}

final class MediaCompressorTests: XCTestCase {
    private func noisyJPEG(width: Int, height: Int) throws -> Data {
        let noise = CIFilter(name: "CIRandomGenerator")!.outputImage!.cropped(to: CGRect(x: 0, y: 0, width: width, height: height))
        let cg = try XCTUnwrap(CIContext().createCGImage(noise, from: noise.extent))
        let out = NSMutableData()
        let dest = try XCTUnwrap(CGImageDestinationCreateWithData(out, "public.jpeg" as CFString, 1, nil))
        let exif: [CFString: Any] = [kCGImagePropertyExifDateTimeOriginal: "2024:05:01 10:00:00"]
        CGImageDestinationAddImage(dest, cg, [kCGImagePropertyExifDictionary: exif, kCGImageDestinationLossyCompressionQuality: 0.95] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(dest))
        return out as Data
    }

    func testShrinksAndKeepsMetadata() throws {
        let data = try noisyJPEG(width: 3000, height: 2000)
        let out = try MediaCompressor.photo(data, maxEdge: ExportSize.hd.maxLongEdge, quality: .medium)
        XCTAssertLessThan(out.count, data.count / 2)
        let src = try XCTUnwrap(CGImageSourceCreateWithData(out as CFData, nil))
        let props = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any])
        XCTAssertEqual(props[kCGImagePropertyPixelWidth] as? Int, 1280)
        XCTAssertEqual(props[kCGImagePropertyPixelHeight] as? Int, 853)
        let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any]
        XCTAssertEqual(exif?[kCGImagePropertyExifDateTimeOriginal] as? String, "2024:05:01 10:00:00")
    }

    func testNeverUpscales() throws {
        let data = try noisyJPEG(width: 800, height: 600)
        let out = try MediaCompressor.photo(data, maxEdge: ExportSize.uhd.maxLongEdge, quality: .high)
        let src = try XCTUnwrap(CGImageSourceCreateWithData(out as CFData, nil))
        let props = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any])
        XCTAssertEqual(props[kCGImagePropertyPixelWidth] as? Int, 800)
    }
}
