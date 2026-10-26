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

    // MARK: - The well

    /// Where each glint was drawn, "list 1,well 1", or "none".
    private func drawn(_ app: XCUIApplication) -> String {
        let probe = app.staticTexts["DebugGlintDrawn"]
        XCTAssertTrue(probe.waitForExistence(timeout: 40), "no drawn-glint probe")
        return probe.label
    }

    /// 24 October 2026's board, `literary`, as today, played by tapping.
    /// TEL is Mythic there, ARET Rare and LAY in the basket.
    private func launchLiterary(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-resetProgress", "1",
                               "-dayOffset", MarkInTheWell.octoberTwentyFourth,
                               "-exposeGlint", "1",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
            + extra
        app.launch()
        XCTAssertTrue(LayoutBudget.rackTile(app).waitForExistence(timeout: 40), "no rack")
        return app
    }

    private func found(_ word: String, _ rung: String, in app: XCUIApplication) {
        MarkInTheWell.pick(word, in: app)
        let chip = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "\(word), \(rung), ")).firstMatch
        XCTAssertTrue(chip.waitForExistence(timeout: 10), "\(word) was not found")
    }

    /// The well's mark glints with the list's, the same glint at the same time.
    func testAMythicFoundByPlayGlintsInTheWellAndTheList() {
        let app = launchLiterary()
        found("tel", "Mythic", in: app)
        let places = drawn(app).split(separator: ",").map(String.init)
        XCTAssertTrue(places.contains("well 1"), "the well's mark did not glint: \(places)")
        XCTAssertTrue(places.contains("list 1"), "the list's mark did not glint: \(places)")
    }

    func testNothingGlintsInTheWellUnderReduceMotion() {
        let app = launchLiterary(["-reduceMotion", "1"])
        found("tel", "Mythic", in: app)
        XCTAssertEqual(drawn(app), "none", "a mark glinted under Reduce Motion")
    }

    /// Only the line of the find just made. With the glint held open, the
    /// lines after TEL's, a rejection, a basket word and a Rare find, all come
    /// while it is still set, and none of them glints.
    func testOnlyTheMythicFindsOwnLineGlints() {
        let app = launchLiterary(["-holdGlint", "60"])
        found("tel", "Mythic", in: app)
        MarkInTheWell.pick("lyt", in: app)         // not a word
        found("lay", "on the page", in: app)
        found("aret", "Rare", in: app)
        let wells = drawn(app).split(separator: ",").filter { $0.hasPrefix("well") }
        XCTAssertEqual(wells, ["well 1"], "the well should glint for TEL's line alone")
    }

    /// TEL's line, redrawn while its glint is still set, does not play it
    /// again: the app sent to the background and brought back.
    func testTheWellsLineRedrawnDoesNotGlintAgain() {
        let app = launchLiterary(["-holdGlint", "60"])
        found("tel", "Mythic", in: app)
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(LayoutBudget.rackTile(app).waitForExistence(timeout: 20), "no rack")
        let wells = drawn(app).split(separator: ",").filter { $0.hasPrefix("well") }
        XCTAssertEqual(wells, ["well 1"], "the well should glint once, for TEL")
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
