import Foundation

nonisolated struct AIImageJob: Sendable {
    enum Kind: Sendable { case erase, fill, restyle }
    var kind: Kind
    /// PNG of the photo region.
    var image: Data
    var imageSize: CGSize
    /// PNG, same size: transparent = area to change (OpenAI convention). Nil for whole-image jobs.
    var alphaMask: Data?
    /// PNG of the photo with the area to change painted red, for vendors without mask input.
    var highlighted: Data?
    var prompt: String
}

nonisolated struct AIError: LocalizedError, Sendable {
    var vendor: AIVendor
    var status: Int?
    var code: String?
    var message: String

    /// Retryable on another key: auth, quota, rate limit, server or network trouble.
    var shouldFallback: Bool {
        guard let status else { return true }
        return status == 401 || status == 403 || status == 429 || status >= 500
    }

    var isAuth: Bool { status == 401 || status == 403 }

    var errorDescription: String? {
        if isAuth { return "\(vendor.shortName) rejected the key (\(status!))." }
        if status == 429 { return "\(vendor.shortName) rate limited this key (429)." }
        if status == nil { return "Couldn't reach \(vendor.shortName)." }
        return "\(vendor.shortName) said: \(code ?? message) (\(status!))"
    }

    /// Short form for the key's row in Settings.
    var rowSummary: String {
        if let status { return "\(code ?? (isAuth ? "Rejected" : "Error")) (\(status))" }
        return "Network error"
    }
}

nonisolated protocol AIImageClient: Sendable {
    /// A cheap request that proves the key works.
    func test(key: String) async throws
    func run(_ job: AIImageJob, key: String) async throws -> Data
}

nonisolated enum HTTP {
    static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 180
        config.timeoutIntervalForResource = 240
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    static func send(_ request: URLRequest, vendor: AIVendor) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let e as URLError where e.code == .cancelled {
            throw CancellationError()
        } catch {
            throw AIError(vendor: vendor, status: nil, code: nil, message: error.localizedDescription)
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let (code, message) = parseError(data)
            throw AIError(vendor: vendor, status: status, code: code, message: message ?? HTTPURLResponse.localizedString(forStatusCode: status))
        }
        return data
    }

    /// Both vendors use {"error": {"code"/"status", "message"}}.
    private static func parseError(_ data: Data) -> (String?, String?) {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let err = obj["error"] as? [String: Any] else { return (nil, nil) }
        let code = (err["code"] as? String) ?? (err["status"] as? String) ?? (err["type"] as? String)
        return (code, err["message"] as? String)
    }
}

nonisolated struct MultipartForm {
    let boundary = "Boundary-\(UUID().uuidString)"
    private(set) var body = Data()

    mutating func field(_ name: String, _ value: String) {
        body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n".data(using: .utf8)!)
    }

    mutating func file(_ name: String, filename: String, mime: String, data: Data) {
        body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\nContent-Type: \(mime)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n".data(using: .utf8)!)
    }

    func finalized() -> Data {
        body + "--\(boundary)--\r\n".data(using: .utf8)!
    }
}

// MARK: - OpenAI

nonisolated struct OpenAIImageClient: AIImageClient {
    let base = URL(string: "https://api.openai.com/v1")!

    func test(key: String) async throws {
        var req = URLRequest(url: base.appendingPathComponent("models/\(AIVendor.openAI.imageModel)"))
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        _ = try await HTTP.send(req, vendor: .openAI)
    }

    func run(_ job: AIImageJob, key: String) async throws -> Data {
        var form = MultipartForm()
        form.field("model", AIVendor.openAI.imageModel)
        form.field("prompt", job.prompt)
        form.field("n", "1")
        form.field("size", Self.size(for: job.imageSize))
        form.field("quality", "high")
        form.field("input_fidelity", "high")
        form.file("image", filename: "image.png", mime: "image/png", data: job.image)
        if let mask = job.alphaMask {
            form.file("mask", filename: "mask.png", mime: "image/png", data: mask)
        }
        var req = URLRequest(url: base.appendingPathComponent("images/edits"))
        req.httpMethod = "POST"
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.setValue("multipart/form-data; boundary=\(form.boundary)", forHTTPHeaderField: "Content-Type")
        req.httpBody = form.finalized()
        let data = try await HTTP.send(req, vendor: .openAI)
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let first = (obj["data"] as? [[String: Any]])?.first,
              let b64 = first["b64_json"] as? String,
              let png = Data(base64Encoded: b64) else {
            throw AIError(vendor: .openAI, status: 200, code: "bad_response", message: "No image in the response.")
        }
        return png
    }

    /// The API's fixed sizes; the caller letterboxes to the same aspect.
    static func size(for s: CGSize) -> String {
        let aspect = s.width / s.height
        if aspect > 1.2 { return "1536x1024" }
        if aspect < 0.83 { return "1024x1536" }
        return "1024x1024"
    }

    static func canvasSize(for s: CGSize) -> CGSize {
        let parts = size(for: s).split(separator: "x").compactMap { Double($0) }
        return CGSize(width: parts[0], height: parts[1])
    }
}

// MARK: - Gemini

nonisolated struct GeminiImageClient: AIImageClient {
    let base = URL(string: "https://generativelanguage.googleapis.com/v1beta")!

    func test(key: String) async throws {
        var req = URLRequest(url: base.appendingPathComponent("models/\(AIVendor.gemini.imageModel)"))
        req.setValue(key, forHTTPHeaderField: "x-goog-api-key")
        _ = try await HTTP.send(req, vendor: .gemini)
    }

    func run(_ job: AIImageJob, key: String) async throws -> Data {
        let image = job.highlighted ?? job.image
        let prompt: String
        switch job.kind {
        case .erase:
            prompt = "Remove everything covered by the red highlighted area and fill it in so it blends naturally with the surroundings. "
                + "Remove the red highlight too. Keep every other pixel of the photo unchanged, with the same framing and size."
        case .fill:
            prompt = "In the red highlighted area only: \(job.prompt). Make it photorealistic and blend it with the lighting and texture of the photo. "
                + "Remove the red highlight. Keep every other pixel unchanged, with the same framing and size."
        case .restyle:
            prompt = job.prompt + " Keep the same framing and aspect ratio."
        }
        let body: [String: Any] = [
            "contents": [[
                "parts": [
                    ["text": prompt],
                    ["inline_data": ["mime_type": "image/png", "data": image.base64EncodedString()]],
                ],
            ]],
            "generationConfig": ["responseModalities": ["IMAGE"]],
        ]
        var req = URLRequest(url: base.appendingPathComponent("models/\(AIVendor.gemini.imageModel):generateContent"))
        req.httpMethod = "POST"
        req.setValue(key, forHTTPHeaderField: "x-goog-api-key")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let data = try await HTTP.send(req, vendor: .gemini)
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = obj["candidates"] as? [[String: Any]],
              let parts = (candidates.first?["content"] as? [String: Any])?["parts"] as? [[String: Any]] else {
            throw AIError(vendor: .gemini, status: 200, code: "bad_response", message: "No image in the response.")
        }
        for part in parts {
            let inline = (part["inlineData"] ?? part["inline_data"]) as? [String: Any]
            if let b64 = inline?["data"] as? String, let img = Data(base64Encoded: b64) {
                return img
            }
        }
        let reason = (candidates.first?["finishReason"] as? String) ?? "no_image"
        throw AIError(vendor: .gemini, status: 200, code: reason, message: "Gemini didn't return an image.")
    }
}
