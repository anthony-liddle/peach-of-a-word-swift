import XCTest

/// After a find, a tap on its line in the well opens that word's card, the one
/// its chip in the found list opens. Today the only way is to scroll to the
/// chip.
///
/// On 24 October 2026's board, `literary`, opened as today and played by
/// tapping its tiles, as a player would. TEL is Mythic there, ARET Rare, LAY
/// in the basket, and LITERARY the source word.
final class TapTheWell: XCTestCase {

    private func launch(_ extra: [String] = [], size: String = "L") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-resetProgress", "1",
                               "-dayOffset", MarkInTheWell.octoberTwentyFourth,
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategory\(size)"]
            + extra
        app.launch()
        XCTAssertTrue(LayoutBudget.rackTile(app).waitForExistence(timeout: 40), "no rack")
        return app
    }

    /// The well, by its identifier. Its label and its type change with what it
    /// shows, so neither can find it in every state.
    private func well(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["ComposingWell"].firstMatch
    }

    /// The way out every card carries, the cheapest proof that one is up.
    private func wayOut(_ app: XCUIApplication) -> XCUIElement {
        app.buttons["Back to the basket"].firstMatch
    }

    /// The crown card's kicker, which only that card carries. Not its
    /// celebration line: the well's own line says the same words, and the
    /// tree lists the well's text though VoiceOver never reads it.
    private func crownCard(_ app: XCUIApplication) -> XCUIElement {
        app.staticTexts["The peach every word grew from"]
    }

    /// A definition card's prose, which only a definition card carries.
    private func definitionCard(_ app: XCUIApplication) -> XCUIElement {
        app.staticTexts["DefinitionProse"]
    }

    /// Texts reading exactly this word. The board already has some, inside
    /// its chips, so a card for the word is one more than the board alone.
    private func texts(_ word: String, in app: XCUIApplication) -> Int {
        app.staticTexts.matching(NSPredicate(format: "label == %@", word)).count
    }

    private func found(_ word: String, _ rung: String, in app: XCUIApplication) {
        MarkInTheWell.pick(word, in: app)
        let chip = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "\(word), \(rung), ")).firstMatch
        XCTAssertTrue(chip.waitForExistence(timeout: 10), "\(word) was not found")
    }

    /// Tiles picked and not yet sent, by their spoken state.
    private func picked(_ app: XCUIApplication) -> [String] {
        app.buttons.matching(NSPredicate(format: "label ENDSWITH %@", ", already picked"))
            .allElementsBoundByIndex.map { $0.label }
    }

    // MARK: - What a tap does

    /// A Rare find's line opens that word's card, and closing it returns to
    /// the board with the line still there to open it again.
    func testARareFindsLineOpensItsCard() {
        let app = launch()
        found("aret", "Rare", in: app)
        let board = texts("aret", in: app)
        well(app).tap()
        XCTAssertTrue(definitionCard(app).waitForExistence(timeout: 10), "tapping ARET's line opened no card")
        XCTAssertEqual(texts("aret", in: app), board + 1, "the card that opened is not ARET's")

        wayOut(app).tap()
        XCTAssertTrue(definitionCard(app).waitForNonExistence(timeout: 10), "the card did not close")
        well(app).tap()
        XCTAssertTrue(definitionCard(app).waitForExistence(timeout: 10),
                      "after the card closed, the line no longer opened it")
        XCTAssertEqual(texts("aret", in: app), board + 1, "the card that reopened is not ARET's")
    }

    /// A basket word has no mark, and its line opens its card all the same.
    func testABasketWordsLineOpensItsCard() {
        let app = launch()
        found("lay", "on the page", in: app)
        let board = texts("lay", in: app)
        well(app).tap()
        XCTAssertTrue(definitionCard(app).waitForExistence(timeout: 10), "tapping LAY's line opened no card")
        XCTAssertEqual(texts("lay", in: app), board + 1, "the card that opened is not LAY's")
    }

    /// The source word's line reopens its reveal card, once the card that
    /// opened by itself has been closed.
    func testTheSourceWordsLineReopensTheRevealCard() {
        let app = launch()
        MarkInTheWell.pick("literary", in: app)
        XCTAssertTrue(crownCard(app).waitForExistence(timeout: 10), "finding LITERARY opened no reveal card")
        wayOut(app).tap()
        XCTAssertTrue(crownCard(app).waitForNonExistence(timeout: 10), "the reveal card did not close")

        well(app).tap()
        XCTAssertTrue(crownCard(app).waitForExistence(timeout: 10),
                      "tapping the source word's line did not reopen its reveal card")
    }

    /// The placeholder, a rejection, and a letter picked after a find: none of
    /// them is a find's line, so a tap on the well opens nothing, and it never
    /// places or removes a letter.
    func testNothingOpensFromThePlaceholderARejectionOrALetter() {
        let app = launch()
        well(app).tap()
        XCTAssertFalse(wayOut(app).waitForExistence(timeout: 2), "the placeholder opened a card")

        MarkInTheWell.pick("lyt", in: app)         // not a word
        well(app).tap()
        XCTAssertFalse(wayOut(app).waitForExistence(timeout: 2), "a rejection opened a card")

        found("tel", "Mythic", in: app)
        app.buttons["Letter a"].firstMatch.tap()
        well(app).tap()
        XCTAssertFalse(wayOut(app).waitForExistence(timeout: 2),
                       "the well opened a card once a letter was picked")
        XCTAssertEqual(picked(app), ["Letter a, already picked"], "a tap on the well changed the letters")
    }

    /// **The rack commits a tile on touch down** in the fixed layout, so a
    /// fast stroke between the line and the rack is where a letter could slip
    /// in or a card open. A stroke from the line to a tile places nothing,
    /// and opens nothing: a plain button fires on a lift that far outside
    /// itself, and the card it opened came up under a finger on a tile.
    ///
    /// The scrolling layout commits on lift and scrolls on a drag; its own
    /// guard is `testASwipeFromTheLineScrollsTheScrollingLayout`.
    func testAStrokeFromTheLineToATilePlacesNothingAndOpensNothing() throws {
        let app = launch()
        try XCTSkipUnless(LayoutBudget.rackIsFixed(app), "the rack scrolls at this size")
        found("tel", "Mythic", in: app)

        well(app).press(forDuration: 0.05, thenDragTo: app.buttons["Letter a"].firstMatch,
                        withVelocity: .fast, thenHoldForDuration: 0)
        XCTAssertFalse(wayOut(app).waitForExistence(timeout: 2), "a stroke off the line opened a card")
        XCTAssertEqual(picked(app), [], "a stroke from the line to the rack placed a letter")
    }

    /// The other way: a tile commits on touch down, the line is gone with
    /// the letter, and the lift over the well opens nothing.
    func testAStrokeFromATileToTheWellPlacesThatLetterAlone() throws {
        let app = launch()
        try XCTSkipUnless(LayoutBudget.rackIsFixed(app), "the rack scrolls at this size")
        found("tel", "Mythic", in: app)

        app.buttons["Letter a"].firstMatch.press(forDuration: 0.05, thenDragTo: well(app),
                                                 withVelocity: .fast, thenHoldForDuration: 0)
        XCTAssertFalse(wayOut(app).waitForExistence(timeout: 2), "a stroke onto the well opened a card")
        XCTAssertEqual(picked(app), ["Letter a, already picked"],
                       "a stroke from a tile to the well placed other than that tile's letter")
    }

    /// A tap that wobbles a few points is still a tap: the allowance that
    /// stops a slide is not so tight that a real tap misses.
    func testATapThatWobblesStillOpensTheCard() {
        let app = launch()
        found("aret", "Rare", in: app)
        let centre = well(app).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        centre.press(forDuration: 0.1, thenDragTo: centre.withOffset(CGVector(dx: 4, dy: 3)))
        XCTAssertTrue(definitionCard(app).waitForExistence(timeout: 10),
                      "a tap that moved 5pt opened no card")
    }

    /// **The scrolling layout keeps the page's scroll.** There the well is
    /// inside the scroll view, so a swipe that starts on the line must move
    /// the page, as it did before the line was a button, and open nothing.
    /// The fixed layout's slide-cancelling tap would hold the page still.
    func testASwipeFromTheLineScrollsTheScrollingLayout() throws {
        let app = launch(size: "AccessibilityXXXL")
        try XCTSkipIf(LayoutBudget.rackIsFixed(app), "the rack is fixed at AX5 on this phone")
        found("tel", "Mythic", in: app)
        let page = app.scrollViews.firstMatch
        for _ in 0..<4 where !well(app).isHittable { page.swipeDown() }
        XCTAssertTrue(well(app).isHittable, "the well could not be brought on screen")

        let tile = LayoutBudget.rackTile(app)
        let before = tile.frame.minY
        let start = well(app).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -120)),
                    withVelocity: .fast, thenHoldForDuration: 0)
        XCTAssertFalse(wayOut(app).waitForExistence(timeout: 2), "a swipe from the line opened a card")
        XCTAssertLessThan(tile.frame.minY, before - 20, "a swipe from the line did not scroll the page")
        XCTAssertEqual(picked(app), [], "a swipe from the line placed a letter")
    }

    // MARK: - To VoiceOver

    /// What was announced since launch, oldest first, by `-exposeAnnounced 1`.
    private func announced(_ app: XCUIApplication) -> [String] {
        let probe = app.staticTexts["DebugAnnounced"]
        XCTAssertTrue(probe.waitForExistence(timeout: 10), "no announcement probe")
        return probe.label == "none" ? [] : probe.label.components(separatedBy: " | ")
    }

    /// The well is its find's button while it shows one, named by what was
    /// announced; at other times it is the composing well it always was, and
    /// no button. Its hint, "Shows the definition", is the chips' own, which
    /// the tree does not carry; the report's VoiceOver pass hears it.
    func testTheLineIsAButtonOnlyWhileItShowsAFind() {
        let app = launch()
        let button = app.buttons["ComposingWell"]
        XCTAssertTrue(well(app).waitForExistence(timeout: 10), "no well")
        XCTAssertFalse(button.exists, "the placeholder is a button")

        MarkInTheWell.pick("lyt", in: app)         // not a word
        XCTAssertFalse(button.waitForExistence(timeout: 2), "a rejection is a button")

        found("tel", "Mythic", in: app)
        XCTAssertTrue(button.waitForExistence(timeout: 5), "TEL's line is not a button")
        XCTAssertEqual(button.label, "Mythic find: tel, 5 points")

        app.buttons["Letter a"].firstMatch.tap()
        XCTAssertTrue(button.waitForNonExistence(timeout: 5),
                      "the well stayed a button once a letter was picked")
        XCTAssertEqual(well(app).label, "Picked so far: a")
    }

    /// The source word's line is a button too, named by what it shows.
    func testTheSourceWordsLineIsAButtonNamedByWhatItShows() {
        let app = launch()
        MarkInTheWell.pick("literary", in: app)
        XCTAssertTrue(crownCard(app).waitForExistence(timeout: 10), "finding LITERARY opened no reveal card")
        wayOut(app).tap()
        XCTAssertTrue(crownCard(app).waitForNonExistence(timeout: 10), "the reveal card did not close")
        let button = app.buttons["ComposingWell"]
        XCTAssertTrue(button.waitForExistence(timeout: 5), "the source word's line is not a button")
        XCTAssertEqual(button.label, "You found the Peach of a Word!")
    }

    /// **A find is said once,** by the announcement posted as it lands, and
    /// opening its card from the line and closing it says nothing more. The
    /// tree cannot hear VoiceOver, so this holds the app to the announcements
    /// it posts; whether VoiceOver's focus stays put is the report's check.
    func testAFindIsAnnouncedOnce() {
        let app = launch(["-exposeAnnounced", "1"])
        found("tel", "Mythic", in: app)
        XCTAssertEqual(announced(app), ["Mythic find: tel, 5 points."])

        well(app).tap()
        XCTAssertTrue(wayOut(app).waitForExistence(timeout: 10), "the line opened no card")
        wayOut(app).tap()
        XCTAssertTrue(wayOut(app).waitForNonExistence(timeout: 10), "the card did not close")
        XCTAssertEqual(announced(app), ["Mythic find: tel, 5 points."],
                       "opening and closing the card said the find again")

        found("aret", "Rare", in: app)
        XCTAssertEqual(announced(app), ["Mythic find: tel, 5 points.", "Rare find: aret, 5 points."])
    }
}
