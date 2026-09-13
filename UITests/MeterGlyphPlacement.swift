import XCTest

/// Where the archive glyph sits in the meter's top row.
///
/// The button is a 44pt box overlaid at the meter's top trailing corner with the
/// glyph centred in it, so the glyph's centre is 22pt down from the meter's top.
/// The top row is about 26pt tall and its text centres near 13pt, which leaves
/// the glyph sitting low enough to touch the track below it.
///
/// Measured against the points label rather than against a constant: the row's
/// height moves with Dynamic Type, so the only stable claim is that the two are
/// on the same line as each other.
final class MeterGlyphPlacement: XCTestCase {
    private func launched(_ size: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-resetProgress", "1", "-seedBoard", "almost",
            "-UIPreferredContentSizeCategoryName", size,
        ]
        app.launch()
        XCTAssertTrue(app.staticTexts["FoundSummaryCount"].waitForExistence(timeout: 30),
                      "the app never rendered")
        return app
    }

    private func assertGlyphIsOnItsRow(_ size: String, file: StaticString = #filePath,
                                       line: UInt = #line) {
        let app = launched(size)
        let glyph = app.buttons["Past days"].firstMatch
        let points = app.staticTexts["MeterPoints"].firstMatch
        let track = app.otherElements["MeterTrack"].firstMatch
        XCTAssertTrue(glyph.waitForExistence(timeout: 10), "no archive glyph",
                      file: file, line: line)
        XCTAssertTrue(points.exists, "no points label", file: file, line: line)

        let drift = glyph.frame.midY - points.frame.midY
        // The hit box, reported rather than asserted.
        //
        // `ArchiveGlyph` is on the image, but the accessibility element is the
        // 44pt frame wrapped around it, so this measures the target and not the
        // drawn mark. The target is ALLOWED across the track, which is not
        // interactive; the mark is not. A frame cannot tell those apart, so the
        // mark's clearance is measured in pixels from a screenshot instead and
        // recorded in the report rather than asserted here. A test that cannot
        // fail for the right reason is not a guard.
        let box = app.images["ArchiveGlyph"].firstMatch
        let boxFrame = box.exists ? box.frame : glyph.frame
        print(String(format: "GLYPH %@ drift %+.2f box=%.1f..%.1f track=%.1f..%.1f",
                     size, drift, boxFrame.minY, boxFrame.maxY,
                     track.frame.minY, track.frame.maxY))

        XCTAssertLessThanOrEqual(
            abs(drift), 1,
            "the archive glyph sits \(drift)pt off the points label's line",
            file: file, line: line)
    }

    func testGlyphIsOnThePointsLineAtDefaultSize() {
        assertGlyphIsOnItsRow("UICTContentSizeCategoryL")
    }

    func testGlyphIsOnThePointsLineAtXXXL() {
        assertGlyphIsOnItsRow("UICTContentSizeCategoryXXXL")
    }
}
