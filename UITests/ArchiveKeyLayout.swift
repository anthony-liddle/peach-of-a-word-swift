import XCTest

/// The key at accessibility sizes, which is issue #66.
///
/// **The key was taking the calendar's room.** Four fixed columns above the
/// grid, each a quarter of the width, left 173.3pt of grid on a 390pt phone and
/// 92.0pt on an SE 3 at AX5, against roughly 300pt for a six row month. Two rows
/// of a calendar is not a calendar. The same quarter width was breaking three of
/// the four labels inside a word.
///
/// Below the grid and inside its scroll, the grid gets the viewport and the key
/// is one scroll away. What the labels do with their new width is a matter of
/// pixels and is checked in the report; what the grid gets back is a number and
/// is checked here.
final class ArchiveKeyLayout: XCTestCase {
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

    private func anyCell(_ app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(identifier: "ArchiveDayCell").element(boundBy: 0)
    }

    /// Four rows of cells, which is the point of the change.
    ///
    /// A row is a cell plus the 5pt gap, and the cell is taken from the running
    /// app rather than restated here, so the floor moves with the grid rather
    /// than having to be kept in step with it by hand.
    func testTheGridKeepsTheViewportAtAccessibilitySize() {
        let app = openArchive("UICTContentSizeCategoryAccessibilityXXXL")
        let scroll = app.scrollViews["ArchiveScroll"].firstMatch
        XCTAssertTrue(scroll.waitForExistence(timeout: 10), "no archive scroll view")

        let cell = anyCell(app)
        XCTAssertTrue(cell.waitForExistence(timeout: 10), "no day cell")
        let row = cell.frame.height + 5
        let fourRows = row * 4 - 5

        print(String(format: "KEYLAYOUT viewport %.1f cell %.1f fourRows %.1f",
                     scroll.frame.height, cell.frame.height, fourRows))

        XCTAssertGreaterThanOrEqual(
            scroll.frame.height, fourRows,
            "the grid has \(scroll.frame.height)pt, under four rows at \(fourRows)pt")
    }

    /// **One state per row, left aligned, which is the whole of the wrapping
    /// fix.**
    ///
    /// Four columns gave each state a quarter of the width, and a quarter of a
    /// 390pt phone is about 97pt, which at AX5 is narrower than the word
    /// "Started". A `Text` breaks inside a word only when the word cannot fit
    /// the line at all, so "Star / ted" was the column width being reported
    /// rather than a wrapping setting.
    ///
    /// This asserts the arrangement, not the wrapping. XCUITest reads a label as
    /// its whole string and cannot see where the lines fell. It cannot read the
    /// offered width either: an accessibility element's frame is the union of
    /// what its children actually drew, so a short label like "Started" comes
    /// back 161.7pt wide in a row that is 354pt across. What it can see is that
    /// the states are stacked rather than side by side, which is the change.
    func testTheKeyStatesAreStackedAtAccessibilitySize() {
        let app = openArchive("UICTContentSizeCategoryAccessibilityXXXL")
        let items = app.descendants(matching: .any)
            .matching(identifier: "ArchiveKeyItem").allElementsBoundByIndex
        XCTAssertEqual(items.count, 4, "the key does not have its four states")

        let ordered = items.sorted { $0.frame.minY < $1.frame.minY }
        for (above, below) in zip(ordered, ordered.dropFirst()) {
            print(String(format: "KEYROW %@ y %.1f..%.1f x %.1f",
                         above.label, above.frame.minY, above.frame.maxY, above.frame.minX))
            XCTAssertLessThanOrEqual(
                above.frame.maxY, below.frame.minY + 0.5,
                "\(above.label) and \(below.label) share a line, so the key is still "
                + "in columns and a column is narrower than a word")
            XCTAssertEqual(
                above.frame.minX, below.frame.minX, accuracy: 0.5,
                "\(above.label) and \(below.label) do not start at the same edge")
        }
    }

    /// The key is still there, still complete, and now under the grid.
    func testTheKeyIsWholeAndBelowTheGridAtAccessibilitySize() {
        let app = openArchive("UICTContentSizeCategoryAccessibilityXXXL")
        let items = app.descendants(matching: .any)
            .matching(identifier: "ArchiveKeyItem").allElementsBoundByIndex
        XCTAssertEqual(items.count, 4, "the key lost a state when it moved")

        let cell = anyCell(app)
        XCTAssertTrue(cell.waitForExistence(timeout: 10), "no day cell")
        let keyTop = items.map { $0.frame.minY }.min() ?? 0
        XCTAssertGreaterThanOrEqual(
            keyTop, cell.frame.minY,
            "the key is above the grid at an accessibility size")
    }
}
