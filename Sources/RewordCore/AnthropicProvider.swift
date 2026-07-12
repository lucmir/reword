import Foundation

public final class AnthropicProvider: AIProvider {
    private let session: URLSession
    private let apiKey: () -> String?
    private let model: () -> String
    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    public init(session: URLSession = .shared,
                apiKey: @escaping () -> String?,
                model: @escaping () -> String) {
        self.session = session
        self.apiKey = apiKey
        self.model = model
    }

    private struct RequestBody: Encodable {
        struct Message: Encodable {
            let role: String
            let content: String
        }
        let model: String
        let max_tokens: Int
        let system: String
        let messages: [Message]
    }

    private struct ResponseBody: Decodable {
        struct Block: Decodable {
            let type: String
            let text: String?
        }
        let content: [Block]
    }

    public func transform(text: String, prompt: String) async throws -> String {
        guard let key = apiKey(), !key.isEmpty else { throw AIError.missingAPIKey }

        var request = URLRequest(url: Self.endpoint, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(RequestBody(
            model: model(),
            max_tokens: 16000,
            system: prompt,
            messages: [.init(role: "user", content: text)]
        ))

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AIError.network
        }

        guard let http = response as? HTTPURLResponse else { throw AIError.network }
        switch http.statusCode {
        case 200:
            break
        case 401, 403:
            throw AIError.authenticationFailed
        case 429:
            throw AIError.rateLimited
        case 400..<500:
            throw AIError.badRequest
        default:
            throw AIError.serverError
        }

        guard let decoded = try? JSONDecoder().decode(ResponseBody.self, from: data),
              let text = decoded.content.first(where: { $0.type == "text" })?.text else {
            throw AIError.invalidResponse
        }
        return text
    }
}
