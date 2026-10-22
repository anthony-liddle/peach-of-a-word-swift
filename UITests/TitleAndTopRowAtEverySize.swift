import XCTest

/// The title screen and the board's top row, at all nine text sizes, in one
/// launch per size.
///
/// **The title:** Play, or Continue, is on screen at rest and hittable, inside
/// the window and above the home indicator, with nothing scrolled. Where the
/// fixed layout cannot fit, everything else scrolls and Play stays pinned, as
/// the board pins its controls. Shown red first with the fixed layout forced at
/// every size: on an SE, Play fell below the window from XXXL up.
///
/// **The top row:** the way back to the title costs it nothing. The row has
/// about 2pt to spare on an iPhone SE at XXXL (`The Meter's Budget`,
/// 2026-09-23), the budget a gear on it already failed, and the peach takes the
/// calendar's old slot, an overlay in a width the row already reserved. Held
/// against a copy of the meter, not a table: `-exposeTopRow 1` lays out a
/// hidden copy with no way back at the same width and prints both heights,
/// which must match. Shown red first with the peach ahead of the rank's name:
/// on an SE the meter measured 107.0pt against the copy's 79.5 at XXXL.
///
/// **At L and AX5, the title's order** in XCUITest's tree, which is the order VoiceOver
/// usually reads but not a promise of it: the name, the line, the date and the
/// streak, the week, Play, Past days, A day at random, How to play, Settings.
final class TitleAndTopRowAtEverySize: XCTestCase {
    static let sizes = [
        "UICTContentSizeCategoryL", "UICTContentSizeCategoryXL",
        "UICTContentSizeCategoryXXL", "UICTContentSizeCategoryXXXL",
        "UICTContentSizeCategoryAccessibilityM", "UICTContentSizeCategoryAccessibilityL",
        "UICTContentSizeCategoryAccessibilityXL", "UICTContentSizeCategoryAccessibilityXXL",
        "UICTContentSizeCategoryAccessibilityXXXL",
    ]

    /// "real=73.50 bare=73.50", as two numbers.
    static func heights(_ label: String) -> (real: Double, bare: Double)? {
        let parts = label.split(separator: " ").compactMap { $0.split(separator: "=").last }
            .compactMap { Double($0) }
        return parts.count == 2 ? (parts[0], parts[1]) : nil
    }

    /// The bottom safe-area inset, as `LayoutBudget` tables it: XCUITest has
    /// no safe-area API, and the supported phones have two answers.
    static func bottomInset(windowHeight: CGFloat) -> CGFloat {
        windowHeight <= 667 ? 0 : 34
    }

