import XCTest

/// The peach dresses up by the board's date, never today's.
///
/// The date rule itself is the engine's (`CostumeDayTests`). These hold the app
/// to it through the board it actually opens: today's board on the day, the
/// day's board replayed later from the calendar, and another day's board played
/// on the day. The reveal card is where it is read, because its peach says what
/// it is wearing to VoiceOver and is otherwise decorative.
final class CostumeOnTheDay: XCTestCase {
    private static let spoken = "The peach is in a ghost sheet."

    /// The next 31 October on or after today, in whichever year that falls.
    ///
    /// **Not 31 October 2026, because the offset to a past date is negative,
    /// and Foundation drops a negative `-dayOffset`.** It reads `-dayOffset -1`
    /// as a key with no value, so the app stays on today without a word. Aimed
    /// at 2026 from 1 November on, these ran on the wrong day: two failed, and
    /// the one that asserts the costume is absent passed without checking
    /// anything. The costume goes by month and day in any year, so the next
    /// 31 October is as good a board as the first, and the offset to it is
    /// never negative.
    private var nextHalloween: Date {
        let cal = Calendar.current
        let today = cal.startOfDay(for: TestClock.now)
        let year = cal.component(.year, from: today)
        let thisYear = cal.date(from: DateComponents(year: year, month: 10, day: 31))!
        return thisYear >= today
            ? thisYear : cal.date(from: DateComponents(year: year + 1, month: 10, day: 31))!
    }

    /// The `-dayOffset` that makes the app's today `date`, which must not be
    /// in the past; see `nextHalloween`.
    private func offset(to date: Date, plus days: Int = 0) -> String {
        let cal = Calendar.current
        let target = cal.date(byAdding: .day, value: days, to: date)!
        let offset = cal.dateComponents([.day], from: cal.startOfDay(for: TestClock.now),
                                        to: target).day!
        XCTAssertGreaterThanOrEqual(offset, 0,
                                    "a negative -dayOffset is dropped, so the app would stay on today")
        return String(offset)
    }

    private func reveal(_ extra: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-resetProgress", "1", "-revealCard", "industry",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
            + extra
        app.launch()
        return app
    }

    private func peachSaysCostume(_ app: XCUIApplication, timeout: TimeInterval) -> Bool {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", Self.spoken))
            .firstMatch.waitForExistence(timeout: timeout)
    }

    private func waitForTheCard(_ app: XCUIApplication) {
        XCTAssertTrue(app.staticTexts["You found the Peach of a Word!"].waitForExistence(timeout: 30),
                      "the reveal card never opened")
    }

    func testTodaysBoardOnTheDayWearsIt() {
        let app = reveal(["-dayOffset", offset(to: nextHalloween)])
        waitForTheCard(app)
        XCTAssertTrue(peachSaysCostume(app, timeout: 5), "31 October's board did not dress the peach")
    }

    func testTheDaysBoardReplayedLaterWearsIt() {
        let app = reveal(["-dayOffset", offset(to: nextHalloween, plus: 5), "-archiveDay", "5"])
        XCTAssertTrue(app.buttons["Back to today"].waitForExistence(timeout: 30),
                      "the past board never opened")
        waitForTheCard(app)
        XCTAssertTrue(peachSaysCostume(app, timeout: 5),
                      "31 October's board, replayed on 5 November, did not dress the peach")
        // The way back is a chevron since 22 October 2026, not #93's peach, and
        // a chevron wears nothing, on this board or any.
        XCTAssertEqual(app.buttons["BoardHome"].label, "Back to the title screen",
                       "31 October's board's way back is not the plain chevron")
    }

