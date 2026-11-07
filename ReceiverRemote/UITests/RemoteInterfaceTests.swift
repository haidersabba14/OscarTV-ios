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
        app.swipeUp()
        app.buttons["الرئيسية"].tap()
        XCTAssertEqual(result.label, "HOME")
        app.buttons["رجوع"].tap()
        XCTAssertEqual(result.label, "BACK")
        app.buttons["الإعدادات"].tap()
        XCTAssertEqual(result.label, "OPEN_IPTV_SMARTERS_PRO")
    }

    @MainActor
    func testLegacyReceiverShowsIPTVUpdateRequirement() {
        let app = XCUIApplication()
        app.launchArguments = ["--capture-remote"]
        app.launch()
        XCTAssertTrue(app.buttons["الإعدادات"].waitForExistence(timeout: 10))
        app.swipeUp()
        app.buttons["الإعدادات"].tap()
        XCTAssertTrue(app.staticTexts["فتح IPTV Smarters Pro يحتاج تحديث خدمة التحكم على الرسيفر"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testNumberPadIsRemovedAndPreferencesPersist() {
        let app = XCUIApplication()
        app.launchArguments = ["--capture-remote", "--ui-test"]
        app.launch()
        XCTAssertFalse(app.buttons["tab-number"].exists)
        app.buttons["tab-slider.horizontal.3"].tap()
        let haptics = app.switches["preference-haptics"]
        XCTAssertTrue(haptics.waitForExistence(timeout: 5))
        let oldValue = haptics.value as? String
        haptics.tap()
        let changedValue = haptics.value as? String
        XCTAssertNotEqual(changedValue, oldValue)
        app.terminate()
        app.launch()
        app.buttons["tab-slider.horizontal.3"].tap()
        XCTAssertTrue(haptics.waitForExistence(timeout: 5))
        XCTAssertEqual(haptics.value as? String, changedValue)
        haptics.tap()
        XCTAssertFalse(app.buttons["1"].exists)
        XCTAssertTrue(app.buttons["اختبار الاتصال"].exists)
    }

    @MainActor
    func testVolumeHoldUsesRepeatedCommands() {
        let app = XCUIApplication()
        app.launchArguments = ["--capture-remote", "--ui-test"]
        app.launch()
        app.swipeUp()
        let volumeUp = app.buttons["رفع الصوت"]
        XCTAssertTrue(volumeUp.waitForExistence(timeout: 5))
        volumeUp.press(forDuration: 1.2)
        let result = app.staticTexts["captured-command"]
        XCTAssertEqual(result.label, "VOLUME_UP")
        XCTAssertGreaterThanOrEqual(Int(result.value as? String ?? "0") ?? 0, 2)
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
