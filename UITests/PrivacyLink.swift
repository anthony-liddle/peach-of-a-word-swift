import XCTest

/// The privacy policy is linked inside the app, and the link leaves for Safari.
///
/// Apple's review guidelines (5.1.1(i)) ask for the privacy policy to be
/// reachable within the app as well as on the App Store record, and until this
/// test the app linked it nowhere. It sits in the colophon beside the
/// explainer, where the web puts its own. The handoff half is the same claim
/// `ExplainerReach` makes about the explainer's links: the system opens the
/// page, and the app shows no web view of its own.
final class PrivacyLink: XCTestCase {
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