    func testAnotherDaysBoardOnTheDayDoesNot() {
        let app = reveal(["-dayOffset", offset(to: nextHalloween), "-archiveDay", "1"])
        XCTAssertTrue(app.buttons["Back to today"].waitForExistence(timeout: 30),
                      "the past board never opened")
        waitForTheCard(app)
        XCTAssertFalse(peachSaysCostume(app, timeout: 3),
                       "30 October's board, played on 31 October, dressed the peach")
        XCTAssertEqual(app.buttons["BoardHome"].label, "Back to the title screen",
                       "30 October's board's way back is not the plain chevron")
    }

    /// The title shows today, so its peach wears today's costume: plain on 30
    /// October, and the ghost when the app comes back on the 31st. Play then
    /// opens that day's board, whose way back is the plain chevron; until
    /// 22 October 2026 it was a peach, and wore the ghost too.
    func testTheTitleWearsTodaysCostume() {
        // A Halloween whose eve is still to come, so the offset is never
        // negative, even when the suite runs on the 31st.
        let cal = Calendar.current
        let halloween = cal.isDate(nextHalloween, inSameDayAs: TestClock.now)
            ? cal.date(byAdding: .year, value: 1, to: nextHalloween)! : nextHalloween
        let app = XCUIApplication()
        app.launchArguments = ["-showTitle", "1", "-resetProgress", "1", "-seedBoard", "3",
                               "-dayOffset", offset(to: halloween, plus: -1),
                               "-dayOffsetOnResume", "1",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()
        let play = app.buttons["TitlePlay"]
        XCTAssertTrue(play.waitForExistence(timeout: 30), "no title on 30 October")
        XCTAssertFalse(peachSaysCostume(app, timeout: 3), "the title dressed the peach on 30 October")

        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 2)
        app.activate()
        XCTAssertTrue(peachSaysCostume(app, timeout: 15),
                      "the title did not dress the peach on 31 October")

        let enabled = expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: play)
        XCTAssertEqual(XCTWaiter().wait(for: [enabled], timeout: 30), .completed)
        play.tap()
        let home = app.buttons["BoardHome"]
        XCTAssertTrue(home.waitForExistence(timeout: 10), "Play did not open the board")
        XCTAssertEqual(home.label, "Back to the title screen", "31 October's way back is not the plain chevron")
    }

    /// And the day after, plain again.
    func testTheTitleTheDayAfterDoesNot() {
        let app = XCUIApplication()
        app.launchArguments = ["-showTitle", "1", "-resetProgress", "1",
                               "-dayOffset", offset(to: nextHalloween, plus: 1),
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()
        XCTAssertTrue(app.buttons["TitlePlay"].waitForExistence(timeout: 30), "no title on 1 November")
        XCTAssertFalse(peachSaysCostume(app, timeout: 3), "the title dressed the peach on 1 November")
    }

    /// The costume must not move anything: the source word's chip, with the
    /// peach in costume, takes exactly the frame it takes plain, at the default
    /// text size and at the largest.
    func testTheCostumeDoesNotChangeTheChipsFootprint() {
        for size in ["UICTContentSizeCategoryL", "UICTContentSizeCategoryAccessibilityXXXL"] {
            func chip(_ extra: [String]) -> (frame: CGRect, label: String) {
                let app = XCUIApplication()
                app.launchArguments = ["-resetProgress", "1", "-replaySource", "1",
                                       "-UIPreferredContentSizeCategoryName", size] + extra
                app.launch()
                let source = app.buttons.matching(
                    NSPredicate(format: "label CONTAINS %@", ", source word")).firstMatch
                XCTAssertTrue(source.waitForExistence(timeout: 30), "no source-word chip at \(size)")
                let result = (source.frame, source.label)
                app.terminate()
                return result
            }
            let plain = chip([])
            let worn = chip(["-costumeDate", "2026-10-31"])
            XCTAssertTrue(worn.label.contains("the peach in a ghost sheet"),
                          "the chip did not wear the costume at \(size): \(worn.label)")
            XCTAssertEqual(plain.frame, worn.frame, "the costume moved the chip at \(size)")
        }
    }
}
