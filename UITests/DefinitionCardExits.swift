import XCTest

/// Every way out of the definition card, at every text size from L to AX5.
///
/// **This replaces `DefinitionReveal.testTheCardIsUsableAtTheLargestTextSize`,
/// which was the guard for the same promise and could not see the defect.** It
/// swiped up once and asked `isHittable`. Swept across 31 days of puzzles on an
/// iPhone SE at AX5, one swipe fell short on 5 of them, so it failed about one
/// day in six for a reason unrelated to whether the card could be left (#68).
/// And on 17 of those days `isHittable` called the button reachable at rest
/// while its frame ran past the bottom edge, as far as 647.5 to 762.9 in a
/// 667pt window: 19.5pt of a 115pt button on screen, and the sliver could be
/// tapped. A check that passes on
/// a button mostly below the edge, and fails on a card that can be left, is
/// measuring the swipe rather than the way out.
///
/// So the two exits are asserted as what a player meets:
///
/// - **The labelled way out is wholly on screen at rest, and it dismisses.**
///   No swipe first. The frame against the window, not `isHittable` alone.
/// - **Dragging the card down dismisses it.** The sheet's own gesture, which
///   was never suppressed and is the exit a player who cannot find the button
///   reaches for.
///
/// The grabber is not asserted as a third exit, and that is measured rather
/// than overlooked: on a phone with a home button, a card at its large detent
/// puts the grabber at y=12.5, under the status bar, and six drags from it did
/// not move the sheet. See the 2026-09-23 report.
///
/// Seeded with today's board and the first set word, like the rest of
/// `DefinitionReveal`. Both properties hold for any gloss once the way out is
/// pinned, which is what makes a day-dependent seed safe here: the length of
/// the definition no longer decides where the button is.
final class DefinitionCardExits: XCTestCase {
    private func openCard(at size: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-resetProgress", "1", "-seedBoard", "almost",
            "-UIPreferredContentSizeCategoryName", size,
        ]
        app.launch()
        XCTAssertTrue(app.staticTexts["FoundSummaryCount"].waitForExistence(timeout: 40),
                      "no board at \(size)")
        let chip = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@",
                        ", on the page, ", " point")
        ).firstMatch
        XCTAssertTrue(chip.exists, "no set-word chip at \(size)")
        chip.tap()
        XCTAssertTrue(app.staticTexts["DefinitionProse"].waitForExistence(timeout: 10),
                      "the card did not open at \(size)")
        return app
    }

    private func isDismissed(_ app: XCUIApplication) -> Bool {
        app.staticTexts["DefinitionProse"].waitForNonExistence(timeout: 4)
            && app.staticTexts["FoundSummaryCount"].exists
    }

    /// The labelled way out, on screen with nothing scrolled, at every size.
    func testTheWayOutIsOnScreenAtRestAtEverySize() {
        for size in RackAtLargeText.sizes {
            let app = openCard(at: size)
            let close = app.buttons["Back to the basket"].firstMatch
            XCTAssertTrue(close.exists, "no way out at \(size)")
            let win = app.windows.firstMatch.frame
            let floor = win.maxY - LayoutBudget.bottomInset(windowHeight: win.height)
            XCTAssertGreaterThanOrEqual(close.frame.minY, win.minY,
                                        "the way out starts above the screen at \(size)")
            XCTAssertLessThanOrEqual(
                close.frame.maxY, floor + 0.5,
                "the way out runs off the bottom at rest at \(size): "
                + "\(close.frame.minY) to \(close.frame.maxY) in a \(win.height)pt window")
            XCTAssertTrue(close.isHittable, "the way out is not hittable at \(size)")
            close.tap()
            XCTAssertTrue(isDismissed(app), "the way out did not dismiss the card at \(size)")
            app.terminate()
        }
    }

    /// Dragging the card down dismisses it, at every size.
    ///
    /// From rest, one drag down the card. Then, at the sizes
    /// where the card scrolls, the harder case: scrolled to its end, where a
    /// drag first scrolls the content back, then steps the sheet from large to
    /// medium, then dismisses. Measured at 3 and 4 drags on an SE at AX5; the
    /// bound of 6 is room for a longer gloss, not a target.
    func testDraggingTheCardDownDismissesItAtEverySize() {
        for size in RackAtLargeText.sizes {
            let app = openCard(at: size)
            drag(app)
            XCTAssertTrue(isDismissed(app), "one drag from rest did not dismiss at \(size)")
            app.terminate()
        }
        for size in ["UICTContentSizeCategoryAccessibilityXXL",
                     "UICTContentSizeCategoryAccessibilityXXXL"] {
            let app = openCard(at: size)
            app.swipeUp(); app.swipeUp()
            var drags = 0
            var gone = false
            while !gone && drags < 6 {
                drag(app)
                drags += 1
                gone = isDismissed(app)
            }
            XCTAssertTrue(gone, "six drags did not dismiss a scrolled card at \(size)")
            app.terminate()
        }
    }

    /// Down from 62 percent of the way down the screen, which lands on the card
    /// at both detents and clear of the status bar. At the medium detent on an
    /// SE the sheet starts near y=313, so the middle is barely inside it.
    private func drag(_ app: XCUIApplication) {
        let w = app.windows.firstMatch
        w.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.62)).press(
            forDuration: 0.05,
            thenDragTo: w.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98)))
    }
}
