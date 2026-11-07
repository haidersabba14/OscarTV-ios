import XCTest

final class RemoteInterfaceTests: XCTestCase {
    @MainActor
    func testPhysicalDirectionsAndOriginalActions() {
        let app = XCUIApplication()
        app.launchArguments = ["--capture-remote", "--ui-test"]
        app.launch()
        let dial = app.otherElements["directional-dial"]
        XCTAssertTrue(dial.waitForExistence(timeout: 10))
        let result = app.staticTexts["captured-command"]
        for (x, y, command) in [(0.865, 0.5, "RIGHT"), (0.135, 0.5, "LEFT"), (0.5, 0.135, "UP"), (0.5, 0.865, "DOWN"), (0.5, 0.5, "OK")] {
            dial.coordinate(withNormalizedOffset: CGVector(dx: x, dy: y)).tap()
            XCTAssertEqual(result.label, command)
        }
        app.buttons["الرئيسية"].tap()
        XCTAssertEqual(result.label, "HOME")
        app.buttons["رجوع"].tap()
        XCTAssertEqual(result.label, "BACK")
        app.buttons["الإعدادات"].tap()
        XCTAssertEqual(result.label, "SETTINGS")
    }

    @MainActor
    func testNumbersKeepReceiverCapabilityGates() {
        let app = XCUIApplication()
        app.launchArguments = ["--capture-remote", "--ui-test"]
        app.launch()
        app.buttons["tab-number"].tap()
        XCTAssertTrue(app.buttons["1"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["1"].isEnabled)
        XCTAssertFalse(app.buttons["القناة السابقة"].isEnabled)
        XCTAssertFalse(app.buttons["القناة التالية"].isEnabled)
    }

    @MainActor
    func testConnectionAndUnpairRemainAvailable() {
        let app = XCUIApplication()
        app.launchArguments = ["--capture-remote", "--ui-test"]
        app.launch()
        app.buttons["tab-wifi"].tap()
        XCTAssertTrue(app.buttons["تحديث الاتصال"].waitForExistence(timeout: 5))
        app.buttons["إلغاء الاقتران"].tap()
        XCTAssertTrue(app.textFields["عنوان IP للرسيفر"].waitForExistence(timeout: 5))
        let pair = app.buttons["اقتران بالرسيفر"]
        app.swipeUp()
        XCTAssertTrue(pair.waitForExistence(timeout: 5))
        XCTAssertFalse(pair.isEnabled)
    }
}
