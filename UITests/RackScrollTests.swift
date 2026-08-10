import XCTest

/// Does a scroll that starts on a tile insert a letter?
///
/// This is the question that kept the touch-down commit off the accessibility
/// path. At those text sizes the whole screen is one scroll view with the rack
/// inside it, and a `DragGesture(minimumDistance: 0)` fires before the system
/// can know whether the finger is tapping or starting a scroll. That was
/// reasoned, never observed, and a scroll view that types at you would be a
/// worse bug than a slow tile.
///
/// It could not be observed before because it needs a real gesture. `simctl`
/// can launch, seed and screenshot; it cannot drag. Four questions in this
/// project have now hit that wall, and each was worked around with a launch
/// argument. This is the instrument instead.
///
/// The experiment is one swipe, run against both configurations, so the result
/// is a comparison rather than a single observation:
///
///   - `-forceTouchDown 0`: the shipping behaviour at accessibility sizes,
///     where tiles are Buttons and commit on release
///   - `-forceTouchDown 1`: the touch-down gesture, extended to that path
///
/// If both scroll and neither types, the exclusion is unnecessary. If the
/// second types a letter, the exclusion is correct and now has evidence.
final class RackScrollTests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// The compose well's placeholder. Its presence is the assertion: it is
    /// shown only while nothing has been composed, so if a swipe inserted a
    /// letter it is gone.
    private static let placeholder = "Pick letters to make a word"

    private func launch(forceTouchDown: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-resetProgress", "1",
            "-seedBoard", "almost",
            "-forceTouchDown", forceTouchDown ? "1" : "0",
            // Dynamic Type per launch, which is what puts the rack inside the
            // scroll view in the first place.
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL",
        ]
        app.launch()
        return app
    }

    /// Any rack tile, found by the accessibility label the tiles already carry.
    ///
    /// The predicate excludes the rack container, whose label is "Letter tiles"
    /// and therefore also begins with "Letter ". Matching it instead of a tile
    /// is why the first run reported that a tap composed nothing: the tap landed
    /// on the container. The control test caught it, which is what it is for.
    private func firstTile(in app: XCUIApplication) throws -> XCUIElement {
        // `app.buttons`, not every descendant. The rack container is labelled
        // "Letter tiles" and is an Other, so a loose query matches it first and
        // every tap lands on a gap between tiles.
        let tile = app.buttons
            .matching(NSPredicate(format: "label MATCHES %@", "^Letter [a-z].*"))
            .firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 20), "no rack tile found")
        return tile
    }

    /// Something known to be far down the scroll, so scrolling can be detected
    /// by what moved rather than by a tile that may not move at all.
    private func scrollProbe(in app: XCUIApplication) -> XCUIElement {
        app.staticTexts["Words from ENABLE and SCOWL."]
    }

    /// Swipe up starting from the centre of a tile, the way a thumb would when
    /// scrolling from wherever it happens to be resting.
    private func swipeUp(from tile: XCUIElement, in app: XCUIApplication) {
        let start = tile.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = start.withOffset(CGVector(dx: 0, dy: -320))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    private func runSwipe(forceTouchDown: Bool) throws -> (scrolled: Bool, typed: Bool) {
        let app = launch(forceTouchDown: forceTouchDown)
        let tile = try firstTile(in: app)
        let before = tile.frame.origin.y
        swipeUp(from: tile, in: app)
        // Settle, since the scroll is animated and the assertion is about where
        // things ended up rather than where they were mid-flight.
        Thread.sleep(forTimeInterval: 1.2)
        let after = tile.frame.origin.y
        let placeholderGone = !app.staticTexts[Self.placeholder].exists
        return (scrolled: abs(after - before) > 20, typed: placeholderGone)
    }

    func testSwipeFromTileWithShippingBehaviour() throws {
        let r = try runSwipe(forceTouchDown: false)
        XCTContext.runActivity(named: "shipping: scrolled=\(r.scrolled) typed=\(r.typed)") { _ in }
        XCTAssertTrue(r.scrolled, "a swipe starting on a tile did not scroll the view")
        XCTAssertFalse(r.typed, "a swipe starting on a tile inserted a letter")
    }

    /// The conflict, measured.
    ///
    /// Result on 2026-08-10, iPhone 15 simulator at AccessibilityXXXL:
    /// **scrolled = false, typed = true**. Forcing the touch-down commit onto
    /// this path did not merely insert a letter, it stopped the view scrolling
    /// at all. A rack you cannot scroll past, which types at you when you try,
    /// is a considerably worse bug than a tile that waits for your finger to
    /// lift. The exclusion in `ContentView.commitOnTouchDown` stays, and now
    /// has evidence rather than an argument behind it.
    ///
    /// **This test is written to fail if the conflict ever goes away.** If
    /// SwiftUI changes, or a gesture that defers to the scroll pan is found,
    /// this starts failing and that is the signal to remove the exclusion and
    /// give large-text players the responsiveness fix. A test that fails when
    /// the world improves is the point here, not an accident.
    func testTouchDownCommitStillConflictsWithTheScroll() throws {
        let r = try runSwipe(forceTouchDown: true)
        XCTAssertTrue(
            r.typed,
            "the touch-down commit no longer types when scrolled from a tile; "
            + "recheck whether the exclusion is still needed"
        )
        XCTAssertFalse(
            r.scrolled,
            "the touch-down commit no longer blocks the scroll; "
            + "recheck whether the exclusion is still needed"
        )
    }

    /// A tap must still commit, so a swipe test that passes by breaking taps
    /// cannot be mistaken for a result.
    func testTapStillCommits() throws {
        let app = launch(forceTouchDown: false)
        let tile = try firstTile(in: app)
        tile.tap()
        Thread.sleep(forTimeInterval: 0.6)
        XCTAssertFalse(app.staticTexts[Self.placeholder].exists,
                       "a tap on a tile did not compose a letter")
    }
}
