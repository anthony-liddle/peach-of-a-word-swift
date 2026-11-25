import XCTest

/// Peach rush: one run a day against the clock on today's board, offered
/// until the basket's first find (`reports/2026-11-24 Timed Mode.md`).
///
/// Every launch starts from a phone that has never played. Nothing here names
/// a board's word: the run's finds are made by hooks that spell the day's
/// words without a test knowing them, and every failure message says what
/// failed, not what was found.
final class PeachRush: XCTestCase {
    private func launch(_ extra: [String], title: Bool = false, reset: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = (reset ? ["-resetProgress", "1"] : [])
            + (title ? ["-showTitle", "1", "-titleLastShownDay", "never"] : []) + extra
        app.launch()
        return app
    }

    /// The rack's tiles that VoiceOver and XCUITest can reach.
    private func tiles(_ app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Letter'"))
    }

    private func tap(_ element: XCUIElement, _ what: String, until done: () -> Bool) {
        element.tap()
        if !done() {
            SecondTap.record(what)
            element.tap()
        }
    }

    // MARK: Start, Back, End

    func testOfferedAndHiddenUntilStartAndBackKeepsIt() {
        let app = launch([], title: true)
        let offer = app.buttons["TitleRun"]
        XCTAssertTrue(offer.waitForExistence(timeout: 60), "a fresh day offers no run")
        tap(offer, "the run's button") { app.buttons["RunStart"].waitForExistence(timeout: 5) }
        XCTAssertTrue(app.buttons["RunStart"].exists, "the run opened with no Start")
        XCTAssertEqual(tiles(app).count, 0, "the letters showed before the clock started")

        tap(app.buttons["RunLeave"], "Back") { offer.waitForExistence(timeout: 5) }
        XCTAssertTrue(offer.exists, "Back before Start lost the day's run")

        tap(offer, "the run's button, again") { app.buttons["RunStart"].waitForExistence(timeout: 5) }
        tap(app.buttons["RunStart"], "Start") { tiles(app).count == 8 }
        XCTAssertEqual(tiles(app).count, 8, "Start didn't show all eight letters")
        XCTAssertTrue(app.staticTexts["RunClock"].label.hasPrefix("Time left, "),
                      "the clock doesn't say the time left")
    }

    func testEndAsksFirstAndAResultNeverStartsAnother() {
        let app = launch(["-timedRun", "running"], title: true)
        let leave = app.buttons["RunLeave"]
        XCTAssertTrue(leave.waitForExistence(timeout: 60), "no run running")

        tap(leave, "End") { app.alerts.firstMatch.waitForExistence(timeout: 5) }
        let question = app.alerts.firstMatch
        XCTAssertEqual(question.label, "End the run?", "End didn't ask first")
        question.buttons["Keep playing"].tap()
        let clock = app.staticTexts["RunClock"]
        let before = clock.label
        sleep(2)
        XCTAssertNotEqual(clock.label, before, "Keep playing stopped the clock")

        tap(leave, "End, again") { app.alerts.firstMatch.waitForExistence(timeout: 5) }
        app.alerts.firstMatch.buttons["End"].tap()
        let heading = app.staticTexts["RunResultHeading"]
        XCTAssertTrue(heading.waitForExistence(timeout: 5), "End didn't end the run")
        XCTAssertTrue(heading.label.hasPrefix("Ended with "), "an early end didn't say so")

        tap(app.buttons["RunDone"], "Done") { app.buttons["TitleRun"].waitForExistence(timeout: 5) }
        let played = app.buttons["TitleRun"]
        XCTAssertTrue(played.label.contains("0 words · 0 points"), "the title doesn't show the run played")
        tap(played, "the played run") { heading.waitForExistence(timeout: 5) }
        XCTAssertTrue(heading.exists, "the title's button didn't reopen the result")
        XCTAssertFalse(app.buttons["RunStart"].exists, "a played run offered a second")
    }

    // MARK: Apart from the basket

