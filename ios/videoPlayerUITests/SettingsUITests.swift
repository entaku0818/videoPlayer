//
//  SettingsUITests.swift
//  videoPlayerUITests
//

import XCTest

final class SettingsUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// 設定画面のバックグラウンド再生トグルが保存され、再起動後も維持されること
    func testBackgroundPlaybackTogglePersists() throws {
        let app = XCUIApplication()
        app.launch()

        let toggle = openSettings(app)
        XCTAssertEqual(toggle.value as? String, "1", "既定はON")

        tapSwitch(toggle)
        XCTAssertEqual(toggle.value as? String, "0")

        app.terminate()
        app.launch()
        let relaunched = openSettings(app)
        XCTAssertEqual(relaunched.value as? String, "0", "再起動後もOFFが維持される")

        // 後続テストのため ON に戻す
        tapSwitch(relaunched)
        XCTAssertEqual(relaunched.value as? String, "1")
    }

    private func openSettings(_ app: XCUIApplication) -> XCUIElement {
        app.tabBars.buttons["IPTV"].tap()
        app.navigationBars.buttons["設定"].tap()
        let toggle = app.switches["backgroundPlaybackToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        return toggle
    }

    private func tapSwitch(_ toggle: XCUIElement) {
        // Form 内の Toggle は行全体ではなくスイッチ部分をタップする
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
    }
}
