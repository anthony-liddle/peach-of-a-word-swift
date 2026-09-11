import XCTest

/// The sheet is one height, on every month.
///
/// **A sheet sized to its content is a sheet that changes size as you page**,
/// unless something holds it still. June 2026 draws two rows, September five and
/// August six, and a calendar that grows and shrinks under the reader's thumb as
/// they step back through the year would be worse than the empty space it was
/// meant to fix. The grid reserves six rows, which is the most a month can need,
/// so every month costs the same.
///
/// The sheet is anchored to the bottom of the screen, so its height is read from
/// where its top lands: the title's own position is the sheet's height with the
/// sign flipped. That is measured rather than the sheet's frame because the
/// sheet itself is not an element XCUITest hands back a useful box for.
final class ArchiveSheetHeight: XCTestCase {
    private func openArchive(month: String?) -> XCUIApplication {
        let app = XCUIApplication()
        var arguments = [
            "-resetProgress", "1", "-seedArchive", "showcase", "-openArchive", "1",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL",
        ]
        if let month { arguments += ["-archiveMonth", month] }
        app.launchArguments = arguments
        app.launch()
        XCTAssertTrue(app.buttons["Back to the basket"].waitForExistence(timeout: 30),
                      "the archive sheet never opened")
        return app
    }

    /// The top of the sheet, which on a bottom anchored sheet is its height.
    private func sheetTop(_ app: XCUIApplication) -> CGFloat {
        let title = app.staticTexts["Past days"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 10), "no sheet title")
        return title.frame.minY
    }

    func testTheSheetIsTheSameHeightOnEveryMonth() {
        // June draws two rows, August six, and September, the current month,
        // five. If the reservation were not there these would be three heights.
        let june = sheetTop(openArchive(month: "2026-06"))
        let august = sheetTop(openArchive(month: "2026-08"))
        let current = sheetTop(openArchive(month: nil))

        print(String(format: "SHEETTOP june %.2f august %.2f current %.2f",
                     june, august, current))

        XCTAssertEqual(june, august, accuracy: 0.5,
                       "a two row month and a six row month give different sheets")
        XCTAssertEqual(august, current, accuracy: 0.5,
                       "the current month gives a different sheet again")
    }

    /// Six rows fit without scrolling, which is what the reservation is for.
    ///
    /// August 2026 is the six row case: it starts on a Saturday, so 31 days need
    /// six rows. If the sheet were sized to five, this is where it would show.
    func testASixRowMonthNeedsNoScrolling() {
        let app = openArchive(month: "2026-08")
        let scroll = app.scrollViews["ArchiveScroll"].firstMatch
        XCTAssertTrue(scroll.waitForExistence(timeout: 10), "no archive scroll view")

        let cells = app.buttons.matching(identifier: "ArchiveDayCell").allElementsBoundByIndex
        XCTAssertFalse(cells.isEmpty, "no day cells")
        let first = cells.map { $0.frame.minY }.min() ?? 0
        let last = cells.map { $0.frame.maxY }.max() ?? 0

        print(String(format: "SIXROWS grid %.1f..%.1f viewport %.1f..%.1f",
                     first, last, scroll.frame.minY, scroll.frame.maxY))

        XCTAssertGreaterThanOrEqual(first, scroll.frame.minY - 0.5,
                                    "the first row starts above the viewport")
        XCTAssertLessThanOrEqual(last, scroll.frame.maxY + 0.5,
                                 "the sixth row runs past the viewport, so it scrolls")
    }
}
