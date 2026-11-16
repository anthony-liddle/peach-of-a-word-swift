import XCTest

/// Days from the web, brought in through Settings: the paste, the question,
/// Transfer, the one message after, and the title's streak.
///
/// **Everything after the paste is the real path.** `-pasteDays sample` hands
/// the card a payload the app writes from its own calendar, as if from the
/// clipboard: today and the two days before, each with its crown found, and a
/// streak of three ending today. The parse, the plan, the question, the board
/// builds, the import and the message are the shipping code. iOS's Paste
/// button is the one part a test can't press for the player.
///
/// **What the numbers rest on.** A crown alone doesn't reach the streak's rank
/// on a real board, so each day counts as finished because the web's run says
/// it reached it, which is the import's floor inside the run. Each has its
/// peach, since its crown is among its words.
final class DaysFromTheWeb: XCTestCase {
    private func launch(paste: String, reset: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = (reset ? ["-resetProgress", "1"] : [])
            + ["-openSettings", "1", "-pasteDays", paste]
        app.launch()
        return app
    }

    private func message(_ app: XCUIApplication) -> XCUIElement {
        app.staticTexts["SettingsDaysMessage"]
    }

    /// Close Settings, and from the board it was opened over, go back to the
    /// title. A fresh launch opens Settings over today's board.
    private func closeToTheTitle(_ app: XCUIApplication) {
        app.buttons["SheetClose"].tap()
        let home = app.buttons["BoardHome"]
        if home.waitForExistence(timeout: 5) { home.tap() }
        XCTAssertTrue(app.buttons["TitlePlay"].waitForExistence(timeout: 10), "not back on the title")
    }

    private func titleStreak(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "TitleStreak").firstMatch
    }

    /// Asked, brought, and said: three days, all finished, all with their
    /// peach, and the streak of three, which the title shows once Settings
    /// closes.
    func testDaysComeAcrossWithTheStreak() {
        let app = launch(paste: "sample")
        let question = app.alerts["Transfer 3 days from the website?"]
        XCTAssertTrue(question.waitForExistence(timeout: 60), "no question after the paste")
        question.buttons["Transfer"].tap()

        XCTAssertTrue(message(app).waitForExistence(timeout: 60), "no message after Transfer")
        XCTAssertEqual(
            message(app).label,
            "3 days transferred. 3 are finished, and 3 have their peach. Your streak is 3."
        )

        closeToTheTitle(app)
        XCTAssertTrue(titleStreak(app).waitForExistence(timeout: 10), "no streak on the title")
        XCTAssertEqual(titleStreak(app).label, "Streak, 3 days")
    }

    /// The same days again change nothing, and say so: rule 7.
    func testTheSameDaysTwiceBringNothingNew() {
        var app = launch(paste: "sample")
        XCTAssertTrue(app.alerts["Transfer 3 days from the website?"].waitForExistence(timeout: 60))
        app.alerts.buttons["Transfer"].tap()
        XCTAssertTrue(message(app).waitForExistence(timeout: 60))
        app.terminate()

        app = launch(paste: "sample", reset: false)
        XCTAssertTrue(app.alerts["Transfer 3 days from the website?"].waitForExistence(timeout: 60))
        app.alerts.buttons["Transfer"].tap()
        XCTAssertTrue(message(app).waitForExistence(timeout: 60))
        XCTAssertEqual(
            message(app).label,
            "Nothing new to transfer. The app's streak was already as long, so it stays."
        )
    }

    /// Not now writes nothing: no message, and no streak on the title.
    func testNotNowBringsNothing() {
        let app = launch(paste: "sample")
        let question = app.alerts["Transfer 3 days from the website?"]
        XCTAssertTrue(question.waitForExistence(timeout: 60))
        question.buttons["Not now"].tap()
        XCTAssertFalse(message(app).waitForExistence(timeout: 3), "a message without Transfer")
        closeToTheTitle(app)
        XCTAssertFalse(titleStreak(app).exists, "a streak without Transfer")
    }

    /// Text that isn't days from the web is refused with a line, and no question.
    func testOtherTextIsRefused() {
        let app = launch(paste: "Hello from a group chat")
        XCTAssertTrue(message(app).waitForExistence(timeout: 60), "nothing said about the paste")
        XCTAssertTrue(message(app).label.hasPrefix("That isn't your days."))
        XCTAssertFalse(app.alerts.firstMatch.exists, "asked about text that isn't days")
    }
}
