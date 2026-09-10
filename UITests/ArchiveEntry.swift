import XCTest

/// The way in to the archive, and one past board opened through it.
///
/// The entry point could not be checked any other way. It is a 44pt target drawn
/// as an overlay on a row it deliberately does not belong to, and the thing worth
/// asserting is that it is still reachable and still opens a board, which is a
/// gesture rather than a state a launch argument can set up.
final class ArchiveEntry: XCTestCase {
    private func launched() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-resetProgress", "1",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL",
        ]
        app.launch()
        XCTAssertTrue(app.staticTexts["FoundSummaryCount"].waitForExistence(timeout: 30),
                      "the app never rendered the found summary")
        return app
    }

    /// The button rides the meter's top row as an overlay, so "is it hittable"
    /// is a real question rather than a formality.
    func testTheArchiveButtonOpensTheCalendar() {
        let app = launched()
        let entry = app.buttons["Past days"].firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 10), "no way in to the archive")
        XCTAssertTrue(entry.isHittable, "the archive button is present but not hittable")
        entry.tap()

        XCTAssertTrue(app.buttons["Back to the basket"].waitForExistence(timeout: 10),
                      "the archive sheet did not open")
    }

    /// The whole path: open the calendar, pick a day that is not today, and end
    /// up on that board.
    ///
    /// The day is chosen by its spoken state rather than by its date. Dates move
    /// every morning, and a test that names one passes on one day in seventy;
    /// `LayoutBudget` records that trap after being caught by it.
    func testAPastDayOpensItsOwnBoard() {
        let app = launched()
        XCTAssertFalse(app.staticTexts["ArchiveDateRow"].exists,
                       "today's board is claiming to be an archive board")

        app.buttons["Past days"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Back to the basket"].waitForExistence(timeout: 10))

        // Explicitly not today, and that exclusion is load-bearing.
        //
        // The grid opens anchored to its newest end, and `LazyVGrid` does not
        // build rows that start off screen, so "the first unplayed cell" is
        // whatever happens to be visible rather than the oldest day. On a fresh
        // install today is unplayed too, and picking it would open today's board
        // and fail this test for a reason that has nothing to do with the
        // archive. Issue #40 is the same lazy-grid behaviour biting a different
        // test.
        let past = app.buttons
            .matching(NSPredicate(
                format: "label CONTAINS %@ AND NOT (label CONTAINS %@)",
                "Still on the tree", "today"))
            .element(boundBy: 0)
        guard past.waitForExistence(timeout: 10) else {
            return XCTFail("the calendar drew no playable past day")
        }
        past.tap()

        XCTAssertTrue(app.staticTexts["ArchiveDateRow"].waitForExistence(timeout: 20),
                      "tapping a past day did not open its board")
    }

    /// A day that has not happened is the seventh state, and it must be inert in
    /// the grid as well as refused in the model.
    func testTomorrowIsNotOfferedAtAll() {
        let app = launched()
        app.buttons["Past days"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Back to the basket"].waitForExistence(timeout: 10))

        // The grid runs to the end of the current month now, so days after
        // today are drawn rather than absent: that is the seventh state, and it
        // had nowhere to appear while the range stopped at today. Drawn is not
        // the same as offered, and this asserts the difference.
        let notYet = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "Not yet")
        )
        XCTAssertGreaterThan(notYet.count, 0,
                             "no future day was drawn, so the seventh state is unreachable")
        XCTAssertFalse(notYet.element(boundBy: 0).isEnabled,
                       "the archive offered a day that has not happened yet")
    }
}
