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
        // How to play has been seen, so Play and the run's button go
        // straight on. `testHowToPlayComesFirstForANewPlayer` holds the rest.
        app.launchArguments = (reset ? ["-resetProgress", "1"] : []) + ["-howToPlaySeen", "1"]
            + (title ? ["-showTitle", "1", "-titleLastShownDay", "never"] : []) + extra
        app.launch()
        return app
    }

    /// The rack's tiles that carry a letter, for the eye or for VoiceOver.
    ///
    /// A hidden tile is still listed by XCUITest, which keeps elements
    /// VoiceOver is told to skip, so the count is of tiles with a letter in
    /// their label, not of tiles. Whether VoiceOver is silent on the hidden
    /// rack is phone check 1.
    private func lettered(_ app: XCUIApplication) -> Int {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Letter'"))
            .allElementsBoundByIndex
            .filter { $0.exists && $0.label.trimmingCharacters(in: .whitespaces) != "Letter" }
            .count
    }

    /// Everything that stands for a tile or carries a letter, to the eye or to
    /// VoiceOver: a tile, "Letter" and its letter or blank, the rack, "Letter
    /// tiles", and any label that is one letter alone. Not the ready screen's
    /// own line, "Letters show when the clock starts." Counted, never read
    /// out, so a failure prints no letter.
    private func exposed(_ app: XCUIApplication) -> Int {
        app.descendants(matching: .any)
            .matching(NSPredicate(format:
                "label == 'Letter' OR label BEGINSWITH 'Letter ' OR label MATCHES '^[A-Za-z]$'"))
            .count
    }

    /// Tap, once the element is there, and once more if nothing answered.
    ///
    /// **Never on an element that isn't there.** A tap or a read of a missing
    /// element makes XCUITest print the whole tree into the log, the rack's
    /// letters among it, and the repo is public: a run a day ahead would print
    /// a day nobody has played. So each waits, and fails in its own words.
    private func tap(_ element: XCUIElement, _ what: String, until done: () -> Bool = { true }) {
        guard element.waitForExistence(timeout: 10) else {
            XCTFail("\(what) isn't there to tap")
            return
        }
        element.tap()
        if !done() {
            SecondTap.record(what)
            if element.exists { element.tap() }
        }
    }

    /// An element's label, read only once it's there. See `tap`.
    private func label(_ element: XCUIElement, _ what: String) -> String {
        guard element.waitForExistence(timeout: 10) else {
            XCTFail("\(what) isn't there to read")
            return ""
        }
        return element.label
    }

    // MARK: Start, Back, End

    /// A phone that has never played sees How to play first, from the run's
    /// button as from Play, and goes on to the run.
    func testHowToPlayComesFirstForANewPlayer() {
        let app = XCUIApplication()
        app.launchArguments = ["-resetProgress", "1", "-showTitle", "1", "-titleLastShownDay", "never"]
        app.launch()
        let offer = app.buttons["TitleRun"]
        XCTAssertTrue(offer.waitForExistence(timeout: 60), "a fresh day offers no run")
        tap(offer, "the run's button") { app.buttons["HowToPlayDone"].waitForExistence(timeout: 5) }
        XCTAssertTrue(app.buttons["HowToPlayDone"].exists, "a new player went to the run without How to play")
        tap(app.buttons["HowToPlayDone"], "How to play's button") {
            app.buttons["RunStart"].waitForExistence(timeout: 5)
        }
        XCTAssertTrue(app.buttons["RunStart"].exists, "How to play didn't go on to the run")
    }

    func testOfferedAndHiddenUntilStartAndBackKeepsIt() {
        let app = launch([], title: true)
        let offer = app.buttons["TitleRun"]
        XCTAssertTrue(offer.waitForExistence(timeout: 60), "a fresh day offers no run")
        tap(offer, "the run's button") { app.buttons["RunStart"].waitForExistence(timeout: 5) }
        XCTAssertTrue(app.buttons["RunStart"].exists, "the run opened with no Start")
        XCTAssertEqual(lettered(app), 0, "the letters showed before the clock started")

        tap(app.buttons["RunBack"], "the way back") { offer.waitForExistence(timeout: 5) }
        XCTAssertTrue(offer.exists, "Back before Start lost the day's run")

        tap(offer, "the run's button, again") { app.buttons["RunStart"].waitForExistence(timeout: 5) }
        tap(app.buttons["RunStart"], "Start") { lettered(app) == 8 }
        XCTAssertEqual(lettered(app), 8, "Start didn't show all eight letters")
        XCTAssertTrue(label(app.staticTexts["RunClock"], "the clock").hasPrefix("Time left, "),
                      "the clock doesn't say the time left")
    }

    /// Before Start and while paused there's no tile at all for VoiceOver,
    /// blank or not, and no letter anywhere. Phone check 1 hears it.
    func testNoLetterIsExposedBeforeStartOrWhilePaused() {
        let app = launch([], title: true)
        let offer = app.buttons["TitleRun"]
        XCTAssertTrue(offer.waitForExistence(timeout: 60), "a fresh day offers no run")
        tap(offer, "the run's button") { app.buttons["RunStart"].waitForExistence(timeout: 5) }
        XCTAssertEqual(exposed(app), 0, "the ready screen exposes the rack")

        tap(app.buttons["RunStart"], "Start") { lettered(app) == 8 }
        XCUIDevice.shared.press(.home)
        sleep(2)
        app.activate()
        XCTAssertTrue(app.buttons["RunResume"].waitForExistence(timeout: 10), "leaving didn't pause the run")
        XCTAssertEqual(exposed(app), 0, "a paused run exposes the rack")
    }

    /// The way back before Start is heard as the board's is: the same words,
    /// and a button. Each is sorted first in its row, which XCUITest can't
    /// see: it lists a row in the order it's drawn, the chevron after the
    /// text it sits beside, on the board as here. Phone check 1 hears it.
    func testTheWayBackIsHeardAsTheBoardsIs() {
        let app = launch([], title: true)
        let play = app.buttons["TitlePlay"]
        XCTAssertTrue(play.waitForExistence(timeout: 60), "no title")
        let home = app.buttons["BoardHome"]
        tap(play, "Play") { home.waitForExistence(timeout: 10) }
        let board = label(home, "the board's way back")

        tap(home, "the board's way back") { app.buttons["TitleRun"].waitForExistence(timeout: 5) }
        tap(app.buttons["TitleRun"], "the run's button") { app.buttons["RunBack"].waitForExistence(timeout: 5) }
        XCTAssertEqual(label(app.buttons["RunBack"], "the run's way back"), board,
                       "the run's way back isn't heard as the board's")
    }

    func testEndAsksFirstAndAResultNeverStartsAnother() {
        let app = launch(["-timedRun", "running"], title: true)
        let leave = app.buttons["RunLeave"]
        XCTAssertTrue(leave.waitForExistence(timeout: 60), "no run running")

        tap(leave, "End") { app.alerts.firstMatch.waitForExistence(timeout: 5) }
        let question = app.alerts.firstMatch
        XCTAssertEqual(label(question, "End's question"), "End the run?", "End didn't ask first")
        tap(question.buttons["Keep playing"], "Keep playing")
        let clock = app.staticTexts["RunClock"]
        let before = label(clock, "the clock")
        sleep(2)
        XCTAssertNotEqual(label(clock, "the clock"), before, "Keep playing stopped the clock")

        tap(leave, "End, again") { app.alerts.firstMatch.waitForExistence(timeout: 5) }
        tap(app.alerts.firstMatch.buttons["End"], "End, in the question")
        let heading = app.staticTexts["RunResultHeading"]
        XCTAssertTrue(heading.waitForExistence(timeout: 5), "End didn't end the run")
        XCTAssertTrue(label(heading, "the result's heading").hasPrefix("Ended with "), "an early end didn't say so")

        tap(app.buttons["RunDone"], "Done") { app.buttons["TitleRun"].waitForExistence(timeout: 5) }
        let played = app.buttons["TitleRun"]
        XCTAssertTrue(label(played, "the run's button").contains("0 words · 0 points"), "the title doesn't show the run played")
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
        let weekBefore = label(week, "today in the week")
        fresh.terminate()

        let app = launch(["-timedRun", "played", "-timedRunFindSource", "1"], title: true)
        let played = app.buttons["TitleRun"]
        XCTAssertTrue(played.waitForExistence(timeout: 60), "no run on the title")
        XCTAssertTrue(label(played, "the run's button").contains("1 word · 15 points"),
                      "the run didn't keep the peach of a word as its one find")
        let play = app.buttons["TitlePlay"]
        XCTAssertTrue(label(play, "Play").hasPrefix("Play"), "the run started the basket")
        XCTAssertTrue(label(app.buttons["WeekToday"], "today in the week") == weekBefore, "the run changed today in the week")
        XCTAssertFalse(app.otherElements["TitleStreak"].exists || app.staticTexts["TitleStreak"].exists,
                       "the run gave a streak")

        tap(play, "Play") { app.staticTexts["MeterPoints"].waitForExistence(timeout: 10) }
        XCTAssertEqual(label(app.staticTexts["MeterPoints"], "the board's points"), "0 points", "the run's points reached the basket")
    }

    // MARK: Pausing

    func testLeavingPausesAndHidesTheLetters() {
        let app = launch(["-timedRun", "running"])
        XCTAssertTrue(app.buttons["RunLeave"].waitForExistence(timeout: 60), "no run running")
        XCTAssertEqual(lettered(app), 8, "a running run hid its letters")

        XCUIDevice.shared.press(.home)
        sleep(2)
        app.activate()

        XCTAssertTrue(app.buttons["RunResume"].waitForExistence(timeout: 10), "leaving didn't pause the run")
        XCTAssertEqual(lettered(app), 0, "a paused run showed its letters")
        let clock = app.staticTexts["RunClock"]
        let held = label(clock, "the clock")
        sleep(2)
        XCTAssertEqual(label(clock, "the clock"), held, "a paused run's clock kept going")

        tap(app.buttons["RunResume"], "Resume") { lettered(app) == 8 }
        XCTAssertEqual(lettered(app), 8, "Resume didn't bring the letters back")
    }

    /// A run left waiting comes back paused, and Play asks before the basket
    /// ends it (Antoine, 24 November): Keep playing opens the run, still
    /// paused, and End ends it with what it had and opens the basket.
    func testARunLeftWaitingComesBackPausedAndPlayAsksFirst() {
        let app = launch(["-timedRun", "waiting"], title: true)
        let waiting = app.buttons["TitleRun"]
        XCTAssertTrue(waiting.waitForExistence(timeout: 60), "no run on the title")
        XCTAssertTrue(label(waiting, "the run's button").contains("paused"), "a waiting run doesn't say it's paused")

        tap(waiting, "the waiting run") { app.buttons["RunResume"].waitForExistence(timeout: 5) }
        XCTAssertTrue(app.buttons["RunResume"].exists, "a waiting run didn't open paused")
        XCTAssertEqual(lettered(app), 0, "a waiting run showed its letters")
        app.terminate()

        // Play asks, and Keep playing goes to the run.
        let again = launch([], title: true, reset: false)
        XCTAssertTrue(again.buttons["TitlePlay"].waitForExistence(timeout: 60), "no title")
        tap(again.buttons["TitlePlay"], "Play") { again.alerts.firstMatch.waitForExistence(timeout: 5) }
        guard again.alerts.firstMatch.exists else {
            XCTFail("Play went into the basket without asking")
            return
        }
        XCTAssertEqual(label(again.alerts.firstMatch, "End's question"), "End the run?", "Play didn't ask End's question")
        tap(again.alerts.firstMatch.buttons["Keep playing"], "Keep playing") {
            again.buttons["RunResume"].waitForExistence(timeout: 5)
        }
        XCTAssertTrue(again.buttons["RunResume"].exists, "Keep playing didn't open the run, paused")
        XCTAssertEqual(lettered(again), 0, "Keep playing showed the letters")
        again.terminate()

        // Play asks again, and End ends the run and opens the basket.
        let ending = launch([], title: true, reset: false)
        XCTAssertTrue(ending.buttons["TitlePlay"].waitForExistence(timeout: 60), "no title")
        tap(ending.buttons["TitlePlay"], "Play") { ending.alerts.firstMatch.waitForExistence(timeout: 5) }
        tap(ending.alerts.firstMatch.buttons["End"], "End, in the question") {
            ending.staticTexts["MeterPoints"].waitForExistence(timeout: 10)
        }
        XCTAssertTrue(ending.staticTexts["MeterPoints"].exists, "End didn't go on to the basket")
        ending.terminate()

        let after = launch([], title: true, reset: false)
        let ended = after.buttons["TitleRun"]
        XCTAssertTrue(ended.waitForExistence(timeout: 60), "the run left the title")
        XCTAssertFalse(label(ended, "the run's button").contains("paused"), "the basket left the run waiting")
        XCTAssertTrue(label(ended, "the run's button").contains("0 words · 0 points"), "the run didn't end with what it had")
    }

    /// Today picked in Past days asks too, once the sheet is down, and End
    /// opens the basket.
    func testTodayFromPastDaysAsksFirstToo() {
        let app = launch(["-timedRun", "waiting"], title: true)
        XCTAssertTrue(app.buttons["TitleRun"].waitForExistence(timeout: 60), "no run on the title")
        let today = app.buttons["ArchiveTodayCell"]
        tap(app.buttons["TitlePastDays"], "Past days") { today.waitForExistence(timeout: 20) }
        tap(today, "today in Past days") { app.alerts.firstMatch.waitForExistence(timeout: 10) }
        guard app.alerts.firstMatch.exists else {
            XCTFail("today in Past days went into the basket without asking")
            return
        }
        XCTAssertEqual(label(app.alerts.firstMatch, "End's question"), "End the run?", "Past days didn't ask End's question")
        tap(app.alerts.firstMatch.buttons["End"], "End, in the question") {
            app.staticTexts["MeterPoints"].waitForExistence(timeout: 10)
        }
        XCTAssertTrue(app.staticTexts["MeterPoints"].exists, "End didn't go on to the basket")
    }

    // MARK: The clock

    /// A 12 second clock, run out: "10 seconds left." once, then Time's up
    /// once, and neither of the marks it never reached.
    func testTheTimeIsSpokenAtItsMarksOnly() {
        let app = launch(["-timedRun", "running", "-runClock", "12", "-exposeAnnounced", "1"])
        XCTAssertTrue(app.staticTexts["RunResultHeading"].waitForExistence(timeout: 30),
                      "the clock never ran out")
        XCTAssertEqual(label(app.staticTexts["RunResultHeading"], "the result's heading"), "Time's up")
        let said = label(app.staticTexts["DebugAnnounced"], "the announcements").components(separatedBy: " | ")
        XCTAssertEqual(said.filter { $0 == "10 seconds left." }.count, 1, "10 seconds left wasn't said once")
        XCTAssertEqual(said.filter { $0.hasPrefix("Time's up.") }.count, 1, "Time's up wasn't said once")
        XCTAssertFalse(said.contains("1 minute left.") || said.contains("30 seconds left."),
                       "a mark the clock never reached was said")
        XCTAssertFalse(said.contains { $0.contains("second") && !$0.hasPrefix("10 ") && !$0.hasPrefix("Started") },
                       "the time was said other than at its marks")
    }
}
