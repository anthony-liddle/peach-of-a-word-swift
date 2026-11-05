import XCTest

/// Opening the app the same day takes her back to the board she was on.
///
/// **What Bea found, on 5 November 2026.** She opened a past day, from Past
/// days or from "A day at random", closed the app, opened it again, and was on
/// today's board. Switching away and coming back had always kept her place:
/// the rollover leaves a past board alone, and the view is still there. A cold
/// launch did not, because nothing remembered which board was in play, and the
/// load always built today's. An app iOS ends in the background launches cold
/// the same way, so both are this test's relaunch.
///
/// **A new day still leads to today.** The title shows once a day, as before,
/// and Play goes to today; the past day is a tap away in Past days. A reminder
/// tapped from cold lands on the title for today's board, wherever she was.
///
/// The first two tests failed on `main` before the fix. The other three passed
/// there too, since `main` always lands on today; they hold the edges of the
/// rule, and each was shown to fail against a resume that ignored its edge.
final class BackToTheDayYouWereOn: XCTestCase {
    private static let size = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]

    /// What the completion card says. A finished day reopened must not show it.
    private static let completionLine = "Every common word these letters can grow, picked."

    /// The board on screen: its date, if it is a past day's, its letters, and
    /// its count of words found.
    private struct Board: Equatable {
        let date: String?
        let letters: [String]
        let count: String
    }

    private func launch(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments + Self.size
        app.launch()
        return app
    }

    private func board(_ app: XCUIApplication, file: StaticString = #filePath,
                       line: UInt = #line) -> Board {
        let count = app.staticTexts["FoundSummaryCount"]
        XCTAssertTrue(count.waitForExistence(timeout: 30), "no board on screen",
                      file: file, line: line)
        let date = app.staticTexts["ArchiveDateRow"]
        let letters = app.buttons.matching(NSPredicate(format: "label MATCHES %@", "^Letter [a-z].*"))
            .allElementsBoundByIndex
            .compactMap { $0.label.split(separator: " ").dropFirst().first.map(String.init) }
            .sorted()
        return Board(date: date.exists ? date.label : nil, letters: letters, count: count.label)
    }

    /// Past days from the board, and the first day in it whose basket is full:
    /// the `bea` seed fills one, four and nine days back.
    private func openAFinishedDay(_ app: XCUIApplication, file: StaticString = #filePath,
                                  line: UInt = #line) {
        let entry = app.buttons["Past days"].firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 30), "no way in to Past days",
                      file: file, line: line)
        entry.tap()
        // **Once more if the sheet does not come.** On 5 November 2026 one tap
        // here, synthesized on the glyph 1.2 seconds after the board appeared,
        // opened nothing; the same tap opened the sheet in this class's other
        // tests and in three reruns of that one. A sheet that never opens still
        // fails, at the cell below.
        if !app.buttons["Back to the basket"].waitForExistence(timeout: 10) {
            print("BACKTOTHEDAY the tap on Past days opened nothing: once more")
            entry.tap()
        }
        let finished = app.buttons.matching(identifier: "ArchiveDayCell")
            .matching(NSPredicate(format: "label CONTAINS %@", "Basket full"))
            .element(boundBy: 0)
        XCTAssertTrue(finished.waitForExistence(timeout: 10), "Past days drew no finished day",
                      file: file, line: line)
        finished.tap()
        XCTAssertTrue(app.staticTexts["ArchiveDateRow"].waitForExistence(timeout: 20),
                      "the finished day did not open", file: file, line: line)
    }

    /// Play, once the board is ready and it can be tapped.
    @discardableResult
    private func waitForPlay(_ app: XCUIApplication, file: StaticString = #filePath,
                             line: UInt = #line) -> XCUIElement {
        let play = app.buttons["TitlePlay"]
        XCTAssertTrue(play.waitForExistence(timeout: 30), "no title", file: file, line: line)
        let enabled = expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: play)
        XCTAssertEqual(XCTWaiter().wait(for: [enabled], timeout: 30), .completed,
                       "Play never became tappable", file: file, line: line)
        return play
    }

    private func backgroundAndReturn(_ app: XCUIApplication) {
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 2)
        app.activate()
    }

    /// A finished day from Past days, the app ended, and opened again the same
    /// day: that day's board, its words, still finished, and no card again.
    func testAPastDayIsStillOpenAfterTheAppEnds() {
        // A 15th, so the seed's finished days are all in the month Past days
        // opens on. See `TestClock.midMonthDayOffset`.
        let day = ["-dayOffset", TestClock.midMonthDayOffset]
        let first = launch(["-resetProgress", "1", "-seedArchive", "bea"] + day)
        _ = board(first)
        openAFinishedDay(first)
        let before = board(first)
        XCTAssertNotNil(before.date, "the board opened is not a past day's")
        first.terminate()

        let app = launch(day)
        XCTAssertTrue(app.staticTexts["ArchiveDateRow"].waitForExistence(timeout: 30),
                      "the relaunch went to today, not the day she was on: \(board(app))")
        XCTAssertEqual(board(app), before, "the relaunch opened a different board")
        XCTAssertFalse(app.buttons["TitlePlay"].exists, "the title came up on the same day")
        // The card is a sheet raised after the board is ready, so give it time
        // to come before saying it did not.
        Thread.sleep(forTimeInterval: 3)
        XCTAssertFalse(app.staticTexts[Self.completionLine].exists,
                       "the finished day celebrated again on reopening")
    }

    /// The same through "A day at random", from the title.
    func testADayAtRandomIsStillOpenAfterTheAppEnds() {
        let first = launch(["-showTitle", "1", "-resetProgress", "1", "-seedArchive", "bea"])
        waitForPlay(first)
        first.buttons["TitleRandomDay"].tap()
        XCTAssertTrue(first.staticTexts["ArchiveDateRow"].waitForExistence(timeout: 20),
                      "a day at random did not open a past board")
        let before = board(first)
        first.terminate()

        let app = launch([])
        XCTAssertTrue(app.staticTexts["ArchiveDateRow"].waitForExistence(timeout: 30),
                      "the relaunch went to today, not the day she was on: \(board(app))")
        XCTAssertEqual(board(app), before, "the relaunch opened a different board")
        XCTAssertFalse(app.buttons["TitlePlay"].exists, "the title came up on the same day")
    }

    /// Opened again the next day: the title, as on any new day, and Play goes
    /// to today, not to the past day she left.
    func testTheNextDayOpensOnTheTitleAndPlayGoesToToday() {
        let offset = TestClock.midMonthDayOffset
        let first = launch(["-resetProgress", "1", "-seedArchive", "bea", "-dayOffset", offset])
        _ = board(first)
        openAFinishedDay(first)
        first.terminate()

        let app = launch(["-dayOffset", String(Int(offset)! + 1)])
        waitForPlay(app).tap()
        let today = board(app)
        XCTAssertNil(today.date, "Play on the next day went to the past day: \(today)")
    }

    /// The title came up over the past day when she came back after midnight,
    /// and she ended the app there. Opened again that day, it is today's board:
    /// the past day was left on the day before, and the title has had its day.
    func testThePastDayIsNotKeptPastTheDayItWasOpen() {
        let first = launch(["-showTitle", "1", "-resetProgress", "1", "-seedArchive", "bea",
                            "-dayOffsetOnResume", "1"])
        waitForPlay(first)
        first.buttons["TitleRandomDay"].tap()
        XCTAssertTrue(first.staticTexts["ArchiveDateRow"].waitForExistence(timeout: 20),
                      "a day at random did not open a past board")
        backgroundAndReturn(first)
        XCTAssertTrue(first.buttons["TitlePlay"].waitForExistence(timeout: 20),
                      "the new day's title did not come up over the past day")
        first.terminate()

        let app = launch(["-dayOffset", "1"])
        let today = board(app)
        XCTAssertNil(today.date, "a past day left yesterday came back today: \(today)")
        XCTAssertFalse(app.buttons["TitlePlay"].exists, "the title came up twice in a day")
    }

    /// A reminder tapped from cold, with a past day open: the title, for
    /// today's board. Today has words, so the line under Play gives today's
    /// count, which it gives only with today's board beneath it; over a past
    /// day it is the rank alone. Then Play goes to today.
    func testAReminderTappedFromColdLandsOnTheTitleForToday() {
        let day = ["-dayOffset", TestClock.midMonthDayOffset]
        let first = launch(["-resetProgress", "1", "-seedArchive", "bea", "-seedBoard", "3"] + day)
        _ = board(first)
        openAFinishedDay(first)
        first.terminate()

        let app = launch(["-reminderTapped", "1"] + day)
        let play = waitForPlay(app)
        let counted = expectation(for: NSPredicate(format: "label CONTAINS %@", " \u{00B7} "),
                                  evaluatedWith: play)
        XCTAssertEqual(XCTWaiter().wait(for: [counted], timeout: 20), .completed,
                       "the title is not over today's board: \(play.label)")
        play.tap()
        let today = board(app)
        XCTAssertNil(today.date, "Play from the reminder's title went to the past day: \(today)")
    }
}
