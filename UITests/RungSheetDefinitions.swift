import XCTest

/// Can a word inside a rung sheet be asked what it means?
///
/// Bea found that tapping a rung count opens the list of those words and then
/// the words do nothing, so a definition was reachable from the found list and
/// not from the place she was actually browsing.
///
/// Two things are worth asserting by driving the app rather than by reading it.
/// The first is that the definition really does open from in there, over the
/// rung sheet rather than in place of it, since losing her place was the reason
/// not to replace it. The second is the launch race below.
final class RungSheetDefinitions: XCTestCase {

    private func launch(_ extra: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-resetProgress", "1", "-seedBoard", "almost",
                               "-UIPreferredContentSizeCategoryName",
                               "UICTContentSizeCategoryL"] + extra
        app.launch()
        XCTAssertTrue(app.buttons.matching(
            NSPredicate(format: "label MATCHES %@", "^Letter [a-z].*")
        ).firstMatch.waitForExistence(timeout: 30), "the app never rendered a rack")
        return app
    }

    private func rungTally(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", name)).firstMatch
    }

    func testAWordInTheRungSheetOpensItsDefinition() {
        let app = launch([])
        let tally = rungTally(app, "Mythic")
        XCTAssertTrue(tally.waitForExistence(timeout: 10), "no Mythic tally to tap")
        tally.tap()

        // The sheet's own way out proves the rung sheet is up.
        let backToBasket = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "back to the")).firstMatch
        XCTAssertTrue(backToBasket.waitForExistence(timeout: 10), "the rung sheet did not open")

        // A word chip inside the sheet, which means a hittable one. The found
        // list is still in the hierarchy behind the sheet and its chips carry
        // the same kind of label, so `firstMatch` finds one of those and fails
        // as not hittable. Being on top is the thing that distinguishes them.
        let chips = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "point"))
        XCTAssertTrue(chips.firstMatch.waitForExistence(timeout: 10), "no word chips at all")
        guard let chip = chips.allElementsBoundByIndex.first(where: { $0.isHittable }) else {
            return XCTFail("no tappable word in the rung sheet")
        }
        chip.tap()

        // The card is up. Matched on the gloss's credit line rather than on a
        // button: both sheets label their way out "Back to the basket", so a
        // button query cannot tell the definition card from the rung sheet, and
        // an earlier version of this test asserted the rung sheet survived by
        // finding the definition card's own button.
        let credit = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Wiktionary")).firstMatch
        XCTAssertTrue(credit.waitForExistence(timeout: 10), "the definition card did not open")

        // And the rung sheet is still underneath rather than replaced, which is
        // the point of nesting: she keeps her place in the list she was
        // reading. The rung's name is in its header and nowhere else on screen.
        XCTAssertTrue(app.staticTexts["Mythic"].exists,
                      "the rung sheet was replaced rather than covered")

        // And she gets back to it. The card covers the rung sheet exactly at
        // this detent, so there is no visual cue that two sheets are stacked;
        // what makes the nesting worth anything is that dismissing the card
        // returns her to the list rather than to the board.
        let cardWayOut = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "back to the"))
        guard let dismissCard = cardWayOut.allElementsBoundByIndex
            .first(where: { $0.isHittable }) else {
            return XCTFail("no hittable way out of the definition card")
        }
        dismissCard.tap()

        let chipsAgain = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "point"))
        XCTAssertTrue(
            chipsAgain.allElementsBoundByIndex.contains { $0.isHittable },
            "dismissing the definition did not return her to the rung sheet")
    }

    /// The launch race, which this codebase has produced once already.
    ///
    /// The sheet spike found that a moment firing during `load()` permanently
    /// suppressed the list sheet: two `.sheet` modifiers on one root, racing.
    /// That was siblings rather than nesting, so it need not apply here, but it
    /// is the known failure of this shape in this codebase and assuming it does
    /// not apply is exactly how it would come back.
    ///
    /// `-revealCard` fires a moment during load. The assertion is not that the
    /// moment loses, which is a presentation detail: it is that the rung sheet
    /// still opens afterwards. Permanent suppression is the defect.
    func testAMomentAtLaunchDoesNotSuppressTheRungSheet() {
        let app = launch(["-revealCard", "withdraw"])

        // Clear whatever the launch put up, if anything did.
        let dismissReveal = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "back to the")).firstMatch
        if dismissReveal.waitForExistence(timeout: 6) { dismissReveal.tap() }

        let tally = rungTally(app, "Mythic")
        XCTAssertTrue(tally.waitForExistence(timeout: 10), "no Mythic tally after the moment")
        tally.tap()

        let backToBasket = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "back to the")).firstMatch
        XCTAssertTrue(backToBasket.waitForExistence(timeout: 10),
                      "a moment at launch suppressed the rung sheet")
    }
}
