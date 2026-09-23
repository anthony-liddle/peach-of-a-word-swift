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
    static func rackTile(_ app: XCUIApplication) -> XCUIElement {
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
    static func rackIsFixed(_ app: XCUIApplication) -> Bool {
        let tile = rackTile(app).frame
        return !app.scrollViews.allElementsBoundByIndex.contains { $0.frame.contains(tile) }
    }

    private func probe(_ size: String,
                       extra: [String] = [],
                       tag: String = "LAYOUT") {
        let app = XCUIApplication()
        app.launchArguments = [
            "-resetProgress", "1", "-seedBoard", "almost",
            "-UIPreferredContentSizeCategoryName", size,
        ] + extra
        app.launch()
        // Waiting on the element rather than sleeping a fixed 2.5s and hoping.
        // A sleep that is too short reports "indeterminate", which reads as a
        // layout finding rather than as a test that gave up too early.
        let summary = app.staticTexts["FoundSummaryCount"]
        guard summary.waitForExistence(timeout: 15), Self.rackTile(app).exists else {
            print("\(tag) \(size) = indeterminate"); return
        }
        let fixed = Self.rackIsFixed(app)
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
        let rack = rackGeometry(app)
        let meter = app.descendants(matching: .any)["MeterTrack"].firstMatch.frame
        print("\(tag) \(size) window=\(Int(win.width))x\(Int(win.height)) "
              + "mode=\(fixed ? "FIXED" : "fallback") list=\(list) "
              + "cols=\(rack.columns) tile=\(rack.size) "
              + "meter=\(String(format: "%.2f+%.2f", meter.minY, meter.height)) "
              + "controls=\(controlsReport(app)) \(restReport(app))")
        shoot(app, name: "\(tag)-\(Int(win.width))x\(Int(win.height))-\(size)")
    }

    /// The four controls, by the labels they already carry.
    static let controlLabels = ["Shuffle", "Pick word", "Clear", "Delete last letter"]

    /// The bottom safe-area inset, from the window's height.
    ///
    /// **A table, because XCUITest has no safe-area API**, and the property
    /// being measured is where a control sits against the home indicator. Every
    /// supported phone with a home button is 667pt tall and has no bottom
    /// inset; every phone without one reserves 34pt in portrait. The table
    /// has two rows because the hardware has two answers.
    static func bottomInset(windowHeight: CGFloat) -> CGFloat {
        windowHeight <= 667 ? 0 : 34
    }

    /// A control is on screen when its whole frame sits inside the window and
    /// above the bottom inset, **at rest, with nothing scrolled**, and is
    /// hittable.
    ///
    /// Hittable alone is not the property. In the scrolling fallback a control
    /// below the fold is reachable by a scroll, and XCUITest's answer to
    /// "hittable" says nothing about whether the finger had to travel first.
    /// The frame against the window is what a player actually sees on launch.
    static func controlIsOnScreen(_ control: XCUIElement,
                                  in app: XCUIApplication) -> Bool {
        guard control.exists else { return false }
        let win = app.windows.firstMatch.frame
        let f = control.frame
        let floor = win.maxY - bottomInset(windowHeight: win.height)
        return f.minY >= win.minY && f.maxY <= floor + 0.5 && control.isHittable
    }

    private func controlsReport(_ app: XCUIApplication) -> String {
        let win = app.windows.firstMatch.frame
        let floor = win.maxY - Self.bottomInset(windowHeight: win.height)
        var off: [String] = []
        for label in Self.controlLabels {
            let c = app.buttons[label]
            if !Self.controlIsOnScreen(c, in: app) {
                let bottom = c.exists ? String(format: "%.1f", c.frame.maxY) : "absent"
                off.append("\(label)@\(bottom)")
            }
        }
        return off.isEmpty
            ? "all-on"
            : "OFF[\(off.joined(separator: ","))|floor=\(Int(floor))]"
    }

    /// The controls block's height, and how many tiles are usable at rest.
    ///
    /// The block runs from the top of the highest control to the bottom of the
    /// lowest; where the controls are pinned, the bar around them adds its 8pt
    /// of padding above and below. A tile counts as usable at rest when it sits
    /// wholly on screen above the top of the controls and is hittable, which in
    /// the scrolling layout is the question of whether the pinned bar has
    /// covered the rack.
    private func restReport(_ app: XCUIApplication) -> String {
        let controls = Self.controlLabels.map { app.buttons[$0] }.filter { $0.exists }
        guard !controls.isEmpty else { return "block=none tilesAtRest=?" }
        let top = controls.map { $0.frame.minY }.min()!
        let bottom = controls.map { $0.frame.maxY }.max()!
        let win = app.windows.firstMatch.frame
        let usable = app.buttons.matching(
            NSPredicate(format: "label MATCHES %@", "^Letter [a-z].*")
        ).allElementsBoundByIndex.filter {
            $0.frame.minY >= win.minY && $0.frame.maxY <= top && $0.isHittable
        }.count
        return String(format: "block=%.2f top=%.2f tilesAtRest=%d", bottom - top, top, usable)
    }

    /// Columns and the first tile's size, read off the tiles' own frames.
    ///
    /// Columns are the tiles sharing the first row's top edge. Rows below the
    /// fold may be absent from the tree altogether, since the grid is lazy, so
    /// this counts the first row rather than dividing eight by the rows seen.
    private func rackGeometry(_ app: XCUIApplication) -> (columns: Int, size: String) {
        let tiles = app.buttons.matching(
            NSPredicate(format: "label MATCHES %@", "^Letter [a-z].*")
        ).allElementsBoundByIndex
        guard let first = tiles.first else { return (0, "none") }
        let top = first.frame.minY.rounded()
        let columns = tiles.filter { $0.frame.minY.rounded() == top }.count
        return (columns, String(format: "%.2fx%.2f", first.frame.width, first.frame.height))
    }

    /// A screenshot per cell, written to the host when `MATRIX_SHOTS` names a
    /// directory (passed as `TEST_RUNNER_MATRIX_SHOTS`), and nothing otherwise.
    private func shoot(_ app: XCUIApplication, name: String) {
        guard let dir = ProcessInfo.processInfo.environment["MATRIX_SHOTS"] else { return }
        let url = URL(fileURLWithPath: dir).appendingPathComponent("\(name).png")
        try? app.screenshot().pngRepresentation.write(to: url)
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
        XCTAssertTrue(Self.rackTile(app).exists, "no rack tile found")
        XCTAssertTrue(
            Self.rackIsFixed(app),
            "the rack is inside a scroll view, so this fell back to the "
            + "scrolling layout at default size on a tall phone"
        )
    }

    /// The same sweep, on an archive board.
    ///
    /// **The meter grows a second row when a past day is on screen**, carrying
    /// the date and the way back, and a row is the thing this whole file exists
    /// to price. It appears only on an archive board, so `testSweep` never sees
    /// it: without this the fixed layout's survival on the one screen that has
    /// extra furniture would be a matter of opinion.
    ///
    /// `-archiveDay 7` opens a past board at launch, because the board cannot be
    /// reached without a tap and a launch argument cannot perform one.
    func testArchiveSweep() {
        for s in ["UICTContentSizeCategoryL",
                  "UICTContentSizeCategoryXL",
                  "UICTContentSizeCategoryXXL",
                  "UICTContentSizeCategoryXXXL"] {
            probe(s, extra: ["-seedArchive", "showcase", "-archiveDay", "7"], tag: "ARCHIVE")
        }
    }

    /// Every size from L up, for the matrix: the normal range and all five
    /// accessibility sizes, since the rack reflows and the tiles grow across
    /// the second half and a sweep that samples two of them cannot say where.
    func testMatrix() {
        for s in ["UICTContentSizeCategoryL",
                  "UICTContentSizeCategoryXL",
                  "UICTContentSizeCategoryXXL",
                  "UICTContentSizeCategoryXXXL",
                  "UICTContentSizeCategoryAccessibilityM",
                  "UICTContentSizeCategoryAccessibilityL",
                  "UICTContentSizeCategoryAccessibilityXL",
                  "UICTContentSizeCategoryAccessibilityXXL",
                  "UICTContentSizeCategoryAccessibilityXXXL"] {
            probe(s, tag: "MATRIX")
        }
    }

    /// How tall one group header and one row of chips are, at each size.
    ///
    /// This is what "a list worth calling a list" means in points, and the
    /// floor on the found list is justified against it rather than chosen.
    /// Read off the first group's own frames: its combined header element,
    /// and the first chip beneath it.
    func testHeaderAndRow() {
        for s in ["UICTContentSizeCategoryL",
                  "UICTContentSizeCategoryXL",
                  "UICTContentSizeCategoryXXL",
                  "UICTContentSizeCategoryXXXL",
                  "UICTContentSizeCategoryAccessibilityM",
                  "UICTContentSizeCategoryAccessibilityXXXL"] {
            let app = XCUIApplication()
            app.launchArguments = [
                "-resetProgress", "1", "-seedBoard", "almost",
                "-UIPreferredContentSizeCategoryName", s,
            ]
            app.launch()
            let header = app.descendants(matching: .any).matching(
                NSPredicate(format: "label MATCHES %@", "^[0-9]+ letters.*")
            ).firstMatch
            guard header.waitForExistence(timeout: 15) else {
                print("HEADROW \(s) = indeterminate"); continue
            }
            let top = header.frame
            let chip = app.buttons.matching(
                NSPredicate(format: "label MATCHES %@", ".*, [0-9]+ points?$")
            ).allElementsBoundByIndex.first { $0.frame.minY >= top.maxY - 1 }
            guard let chip else { print("HEADROW \(s) = no chip"); continue }
            print("HEADROW \(s) header=\(String(format: "%.2f", top.height)) "
                  + "chip=\(String(format: "%.2f", chip.frame.height)) "
                  + "headerPlusRow=\(String(format: "%.2f", chip.frame.maxY - top.minY))")
        }
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
