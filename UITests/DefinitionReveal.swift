import XCTest

/// Tapping a found word, and which card it opens.
///
/// **Nothing here names a word.** `-seedBoard almost` seeds TODAY's daily
/// puzzle and the crown rotates daily, so a test that taps "resident" passes on
/// one day in 626. `LayoutBudget` carries the scar from exactly that mistake:
/// it queried a summary by the text "47 of 48 words", matched on roughly one
/// day in sixty, and failed at every commit including ones months older. Chips
/// are found by the category in their accessibility label instead, which is a
/// property of the rung rather than of the day.
///
/// The chip labels are built in `WordChip` as "word, spoken category, N points",
/// and `WordCategory.spokenName` supplies "source word", "on the page",
/// "Uncommon", "Rare", "Mythic".
final class DefinitionReveal: XCTestCase {

    private func seededApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-resetProgress", "1", "-seedBoard", "almost",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL",
        ]
        app.launch()
        return app
    }

    /// Chips combine their children, so each is one element whose label starts
    /// with the word. Queried across all descendants rather than `app.buttons`
    /// because the chip is a button whose label is the combined string, and a
    /// looser query is safe here: nothing else on the screen ends in " points".
    private func chips(_ app: XCUIApplication, category: String) -> [XCUIElement] {
        app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@",
                        ", \(category), ", " point")
        ).allElementsBoundByIndex
    }

    /// The way back, which every card carries and which is the cheapest proof
    /// that a card is on screen at all.
    private func closeButton(_ app: XCUIApplication) -> XCUIElement {
        app.buttons["Back to the basket"].firstMatch
    }

    /// The chips were buttons, then deliberately made inert because tapping did
    /// nothing, and a control that invites a tap and ignores it reads as broken.
    /// This is the assertion that the promise is kept again.
    func testTappingASetWordOpensACard() {
        let app = seededApp()
        XCTAssertTrue(app.staticTexts["FoundSummaryCount"].waitForExistence(timeout: 30))

        let setChips = chips(app, category: "on the page")
        XCTAssertFalse(setChips.isEmpty, "no set-word chips on a seeded board")
        setChips[0].tap()

        XCTAssertTrue(closeButton(app).waitForExistence(timeout: 10),
                      "tapping a set word opened no card")
    }

    func testTappingAnUncommonOpensACard() {
        let app = seededApp()
        XCTAssertTrue(app.staticTexts["FoundSummaryCount"].waitForExistence(timeout: 30))

        let uncommon = chips(app, category: "Uncommon")
        try? XCTSkipIf(uncommon.isEmpty, "today's rack seeded no uncommon finds")
        uncommon[0].tap()

        XCTAssertTrue(closeButton(app).waitForExistence(timeout: 10),
                      "tapping an uncommon opened no card")
    }

    /// **The card always says something**, which is the guarantee that covers
    /// the miss without naming a word that misses.
    ///
    /// Rare coverage is about 72 percent rack-weighted and the gap is mostly
    /// not-words, so a seeded board reliably carries both kinds of Rare and
    /// there is no way to know from here which chip is which. Rather than pick
    /// one and hope, this taps several and requires each to produce a card
    /// carrying prose: a gloss, or the sentence that stands in for one.
    ///
    /// A blank card is the failure this is really aimed at. A word that falls
    /// through to an empty string renders a rule and nothing under it, which is
    /// the outcome `parseDefinitions` drops empty glosses to avoid, and it
    /// would pass any test that only checked a card had opened.
    func testEveryRareOpensACardThatSaysSomething() {
        let app = seededApp()
        XCTAssertTrue(app.staticTexts["FoundSummaryCount"].waitForExistence(timeout: 30))

        let rare = chips(app, category: "Rare")
        try? XCTSkipIf(rare.isEmpty, "today's rack seeded no rare finds")

        for chip in rare.prefix(4) {
            chip.tap()
            XCTAssertTrue(closeButton(app).waitForExistence(timeout: 10),
                          "a rare chip opened no card")

            // The card's prose, by identifier. The miss line and a gloss both
            // satisfy this; a card rendering an empty definition would not.
            //
            // **Asked of one named element rather than found by scanning.** The
            // first version of this filtered `app.staticTexts.allElementsBoundByIndex`
            // for anything long enough to be prose, which is a full tree walk
            // per iteration on a board carrying several hundred chips. It
            // passed, and it took **1120 seconds** against 8 for every other
            // test in this file. Correct and unusable is still unusable.
            let prose = app.staticTexts["DefinitionProse"]
            XCTAssertTrue(prose.waitForExistence(timeout: 10),
                          "the card carried no prose at all")
            XCTAssertGreaterThan(prose.label.count, 10,
                                 "the card's prose was effectively empty")

            closeButton(app).tap()
            XCTAssertTrue(app.staticTexts["FoundSummaryCount"].waitForExistence(timeout: 10),
                          "the card did not dismiss")
        }
    }

    /// **The card stays usable at the largest accessibility size.**
    ///
    /// Dynamic Type has been regressed on this app's cards three times, and the
    /// specific failure each time was content taller than a sheet detent: the
    /// crown card's celebration line and kicker both truncated to an ellipsis
    /// before `SourceRevealCard` was made scrollable. This card is one long
    /// paragraph, so it overflows a medium detent at AX5 by construction rather
    /// than by accident, and the question is not whether it overflows but
    /// whether the player can still read it and get out.
    ///
    /// Asserted on the way out rather than on the prose, because a card you
    /// cannot dismiss is the failure that traps someone. The prose being
    /// present is already covered above at default size; reachability is what
    /// only this size can test.
    func testTheCardIsUsableAtTheLargestTextSize() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-resetProgress", "1", "-seedBoard", "almost",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL",
        ]
        app.launch()
        XCTAssertTrue(app.staticTexts["FoundSummaryCount"].waitForExistence(timeout: 40))

        let setChips = chips(app, category: "on the page")
        XCTAssertFalse(setChips.isEmpty, "no set-word chips on a seeded board")
        setChips[0].tap()

        let prose = app.staticTexts["DefinitionProse"]
        XCTAssertTrue(prose.waitForExistence(timeout: 10),
                      "the card carried no prose at AX5")

        // The way out, after scrolling the card. `swipeUp` scrolls the content
        // inside the sheet; it does NOT drag the sheet to its large detent, and
        // the distinction is worth keeping straight because both would make
        // this pass and only one is what runs.
        //
        // Reachability is asserted after the scroll rather than before it, so
        // this passes whether or not the button was already in view at the
        // medium detent. That is deliberate: at AX5 one long gloss overflows a
        // medium detent by construction, so requiring no-scroll would be
        // requiring the card not to be what it is. The failure being guarded is
        // a card that cannot be dismissed at all.
        let close = closeButton(app)
        if !close.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(close.waitForExistence(timeout: 10),
                      "the close button does not exist at AX5")
        XCTAssertTrue(close.isHittable,
                      "the close button is not reachable at AX5, so the card traps you")
        close.tap()
        XCTAssertTrue(app.staticTexts["FoundSummaryCount"].waitForExistence(timeout: 10),
                      "the card did not dismiss at AX5")
    }

    /// **The crown keeps the crown card.** The whole point of building a second
    /// card was that a found word wants a definition and very little else; the
    /// source word wants the peach, the celebration line and the etymology, and
    /// routing it to the quiet card would be a downgrade of the biggest beat in
    /// the game.
    ///
    /// Asserted on the celebration line, which only the crown card renders.
    func testTheCrownStillGetsTheCrownCard() {
        let app = seededApp()
        XCTAssertTrue(app.staticTexts["FoundSummaryCount"].waitForExistence(timeout: 30))

        let crown = chips(app, category: "source word")
        try? XCTSkipIf(crown.isEmpty, "the seeded board did not include the source word")
        crown[0].tap()

        XCTAssertTrue(
            app.staticTexts["You found the Peach of a Word!"].waitForExistence(timeout: 10),
            "the source word opened something that is not the crown card"
        )
    }
}
