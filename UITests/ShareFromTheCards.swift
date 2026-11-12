import XCTest

/// Share on the two cards that open for the big finds: the crown card, for
/// every common word, and the peach card, for the peach of a word.
///
/// Each card's Share is the found list's own control, and must share what the
/// list's does at that moment. `-exposeShare 1` puts each Share's text in its
/// accessibility value, so the two can be compared; without it the text only
/// exists inside the system's share sheet.
///
/// **The peach card is the one place the answer is on screen,** so its share
/// is held to the daily rule hardest: the text never carries the word. Played
/// for real, `-seedBoard hierarchy -findSource 1`, so the word checked is the
/// board's own source word, read off the card. A card opened with
/// `-revealCard` shows a word that isn't the board's, and the check would
/// pass without testing anything.
final class ShareFromTheCards: XCTestCase {

    private func launch(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-resetProgress", "1", "-exposeShare", "1"] + arguments
        app.launch()
        return app
    }

    /// The card's Share, by the identifier only a card's Share carries.
    private func cardShare(_ app: XCUIApplication) -> XCUIElement {
        app.buttons["CardShare"]
    }

    /// The found list's Share, once no card is up.
    private func listShare(_ app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label == %@", "Share your result")).firstMatch
    }

    private func text(of share: XCUIElement) -> String {
        (share.value as? String) ?? ""
    }

    func testThePeachCardSharesWhatTheListSharesAndNeverTheWord() {
        let app = launch(["-seedBoard", "hierarchy", "-findSource", "1"])
        let word = app.staticTexts["RevealWord"]
        XCTAssertTrue(word.waitForExistence(timeout: 30), "finding the source word opened no peach card")
        let share = cardShare(app)
        XCTAssertTrue(share.waitForExistence(timeout: 10), "the peach card has no Share")
        XCTAssertTrue(share.isHittable, "the peach card's Share isn't on screen")

        let fromCard = text(of: share)
        XCTAssertFalse(fromCard.isEmpty, "the card's Share exposed no text")
        XCTAssertFalse(word.label.isEmpty, "the card's word has no label")
        // The message leaves the text out: on a leak it holds the day's word,
        // and CI's logs are public.
        XCTAssertFalse(fromCard.lowercased().contains(word.label.lowercased()),
                       "the peach card's share names the peach of a word")

        app.buttons.matching(NSPredicate(format: "label ==[c] %@", "back to the basket"))
            .firstMatch.tap()
        let list = listShare(app)
        XCTAssertTrue(list.waitForExistence(timeout: 10), "no Share on the found list")
        // Compared without printing either text, for the reason above.
        XCTAssertTrue(fromCard == text(of: list),
                      "the peach card shares something other than the found list")
    }

    /// At the default text size, at the medium detent the card opens at, Share
    /// is on screen without scrolling: inside the sheet's visible scroll area,
    /// wholly. Measured on 12 November 2026, the iPhone 17 had 94pt under Keep
    /// playing, and the SE had none: Keep playing itself ran past the sheet's
    /// edge there. That is an open question for Antoine, not this test's to
    /// decide, so on an SE this fails until it's answered.
    func testTheCrownCardSharesWhatTheListSharesAndShowsItAtMedium() {
        let app = launch(["-seedBoard", "source-last", "-findSource", "1"])
        let keepPlaying = app.buttons.matching(NSPredicate(format: "label ==[c] %@", "Keep playing")).firstMatch
        XCTAssertTrue(keepPlaying.waitForExistence(timeout: 30), "completing the basket opened no crown card")
        let share = cardShare(app)
        XCTAssertTrue(share.waitForExistence(timeout: 10), "the crown card has no Share")
        XCTAssertGreaterThan(share.frame.minY, keepPlaying.frame.minY, "Share isn't under Keep playing")

        let sheet = app.scrollViews.containing(.button, identifier: "CardShare").firstMatch
        XCTAssertTrue(sheet.exists, "no scroll area holds the card's Share")
        XCTAssertTrue(sheet.frame.contains(share.frame),
                      "Share needs a scroll at medium: \(share.frame) outside \(sheet.frame)")

        let fromCard = text(of: share)
        XCTAssertFalse(fromCard.isEmpty, "the card's Share exposed no text")
        keepPlaying.tap()
        let list = listShare(app)
        XCTAssertTrue(list.waitForExistence(timeout: 10), "no Share on the found list")
        XCTAssertTrue(fromCard == text(of: list),
                      "the crown card shares something other than the found list")
    }

    /// The peach card's Share is in its pinned bar, and the bar's type stops
    /// at AX1, as its button's always has: every point the bar grows comes out
    /// of the prose at AX5. Same height at AX1 and AX5 means it stopped.
    func testThePeachCardsShareStopsGrowingAtAX1() {
        func shareHeight(_ size: String) -> CGFloat {
            let app = launch(["-revealCard", "withdraw", "-UIPreferredContentSizeCategoryName", size])
            let share = cardShare(app)
            XCTAssertTrue(share.waitForExistence(timeout: 30), "the peach card has no Share at \(size)")
            XCTAssertTrue(share.isHittable, "the peach card's Share isn't on screen at \(size)")
            let height = share.frame.height
            app.terminate()
            return height
        }
        let ax1 = shareHeight("UICTContentSizeCategoryAccessibilityM")
        let ax5 = shareHeight("UICTContentSizeCategoryAccessibilityXXXL")
        XCTAssertEqual(ax5, ax1, accuracy: 0.5, "the peach card's Share grew past AX1")
    }
}
