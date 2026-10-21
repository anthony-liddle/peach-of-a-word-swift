import XCTest

/// Each moment asks for the web's cue, or for none.
///
/// A simulator cannot say whether a sound was heard, so this holds the
/// moments to the cues they ask for: `-exposeSound 1` lists every cue asked
/// for since launch. Which cue a submit plays is the engine's, and
/// `CueChoiceTests` covers every branch of it; this covers the app's half,
/// that each moment asks, and the rows of the web's table that ask for
/// nothing. `OneBeatPerFind` holds the source word and completion to their
/// cues in the launches it already makes.
final class CueAtEachMoment: XCTestCase {
    private func launch(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-resetProgress", "1", "-exposeSound", "1"] + arguments
        app.launch()
        return app
    }

    private func asked(in app: XCUIApplication) -> String {
        let probe = app.staticTexts["DebugSound"]
        XCTAssertTrue(probe.waitForExistence(timeout: 30), "the app never exposed its cues")
        return probe.label
    }

    /// A tile placed ticks. A used tile, delete, shuffle and clear ask for
    /// nothing: the web disables used tiles, and plays nothing for the other
    /// three.
    func testATilePlacedTicksAndNothingElseOnTheRackSounds() {
        let app = launch([])
        let tiles = app.buttons.matching(NSPredicate(format: "label MATCHES %@", "^Letter [a-z]$"))
        XCTAssertTrue(tiles.firstMatch.waitForExistence(timeout: 30), "no rack tile found")

        tiles.firstMatch.tap()
        let used = app.buttons.matching(NSPredicate(format: "label ENDSWITH %@", ", already picked")).firstMatch
        XCTAssertTrue(used.waitForExistence(timeout: 5), "the tile never went on the stick")
        used.tap()
        tiles.firstMatch.tap()
        app.buttons["Delete last letter"].tap()
        app.buttons["Shuffle"].tap()
        app.buttons["Clear"].tap()

        XCTAssertEqual(asked(in: app), "tick,tick",
                       "two tiles placed should ask for two ticks, and nothing else on the rack for any")
    }

    /// Each of the three rejections plays `invalid`. `-guesses` submits two
    /// letters and then letters the rack does not have; `-seedBoard full`
    /// finds every set word, the source word among them, so `-findSource`
    /// submits a word already found.
    func testEachRejectionPlaysInvalid() {
        let app = launch(["-guesses", "ab,zzz", "-seedBoard", "full", "-findSource", "1"])
        XCTAssertEqual(asked(in: app), "invalid,invalid,invalid",
                       "too short, not from these letters and already found should each ask for invalid")
    }
}
