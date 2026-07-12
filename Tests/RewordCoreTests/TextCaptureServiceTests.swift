import XCTest
@testable import RewordCore

final class FakeStrategy: TextCaptureStrategy {
    var captureResult: Result<String, CaptureError>
    var replaceError: CaptureError?
    /// Mirrors a well-behaved app: after a replace, reading the selection
    /// reflects the new text. Set false to model Chromium-style silent no-ops.
    var updatesCaptureOnReplace = true
    private(set) var captureCalls = 0
    private(set) var replacedWith: [String] = []

    init(capture: Result<String, CaptureError> = .success("text")) {
        self.captureResult = capture
    }

    func captureSelection() throws -> String {
        captureCalls += 1
        return try captureResult.get()
    }

    func replaceSelection(with text: String) throws {
        if let error = replaceError { throw error }
        replacedWith.append(text)
        if updatesCaptureOnReplace {
            captureResult = .success(text)
        }
    }
}

final class TextCaptureServiceTests: XCTestCase {
    func testUsesAccessibilityFirst() throws {
        let ax = FakeStrategy(capture: .success("from ax"))
        let clip = FakeStrategy(capture: .success("from clipboard"))
        let service = TextCaptureService(accessibility: ax, clipboard: clip)

        let captured = try service.captureSelection()

        XCTAssertEqual(captured, CapturedText(text: "from ax", method: .accessibility))
        XCTAssertEqual(clip.captureCalls, 0)
    }

    func testFallsBackToClipboardWhenAccessibilityFails() throws {
        let ax = FakeStrategy(capture: .failure(.strategyFailed))
        let clip = FakeStrategy(capture: .success("from clipboard"))
        let service = TextCaptureService(accessibility: ax, clipboard: clip)

        let captured = try service.captureSelection()

        XCTAssertEqual(captured, CapturedText(text: "from clipboard", method: .clipboard))
    }

    func testFallsBackWhenAccessibilityReturnsEmpty() throws {
        let ax = FakeStrategy(capture: .success(""))
        let clip = FakeStrategy(capture: .success("from clipboard"))
        let service = TextCaptureService(accessibility: ax, clipboard: clip)

        XCTAssertEqual(try service.captureSelection().method, .clipboard)
    }

    func testPropagatesNoSelectionWhenBothFail() {
        let ax = FakeStrategy(capture: .failure(.strategyFailed))
        let clip = FakeStrategy(capture: .failure(.noSelection))
        let service = TextCaptureService(accessibility: ax, clipboard: clip)

        XCTAssertThrowsError(try service.captureSelection()) { error in
            XCTAssertEqual(error as? CaptureError, .noSelection)
        }
    }

    func testReplaceUsesCaptureMethodStrategy() throws {
        let ax = FakeStrategy()
        let clip = FakeStrategy()
        let service = TextCaptureService(accessibility: ax, clipboard: clip)

        try service.replaceSelection(with: "new", using: .clipboard)

        XCTAssertEqual(clip.replacedWith, ["new"])
        XCTAssertEqual(ax.replacedWith, [])
    }

    func testReplaceFallsBackToClipboardWhenAccessibilityReplaceFails() throws {
        let ax = FakeStrategy()
        ax.replaceError = .strategyFailed
        let clip = FakeStrategy()
        let service = TextCaptureService(accessibility: ax, clipboard: clip)

        try service.replaceSelection(with: "new", using: .accessibility)

        XCTAssertEqual(clip.replacedWith, ["new"])
    }

    func testEmptyClipboardResultThrowsNoSelection() {
        let ax = FakeStrategy(capture: .failure(.strategyFailed))
        let clip = FakeStrategy(capture: .success(""))
        let service = TextCaptureService(accessibility: ax, clipboard: clip)

        XCTAssertThrowsError(try service.captureSelection()) { error in
            XCTAssertEqual(error as? CaptureError, .noSelection)
        }
    }

    func testReplaceViaAccessibilitySucceedsWithoutFallback() throws {
        let ax = FakeStrategy()
        let clip = FakeStrategy()
        let service = TextCaptureService(accessibility: ax, clipboard: clip)

        try service.replaceSelection(with: "new", using: .accessibility)

        XCTAssertEqual(ax.replacedWith, ["new"])
        XCTAssertEqual(clip.replacedWith, [])
    }

    func testSilentlyIgnoredAXReplaceFallsBackToClipboard() throws {
        // Chromium apps (Slack, Chrome/Gmail) return success for AX selected-text
        // writes without applying them — the selection still holds the old text.
        let ax = FakeStrategy(capture: .success("old text"))
        ax.updatesCaptureOnReplace = false
        let clip = FakeStrategy()
        let service = TextCaptureService(accessibility: ax, clipboard: clip)

        try service.replaceSelection(with: "new", using: .accessibility)

        XCTAssertEqual(ax.replacedWith, ["new"], "AX write should still be attempted first")
        XCTAssertEqual(clip.replacedWith, ["new"], "no-op AX write must fall back to paste")
    }

    func testVerifiedAXReplaceDoesNotFallBack() throws {
        let ax = FakeStrategy(capture: .success("old text"))
        let clip = FakeStrategy()
        let service = TextCaptureService(accessibility: ax, clipboard: clip)

        try service.replaceSelection(with: "new", using: .accessibility)

        XCTAssertEqual(ax.replacedWith, ["new"])
        XCTAssertEqual(clip.replacedWith, [])
    }

    func testPermissionDeniedPropagatesWithoutClipboardFallback() {
        let ax = FakeStrategy(capture: .failure(.permissionDenied))
        let clip = FakeStrategy(capture: .success("from clipboard"))
        let service = TextCaptureService(accessibility: ax, clipboard: clip)

        XCTAssertThrowsError(try service.captureSelection()) { error in
            XCTAssertEqual(error as? CaptureError, .permissionDenied)
        }
        XCTAssertEqual(clip.captureCalls, 0)
    }
}
