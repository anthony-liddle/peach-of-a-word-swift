import XCTest

/// The order of the page, top to bottom.
///
/// **A calendar's furniture is only useful in one order, and the sheet had it
/// wrong.** The key came first, then the weekday letters, then the month name,
/// then the grid: a legend before the thing it explains, and column headings
/// above the title of the month whose columns they head. That order was not a
/// mistake when it was written. The sheet scrolled every month at once, so the
/// letters headed all of them and had to sit above the scroll. One month to a
/// page took the reason away and left the order behind.
///
/// These are frames rather than appearances, because "above" is a number.
///
/// The weekday row is not asserted here: it is `accessibilityHidden`, so it is
/// not in the tree to measure, which is correct for a row of decorative
/// initials that the cells already speak. Its placement and its alignment with
/// the grid columns are checked in pixels instead, in
/// `2026-09-11 The Month Page Layout.md`.
final class ArchivePageOrder: XCTestCase {
    private func openArchive(_ size: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-resetProgress", "1", "-seedArchive", "showcase", "-openArchive", "1",
            "-UIPreferredContentSizeCategoryName", size,
        ]
        app.launch()
        XCTAssertTrue(app.buttons["Back to the basket"].waitForExistence(timeout: 30),
                      "the archive sheet never opened")
        return app
    }

    /// Every day cell on screen, which is the whole month at default size.
    private func dayCells(_ app: XCUIApplication) -> [XCUIElement] {
        let cells = app.buttons.matching(identifier: "ArchiveDayCell").allElementsBoundByIndex
        let today = app.buttons["ArchiveTodayCell"].firstMatch
        return today.exists ? cells + [today] : cells
    }

    /// **This one does not discriminate the reorder, and it is kept anyway.**
    /// Run against the old order it passes, because the month name was already
    /// directly above the grid there; what sat wrong was the key and the
    /// weekday row above it, and the weekday row cannot be measured from here.
    /// It guards the title never falling below the grid, which is worth having
    /// and is not what item 1 changed. `testTheKeySitsBelowTheGrid` is the one
    /// that goes red on the old order.
    func testTheMonthTitleSitsAboveTheGridAndUnderTheSheetTitle() {
        let app = openArchive("UICTContentSizeCategoryL")

        let sheetTitle = app.staticTexts["Past days"].firstMatch
        XCTAssertTrue(sheetTitle.waitForExistence(timeout: 10), "no sheet title")
        let monthTitle = app.staticTexts["ArchiveMonthTitle"].firstMatch
        XCTAssertTrue(monthTitle.waitForExistence(timeout: 10), "no month title")

        let cells = dayCells(app)
        XCTAssertFalse(cells.isEmpty, "no day cells")
        let gridTop = cells.map { $0.frame.minY }.min() ?? 0

        XCTAssertLessThanOrEqual(
            sheetTitle.frame.maxY, monthTitle.frame.minY,
            "the sheet title is not above the month name")
        XCTAssertLessThanOrEqual(
            monthTitle.frame.maxY, gridTop,
            "the month name is not above the grid it names")
    }

    func testTheKeySitsBelowTheGrid() {
        let app = openArchive("UICTContentSizeCategoryL")

        let items = app.descendants(matching: .any)
            .matching(identifier: "ArchiveKeyItem").allElementsBoundByIndex
        XCTAssertEqual(items.count, 4, "the key does not have its four states")

        let cells = dayCells(app)
        XCTAssertFalse(cells.isEmpty, "no day cells")
        let gridBottom = cells.map { $0.frame.maxY }.max() ?? 0
        let keyTop = items.map { $0.frame.minY }.min() ?? 0

        XCTAssertGreaterThanOrEqual(
            keyTop, gridBottom,
            "the key is above the grid it explains")

        // And still above the way out, which is the last thing on the sheet.
        //
        // **Compared top to top, because the way out's frame is now its band.**
        // It used to be the lettering, and a key ending where the band's top
        // padding begins failed this by 0.15pt: 751.44 against 751.29. That is
        // the two controls sitting flush, not the key falling past anything.
        // Ordering is what this asserts, so it asks which starts first and
        // which ends first rather than measuring a gap that is padding.
        let wayOut = app.buttons["Back to the basket"].firstMatch
        let keyBottom = items.map { $0.frame.maxY }.max() ?? 0
        XCTAssertLessThanOrEqual(
            keyTop, wayOut.frame.minY,
            "the key starts below the way out")
        XCTAssertLessThanOrEqual(
            keyBottom, wayOut.frame.maxY,
            "the key has fallen past the way out")
    }
}
