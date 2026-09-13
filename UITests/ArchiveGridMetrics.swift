import XCTest

/// The grid's own measurements, taken from the running app.
///
/// These are frames rather than appearances, so they belong in a test rather
/// than in a screenshot: a cell that is too small to hit and a ring clipped by
/// three points are both invisible in a picture and both decided by numbers.
final class ArchiveGridMetrics: XCTestCase {
    /// Grows the sheet's header by this many points before opening it.
    ///
    /// **A permanent fixture, because a squeezed container is a case worth
    /// holding.** Its stated reason used to be that it was the only reproducer
    /// this bug ever had, and that was wrong twice over. Issue #65 was found on
    /// a 390pt phone at AX5 and bisected to the commit that renamed the empty
    /// state, which took the key from two wrapped lines to four and cost the
    /// scroll view 50.4pt from its top edge. Growing the header by that amount
    /// was then said to reproduce the same shortfall on the SE 3.
    ///
    /// It does not. Measured at `1508760` with this fixture, the SE fails at the
    /// **top**, +118.50pt grown and +68.00 ungrown, with today above the scroll
    /// view rather than beneath the way out. The screenshot that was read as a
    /// bottom collision has 12.5pt of clearance and a ring whose top is covered
    /// by the pinned month heading. So the fixture reproduces a squeezed
    /// viewport, which is useful, and not #65, which has only ever appeared on
    /// the 390pt phone under XCUITest.
    ///
    /// The pinned heading drawn over the ring is invisible here, because this
    /// guard only asks whether the ring overshoots the scroll view's edges.
    private var headerPad: Double = 0
    private var headerPadArguments: [String] {
        headerPad > 0 ? ["-headerPad", String(headerPad)] : []
    }

    private func openArchive(_ size: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-resetProgress", "1", "-seedArchive", "showcase", "-openArchive", "1",
            "-UIPreferredContentSizeCategoryName", size,
        ] + headerPadArguments
        app.launch()
        XCTAssertTrue(app.buttons["Back to the basket"].waitForExistence(timeout: 30),
                      "the archive sheet never opened")
        return app
    }

    /// Any day that can be opened. Matched on its spoken state rather than on a
    /// date, because the dates move every morning and `LayoutBudget` records
    /// what a date-dependent query costs.
    private func playableCell(_ app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "Finished")
        ).element(boundBy: 0)
    }

    /// A grid cell is a tap target, and `Cute.minTapTarget` is 44.
    private func assertTapTarget(_ size: String, file: StaticString = #filePath,
                                 line: UInt = #line) {
        let app = openArchive(size)
        let cell = playableCell(app)
        XCTAssertTrue(cell.waitForExistence(timeout: 10), "no playable day cell",
                      file: file, line: line)
        let frame = cell.frame
        // The presentation alongside the cell, because the two are one
        // decision. A fitted card starts well down the screen; the large
        // detent starts at the top. **What is measured here is glass, not
        // layout**: from iOS 26 a sheet at a custom detent is scaled, so a
        // 44pt cell laid out inside it can arrive smaller, and the tap target
        // is about the finger.
        let title = app.staticTexts["Past days"].firstMatch
        let sheetTop = title.exists ? title.frame.minY : -1
        print(String(format: "CELL %@ %.2f x %.2f sheetTop %.2f",
                     size, frame.width, frame.height, sheetTop))
        // **A hair of tolerance, for the boundary and not for the rule.** A
        // 375pt phone divides into seven 44.14pt columns and reports them as
        // 44.0, which is the minimum exactly. Two of the five phones measured
        // come back as 43.999999999999986, one part in 10^15 under, and the
        // other as 44.0 on the nose. That difference is arithmetic, not a
        // smaller target. Anything that actually shrinks a cell moves it by
        // points: the card scaling took the same cell to 42.12.
        let floor = 44 - 0.001
        XCTAssertGreaterThanOrEqual(
            frame.width, floor,
            "a day cell is \(frame.width)pt wide, under the 44pt tap target",
            file: file, line: line)
        XCTAssertGreaterThanOrEqual(
            frame.height, floor,
            "a day cell is \(frame.height)pt tall, under the 44pt tap target",
            file: file, line: line)
    }

    func testCellIsATapTargetAtDefaultSize() {
        assertTapTarget("UICTContentSizeCategoryL")
    }

    func testCellIsATapTargetAtAccessibilitySize() {
        assertTapTarget("UICTContentSizeCategoryAccessibilityXXXL")
    }
}

/// The today ring, and whether the grid eats it on open.
///
/// The sheet shows one month and the grid scrolls only when the month does not
/// fit, which is the accessibility sizes. So this asks a smaller question than
/// it used to: not whether a landing resolved, but whether today is whole inside
/// the viewport it has.
///
/// **These are still instrumented readings.** A plain `simctl` launch and an
/// XCUITest run disagreed in both directions under the old design, on one
/// stamped bundle, and the reason was never found. The pixel locator in
/// `2026-09-10 Which Build Took Which Picture.md` is the other half of this
/// check and the two now agree.
extension ArchiveGridMetrics {
    /// How far the ring is drawn outside the cell. Mirrors
    /// `ArchiveCellFace.ringOutset`, deliberately duplicated here: a test that
    /// imported the value would pass whatever the app changed it to.
    private static let ringOutset: CGFloat = 3

