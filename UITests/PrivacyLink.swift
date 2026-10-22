import XCTest

/// The privacy policy is linked inside the app.
///
/// Apple's review guidelines (5.1.1(i)) ask for the privacy policy to be
/// reachable within the app as well as on the App Store record, and until this
/// test the app linked it nowhere. Settings' row opens it in a Safari view,
/// inside the app. The colophon's link, until it leaves, still hands off to
/// Safari, the same claim `ExplainerReach` makes about the explainer's links:
/// the system opens the page, and the app shows no web view of its own.
final class PrivacyLink: XCTestCase {
    /// Settings' row opens the policy inside the app, in a Safari view, and its
    /// Done comes back to Settings. It used to hand off to Safari, and Safari's
    /// way back from there was the website's "Back to the game", which led to
    /// the web game rather than to this one.
    func testSettingsOpensThePolicyInsideTheAppAndDoneComesBack() {
        let app = XCUIApplication()
        app.launchArguments = ["-showTitle", "1", "-resetProgress", "1", "-openSettings", "1",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()

        let row = app.buttons["SettingsPrivacy"]
        XCTAssertTrue(row.waitForExistence(timeout: 30), "Settings has no privacy row")
        row.tap()

        let done = app.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 15), "no Safari view with a Done button opened")
        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        XCTAssertNotEqual(safari.state, .runningForeground, "the policy left the app for Safari")
        XCTAssertEqual(app.state, .runningForeground)

        // Tapped by its point on the screen, not as an element. The Safari
        // view runs in Safari's process, and XCUITest's element tap on its Done
        // left the page up twice, at the button's centre and at its edge, where
        // a tap at the same point by screen coordinate closed it.
        let point = CGVector(dx: done.frame.midX, dy: done.frame.midY)
        app.coordinate(withNormalizedOffset: .zero).withOffset(point).tap()
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Done did not come back to Settings")
        XCTAssertTrue(row.isHittable, "Done did not come back to Settings")
    }

    func testTheColophonLinksThePrivacyPolicyInSafari() {
        let app = XCUIApplication()
        // An empty board keeps the found list short, so the colophon is a
        // short scroll away.
        app.launchArguments = ["-resetProgress", "1",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()

        let link = app.descendants(matching: .any)["Privacy policy"]
        XCTAssertTrue(link.waitForExistence(timeout: 30), "the app links no privacy policy")

        let list = app.scrollViews.firstMatch
        var swipes = 0
        while !link.isHittable && swipes < 8 { list.swipeUp(); swipes += 1 }
        XCTAssertTrue(link.isHittable, "the privacy link never came into reach")
        link.tap()

        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        XCTAssertTrue(safari.wait(for: .runningForeground, timeout: 15),
                      "the privacy link did not open in Safari")
        XCTAssertEqual(app.webViews.count, 0, "the app showed a web view of its own")
    }
}
