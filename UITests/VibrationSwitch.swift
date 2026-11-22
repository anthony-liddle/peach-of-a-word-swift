import XCTest

/// The Vibration switch in Settings: on by default, and an off remembered
/// across a launch.
///
/// What off does is `FeelTests`' to hold, in the unit suite, with a stand-in
/// for the haptics a simulator doesn't have. This holds the switch to the key
/// `Feel` reads: a switch writing anywhere else would leave every haptic on.
final class VibrationSwitch: XCTestCase {
    private func openSettings(_ app: XCUIApplication, file: StaticString = #filePath,
                              line: UInt = #line) -> XCUIElement {
        let link = app.buttons["TitleSettings"]
        XCTAssertTrue(link.waitForExistence(timeout: 30), "no settings on the title",
                      file: file, line: line)
        link.tap()
        let toggle = app.switches["SettingsVibration"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10), "no vibration switch in settings",
                      file: file, line: line)
        return toggle
    }

    private func isOn(_ toggle: XCUIElement) -> Bool {
        (toggle.value as? String) == "1"
    }

    func testOnByDefaultAndAnOffIsRemembered() {
        let app = XCUIApplication()
        app.launchArguments = ["-showTitle", "1", "-resetProgress", "1",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()
        var toggle = openSettings(app)
        XCTAssertEqual(toggle.label, "Vibration", "the switch isn't named Vibration")
        XCTAssertTrue(isOn(toggle), "vibration is not on by default")
        // The switch's own knob, at the row's trailing end, as `SoundSwitch`
        // taps Sound's: a tap on the label's text does not always reach a
        // SwiftUI toggle.
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        XCTAssertFalse(isOn(toggle), "the switch did not turn off")
        app.terminate()

        // The same day, left on the title, so the relaunch reopens there.
        app.launchArguments = ["-showTitle", "1",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()
        toggle = openSettings(app)
        XCTAssertFalse(isOn(toggle), "the off was forgotten across a launch")
    }
}
