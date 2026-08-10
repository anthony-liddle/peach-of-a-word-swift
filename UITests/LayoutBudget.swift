import XCTest

/// Which layout the app chose, and how much list it got.
///
/// The two layouts are told apart by order rather than by measurement: in the
/// fixed layout the controls sit BELOW the summary, and in the scrolling
/// fallback they sit above it. That is a structural difference, so it cannot be
/// fooled by a squeeze the way a height threshold could.
final class LayoutBudget: XCTestCase {
    private func probe(_ size: String) {
        let app = XCUIApplication()
        app.launchArguments = [
            "-resetProgress", "1", "-seedBoard", "almost",
            "-UIPreferredContentSizeCategoryName", size,
        ]
        app.launch()
        Thread.sleep(forTimeInterval: 2.5)
        let summary = app.staticTexts["47 of 48 words"]
        let shuffle = app.buttons["Shuffle"]
        guard summary.exists, shuffle.exists else {
            print("LAYOUT \(size) = indeterminate"); return
        }
        let fixed = shuffle.frame.minY > summary.frame.minY
        let win = app.windows.firstMatch.frame
        print("LAYOUT \(size) window=\(Int(win.height)) mode=\(fixed ? "FIXED" : "fallback")")
    }

    /// The one guarantee that must not regress: a phone the size of the one
    /// this is actually played on, at the text size it is actually played at,
    /// keeps the fixed rack. Everything else in the sweep is information; this
    /// is the line.
    func testDefaultSizeOnATallPhoneKeepsTheFixedRack() {
        let app = XCUIApplication()
        app.launchArguments = ["-resetProgress", "1", "-seedBoard", "almost",
                               "-UIPreferredContentSizeCategoryName",
                               "UICTContentSizeCategoryL"]
        app.launch()
        Thread.sleep(forTimeInterval: 2.5)
        let win = app.windows.firstMatch.frame
        try? XCTSkipIf(win.height < 800, "not a tall phone; the sweep covers short ones")
        let summary = app.staticTexts["47 of 48 words"]
        let shuffle = app.buttons["Shuffle"]
        XCTAssertTrue(summary.waitForExistence(timeout: 15))
        XCTAssertTrue(shuffle.exists)
        XCTAssertGreaterThan(
            shuffle.frame.minY, summary.frame.minY,
            "the controls are above the summary, so this fell back to the "
            + "scrolling layout at default size on a tall phone"
        )
    }

    func testSweep() {
        for s in ["UICTContentSizeCategoryL",
                  "UICTContentSizeCategoryXL",
                  "UICTContentSizeCategoryXXL",
                  "UICTContentSizeCategoryXXXL",
                  "UICTContentSizeCategoryAccessibilityM",
                  "UICTContentSizeCategoryAccessibilityXXXL"] {
            probe(s)
        }
    }
}
