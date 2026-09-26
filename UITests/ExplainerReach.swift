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

    /// A link leaves the app for the browser; nothing loads inside the app.
    ///
    /// These were an in-app Safari view until 2026-09-26, which made the app
    /// load a third party's page itself, its one network request. The claim
    /// now is that the app hands the URL to the system and loads nothing, so
    /// this asserts both halves: Safari comes to the front, and the app never
    /// showed a web view of its own.
    func testALinkOpensInSafariNotInTheApp() {
        let app = launch(size: "UICTContentSizeCategoryL", openExplainer: true)
        let link = app.descendants(matching: .any).matching(
            NSPredicate(format: "label BEGINSWITH %@", "Read about ENABLE")).firstMatch
        XCTAssertTrue(link.waitForExistence(timeout: 10), "no ENABLE link in the explainer")
        var swipes = 0
        while !link.isHittable && swipes < 8 { app.swipeUp(); swipes += 1 }
        link.tap()

        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        XCTAssertTrue(safari.wait(for: .runningForeground, timeout: 15),
                      "the link did not open in Safari")
        XCTAssertEqual(app.webViews.count, 0,
                       "the app showed a web view of its own")
    }
}
