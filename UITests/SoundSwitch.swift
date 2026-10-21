import XCTest

/// The sound switch: remembered across a launch, and off meaning no cue at all.
///
/// **Two launches.** The first turns the switch off in settings. The second is
/// a relaunch that taps two tiles before anyone touches it: the switch must
/// still read off, and no cue must have been handed to the player.
///
/// `-exposeSound 1` lists the cues handed over, after the switch's check, so a
/// cue that reached the player would be listed. Shown red first by playing one
/// anyway: with the check removed, the second launch listed "tick,tick".
final class SoundSwitch: XCTestCase {
    private func openSettings(_ app: XCUIApplication, file: StaticString = #filePath,
                              line: UInt = #line) -> XCUIElement {
        let link = app.buttons["TitleSettings"]
        XCTAssertTrue(link.waitForExistence(timeout: 30), "no settings on the title",
                      file: file, line: line)
        link.tap()
        let toggle = app.switches["SettingsSound"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10), "no sound switch in settings",
                      file: file, line: line)
        return toggle
    }

    private func isOn(_ toggle: XCUIElement) -> Bool {
        (toggle.value as? String) == "1"
    }

    func testAMuteIsRememberedAndPlaysNothing() {
        let app = XCUIApplication()
        app.launchArguments = ["-showTitle", "1", "-resetProgress", "1",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()
        var toggle = openSettings(app)
        XCTAssertTrue(isOn(toggle), "sound is not on by default")
        // The switch's own knob, at the row's trailing end: a tap on the
        // label's text does not always reach a SwiftUI toggle.
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        XCTAssertFalse(isOn(toggle), "the switch did not turn off")
        app.terminate()

        // The same day, so the relaunch opens on the board; the peach goes back
        // to the title and its settings.
        app.launchArguments = ["-showTitle", "1", "-exposeSound", "1", "-tapTiles", "0,1",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()
        let home = app.buttons["BoardHome"]
        XCTAssertTrue(home.waitForExistence(timeout: 30), "the relaunch did not open on the board")
        home.tap()
        toggle = openSettings(app)
        XCTAssertFalse(isOn(toggle), "the mute was forgotten across a launch")

        let probe = app.staticTexts["DebugSound"]
        XCTAssertTrue(probe.waitForExistence(timeout: 30), "no sound probe")
        XCTAssertEqual(probe.label, "none",
                       "with sound off, cues still reached the player: \(probe.label)")
    }
}