    private func assertRingIsWhole(_ size: String, file: StaticString = #filePath,
                                   line: UInt = #line) {
        let app = openArchive(size)
        // **Not scoped to a phone, and it was for a while.**
        //
        // This guard was narrowed to the SE 3 when it failed on a 390pt phone at
        // AX5, on the reasoning that the SE was the device it was specified for.
        // It was not: the cell-size guard names a device, this one asks for
        // default and AX5 and names none. Narrowing a guard to where it passes
        // stops it reporting the thing it found.
        //
        // The 390pt AX5 case then carried a strict `XCTExpectFailure` for #65.
        // It is gone, and it earned its own removal: on the month page it went
        // red with "expected failure but none recorded", which is a strict
        // expectation reporting that the thing it expected to fail now passes.
        let today = app.buttons["ArchiveTodayCell"].firstMatch
        XCTAssertTrue(today.waitForExistence(timeout: 10), "today is not in the tree at all",
                      file: file, line: line)
        // **Existing is not being on screen, and this guard learned that the
        // hard way.** With the landing scroll removed the sheet opened on August
        // with today far below the fold, and every overshoot below came back
        // comfortably negative: XCUITest reports a frame for a cell the lazy
        // stack has built but is not showing. A negative number is only good news
        // if the thing is actually visible.
        XCTAssertTrue(today.isHittable,
                      "today has a frame but is not on screen",
                      file: file, line: line)
        let scroll = app.scrollViews["ArchiveScroll"].firstMatch
        XCTAssertTrue(scroll.exists, "no archive scroll view", file: file, line: line)

        // Wait for the opening scroll to stop moving before measuring.
        //
        // `.task` runs the scroll after the sheet exists, so the Back button
        // appearing is not the same event. On a 390pt phone at AX5 the header
        // takes most of the sheet and the scroll view is left about 227pt tall,
        // where the settle is slow enough that the first read caught today 46pt
        // below the viewport and the screenshot taken seconds later showed it
        // correctly placed. A guard that measures mid-animation reports the
        // animation.
        var previous = today.frame
        for _ in 0..<20 {
            Thread.sleep(forTimeInterval: 0.25)
            let now = today.frame
            if abs(now.minY - previous.minY) < 0.5 { break }
            previous = now
        }

        let ring = today.frame.insetBy(dx: -Self.ringOutset, dy: -Self.ringOutset)
        let visible = scroll.frame
        let overshootBottom = ring.maxY - visible.maxY
        let overshootTop = visible.minY - ring.minY
        // The way out is measured alongside, because it is the only furniture
        // between the scroll view's bottom edge and the sheet's.
        let wayOut = app.buttons["Back to the basket"].firstMatch
        print(String(format:
            "RING %@ ring %.1f..%.1f scroll %.1f..%.1f h=%.1f wayOut h=%.1f bottom %+.2f top %+.2f",
            size, ring.minY, ring.maxY, visible.minY, visible.maxY, visible.height,
            wayOut.exists ? wayOut.frame.height : -1,
            overshootBottom, overshootTop))

        // **A viewport smaller than the ring cannot show the whole ring, and
        // asking it to is not a test.** With `-headerPad 50.4` on an SE 3 at
        // AX5 the grid is left 41.5pt, shorter than one 44pt cell, so every
        // scroll position clips. What can still be demanded there is that the
        // layout does the best available thing and centres today, rather than
        // parking it against an edge with all the loss at one end.
        guard visible.height >= ring.height else {
            let imbalance = abs(overshootTop - overshootBottom)
            XCTAssertLessThanOrEqual(
                imbalance, 1.5,
                "the viewport is \(visible.height)pt against a \(ring.height)pt ring, "
                + "so today cannot be whole, and it is off centre by \(imbalance)pt",
                file: file, line: line)
            return
        }

        XCTAssertLessThanOrEqual(
            overshootBottom, 0,
            "the today ring is clipped by \(overshootBottom)pt at the bottom",
            file: file, line: line)
        XCTAssertLessThanOrEqual(
            overshootTop, 0,
            "the today ring is clipped by \(overshootTop)pt at the top",
            file: file, line: line)
    }

    func testTodayRingIsWholeOnOpenAtDefaultSize() {
        assertRingIsWhole("UICTContentSizeCategoryL")
    }

    func testTodayRingIsWholeOnOpenAtAccessibilitySize() {
        assertRingIsWhole("UICTContentSizeCategoryAccessibilityXXXL")
    }

    /// The smallest viewport the sheet is known to survive.
    ///
    /// This is the case that reproduced issue #65, and on the month page it can
    /// no longer do so. What it still does is squeeze the grid to 41.5pt, under
    /// one 44pt cell, which is where the assertion above stops asking for a
    /// whole ring and asks for a centred one.
    func testTodayRingIsWholeWithTheHeaderGrown() {
        headerPad = 50.4
        assertRingIsWhole("UICTContentSizeCategoryAccessibilityXXXL")
    }
}