    /// A run that finds the peach of a word leaves the basket as it found it:
    /// the title's Play, its week and its streak, and the board's points.
    func testARunLeavesTheBasketAlone() {
        let fresh = launch([], title: true)
        let week = fresh.buttons["WeekToday"]
        XCTAssertTrue(week.waitForExistence(timeout: 60), "no week on a fresh title")
        let weekBefore = week.label
        fresh.terminate()

        let app = launch(["-timedRun", "played", "-timedRunFindSource", "1"], title: true)
        let played = app.buttons["TitleRun"]
        XCTAssertTrue(played.waitForExistence(timeout: 60), "no run on the title")
        XCTAssertTrue(played.label.contains("1 word · 15 points"),
                      "the run didn't keep the peach of a word as its one find")
        let play = app.buttons["TitlePlay"]
        XCTAssertTrue(play.label.hasPrefix("Play"), "the run started the basket")
        XCTAssertTrue(app.buttons["WeekToday"].label == weekBefore, "the run changed today in the week")
        XCTAssertFalse(app.otherElements["TitleStreak"].exists || app.staticTexts["TitleStreak"].exists,
                       "the run gave a streak")

        tap(play, "Play") { app.staticTexts["MeterPoints"].waitForExistence(timeout: 10) }
        XCTAssertEqual(app.staticTexts["MeterPoints"].label, "0 points", "the run's points reached the basket")
    }

    // MARK: Pausing

    func testLeavingPausesAndHidesTheLetters() {
        let app = launch(["-timedRun", "running"])
        XCTAssertTrue(app.buttons["RunLeave"].waitForExistence(timeout: 60), "no run running")
        XCTAssertEqual(tiles(app).count, 8, "a running run hid its letters")

        XCUIDevice.shared.press(.home)
        sleep(2)
        app.activate()

        XCTAssertTrue(app.buttons["RunResume"].waitForExistence(timeout: 10), "leaving didn't pause the run")
        XCTAssertEqual(tiles(app).count, 0, "a paused run showed its letters")
        let clock = app.staticTexts["RunClock"]
        let held = clock.label
        sleep(2)
        XCTAssertEqual(clock.label, held, "a paused run's clock kept going")

        tap(app.buttons["RunResume"], "Resume") { tiles(app).count == 8 }
        XCTAssertEqual(tiles(app).count, 8, "Resume didn't bring the letters back")
    }

    func testARunLeftWaitingComesBackPausedAndTheBasketEndsIt() {
        let app = launch(["-timedRun", "waiting"], title: true)
        let waiting = app.buttons["TitleRun"]
        XCTAssertTrue(waiting.waitForExistence(timeout: 60), "no run on the title")
        XCTAssertTrue(waiting.label.contains("paused"), "a waiting run doesn't say it's paused")

        tap(waiting, "the waiting run") { app.buttons["RunResume"].waitForExistence(timeout: 5) }
        XCTAssertTrue(app.buttons["RunResume"].exists, "a waiting run didn't open paused")
        XCTAssertEqual(tiles(app).count, 0, "a waiting run showed its letters")
        app.terminate()

        // Back to the title, then the basket: the run ends with what it had.
        let again = launch([], title: true, reset: false)
        XCTAssertTrue(again.buttons["TitlePlay"].waitForExistence(timeout: 60), "no title")
        tap(again.buttons["TitlePlay"], "Play") { again.staticTexts["MeterPoints"].waitForExistence(timeout: 10) }
        again.terminate()

        let after = launch([], title: true, reset: false)
        let ended = after.buttons["TitleRun"]
        XCTAssertTrue(ended.waitForExistence(timeout: 60), "the run left the title")
        XCTAssertFalse(ended.label.contains("paused"), "the basket left the run waiting")
        XCTAssertTrue(ended.label.contains("0 words · 0 points"), "the run didn't end with what it had")
    }

    // MARK: The clock

    /// A 12 second clock, run out: "10 seconds left." once, then Time's up
    /// once, and neither of the marks it never reached.
    func testTheTimeIsSpokenAtItsMarksOnly() {
        let app = launch(["-timedRun", "running", "-runClock", "12", "-exposeAnnounced", "1"])
        XCTAssertTrue(app.staticTexts["RunResultHeading"].waitForExistence(timeout: 30),
                      "the clock never ran out")
        XCTAssertEqual(app.staticTexts["RunResultHeading"].label, "Time's up")
        let said = app.staticTexts["DebugAnnounced"].label.components(separatedBy: " | ")
        XCTAssertEqual(said.filter { $0 == "10 seconds left." }.count, 1, "10 seconds left wasn't said once")
        XCTAssertEqual(said.filter { $0.hasPrefix("Time's up.") }.count, 1, "Time's up wasn't said once")
        XCTAssertFalse(said.contains("1 minute left.") || said.contains("30 seconds left."),
                       "a mark the clock never reached was said")
        XCTAssertFalse(said.contains { $0.contains("second") && !$0.hasPrefix("10 ") && !$0.hasPrefix("Started") },
                       "the time was said other than at its marks")
    }
}
