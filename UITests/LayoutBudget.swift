import XCTest

/// Which layout the app chose, and how much list it got.
///
/// The summary is found by accessibility identifier, never by its text. It used
/// to be queried as `staticTexts["47 of 48 words"]`, which embeds the size of
/// one particular day's set. `-seedBoard almost` seeds TODAY's daily puzzle and
/// the crown rotates daily, so that string matched on roughly one day in sixty:
/// across the calendar the set size ranges from 16 to 109, and exactly one crown
/// in sixty has 48. The test passed on 2026-08-10 by coincidence and failed from
/// 2026-08-11 on, at every commit including ones months older, which is what a
/// date-dependent test looks like when you go hunting for the change that broke
/// it and cannot find one.
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
        // Waiting on the element rather than sleeping a fixed 2.5s and hoping.
        // A sleep that is too short reports "indeterminate", which reads as a
        // layout finding rather than as a test that gave up too early.
        let summary = app.staticTexts["FoundSummaryCount"]
        let shuffle = app.buttons["Shuffle"]
        guard summary.waitForExistence(timeout: 15), shuffle.exists else {
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
        let summaryProbe = app.staticTexts["FoundSummaryCount"]
        XCTAssertTrue(summaryProbe.waitForExistence(timeout: 15),
                      "the app never rendered the found summary")
        let win = app.windows.firstMatch.frame
        try? XCTSkipIf(win.height < 800, "not a tall phone; the sweep covers short ones")
        let summary = app.staticTexts["FoundSummaryCount"]
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
