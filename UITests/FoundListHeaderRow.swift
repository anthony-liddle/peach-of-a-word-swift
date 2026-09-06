import XCTest

/// Does the heading and Share stay on one row?
///
/// The found list's header carries two elements where the web's carries one:
/// the heading, and Share on the trailing edge. A heading plus a labelled
/// control on one row is the shape that wraps at large text sizes, and a
/// two-line header is worse than the row Share used to have to itself.
///
/// Asserted on frames rather than by looking, because at accessibility sizes
/// the whole screen becomes one scroll view and the header is off screen at
/// both ends of it: the top shows the rack and the bottom shows the colophon.
/// Whether two elements share a row is a question about geometry, which
/// survives being off screen.
final class FoundListHeaderRow: XCTestCase {

    private func headerFrames(at size: String) -> (heading: CGRect, share: CGRect)? {
        let app = XCUIApplication()
        app.launchArguments = ["-resetProgress", "1", "-seedBoard", "almost",
                               "-UIPreferredContentSizeCategoryName", size]
        app.launch()
        XCTAssertTrue(app.buttons.matching(
            NSPredicate(format: "label MATCHES %@", "^Letter [a-z].*")
        ).firstMatch.waitForExistence(timeout: 30), "the app never rendered a rack")

        let heading = app.staticTexts["The basket"].firstMatch
        let share = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "share")).firstMatch
        guard heading.waitForExistence(timeout: 10),
              share.waitForExistence(timeout: 10) else { return nil }
        return (heading.frame, share.frame)
    }

    /// They share a row when their vertical spans overlap. Comparing centres
    /// would fail on a legitimate baseline offset between a large display face
    /// and a small control; comparing spans asks the question that matters,
    /// which is whether one sits under the other.
    private func assertOneRow(_ size: String, _ label: String) {
        guard let (heading, share) = headerFrames(at: size) else {
            return XCTFail("\(label): could not find the header's two elements")
        }
        let overlap = min(heading.maxY, share.maxY) - max(heading.minY, share.minY)
        XCTAssertGreaterThan(
            overlap, 0,
            "\(label): the header wrapped. heading=\(heading) share=\(share)")
    }

    func testTheHeaderIsOneRowAtDefaultSize() {
        assertOneRow("UICTContentSizeCategoryL", "default")
    }

    func testTheHeaderIsOneRowAtTheLargestAccessibilitySize() {
        assertOneRow("UICTContentSizeCategoryAccessibilityXXXL", "AX5")
    }
}
