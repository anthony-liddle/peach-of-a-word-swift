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
/// **Closed from the title, it reopens on the title** (Antoine, 5 November):
/// the app reopens where she left it, and under the title the board is today's.
///
/// The two tests of a past day kept failed on `main` before #123; the three of
/// the title kept failed on `main` before the title was remembered. The next
/// day and the reminder pass on both, since both land on today; they hold the
/// rule's edges, and each was shown to fail against a resume built to ignore
/// its edge: one that took the new day's title, and one that opened the past
/// day under the reminder's title.
final class BackToTheDayYouWereOn: XCTestCase {
    private static let size = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]

    /// What the completion card says. A finished day reopened must not show it.
    private static let completionLine = "Every common word these letters can grow, picked."

    /// How long a seeded first launch has to reach the board, or to make Play
    /// tappable: 60 seconds, as `ArchiveBeaFirstOpen` and `ArchivePeachDays`
    /// give the same seed. Every other wait here is 30.
    ///
    /// **The seed is slow, and only in a test.** `-seedArchive bea` builds
    /// thirteen past days' puzzles and runs the back-fill over them while the
    /// splash is up, in a Debug build on a simulator. On CI's runners that has
    /// taken a median of 24 seconds and up to 42. At 30, three of these
    /// launches failed, on 9 and 10 November 2026, each with the splash still
    /// up and the board 0.7 to 1.0 seconds after the wait gave up. Reopened
    /// over the same history, the app reaches its screen in 2 to 4 seconds.
    private static let seededLaunch: TimeInterval = 60

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

    private func board(_ app: XCUIApplication, timeout: TimeInterval = 30,
                       file: StaticString = #filePath, line: UInt = #line) -> Board {
        let count = app.staticTexts["FoundSummaryCount"]
        XCTAssertTrue(count.waitForExistence(timeout: timeout), "no board on screen",
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
        // **Once more if the sheet does not come, and on the record when it
        // doesn't.** On 5 November 2026 one tap here, synthesized on the glyph
        // 1.2 seconds after the board appeared, opened nothing; the same tap
        // opened the sheet in this class's other tests and in three reruns of
        // that one. A sheet that never opens still fails, at the cell below.
        // See `SecondTap`.
        if !app.buttons["Back to the basket"].waitForExistence(timeout: 10) {
            SecondTap.record("Past days opened nothing, so it was tapped again")
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
    private func waitForPlay(_ app: XCUIApplication, timeout: TimeInterval = 30,
                             file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let play = app.buttons["TitlePlay"]
        XCTAssertTrue(play.waitForExistence(timeout: timeout), "no title", file: file, line: line)
        let enabled = expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: play)
        XCTAssertEqual(XCTWaiter().wait(for: [enabled], timeout: timeout), .completed,
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
        _ = board(first, timeout: Self.seededLaunch)
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
        waitForPlay(first, timeout: Self.seededLaunch)
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
        _ = board(first, timeout: Self.seededLaunch)
        openAFinishedDay(first)
        first.terminate()

        let app = launch(["-dayOffset", String(Int(offset)! + 1)])
        waitForPlay(app).tap()
        let today = board(app)
        XCTAssertNil(today.date, "Play on the next day went to the past day: \(today)")
    }

    /// The title came up over the past day when she came back after midnight,
    /// and she ended the app there. Opened again that day, it is the title:
    /// she left it there, so it reopens there, and Play goes to today.
    ///
    /// In #123 this asked for today's board with no title, which is where that
    /// build sent her; Antoine's rule since is that the app reopens where she
    /// left it. The title skips the past day before its date is read, so the
    /// date rule (`on == today`) is no longer reached from here:
    /// `BoardInPlayTests` holds it.
    func testTheNewDaysTitleOverAPastDayReopensOnTheTitle() {
        let first = launch(["-showTitle", "1", "-resetProgress", "1", "-seedArchive", "bea",
                            "-dayOffsetOnResume", "1"])
        waitForPlay(first, timeout: Self.seededLaunch)
        first.buttons["TitleRandomDay"].tap()
        XCTAssertTrue(first.staticTexts["ArchiveDateRow"].waitForExistence(timeout: 20),
                      "a day at random did not open a past board")
        backgroundAndReturn(first)
        XCTAssertTrue(first.buttons["TitlePlay"].waitForExistence(timeout: 20),
                      "the new day's title did not come up over the past day")
        first.terminate()

        let app = launch(["-dayOffset", "1"])
        let today = reopensOnTheTitle(app)
        XCTAssertNil(today.date, "Play went to the past day, not today: \(today)")
    }

    /// The title, again, where she left the app on it. Nothing of the board is
    /// drawn beneath it. Then Play, and the board it goes to.
    private func reopensOnTheTitle(_ app: XCUIApplication, file: StaticString = #filePath,
                                   line: UInt = #line) -> Board {
        let play = waitForPlay(app, file: file, line: line)
        XCTAssertFalse(app.staticTexts["FoundSummaryCount"].exists,
                       "a board is showing, not the title", file: file, line: line)
        play.tap()
        return board(app, file: file, line: line)
    }

    /// She went from a past day to the title and closed the app there. It
    /// reopens on the title, and Play goes to today. Closed again from today's
    /// board, it opens on today's board: the title gave the past day up.
    func testClosingFromTheTitleOverAPastDayReopensOnTheTitle() {
        let day = ["-dayOffset", TestClock.midMonthDayOffset]
        let first = launch(["-resetProgress", "1", "-seedArchive", "bea"] + day)
        _ = board(first, timeout: Self.seededLaunch)
        openAFinishedDay(first)
        first.buttons["BoardHome"].tap()
        waitForPlay(first)
        first.terminate()

        let app = launch(day)
        let today = reopensOnTheTitle(app)
        XCTAssertNil(today.date, "Play went to the past day, not today: \(today)")
        app.terminate()

        let again = launch(day)
        let after = board(again)
        XCTAssertNil(after.date, "the past day came back after Play went to today: \(after)")
        XCTAssertFalse(again.buttons["TitlePlay"].exists, "the title came back from the board")
    }

    /// The same from today's board: the title, again.
    func testClosingFromTheTitleOverTodayReopensOnTheTitle() {
        let first = launch(["-resetProgress", "1", "-seedArchive", "bea"])
        _ = board(first, timeout: Self.seededLaunch)
        first.buttons["BoardHome"].tap()
        waitForPlay(first)
        first.terminate()

        let app = launch([])
        let today = reopensOnTheTitle(app)
        XCTAssertNil(today.date, "Play did not go to today: \(today)")
    }

    /// A reminder tapped from cold, with a past day open: the title, for
    /// today's board. Today has words, so the line under Play gives today's
    /// count, which it gives only with today's board beneath it; over a past
    /// day it is the rank alone. Then Play goes to today.
    func testAReminderTappedFromColdLandsOnTheTitleForToday() {
        let day = ["-dayOffset", TestClock.midMonthDayOffset]
        let first = launch(["-resetProgress", "1", "-seedArchive", "bea", "-seedBoard", "3"] + day)
        _ = board(first, timeout: Self.seededLaunch)
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
