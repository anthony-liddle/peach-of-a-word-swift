import XCTest

/// A new Mythic find's gem glints, once, and only a find made by play.
///
/// **Held through `-exposeGlint 1`,** the model's list of finds that glinted.
/// The glint is drawn and never spoken, so the tree cannot see it; its
/// pictures are in the pull request.
///
/// On 17 July 2026's board, `courtesy`, which has twenty Mythic words, opened
/// as today. `-findMythic 1` finds the first of them, alphabetically, through
/// the tile path, as a player would.
final class MythicGlint: XCTestCase {
    /// The `-dayOffset` that makes 17 July 2026 today.
    static var julySeventeenth: String {
        let cal = Calendar.current
        let target = cal.date(from: DateComponents(year: 2026, month: 7, day: 17))!
        return String(cal.dateComponents([.day], from: cal.startOfDay(for: TestClock.now),
                                          to: target).day!)
    }

    private func launch(_ extra: [String], reset: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = (reset ? ["-resetProgress", "1"] : [])
            + ["-dayOffset", Self.julySeventeenth, "-exposeGlint", "1",
               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
            + extra
        app.launch()
        return app
    }

    /// A Mythic chip in the list, by its spoken name.
    private func mythicChip(_ app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", ", Mythic, ")).firstMatch
    }

    private func glinted(_ app: XCUIApplication) -> String {
        let probe = app.staticTexts["DebugGlint"]
        XCTAssertTrue(probe.waitForExistence(timeout: 40), "no glint probe")
        return probe.label
    }

    func testAMythicFoundByPlayGlints() {
        let app = launch(["-findMythic", "1"])
        XCTAssertTrue(mythicChip(app).waitForExistence(timeout: 40), "no Mythic was found")
        XCTAssertNotEqual(glinted(app), "none", "a Mythic found by play did not glint")
    }

    func testNothingGlintsUnderReduceMotion() {
        let app = launch(["-findMythic", "1", "-reduceMotion", "1"])
        XCTAssertTrue(mythicChip(app).waitForExistence(timeout: 40), "no Mythic was found")
        XCTAssertEqual(glinted(app), "none", "a Mythic glinted under Reduce Motion")
    }

    /// Found, then the app opened again on the same board: the Mythic is in
    /// the list from the start, and has had its glint.
    func testAMythicAlreadyInTheListDoesNotGlint() {
        let app = launch(["-findMythic", "1"])
        XCTAssertTrue(mythicChip(app).waitForExistence(timeout: 40), "no Mythic was found")
        XCTAssertNotEqual(glinted(app), "none", "a Mythic found by play did not glint")
        app.terminate()

        let again = launch([], reset: false)
        XCTAssertTrue(mythicChip(again).waitForExistence(timeout: 40),
                      "the Mythic was not in the list on reopening")
        XCTAssertEqual(glinted(again), "none", "a Mythic already in the list glinted")
    }
}
