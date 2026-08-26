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
/// **The two layouts are told apart by asking whether the rack is inside a
/// scroll view, and the question it replaces is worth recording.** This used to
/// compare the controls against the summary: in the fixed layout the controls
/// sat BELOW the summary, and in the scrolling fallback they sat above it.
///
/// Moving the controls up under the rack did not merely invert that answer, it
/// deleted the question. Both layouts now run header, well, rack, controls,
/// summary, list in that exact order, so NO ordering test can separate them and
/// the old probe would have reported "fallback" everywhere, confidently and
/// wrongly, on a screen that had not changed layout at all.
///
/// Containment is the definitional difference rather than a correlate of it.
/// The fixed layout exists precisely because the rack is not inside a scroll
/// view, which is what makes the touch-down commit safe (`RackScrollTests`);
/// the fallback exists because everything had to go into one. So this asks the
/// property the two layouts are actually named for, and there is no
/// rearrangement of the furniture that can fool it.
final class LayoutBudget: XCTestCase {
    /// A rack tile, by the label it already carries.
    ///
    /// `app.buttons`, not every descendant: the rack container is labelled
    /// "Letter tiles" and a loose query matches the container first. Same trap
    /// `MessageLineShove` and `RackScrollTests` both record.
    private func rackTile(_ app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(
            NSPredicate(format: "label MATCHES %@", "^Letter [a-z].*")
        ).element(boundBy: 0)
    }

    /// Is the rack outside every scroll view?
    ///
    /// Containment rather than a `minY` comparison, because containment says
    /// the thing that is meant. "The scroll view starts above the rack" is a
    /// correlate that holds today and would go on reporting an answer if the
    /// furniture were reordered again; "the rack is inside the scroll view" is
    /// the property itself.
    ///
    /// Every scroll view rather than `firstMatch`, deliberately. `firstMatch`
    /// takes whichever one the query traverses first, which is unambiguous
    /// today only because the fixed layout happens to contain exactly one. That
    /// is a fact about the current view tree, not a guarantee, and this probe
    /// exists to survive changes to the view tree.
    private func rackIsFixed(_ app: XCUIApplication) -> Bool {
        let tile = rackTile(app).frame
        return !app.scrollViews.allElementsBoundByIndex.contains { $0.frame.contains(tile) }
    }

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
        guard summary.waitForExistence(timeout: 15), rackTile(app).exists else {
            print("LAYOUT \(size) = indeterminate"); return
        }
        let fixed = rackIsFixed(app)
        let win = app.windows.firstMatch.frame
        // The list height, which is the number the density work is actually
        // spent on and which this probe did not used to print. It was measured
        // by hand for the chrome reclaim, which meant the instruction on
        // `minimumListHeight` to re-measure the tightest cell after any change
        // to the furniture had no tool behind it. Now it does.
        //
        // Only meaningful in the fixed layout: in the fallback the whole screen
        // is one scroll view and "the list's height" is not a frame that means
        // anything, so it is reported as absent rather than as a number.
        let list = fixed
            ? String(format: "%.2f", app.scrollViews.firstMatch.frame.height)
            : "n/a"
        print("LAYOUT \(size) window=\(Int(win.height)) "
              + "mode=\(fixed ? "FIXED" : "fallback") list=\(list)")
    }

    /// The one guarantee that must not regress: a phone the size of the one
    /// this is actually played on, at the text size it is actually played at,
    /// keeps the fixed rack. Everything else in the sweep is information; this
    /// is the line.
    ///
    /// **`throws`, and the `try` is not optional.** This read `try?
    /// XCTSkipIf(...)`, and `try?` discards the thrown skip: the test did not
    /// skip on a short phone, it ran the assertion anyway and failed, for a
    /// reason that has nothing to do with what it asserts. Latent only because
    /// the runners happened to be tall, and CI takes the first iPhone image the
    /// runner has (`test.yml`), so which phone that is was never decided. A
    /// test that fails for the wrong reason is the same family of problem as a
    /// test that passes for the wrong reason, which is what this suite exists
    /// to avoid.
    func testDefaultSizeOnATallPhoneKeepsTheFixedRack() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-resetProgress", "1", "-seedBoard", "almost",
                               "-UIPreferredContentSizeCategoryName",
                               "UICTContentSizeCategoryL"]
        app.launch()
        let summaryProbe = app.staticTexts["FoundSummaryCount"]
        XCTAssertTrue(summaryProbe.waitForExistence(timeout: 15),
                      "the app never rendered the found summary")
        let win = app.windows.firstMatch.frame
        try XCTSkipIf(win.height < 800, "not a tall phone; the sweep covers short ones")
        XCTAssertTrue(rackTile(app).exists, "no rack tile found")
        XCTAssertTrue(
            rackIsFixed(app),
            "the rack is inside a scroll view, so this fell back to the "
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
