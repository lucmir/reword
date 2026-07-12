import XCTest
@testable import RewordCore

final class SmokeTests: XCTestCase {
    func testVersion() {
        XCTAssertEqual(RewordCore.version, "0.1.0")
    }
}
