import XCTest

/// The grid's own measurements, taken from the running app.
///
/// These are frames rather than appearances, so they belong in a test rather
/// than in a screenshot: a cell that is too small to hit and a ring clipped by
/// three points are both invisible in a picture and both decided by numbers.
final class ArchiveGridMetrics: XCTestCase {
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

    /// Any day that can be opened. Matched on its spoken state rather than on a
    /// date, because the dates move every morning and `LayoutBudget` records
    /// what a date-dependent query costs.
    private func playableCell(_ app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "Finished")
        ).element(boundBy: 0)
    }

    /// A grid cell is a tap target, and `Cute.minTapTarget` is 44.
    private func assertTapTarget(_ size: String, file: StaticString = #filePath,
                                 line: UInt = #line) {
        let app = openArchive(size)
        let cell = playableCell(app)
        XCTAssertTrue(cell.waitForExistence(timeout: 10), "no playable day cell",
                      file: file, line: line)
        let frame = cell.frame
        print("CELL \(size) \(String(format: "%.2f x %.2f", frame.width, frame.height))")
        XCTAssertGreaterThanOrEqual(
            frame.width, 44,
            "a day cell is \(frame.width)pt wide, under the 44pt tap target",
            file: file, line: line)
        XCTAssertGreaterThanOrEqual(
            frame.height, 44,
            "a day cell is \(frame.height)pt tall, under the 44pt tap target",
            file: file, line: line)
    }

    func testCellIsATapTargetAtDefaultSize() {
        assertTapTarget("UICTContentSizeCategoryL")
    }

    func testCellIsATapTargetAtAccessibilitySize() {
        assertTapTarget("UICTContentSizeCategoryAccessibilityXXXL")
    }
}
