import XCTest

/// A day whose record is below its board is raised when the board opens.
///
/// What a word demoted out of the basket leaves behind: a board one short of
/// full recomputes as a full basket, over an outcome written when it was one
/// short. The calendar drew the day finished while the board said full, and the
/// next find on it, any find, played the full basket card and recorded the
/// basket as caught up later. No launch can edit the shipped lists, so the
/// record is written low instead: the day played to a full basket, then
/// `-seedOutcome cleared` puts it back to finished. Shown red first on the
/// opening that raised nothing.
///
/// **21 October 2026, on a clock moved to it,** because the next find has to be
/// a word the rack can spell and the basket does not hold. REASSURE is that
/// day's crown for good, the calendar being append-only, and ERASURE is off its
/// page.
final class ARecordBelowItsBoard: XCTestCase {
    private static let size = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]

    private var day: Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 21))!
    }

    /// The `-dayOffset` that makes the app's today `days` after the 21st.
    /// Negative once the real date is past it, which `-dayOffset` takes.
    private func offset(daysAfter days: Int) -> String {
        let cal = Calendar.current
        let target = cal.date(byAdding: .day, value: days, to: day)!
        return String(cal.dateComponents([.day], from: cal.startOfDay(for: TestClock.now),
                                         to: target).day!)
    }

    private func keepPlaying(_ app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label ==[c] %@", "Keep playing")).firstMatch
    }

    /// The day's cell in the calendar, opened from the board and closed again.
    private func calendarSays(_ app: XCUIApplication, file: StaticString = #filePath,
                              line: UInt = #line) -> String {
        app.buttons["Past days"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Back to the basket"].waitForExistence(timeout: 10),
                      "the calendar did not open", file: file, line: line)
        let formatter = DateFormatter()
        formatter.calendar = .current
        formatter.setLocalizedDateFormatFromTemplate("MMMM d")
        let prefix = formatter.string(from: day) + ","
        let label = app.buttons.matching(identifier: "ArchiveDayCell").allElementsBoundByIndex
            .map { $0.label }.first { $0.hasPrefix(prefix) } ?? "no cell"
        app.buttons["Back to the basket"].firstMatch.tap()
        return label
    }

    func testOpeningTheBoardRaisesItsDayAndPlaysNoCard() {
        let app = XCUIApplication()
        app.launchArguments = ["-resetProgress", "1", "-dayOffset", offset(daysAfter: 0),
                               "-seedBoard", "full", "-seedOutcome", "cleared"] + Self.size
        app.launch()
        XCTAssertTrue(app.staticTexts["FoundSummaryCount"].waitForExistence(timeout: 60),
                      "the day was never seeded")
        app.terminate()

        // Six days on, the title's week reads the record as it was left.
        app.launchArguments = ["-dayOffset", offset(daysAfter: 6)] + Self.size
        app.launch()
        let weekday = day.formatted(.dateTime.weekday(.wide).day().month(.wide)) + ","
        let cell = app.buttons.matching(NSPredicate(
            format: "identifier == 'WeekDay' AND label BEGINSWITH %@", weekday)).firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 60), "no cell for the 21st on the week")
        XCTAssertTrue(cell.label.contains("Finished"),
                      "the seed did not leave the day below its board: \(cell.label)")
        for _ in 0..<40 where !cell.isEnabled { usleep(250_000) }
        cell.tap()

        let summary = app.staticTexts["FoundSummaryCount"]
        XCTAssertTrue(app.staticTexts["ArchiveDateRow"].waitForExistence(timeout: 30),
                      "the week did not open the 21st")
        let counts = summary.label.split(separator: " ")
        XCTAssertTrue(counts.count >= 3 && counts[0] == counts[2],
                      "the board is not a full basket, so this tests nothing: \(summary.label)")

        // Opening: no card, and the calendar agrees with the board, on the day.
        sleep(2)
        XCTAssertFalse(keepPlaying(app).exists, "opening the board played the full basket card")
        let opened = calendarSays(app)
        XCTAssertTrue(opened.contains("Basket full"), "the calendar still reads below the board: \(opened)")
        XCTAssertFalse(opened.contains("caught up later"), "opening moved the day off its own: \(opened)")

        // The next find, off the page: still no card, and still the day itself.
        let tiles = app.buttons.matching(NSPredicate(format: "label MATCHES %@", "^Letter [a-z].*"))
            .allElementsBoundByIndex
        var used = Set<Int>()
        for letter in "erasure" {
            guard let index = tiles.indices.first(where: {
                !used.contains($0) && tiles[$0].label.hasPrefix("Letter \(letter)")
            }) else { return XCTFail("the 21st's rack cannot spell erasure: stuck at \(letter)") }
            used.insert(index)
            tiles[index].tap()
        }
        app.buttons["Pick word"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "erasure"))
            .firstMatch.waitForExistence(timeout: 10), "erasure was not accepted, so no find was made")
        sleep(2)
        XCTAssertFalse(keepPlaying(app).exists,
                       "an off-page find played the full basket card for a basket nobody just completed")
        if keepPlaying(app).exists { keepPlaying(app).tap() }
        let found = calendarSays(app)
        XCTAssertTrue(found.contains("Basket full"), "the calendar reads below the board: \(found)")
        XCTAssertFalse(found.contains("caught up later"),
                       "the next find recorded the basket as caught up later: \(found)")
    }
}
