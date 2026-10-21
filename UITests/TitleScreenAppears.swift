import XCTest

/// When the title screen appears, and where its week goes.
///
/// **Two launches cover the rule.** The first is a fresh install, which sees
/// the title. The second is the same day, which opens on the board; it then
/// comes back across midnight, where the title appears again, and a past day
/// on the week opens that day's board.
///
/// `-showTitle 1` opts these launches in: every seeded or reset launch starts
/// on the board, as the tests written before the title expect.
final class TitleScreenAppears: XCTestCase {
    private func tile(_ app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label MATCHES %@", "^Letter [a-z].*")).firstMatch
    }

    /// Play becomes tappable once the board is ready, and not before.
    private func waitForPlay(_ app: XCUIApplication, file: StaticString = #filePath,
                             line: UInt = #line) -> XCUIElement {
        let play = app.buttons["TitlePlay"]
        XCTAssertTrue(play.waitForExistence(timeout: 30), "no title screen", file: file, line: line)
        let enabled = NSPredicate(format: "isEnabled == true")
        let wait = expectation(for: enabled, evaluatedWith: play)
        XCTAssertEqual(XCTWaiter().wait(for: [wait], timeout: 30), .completed,
                       "Play never became tappable", file: file, line: line)
        return play
    }

    func testTheFirstLaunchAndEachNewDayOpenOnTheTitle() {
        // A fresh install: the title, with nothing started.
        let app = XCUIApplication()
        app.launchArguments = ["-showTitle", "1", "-resetProgress", "1",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()
        let play = waitForPlay(app)
        XCTAssertEqual(play.label, "Play", "a fresh install's button is not Play")
        XCTAssertFalse(tile(app).exists, "the board is reachable beneath the title")
        play.tap()
        XCTAssertTrue(tile(app).waitForExistence(timeout: 10), "Play did not open the board")
        app.terminate()

        // The same day: the board, with no tap, and no title.
        app.launchArguments = ["-dayOffsetOnResume", "1",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()
        XCTAssertTrue(tile(app).waitForExistence(timeout: 30),
                      "a second launch on the same day did not open on the board")
        XCTAssertFalse(app.buttons["TitlePlay"].exists, "the title came back on the same day")

        // Across midnight: the title again, as the board rolls over.
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 2)
        app.activate()
        _ = waitForPlay(app)

        // A past day on the week opens its own board.
        let past = app.buttons.matching(identifier: "WeekDay").firstMatch
        XCTAssertTrue(past.exists, "the week has no past day")
        past.tap()
        XCTAssertTrue(app.staticTexts["ArchiveDateRow"].waitForExistence(timeout: 10),
                      "a past day on the week did not open that day's board")

        // And from there back to the title, and a day at random: a past board.
        app.buttons["BoardHome"].tap()
        let random = app.buttons["TitleRandomDay"]
        XCTAssertTrue(random.waitForExistence(timeout: 10), "the way back did not open the title")
        random.tap()
        XCTAssertTrue(app.staticTexts["ArchiveDateRow"].waitForExistence(timeout: 10),
                      "a day at random did not open a past board")
        XCTAssertFalse(app.buttons["TitlePlay"].exists, "the title stayed up over the board")
    }
}
