import XCTest

/// The month chevrons grow with the month's name.
///
/// **The 44pt target was never the problem.** The chevrons always had it, and
/// at AX5 they were still 15pt marks beside a title several times their size:
/// the target is what the finger needs and the glyph is what the eye needs, and
/// a low vision reader is hunting for the glyph.
///
/// The glyph itself is not a frame XCUITest can read, so what is asserted is the
/// tap target it drives: never below 44pt, and larger at AX5 than at the
/// ordinary size. The marks themselves are checked in pixels in the report.
///
/// **These are glass measurements, which is the point.** A sheet at a custom
/// detent is presented as a floating card and on a phone with a home indicator
/// that card is scaled by 0.9597, so a target laid out at 44pt arrives at
/// 42.2pt. XCUITest reports what reached the screen, so this guard sees that
/// and a check against the value in the source would not.
final class ArchiveChevronScale: XCTestCase {
    private func chevronSize(_ size: String) -> CGSize {
        let app = XCUIApplication()
        app.launchArguments = [
            "-resetProgress", "1", "-seedArchive", "showcase", "-openArchive", "1",
            // July, so both chevrons are reachable and neither is at a bound.
            "-archiveMonth", "2026-07",
            "-UIPreferredContentSizeCategoryName", size,
        ]
        app.launch()
        XCTAssertTrue(app.buttons["Back to the basket"].waitForExistence(timeout: 30),
                      "the archive sheet never opened")
        let previous = app.buttons["ArchivePreviousMonth"].firstMatch
        XCTAssertTrue(previous.waitForExistence(timeout: 10), "no previous month button")
        print(String(format: "CHEVRON %@ %.1f x %.1f", size,
                     previous.frame.width, previous.frame.height))
        return previous.frame.size
    }

    func testTheChevronGrowsWithTheTitleAndKeepsItsTarget() {
        let ordinary = chevronSize("UICTContentSizeCategoryL")
        let accessible = chevronSize("UICTContentSizeCategoryAccessibilityXXXL")

        XCTAssertGreaterThanOrEqual(ordinary.width, 44, "under the tap target at L")
        XCTAssertGreaterThanOrEqual(ordinary.height, 44, "under the tap target at L")
        XCTAssertGreaterThanOrEqual(accessible.width, 44, "under the tap target at AX5")
        XCTAssertGreaterThanOrEqual(accessible.height, 44, "under the tap target at AX5")

        XCTAssertGreaterThan(
            accessible.height, ordinary.height + 4,
            "the chevron is the same size at AX5 as at L, so it did not scale")
    }
}
