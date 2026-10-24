import XCTest

/// The title's peach grows with today's rank, and VoiceOver says how far.
///
/// **`-seedBoard full` grows it while the title is up:** the seed runs once
/// the board is ready, with the title over it, and finds every set word, so
/// the peach goes from First Sprout to the crown on any day. `-exposeGrowingPeach
/// 1` lists each change and whether it was animated or cut.
///
/// The drawings are the engine's, held to the box and to the approved table by
/// `GrowthStageTests`; these hold what the title does with them.
final class GrowingPeach: XCTestCase {
    static let sprout = "The peach is a first sprout."
    static let crown = "The peach is wearing its crown."

    /// A day with no costume stands in for the board's date, unless the test
    /// names one, so a run on a costume day still sees the stage.
    private func launch(_ extra: [String], reset: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = (reset ? ["-resetProgress", "1"] : [])
            + ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
            + (extra.contains("-costumeDate") ? [] : ["-costumeDate", "2026-10-30"])
            + extra
        app.launch()
        return app
    }

    private func peach(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["TitlePeach"]
    }

    private func says(_ app: XCUIApplication, _ label: String, timeout: TimeInterval) -> Bool {
        let wait = expectation(for: NSPredicate(format: "label == %@", label),
                               evaluatedWith: peach(app))
        return XCTWaiter().wait(for: [wait], timeout: timeout) == .completed
    }

    private func changes(_ app: XCUIApplication) -> String {
        let probe = app.staticTexts["DebugGrowingPeach"]
        XCTAssertTrue(probe.waitForExistence(timeout: 30), "no growing peach probe")
        return probe.label
    }

    /// The probe once it has something: it reads "none" until the seed runs.
    private func firstChange(_ app: XCUIApplication) -> String {
        let probe = app.staticTexts["DebugGrowingPeach"]
        let wait = expectation(for: NSPredicate(format: "label != %@", "none"), evaluatedWith: probe)
        _ = XCTWaiter().wait(for: [wait], timeout: 40)
        return probe.label
    }

    /// Before the first word, the ladder's first rank: a sprout, said.
    func testANewDayOpensOnTheSprout() {
        let app = launch(["-showTitle", "1"])
        XCTAssertTrue(app.buttons["TitlePlay"].waitForExistence(timeout: 30), "no title")
        XCTAssertTrue(says(app, Self.sprout, timeout: 10),
                      "a new day's title did not say the sprout: \(peach(app).label)")
    }

    /// Every set word found while the title is up: the crown, grown in.
    func testTheFullBasketCrownsItWhileTheTitleIsUp() {
        let app = launch(["-showTitle", "1", "-seedBoard", "full", "-exposeGrowingPeach", "1"])
        XCTAssertTrue(says(app, Self.crown, timeout: 40),
                      "a full basket did not crown the title's peach: \(peach(app).label)")
        XCTAssertEqual(changes(app), "first-sprout>crown animated")
    }

    /// The same change under Reduce Motion is a cut.
    func testUnderReduceMotionTheChangeIsACut() {
        let app = launch(["-showTitle", "1", "-seedBoard", "full", "-exposeGrowingPeach", "1",
                          "-reduceMotion", "1"])
        XCTAssertTrue(says(app, Self.crown, timeout: 40),
                      "a full basket did not crown the title's peach: \(peach(app).label)")
        XCTAssertEqual(changes(app), "first-sprout>crown cut")
    }

    /// The stage a day reached is drawn as soon as the title is, while the
    /// word lists are still loading, so nothing jumps when the board arrives.
    ///
    /// The second launch is the same day, so `-titleLastShownDay` is handed a
    /// value that is no day, which reads as the title not yet shown today. The
    /// hold is long because nothing waits for it to end, and a slow runner's
    /// launch eats into it.
    func testTheStageIsRememberedBeforeTheBoardLoads() {
        let first = launch(["-showTitle", "1", "-seedBoard", "full"])
        XCTAssertTrue(says(first, Self.crown, timeout: 40), "the first launch never reached the crown")
        first.terminate()

        let app = launch(["-showTitle", "1", "-titleLastShownDay", "never", "-holdLoading", "30"],
                         reset: false)
        let play = app.buttons["TitlePlay"]
        XCTAssertTrue(play.waitForExistence(timeout: 10), "no title on the second launch")
        XCTAssertTrue(says(app, Self.crown, timeout: 5),
                      "the title did not draw the remembered crown while loading: \(peach(app).label)")
        XCTAssertFalse(play.isEnabled, "the board was ready already, so this proved nothing")
    }

    /// Back on the title from a past day, the peach is still today's, from the
    /// store. The board in play is the past day's, which has no words, so a
    /// title reading the board in play would say the sprout. The seed runs
    /// once, at launch, so it never reaches the past day.
    func testAPastDayLeavesTodaysStage() {
        let app = launch(["-showTitle", "1", "-seedBoard", "full"])
        XCTAssertTrue(says(app, Self.crown, timeout: 40), "today never reached the crown")

        app.buttons["TitleRandomDay"].tap()
        XCTAssertTrue(app.staticTexts["ArchiveDateRow"].waitForExistence(timeout: 10),
                      "a day at random did not open a past board")
        app.buttons["BoardHome"].tap()
        XCTAssertTrue(app.buttons["TitlePlay"].waitForExistence(timeout: 10),
                      "the way back did not open the title")
        XCTAssertTrue(says(app, Self.crown, timeout: 5),
                      "the title drew the past day's stage, not today's: \(peach(app).label)")
    }

    /// A launch that opens on the board shows the splash while it loads, and
    /// the splash keeps the plain peach, however far today has grown.
    func testTheSplashKeepsThePlainPeach() {
        let first = launch(["-showTitle", "1", "-seedBoard", "full"])
        XCTAssertTrue(says(first, Self.crown, timeout: 40), "the first launch never reached the crown")
        first.terminate()

        let app = launch(["-holdLoading", "30"], reset: false)
        XCTAssertTrue(app.staticTexts["Picking the peaches."].waitForExistence(timeout: 10),
                      "no splash on a launch that opens on the board")
        XCTAssertFalse(app.buttons["TitlePlay"].exists, "the title came up, not the splash")
        let spoken = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", Self.crown))
        XCTAssertEqual(spoken.count, 0, "the splash drew today's stage, not the plain peach")
    }

    /// On a costume day the costume wins over the stage, as it did over the
    /// plain peach.
    func testACostumeWinsOverTheStage() {
        let app = launch(["-showTitle", "1", "-seedBoard", "full", "-exposeGrowingPeach", "1",
                          "-costumeDate", "2026-10-31"])
        XCTAssertTrue(app.buttons["TitlePlay"].waitForExistence(timeout: 30), "no title")
        XCTAssertEqual(firstChange(app), "first-sprout>crown animated",
                       "the stage never changed beneath the costume, so this proved nothing")
        XCTAssertTrue(says(app, "The peach is in a ghost sheet.", timeout: 5),
                      "the stage was said over the costume: \(peach(app).label)")
    }
}
