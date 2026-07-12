import Foundation

public protocol AIProvider {
    func transform(text: String, prompt: String) async throws -> String
}

public enum AIError: Error, Equatable {
    case missingAPIKey
    case authenticationFailed
    case rateLimited
    case badRequest
    case serverError
    case network
    case invalidResponse

    public var userMessage: String {
        switch self {
        case .missingAPIKey: "No API key configured. Add one in Settings → API."
        case .authenticationFailed: "API key rejected. Check it in Settings → API."
        case .rateLimited: "Rate limited by the API. Try again in a moment."
        case .badRequest: "The API rejected the request."
        case .serverError: "The API had a server error. Try again."
        case .network: "Network error. Check your connection."
        case .invalidResponse: "Received an unexpected response from the API."
        }
    }
}
