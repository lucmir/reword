import AppKit
import Carbon.HIToolbox
import RewordCore

final class ClipboardCaptureStrategy: TextCaptureStrategy {
    private let pasteboard = NSPasteboard.general

    private typealias PasteboardSnapshot = [[NSPasteboard.PasteboardType: Data]]

    func captureSelection() throws -> String {
        let saved = snapshot()
        defer { restore(saved) }

        let countBefore = pasteboard.changeCount
        postKeystroke(virtualKey: CGKeyCode(kVK_ANSI_C))
        guard waitForChange(from: countBefore) else { throw CaptureError.noSelection }
        guard let text = pasteboard.string(forType: .string), !text.isEmpty else {
            throw CaptureError.noSelection
        }
        return text
    }

    func replaceSelection(with text: String) throws {
        let saved = snapshot()
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        let pasteChangeCount = pasteboard.changeCount
        postKeystroke(virtualKey: CGKeyCode(kVK_ANSI_V))
        // Restore after the paste has had time to land. Captures by value —
        // must fire even if this strategy instance is gone.
        let pasteboard = self.pasteboard
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Skip restore if something else has since written to the pasteboard.
            guard pasteboard.changeCount == pasteChangeCount else { return }
            Self.restore(saved, on: pasteboard)
        }
    }

    private func snapshot() -> PasteboardSnapshot {
        (pasteboard.pasteboardItems ?? []).map { item in
            var entry: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    entry[type] = data
                }
            }
            return entry
        }
    }

    private func restore(_ saved: PasteboardSnapshot) {
        Self.restore(saved, on: pasteboard)
    }

    private static func restore(_ saved: PasteboardSnapshot, on pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        let items = saved.map { entry -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in entry {
                item.setData(data, forType: type)
            }
            return item
        }
        if !items.isEmpty {
            pasteboard.writeObjects(items)
        }
    }

    private func postKeystroke(virtualKey: CGKeyCode) {
        let source = CGEventSource(stateID: .combinedSessionState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    private func waitForChange(from count: Int, timeout: TimeInterval = 0.6) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if pasteboard.changeCount != count { return true }
            usleep(20_000)
        }
        return false
    }
}