    func testTheTitleAndTheTopRowHoldAtEverySize() {
        for size in Self.sizes {
            let app = XCUIApplication()
            // The near-complete board, whose rank's name is the longest below
            // the crown, so the row is at its tightest; seeded, so Play goes
            // to the board rather than to How to play.
            app.launchArguments = ["-showTitle", "1", "-resetProgress", "1",
                                   "-seedBoard", "almost", "-exposeTopRow", "1",
                                   "-UIPreferredContentSizeCategoryName", size]
            app.launch()

            // The title, at rest.
            let play = app.buttons["TitlePlay"]
            XCTAssertTrue(play.waitForExistence(timeout: 30), "\(size): no title")
            let enabled = expectation(for: NSPredicate(format: "isEnabled == true"),
                                      evaluatedWith: play)
            XCTAssertEqual(XCTWaiter().wait(for: [enabled], timeout: 30), .completed,
                           "\(size): Play never became tappable")
            let window = app.windows.firstMatch.frame
            let floor = window.maxY - Self.bottomInset(windowHeight: window.height)
            XCTAssertGreaterThanOrEqual(play.frame.minY, window.minY, "\(size): Play above the window")
            XCTAssertLessThanOrEqual(play.frame.maxY, floor + 0.5,
                                     "\(size): Play ends at \(play.frame.maxY), below \(floor)")
            XCTAssertTrue(play.isHittable, "\(size): Play is not hittable at rest")
            // And the top: a layout that does not fit spills off both ends,
            // so the name starting inside the window is half of "nothing
            // clipped". The scrolling layout starts at the top.
            let name = app.staticTexts["Peach of a Word"].firstMatch
            XCTAssertTrue(name.exists, "\(size): no name on the title")
            XCTAssertGreaterThanOrEqual(name.frame.minY, window.minY,
                                        "\(size): the name starts above the window, at \(name.frame.minY)")
            print(String(format: "TITLE %@ name=%.1f play=%.1f..%.1f floor=%.1f", size,
                         name.frame.minY, play.frame.minY, play.frame.maxY, floor))

            // The order in both layouts: the fixed one at L, and at AX5 the
            // scrolling one, where Play is pinned in an inset of its own.
            if size == "UICTContentSizeCategoryL" || size == "UICTContentSizeCategoryAccessibilityXXXL" {
                assertReadingOrder(app, size)
            }

            // The board, and its top row.
            play.tap()
            let home = app.buttons["BoardHome"]
            XCTAssertTrue(home.waitForExistence(timeout: 30), "\(size): no way back on the board")
            XCTAssertTrue(home.isHittable, "\(size): the way back is not hittable")

            let probe = app.staticTexts["DebugTopRow"]
            XCTAssertTrue(probe.waitForExistence(timeout: 10), "\(size): no top-row probe")
            var read = Self.heights(probe.label)
            let deadline = Date().addingTimeInterval(5)
            while (read?.real ?? 0) == 0 || (read?.bare ?? 0) == 0, Date() < deadline {
                Thread.sleep(forTimeInterval: 0.2)
                read = Self.heights(probe.label)
            }
            guard let read, read.real > 0, read.bare > 0 else {
                XCTFail("\(size): the probe read \(probe.label)"); continue
            }
            print(String(format: "TOPROW %@ real=%.2f bare=%.2f", size, read.real, read.bare))
            XCTAssertEqual(read.real, read.bare, accuracy: 0.5,
                           "\(size): the meter with the way back is \(read.real)pt tall, "
                           + "without it \(read.bare)pt")
            app.terminate()
        }
    }

    /// The title's elements in the tree's order. Positions in the dump, since
    /// the tree is one ordered walk.
    ///
    /// **Two orders, one per layout.** Fixed, Play follows the week. Where the
    /// title scrolls, Play is pinned at the bottom in an inset of its own, and
    /// is read last, where it is drawn: the scroll view and the inset are
    /// siblings, so nothing can sort Play between the week and the links.
    private func assertReadingOrder(_ app: XCUIApplication, _ size: String) {
        let tree = app.debugDescription
        let pinned = app.scrollViews.firstMatch.exists
        let top = ["label: 'Peach of a Word'", "label: 'Pick the peaches'",
                   "identifier: 'TitleDate'", "identifier: 'TitleStreak'",
                   "identifier: 'WeekDay'", "identifier: 'WeekToday'"]
        let rest = ["identifier: 'TitlePastDays'", "identifier: 'TitleRandomDay'",
                    "identifier: 'TitleHowToPlay'", "identifier: 'TitleSettings'"]
        let play = ["identifier: 'TitlePlay'"]
        let marks = pinned ? top + rest + play : top + play + rest
        print("ORDER \(size) \(pinned ? "pinned" : "fixed")")
        var last = tree.startIndex
        for mark in marks {
            guard let found = tree.range(of: mark, range: last..<tree.endIndex) else {
                let order = tree.split(separator: "\n")
                    .filter { line in marks.contains { line.contains($0) } }
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                XCTFail("\(size): the title's tree has no \(mark) after the one before it; "
                        + "its order is \(order)")
                return
            }
            last = found.upperBound
        }
    }
}
