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

    /// The `-dayOffset` that makes the app's today the given local date.
    private func offset(to year: Int, _ month: Int, _ day: Int) -> String {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let target = cal.date(from: DateComponents(year: year, month: month, day: day))!
        return String(cal.dateComponents([.day], from: today, to: target).day!)
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
        let app = reveal(["-dayOffset", offset(to: 2026, 10, 31)])
        waitForTheCard(app)
        XCTAssertTrue(peachSaysCostume(app, timeout: 5), "31 October's board did not dress the peach")
    }

    func testTheDaysBoardReplayedLaterWearsIt() {
        let app = reveal(["-dayOffset", offset(to: 2026, 11, 5), "-archiveDay", "5"])
        XCTAssertTrue(app.buttons["Back to today"].waitForExistence(timeout: 30),
                      "the past board never opened")
        waitForTheCard(app)
        XCTAssertTrue(peachSaysCostume(app, timeout: 5),
                      "31 October's board, replayed on 5 November, did not dress the peach")
    }

    func testAnotherDaysBoardOnTheDayDoesNot() {
        let app = reveal(["-dayOffset", offset(to: 2026, 10, 31), "-archiveDay", "1"])
        XCTAssertTrue(app.buttons["Back to today"].waitForExistence(timeout: 30),
                      "the past board never opened")
        waitForTheCard(app)
        XCTAssertFalse(peachSaysCostume(app, timeout: 3),
                       "30 October's board, played on 31 October, dressed the peach")
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
