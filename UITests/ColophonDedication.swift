import XCTest

/// Is the dedication in the app, and does it survive the layout switch?
///
/// The port of `Game.test.tsx`'s two footer assertions. The web asserts the
/// dedication is in the colophon and then asserts it again under the other
/// theme, because a credit is exactly the kind of thing a second rendering path
/// quietly drops. This app has one theme and two layouts, so the layouts are
/// where that second assertion belongs: the fixed one puts the colophon at the
/// foot of a scrolling list, the fallback puts it at the foot of a scrolling
/// page, and those are different views of the same four words.
///
/// It shipped on the web and not here, and she went looking for it. The bug was
/// never that the words were wrong, so a test on the words alone would not have
/// caught it. What has to be true is that they are present at all.
///
/// The assertion is on presence, not on position or visibility. The colophon
/// sits below the fold on purpose and reaching it takes a scroll, which is the
/// treatment it has on the web too. Pinning where it lands on screen would be
/// pinning a decision that is allowed to change.
final class ColophonDedication: XCTestCase {

    private func dedication(at size: String) -> XCUIElement {
        let app = XCUIApplication()
        app.launchArguments = ["-resetProgress", "1",
                               "-UIPreferredContentSizeCategoryName", size]
        app.launch()
        // Waiting on the rack rather than on the colophon, so a missing
        // dedication fails the assertion below rather than timing out here,
        // which reads as a hung app instead of an absent credit.
        XCTAssertTrue(app.buttons.matching(
            NSPredicate(format: "label MATCHES %@", "^Letter [a-z].*")
        ).firstMatch.waitForExistence(timeout: 30), "the app never rendered a rack")

        // Matched as a fragment, not as a whole label: until the credits left
        // for Settings the colophon combined its lines into one element, and
        // the dedication was a piece of its label. Now it is the colophon's one
        // line, and a fragment still finds it.
        return app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@", "for Bea")).firstMatch
    }

    func testTheColophonCarriesTheDedication() {
        XCTAssertTrue(dedication(at: "UICTContentSizeCategoryL").exists,
                      "the colophon does not carry the dedication")
    }

    /// The fallback layout, which is a second rendering of the same colophon.
    func testTheDedicationSurvivesTheScrollingLayout() {
        XCTAssertTrue(dedication(at: "UICTContentSizeCategoryAccessibilityXXXL").exists,
                      "the dedication is dropped in the scrolling layout")
    }

    /// The foot of the found list is the dedication and nothing else, since
    /// 22 October 2026: the credits are on Licences, and How the words work and
    /// the privacy policy are Settings' rows. The board's tree is read with
    /// Settings shut, so anything found here is on the board itself.
    func testTheFootOfTheListIsTheDedicationAlone() {
        let line = dedication(at: "UICTContentSizeCategoryL")
        XCTAssertTrue(line.exists, "the colophon does not carry the dedication")
        XCTAssertEqual(line.label, "for Bea", "the colophon carries more than the dedication")
        let app = XCUIApplication()
        for gone in ["How the words work", "Privacy policy"] {
            XCTAssertFalse(app.descendants(matching: .any)[gone].exists,
                           "the board still offers \(gone)")
        }
        for credit in ["ENABLE and SCOWL", "Wiktionary", "Fredoka"] {
            XCTAssertFalse(app.descendants(matching: .any).matching(
                NSPredicate(format: "label CONTAINS %@", credit)).firstMatch.exists,
                           "the board still credits \(credit)")
        }
    }
}
