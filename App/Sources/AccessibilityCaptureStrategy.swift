import AppKit
import ApplicationServices
import RewordCore

final class AccessibilityCaptureStrategy: TextCaptureStrategy {
    private func focusedElement() throws -> AXUIElement {
        guard AXIsProcessTrusted() else { throw CaptureError.permissionDenied }
        let systemWide = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(
            systemWide, kAXFocusedUIElementAttribute as CFString, &focusedRef
        )
        guard status == .success, let ref = focusedRef else { throw CaptureError.strategyFailed }
        return (ref as! AXUIElement)
    }

    func captureSelection() throws -> String {
        let element = try focusedElement()
        var selectedRef: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(
            element, kAXSelectedTextAttribute as CFString, &selectedRef
        )
        guard status == .success, let text = selectedRef as? String else {
            throw CaptureError.strategyFailed
        }
        return text
    }

    func replaceSelection(with text: String) throws {
        let element = try focusedElement()
        let status = AXUIElementSetAttributeValue(
            element, kAXSelectedTextAttribute as CFString, text as CFTypeRef
        )
        guard status == .success else { throw CaptureError.strategyFailed }
    }
}
