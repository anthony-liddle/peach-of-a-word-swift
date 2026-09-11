import XCTest

/// Paging the archive a month at a time.
///
/// The sheet used to scroll every month at once and had to land on today. It now
/// shows one month, and moving between them is a button rather than a scroll
/// position, so what can break is the bounds, the two halves of a page moving
/// together, and the swipe taking a tap that belonged to a day.
final class ArchiveMonthPaging: XCTestCase {
    private func openArchive(month: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-resetProgress", "1", "-seedArchive", "showcase", "-openArchive", "1",
        ] + (month.map { ["-archiveMonth", $0] } ?? [])
        app.launch()
        XCTAssertTrue(app.buttons["Back to the basket"].waitForExistence(timeout: 30),
                      "the archive sheet never opened")
        return app
    }

    private func title(_ app: XCUIApplication) -> String {
        app.staticTexts["ArchiveMonthTitle"].firstMatch.label
    }

    /// The month a title names, lowercased, so cells can be checked against it.
    private func monthWord(_ title: String) -> String {
        (title.split(separator: " ").first.map(String.init) ?? "").lowercased()
    }

    private func dayCells(_ app: XCUIApplication) -> [XCUIElement] {
        let all = app.buttons.matching(
            NSPredicate(format: "identifier == %@ OR identifier == %@",
                        "ArchiveDayCell", "ArchiveTodayCell"))
        return (0..<all.count).map { all.element(boundBy: $0) }
    }

    // MARK: The bounds

    /// June 2026 holds the first playable board, so there is nothing before it.
    func testPreviousIsRefusedOnTheFirstMonth() {
        let app = openArchive(month: "2026-06")
        XCTAssertEqual(monthWord(title(app)), "june", "did not open on June")
        XCTAssertFalse(app.buttons["ArchivePreviousMonth"].isEnabled,
                       "the first month offered a month before it")
        XCTAssertTrue(app.buttons["ArchiveNextMonth"].isEnabled,
                      "the first month refused the month after it")
    }

    /// The sheet opens on the current month, and there is nothing after it.
    func testNextIsRefusedOnTheCurrentMonth() {
        let app = openArchive()
        XCTAssertFalse(app.buttons["ArchiveNextMonth"].isEnabled,
                       "the current month offered a month after it")
        XCTAssertTrue(app.buttons["ArchivePreviousMonth"].isEnabled,
                      "the current month refused the month before it")
    }

    // MARK: A step

    /// **The title and the cells are one page, so they move together.** A title
    /// that changed while the grid did not would be the worst version of this
    /// bug: it reads as correct and every date under it is a lie.
    func testAStepMovesTheTitleAndTheCellsTogether() {
        let app = openArchive()
        let before = title(app)
        XCTAssertFalse(before.isEmpty, "no month title")
        for cell in dayCells(app) {
            XCTAssertTrue(cell.label.lowercased().hasPrefix(monthWord(before)),
                          "a cell said \(cell.label) under the title \(before)")
        }

        app.buttons["ArchivePreviousMonth"].tap()

        let after = title(app)
        XCTAssertNotEqual(after, before, "the title did not change")
        let cells = dayCells(app)
        XCTAssertGreaterThan(cells.count, 0, "the month after a step drew no days")
        for cell in cells {
            XCTAssertTrue(cell.label.lowercased().hasPrefix(monthWord(after)),
                          "after a step a cell said \(cell.label) under the title \(after)")
        }
    }

    // MARK: What a page is for

    func testADayOnAPastMonthStillOpensThatBoard() {
        let app = openArchive(month: "2026-07")
        XCTAssertEqual(monthWord(title(app)), "july", "did not open on July")
        let playable = app.buttons
            .matching(NSPredicate(format: "label CONTAINS %@", "Finished"))
            .element(boundBy: 0)
        guard playable.waitForExistence(timeout: 10) else {
            return XCTFail("July drew no playable day")
        }
        playable.tap()
        XCTAssertTrue(app.staticTexts["ArchiveDateRow"].waitForExistence(timeout: 20),
                      "a day on a past month did not open its board")
    }

    /// **The swipe is an enhancement and must cost nothing.** A gesture that
    /// swallowed taps would take the day cells with it, which is the whole
    /// content of the sheet, and it would look fine in a screenshot.
    func testASwipeDoesNotTakeATapFromADayCell() {
        let app = openArchive()
        let before = title(app)
        app.scrollViews["ArchiveScroll"].firstMatch.swipeRight()

        let after = title(app)
        XCTAssertNotEqual(after, before, "a swipe to the right did not go to the previous month")

        let playable = app.buttons
            .matching(NSPredicate(format: "label CONTAINS %@", "Finished"))
            .element(boundBy: 0)
        guard playable.waitForExistence(timeout: 10) else {
            return XCTFail("the month reached by swiping drew no playable day")
        }
        playable.tap()
        XCTAssertTrue(app.staticTexts["ArchiveDateRow"].waitForExistence(timeout: 20),
                      "after a swipe, tapping a day did not open its board")
    }
}
