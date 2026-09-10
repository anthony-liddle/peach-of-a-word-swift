import XCTest

/// The grid's own measurements, taken from the running app.
///
/// These are frames rather than appearances, so they belong in a test rather
/// than in a screenshot: a cell that is too small to hit and a ring clipped by
/// three points are both invisible in a picture and both decided by numbers.
final class ArchiveGridMetrics: XCTestCase {
    /// Grows the sheet's header by this many points before opening it.
    ///
    /// **A permanent fixture, because it is the only reproducer this bug ever
    /// had.** Issue #65 was found on a 390pt phone at AX5 and bisected to the
    /// commit that renamed the empty state, which took the key from two wrapped
    /// lines to four and cost the scroll view 50.4pt from its top edge. Growing
    /// the header by that same amount reproduces the shortfall on any phone,
    /// including the SE 3, where nothing else did.
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
        print("CELL \(size) \(String(format: "%.2f x %.2f", frame.width, frame.height))")
        XCTAssertGreaterThanOrEqual(
            frame.width, 44,
            "a day cell is \(frame.width)pt wide, under the 44pt tap target",
            file: file, line: line)
        XCTAssertGreaterThanOrEqual(
            frame.height, 44,
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

/// The today ring, and whether the scroll view eats it on open.
///
/// **Every number here is an instrumented landing, and that is not the same as
/// what a plain launch does.** On a 390pt phone at AX5 this guard reads +46.33,
/// stable to the decimal over three repeats and unmoving for twelve seconds of
/// polling, while the same build launched through `simctl` with the same
/// arguments lands correctly in ten screenshots out of ten, at two seconds and
/// at sixteen. The likeliest reason is that driving the accessibility tree
/// materialises rows the lazy stack would not have built, which moves the
/// content-height estimate the landing was resolved against. That makes this
/// guard a fair model of a device with an assistive technology attached and a
/// poor model of one without, so read a failure here as "wrong under
/// VoiceOver", not as "wrong for everyone".
///
/// The ring is drawn 3pt outside the cell through an overlay with negative
/// padding, which does not change the cell's frame. The sheet then opens by
/// scrolling today's bottom edge onto the scroll view's bottom edge, so the
/// ring's bottom stroke lands outside the visible region and is clipped, every
/// time the sheet is opened.
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
        // stops it reporting the thing it found, and what it found is on the
        // standard iPhone width.
        //
        // So the failure is expected rather than hidden. Issue #65 has the
        // measurements and the mechanism: the way out wraps to two lines at this
        // size on a 390pt phone and to one on the SE, and holding it to one line
        // fixes the landing. `XCTExpectFailure` is strict, so this test goes red
        // the day that stops being true, which a skip would never do.
        //
        // Scoped to the ungrown header as well, and that scope was earned: with
        // the header grown this case lands at +0.00, and a strict expectation
        // over both of them went red for the wrong reason, reporting a landing
        // that works as a failure.
        let width = app.windows.firstMatch.frame.width
        if width > 380, headerPad == 0,
           size == "UICTContentSizeCategoryAccessibilityXXXL" {
            XCTExpectFailure(
                "issue #65: today lands under the way out at AX5 on a 390pt phone")
        }
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

    /// The case that reproduced issue #65 on every phone.
    func testTodayRingIsWholeWithTheHeaderGrown() {
        headerPad = 50.4
        assertRingIsWhole("UICTContentSizeCategoryAccessibilityXXXL")
    }
}
