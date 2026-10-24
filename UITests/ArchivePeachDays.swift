import XCTest

/// The calendar's peach: a day you found the peach of a word on says so, in
/// the calendar and in the title's week, and its cell does not grow for it.
///
/// Seeded with `bea`, which saves every common word on the days one, four and
/// nine back, the day's own among them, and leaves the days from fourteen back
/// to the streak, with no words at all. Whether a day's words include its own
/// is the engine's, `PeachDaysTests`, which also holds a day with words but not
/// its own; the seed has no such day on a date this could rely on.
final class ArchivePeachDays: XCTestCase {
    static let phrase = "you found the Peach of a Word"

    private func date(daysAgo: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -daysAgo, to: TestClock.now)!
    }

    /// `-archiveMonth`'s key for the month holding that day, on the phone's
    /// calendar, as `ArchiveBeaFirstOpen` writes it.
    private func monthKey(daysAgo: Int) -> String {
        let parts = Calendar.current.dateComponents([.year, .month], from: date(daysAgo: daysAgo))
        return String(format: "%04d-%02d", parts.year!, parts.month!)
    }

    private func calendar(showing daysAgo: Int,
                          size: String = "UICTContentSizeCategoryL") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-seedArchive", "bea", "-openArchive", "1",
                               "-archiveMonth", monthKey(daysAgo: daysAgo),
                               "-UIPreferredContentSizeCategoryName", size]
        app.launch()
        XCTAssertTrue(app.buttons["Back to the basket"].waitForExistence(timeout: 60),
                      "the archive sheet never opened")
        return app
    }

    /// The day's cell, found by the date its label starts with, as `ArchiveCell`
    /// writes it. The comma keeps "October 2" from matching "October 22".
    private func cell(_ app: XCUIApplication, daysAgo: Int) -> XCUIElement? {
        let formatter = DateFormatter()
        formatter.calendar = .current
        formatter.setLocalizedDateFormatFromTemplate("MMMM d")
        let prefix = formatter.string(from: date(daysAgo: daysAgo)) + ","
        return app.buttons.matching(
            NSPredicate(format: "identifier == %@ OR identifier == %@", "ArchiveDayCell", "ArchiveTodayCell")
        ).allElementsBoundByIndex.first { $0.label.hasPrefix(prefix) }
    }

    func testADayYouFoundItsWordOnSaysSo() {
        for back in [1, 4, 9] {
            let app = calendar(showing: back)
            let label = cell(app, daysAgo: back)?.label
            XCTAssertNotNil(label, "no cell for the day \(back) back")
            XCTAssertTrue(label?.contains(Self.phrase) == true,
                          "the day \(back) back has its word found and does not say so: \(label ?? "")")
            app.terminate()
        }
    }

    /// Days the streak keeps, with no words, and today, unplayed.
    func testADayWithNoWordsSaysNothing() {
        for back in [0, 20] {
            let app = calendar(showing: back)
            let label = cell(app, daysAgo: back)?.label
            XCTAssertNotNil(label, "no cell for the day \(back) back")
            XCTAssertFalse(label?.contains(Self.phrase) == true,
                           "the day \(back) back has no words and claims its own: \(label ?? "")")
            app.terminate()
        }
    }

    /// The title's week draws the calendar's face, and says what it says.
    /// `-resetProgress` too, which clears the day the title last showed, or a
    /// title an earlier test opened today keeps this one on the board.
    func testTheWeekSaysItToo() {
        let app = XCUIApplication()
        app.launchArguments = ["-showTitle", "1", "-resetProgress", "1", "-seedArchive", "bea",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()
        let today = app.buttons["WeekToday"]
        XCTAssertTrue(today.waitForExistence(timeout: 60), "no week on the title")
        // Waited for: the seed lands after the title is first drawn, and the
        // week is read again when the board it seeds becomes ready.
        let yesterday = date(daysAgo: 1).formatted(.dateTime.weekday(.wide).day().month(.wide))
        let marked = app.buttons.matching(NSPredicate(
            format: "identifier == 'WeekDay' AND label BEGINSWITH %@ AND label CONTAINS %@",
            yesterday + ",", Self.phrase)).firstMatch
        let label = app.buttons.matching(identifier: "WeekDay").allElementsBoundByIndex
            .map { $0.label }.first { $0.hasPrefix(yesterday + ",") }
        XCTAssertTrue(marked.waitForExistence(timeout: 40),
                      "yesterday's word was found and the week does not say so: \(label ?? "no cell")")
        XCTAssertFalse(today.label.contains(Self.phrase), "today is unplayed and claims its word")
    }

    /// The peach is drawn over the cell, never beside it: at every size, a day
    /// with the peach is the size of a day without one in the same month.
    /// Shown red first with the peach under the face instead.
    func testThePeachDoesNotGrowItsCell() {
        for size in RackAtLargeText.sizes {
            let app = calendar(showing: 1, size: size)
            guard let peach = cell(app, daysAgo: 1) else {
                XCTFail("no cell for yesterday at \(size)"); app.terminate(); continue
            }
            let plain = app.buttons.matching(identifier: "ArchiveDayCell").allElementsBoundByIndex
                .first { !$0.label.contains(Self.phrase) }
            XCTAssertNotNil(plain, "no day without the peach at \(size)")
            if let plain {
                XCTAssertEqual(peach.frame.width, plain.frame.width, accuracy: 0.5,
                               "a peach widened its cell at \(size)")
                XCTAssertEqual(peach.frame.height, plain.frame.height, accuracy: 0.5,
                               "a peach heightened its cell at \(size)")
            }
            app.terminate()
        }
    }
}
