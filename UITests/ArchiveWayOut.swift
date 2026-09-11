import XCTest

/// The way out is a tap target, measured on the glass.
///
/// **It was the lettering, not the band.** The last report said this control
/// reached the glass at 42.2pt, which was 44 times the card's scale and not a
/// measurement. Measured, it came back 18.86pt tall on a 390pt phone at the
/// default size: a plain button reports and hits what its label drew, and the
/// label is one line of text sitting in a 44pt band. The band was never the
/// target.
///
/// Two changes, and both were needed. `contentShape` makes the band the target
/// rather than the glyphs, and the height comes from the measured card scale so
/// that the band is still 44pt once the card has scaled it. On a 390pt phone
/// that is 44.43pt of glass against 18.86 before.
///
/// The chevrons got the same treatment and are guarded in
/// `ArchiveChevronScale`. The grid is not: cells are sized by dividing the
/// width seven ways, and where the card would take them under the minimum the
/// card is refused instead. That is `ArchiveGridMetrics`.
final class ArchiveWayOut: XCTestCase {
    private func wayOut(_ size: String) -> CGRect {
        let app = XCUIApplication()
        app.launchArguments = [
            "-resetProgress", "1", "-seedArchive", "showcase", "-openArchive", "1",
            "-UIPreferredContentSizeCategoryName", size,
        ]
        app.launch()
        let button = app.buttons["Back to the basket"].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 30),
                      "the archive sheet never opened")
        print(String(format: "WAYOUT %@ %.2f x %.2f", size,
                     button.frame.width, button.frame.height))
        return button.frame
    }

    func testTheWayOutIsATapTargetOnTheGlass() {
        // The same thousandth of a point the cell guard allows, for the same
        // reason: the boundary is exact and the arithmetic is not.
        let floor = 44 - 0.001
        XCTAssertGreaterThanOrEqual(
            wayOut("UICTContentSizeCategoryL").height, floor,
            "the way out is under the 44pt tap target at the default size")
        XCTAssertGreaterThanOrEqual(
            wayOut("UICTContentSizeCategoryAccessibilityXXXL").height, floor,
            "the way out is under the 44pt tap target at AX5")
    }
}
