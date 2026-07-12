import Foundation

public protocol TextCaptureStrategy {
    func captureSelection() throws -> String
    func replaceSelection(with text: String) throws
}

public enum CaptureError: Error, Equatable {
    case noSelection
    case strategyFailed
    case permissionDenied
}

public enum CaptureMethod: Equatable {
    case accessibility
    case clipboard
}

public struct CapturedText: Equatable {
    public let text: String
    public let method: CaptureMethod

    public init(text: String, method: CaptureMethod) {
        self.text = text
        self.method = method
    }
}

public final class TextCaptureService {
    private let accessibility: TextCaptureStrategy
    private let clipboard: TextCaptureStrategy

    public init(accessibility: TextCaptureStrategy, clipboard: TextCaptureStrategy) {
        self.accessibility = accessibility
        self.clipboard = clipboard
    }

    public func captureSelection() throws -> CapturedText {
        do {
            let text = try accessibility.captureSelection()
            if !text.isEmpty {
                return CapturedText(text: text, method: .accessibility)
            }
        } catch CaptureError.permissionDenied {
            throw CaptureError.permissionDenied
        } catch {
            // fall through to clipboard
        }
        let text = try clipboard.captureSelection()
        guard !text.isEmpty else { throw CaptureError.noSelection }
        return CapturedText(text: text, method: .clipboard)
    }

    public func replaceSelection(with text: String, using method: CaptureMethod) throws {
        switch method {
        case .clipboard:
            try clipboard.replaceSelection(with: text)
        case .accessibility:
            do {
                try accessibility.replaceSelection(with: text)
            } catch {
                try clipboard.replaceSelection(with: text)
            }
        }
    }
}
