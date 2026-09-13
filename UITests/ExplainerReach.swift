import XCTest

/// Can the explainer be opened from the colophon, and left again?
///
/// The claims it makes are asserted in `ExplainerClaimsTests`, which reads the
/// copy as text. This is the other half: that there is a way in, and a way out
/// that does not need a scroll.
///
/// Same `isHittable` reasoning as `RevealButtonReach`. The explainer is seven
/// paragraphs, longer than the phone at any text size, so a Close button at the
/// foot of the prose would be a Close button below the fold. It is pinned for
/// that reason and this is what says so.
final class ExplainerReach: XCTestCase {

    private func launch(size: String, openExplainer: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        var args = ["-resetProgress", "1",
                    "-UIPreferredContentSizeCategoryName", size]
        if openExplainer { args += ["-openExplainer", "1"] }
        app.launchArguments = args
        app.launch()
        XCTAssertTrue(app.buttons.matching(
            NSPredicate(format: "label MATCHES %@", "^Letter [a-z].*")
        ).firstMatch.waitForExistence(timeout: 30), "the app never rendered a rack")
        return app
    }

    /// The way in. Presence rather than position: the colophon sits below the
    /// fold on purpose, which is where the web puts its footer too.
    func testTheColophonOffersTheExplainer() {
        let app = launch(size: "UICTContentSizeCategoryL", openExplainer: false)
        let trigger = app.buttons["How the words work"]
        XCTAssertTrue(trigger.waitForExistence(timeout: 10),
                      "the colophon has no way into the explainer")
    }

    func testTheWayOutIsReachableWhenItOpens() {
        let app = launch(size: "UICTContentSizeCategoryL", openExplainer: true)
        let close = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "close")).firstMatch
        XCTAssertTrue(close.waitForExistence(timeout: 10), "no way out of the explainer")
        XCTAssertTrue(close.isHittable, "the explainer opened with its way out off screen")
    }

    func testTheWayOutIsReachableAtTheLargestTextSize() {
        let app = launch(size: "UICTContentSizeCategoryAccessibilityXXXL", openExplainer: true)
        let close = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "close")).firstMatch
        XCTAssertTrue(close.waitForExistence(timeout: 10), "no way out of the explainer")
        XCTAssertTrue(close.isHittable,
                      "the explainer at AX5 opened with its way out off screen")
    }
}
