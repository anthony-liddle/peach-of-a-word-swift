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
}
