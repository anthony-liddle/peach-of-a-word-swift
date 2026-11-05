import XCTest

/// What a player is shown when the game can't start.
///
/// The screen used to say "Could not start" over the reason, such as "the
/// daily calendar is empty", which no player can act on. It now says what to
/// do, and the reason goes to the log. `-failStart 1` fails the start, since no
/// launch can break the shipped word lists. Shown red first against the old
/// screen.
final class AStartThatFails: XCTestCase {
    func testItSaysWhatToDoAndLeavesTheReasonToTheLog() {
        let app = XCUIApplication()
        app.launchArguments = ["-failStart", "1"]
        app.launch()

        XCTAssertTrue(app.staticTexts["The word lists didn't load"].waitForExistence(timeout: 30),
                      "the failed start does not say the word lists didn't load")
        XCTAssertTrue(app.staticTexts["Close Peach of a Word and open it again."].exists,
                      "the failed start does not say what to do")
        let reason = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "-failStart"))
        XCTAssertEqual(reason.count, 0, "the reason reached the screen: \(reason.firstMatch.label)")
    }
}
