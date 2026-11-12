import XCTest

/// The play surface at every text size from L to AX5.
///
/// A tester with a larger default text size sent a screenshot: the tiles
/// filling most of the screen, the rack in three columns, the found list gone,
/// and CLEAR and the delete glyph cut off at the bottom edge. The note that had
/// predicted it measured one phone at one size and generalised, which is how
/// the clipped controls went unrecorded. So these sweep every size, and each
/// one was shown failing on an iPhone SE 3 before the fix it guards.
///
/// One launch per size, in its own process, for the reason `LayoutBudget`
/// records: a size is a launch argument and the app reads it once.
final class RackAtLargeText: XCTestCase {
    /// How long a control has to come to rest on screen after the board appears.
    static let settle: TimeInterval = 10

    static let sizes = [
        "UICTContentSizeCategoryL",
        "UICTContentSizeCategoryXL",
        "UICTContentSizeCategoryXXL",
        "UICTContentSizeCategoryXXXL",
        "UICTContentSizeCategoryAccessibilityM",
        "UICTContentSizeCategoryAccessibilityL",
        "UICTContentSizeCategoryAccessibilityXL",
        "UICTContentSizeCategoryAccessibilityXXL",
        "UICTContentSizeCategoryAccessibilityXXXL",
    ]

    private func launch(_ size: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-resetProgress", "1", "-seedBoard", "almost",
            "-UIPreferredContentSizeCategoryName", size,
        ]
        app.launch()
        XCTAssertTrue(tiles(app).firstMatch.waitForExistence(timeout: 20),
                      "no rack at \(size)")
        return app
    }

    private func tiles(_ app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "label MATCHES %@", "^Letter [a-z].*"))
    }

    /// Every control is on screen at rest and hittable, at every size.
    ///
    /// **At rest is the property, not merely hittable.** In the scrolling
    /// layout a control below the fold can be scrolled to, and a player
    /// looking at the screen they launched into cannot see it. See
    /// `LayoutBudget.controlIsOnScreen`.
    ///
    /// **Each control is given time to settle, and that is the whole fix for
    /// the red of 11 and 12 November.** Read once, the moment the first tile
    /// appeared, this failed on three CI runs in a row, at XXXL, XL and
    /// AccessibilityM in turn, and passed both times it ran on a desk, on the
    /// same board and the same phone. The result bundle's hierarchy
    /// at the failure said why: the pills still carried their drawn, uppercased
    /// text, SHUFFLE, PICK WORD and CLEAR, rather than their labels, so
    /// "Shuffle" matched nothing; and where it did match it was not yet
    /// hittable, with its frame well inside the window. The board was still
    /// settling on the slower simulator. A control that is really off screen
    /// never settles on screen, so it still fails, after `settle`.
    func testEveryControlIsOnScreenAtEverySize() {
        for size in Self.sizes {
            let app = launch(size)
            for label in LayoutBudget.controlLabels {
                let control = app.buttons[label]
                // Read once, as before, and waited on only if that read says
                // no: a waiter polls, and polling every control at every size
                // added half a minute to a run in which all of them were there.
                let settled = LayoutBudget.controlIsOnScreen(control, in: app)
                    || XCTWaiter().wait(for: [expectation(
                        for: NSPredicate { _, _ in LayoutBudget.controlIsOnScreen(control, in: app) },
                        evaluatedWith: control)], timeout: Self.settle) == .completed
                // The bottom is read only if the control is there: reading the
                // frame of one that is not was a second failure of its own.
                XCTAssertTrue(
                    settled,
                    "\(label) is not fully on screen at rest at \(size): bottom "
                    + (control.exists ? "\(control.frame.maxY)" : "absent")
                    + " in a \(app.windows.firstMatch.frame.height)pt window")
            }
        }
    }

    /// A tile is at least 44 by 44 at every size. They are buttons.
    ///
    /// Every tile the tree holds, and at least one full row of them. **Not
    /// all eight, and that is not a loophole.** The rack is a lazy grid, and in
    /// the scrolling layout at the top sizes its second row sits far enough
    /// below the fold that the grid has not built it: an iPhone SE at AX5 had
    /// six tiles in the tree. That is a fact about the scroll view, and asking
    /// for eight here turned a tap-target test red for a reason that had
    /// nothing to do with any tile's size. `RackShape` pins the shape.
    func testEveryTileIsATapTargetAtEverySize() {
        for size in Self.sizes {
            let app = launch(size)
            let all = tiles(app).allElementsBoundByIndex
            XCTAssertGreaterThanOrEqual(all.count, 4, "not one full row at \(size)")
            for tile in all {
                XCTAssertGreaterThanOrEqual(tile.frame.width, 44,
                                            "\(tile.label) is narrow at \(size)")
                XCTAssertGreaterThanOrEqual(tile.frame.height, 44,
                                            "\(tile.label) is short at \(size)")
            }
        }
    }

    /// At a fixed width, the text setting does not reach the tile.
    ///
    /// **One reference per layout, because the two layouts report the same
    /// tile differently.** The fixed layout's touch-down tile reports its
    /// layout frame, 78 by 104 on a 375pt phone. The scrolling layout's tile is
    /// a `Button`, and a `Button` reports its ink: the 1pt stroke's half point
    /// of overhang on each side and the 5pt slab `TilePressStyle` draws beneath
    /// it, so the same face reads 79 by 109.5. That difference follows the
    /// layout, not the text size, and it predates this test: an SE at XXXL
    /// read 79 by 109.5 with four columns before any of the tile work.
    ///
    /// So each layout's first size is its reference, and every later size in
    /// that layout must match it. Half a point of tolerance, for the pixel
    /// grid.
    func testTileSizeDoesNotFollowTheTextSize() {
        var reference: [Bool: (size: String, frame: CGSize)] = [:]
        for size in Self.sizes {
            let app = launch(size)
            let fixed = LayoutBudget.rackIsFixed(app)
            let frame = tiles(app).firstMatch.frame.size
            guard let ref = reference[fixed] else {
                reference[fixed] = (size, frame); continue
            }
            XCTAssertEqual(frame.width, ref.frame.width, accuracy: 0.5,
                           "tile width moved between \(ref.size) and \(size)")
            XCTAssertEqual(frame.height, ref.frame.height, accuracy: 0.5,
                           "tile height moved between \(ref.size) and \(size)")
        }
    }

    /// The found list has room for a group header and a row of chips, at
    /// every size, in whichever layout is active.
    ///
    /// The floor is measured in the same launch rather than written down:
    /// the first group's header to the bottom of the first chip beneath it,
    /// which is what "a list worth calling a list" means in points at that
    /// size. `ContentView.minimumListHeight` is chosen against the same
    /// measurement (see `LayoutBudget.testHeaderAndRow`).
    ///
    /// In the scrolling layout the list is part of the page and has the whole
    /// window once scrolled to, so what is checked there is the page's own
    /// scroll view. The property is structural in that layout, and it is
    /// asserted rather than assumed so a change to the fallback cannot quietly
    /// make it false.
    func testFoundListHasRoomForAHeaderAndARow() {
        for size in Self.sizes {
            let app = launch(size)
            let header = app.descendants(matching: .any).matching(
                NSPredicate(format: "label MATCHES %@", "^[0-9]+ letters.*")
            ).firstMatch
            XCTAssertTrue(header.exists, "no group header at \(size)")
            let top = header.frame
            guard let chip = app.buttons.matching(
                NSPredicate(format: "label MATCHES %@", ".*, [0-9]+ points?$")
            ).allElementsBoundByIndex.first(where: { $0.frame.minY >= top.maxY - 1 })
            else { XCTFail("no chip under the first header at \(size)"); continue }
            let needed = chip.frame.maxY - top.minY
            let list = app.scrollViews.firstMatch.frame.height
            XCTAssertGreaterThanOrEqual(
                list, needed,
                "the list is \(list)pt at \(size), and one header and one row "
                + "need \(needed)pt")
        }
    }
}
