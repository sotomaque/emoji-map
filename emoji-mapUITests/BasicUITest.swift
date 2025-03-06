import XCTest

final class BasicUITest: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAppLaunch() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssert(app.wait(for: .runningForeground, timeout: 5))
    }
} 