import XCTest

/// The winter's costumes, held to `CostumeOnTheDay`'s rules on each of their
/// days: today's board on the day wears the day's costume, the day's board
/// replayed later from the calendar does too, and another day's board played
/// on the day does not. The engine's `WinterCostumeDayTests` hold the dates;
/// these hold the app to passing it the board's day, never today's.
final class WinterCostumesOnTheDay: XCTestCase {
    /// Each costume day, how to find it in a year, and what the reveal card's
    /// peach says on it. Thanksgiving is the fourth Thursday of November,
    /// worked out here by `Calendar` rather than by the engine's own rule. New
    /// Year's Eve and Day share the top hat, so each is its own day here.
    private static let days: [(name: String, on: @Sendable (Int) -> DateComponents, spoken: String)] = [
        ("Thanksgiving", { DateComponents(year: $0, month: 11, weekday: 5, weekdayOrdinal: 4) },
         "The peach is wearing a pie crust hat."),
        ("24 December", { DateComponents(year: $0, month: 12, day: 24) },
         "The peach is wearing antlers and a red nose."),
        ("31 December", { DateComponents(year: $0, month: 12, day: 31) },
         "The peach is wearing a top hat."),
        ("1 January", { DateComponents(year: $0, month: 1, day: 1) },
         "The peach is wearing a top hat."),
    ]

    /// The next such day on or after today, since a negative `-dayOffset` is
    /// dropped; see `CostumeOnTheDay.nextHalloween`.
    private func next(_ on: (Int) -> DateComponents) -> Date {
        let cal = Calendar.current
        let today = cal.startOfDay(for: TestClock.now)
        let year = cal.component(.year, from: today)
        let thisYear = cal.date(from: on(year))!
        return thisYear >= today ? thisYear : cal.date(from: on(year + 1))!
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
        for (name, on, spoken) in Self.days {
            let app = reveal(["-dayOffset", offset(to: next(on))])
            waitForTheCard(app)
            XCTAssertTrue(peachSays(app, any: [spoken], timeout: 5),
                          "\(name)'s board did not say \"\(spoken)\"")
            app.terminate()
        }
    }

    func testEachDaysBoardReplayedLaterWearsIt() {
        for (name, on, spoken) in Self.days {
            let app = reveal(["-dayOffset", offset(to: next(on), plus: 5), "-archiveDay", "5"])
            XCTAssertTrue(app.buttons["Back to today"].waitForExistence(timeout: 30),
                          "the past board never opened")
            waitForTheCard(app)
            XCTAssertTrue(peachSays(app, any: [spoken], timeout: 5),
                          "\(name)'s board, replayed five days later, did not say \"\(spoken)\"")
            app.terminate()
        }
    }

    /// Two days before each is a plain day, now and once the solstice and
    /// Christmas Day dress: the Tuesday before Thanksgiving, 22 December, and
    /// 29 and 30 December.
    func testAnotherDaysBoardOnEachDayDoesNot() {
        for (name, on, _) in Self.days {
            let app = reveal(["-dayOffset", offset(to: next(on)), "-archiveDay", "2"])
            XCTAssertTrue(app.buttons["Back to today"].waitForExistence(timeout: 30),
                          "the past board never opened")
            waitForTheCard(app)
            // Any costume's line, Halloween's too; the growing peach's stages
            // say "The peach is" as well, so that alone is not a costume.
            let anyCostume = Self.days.map(\.spoken) + ["The peach is in a ghost sheet."]
            XCTAssertFalse(peachSays(app, any: anyCostume, timeout: 3),
                           "the board two days before \(name), played on it, dressed the peach")
            app.terminate()
        }
    }
}
