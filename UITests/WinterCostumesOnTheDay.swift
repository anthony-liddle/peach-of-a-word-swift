import XCTest

/// The winter's costumes, held to `CostumeOnTheDay`'s rules on each of their
/// days: today's board on the day wears the day's costume, the day's board
/// replayed later from the calendar does too, and another day's board played
/// on the day does not. The engine's `WinterCostumeDayTests` hold the dates;
/// these hold the app to passing it the board's day, never today's.
final class WinterCostumesOnTheDay: XCTestCase {
    /// Each costume date, and what the reveal card's peach says on it. New
    /// Year's Eve and Day share the top hat, so each is its own date here.
    private static let days: [(month: Int, day: Int, spoken: String)] = [
        (11, 26, "The peach is wearing a pie crust hat."),
        (12, 24, "The peach is wearing antlers and a red nose."),
        (12, 31, "The peach is wearing a top hat."),
        (1, 1, "The peach is wearing a top hat."),
    ]

    /// The next `month` and `day` on or after today, since a negative
    /// `-dayOffset` is dropped; see `CostumeOnTheDay.nextHalloween`.
    private func next(_ month: Int, _ day: Int) -> Date {
        let cal = Calendar.current
        let today = cal.startOfDay(for: TestClock.now)
        let year = cal.component(.year, from: today)
        let thisYear = cal.date(from: DateComponents(year: year, month: month, day: day))!
        return thisYear >= today
            ? thisYear : cal.date(from: DateComponents(year: year + 1, month: month, day: day))!
    }

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

    /// Whether the peach says any of `lines`, as its label.
    private func peachSays(_ app: XCUIApplication, any lines: [String],
                           timeout: TimeInterval) -> Bool {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label IN %@", lines))
            .firstMatch.waitForExistence(timeout: timeout)
    }

    private func waitForTheCard(_ app: XCUIApplication) {
        XCTAssertTrue(app.staticTexts["You found the Peach of a Word!"].waitForExistence(timeout: 30),
                      "the reveal card never opened")
    }

    func testEachDaysBoardOnTheDayWearsIt() {
        for (month, day, spoken) in Self.days {
            let app = reveal(["-dayOffset", offset(to: next(month, day))])
            waitForTheCard(app)
            XCTAssertTrue(peachSays(app, any: [spoken], timeout: 5),
                          "\(day)/\(month)'s board did not say \"\(spoken)\"")
            app.terminate()
        }
    }

    func testEachDaysBoardReplayedLaterWearsIt() {
        for (month, day, spoken) in Self.days {
            let app = reveal(["-dayOffset", offset(to: next(month, day), plus: 5), "-archiveDay", "5"])
            XCTAssertTrue(app.buttons["Back to today"].waitForExistence(timeout: 30),
                          "the past board never opened")
            waitForTheCard(app)
            XCTAssertTrue(peachSays(app, any: [spoken], timeout: 5),
                          "\(day)/\(month)'s board, replayed five days later, did not say \"\(spoken)\"")
            app.terminate()
        }
    }

    /// Two days before each is a plain day, now and once the solstice and
    /// Christmas Day dress: 24 November, 22 December, 29 and 30 December.
    func testAnotherDaysBoardOnEachDayDoesNot() {
        for (month, day, _) in Self.days {
            let app = reveal(["-dayOffset", offset(to: next(month, day)), "-archiveDay", "2"])
            XCTAssertTrue(app.buttons["Back to today"].waitForExistence(timeout: 30),
                          "the past board never opened")
            waitForTheCard(app)
            // Any costume's line, Halloween's too; the growing peach's stages
            // say "The peach is" as well, so that alone is not a costume.
            let anyCostume = Self.days.map(\.spoken) + ["The peach is in a ghost sheet."]
            XCTAssertFalse(peachSays(app, any: anyCostume, timeout: 3),
                           "the board two days before \(day)/\(month), played on it, dressed the peach")
            app.terminate()
        }
    }
}
