import XCTest

/// Is the way out of the source reveal on screen when the card opens?
///
/// Bea asked to "show all of the etymology and definition plus button no matter
/// the length". The length is the whole difficulty: the longest entry in the
/// corpus renders 1,209pt of card on an 874pt phone, so no sheet detent can put
/// a button below that content on screen. The button is pinned below the
/// scrolling prose for that reason, and this is the assertion that says so.
///
/// `isHittable` rather than `exists`. A button under another view, or below the
/// fold, exists perfectly happily; the defect being guarded against is exactly
/// an existing button that cannot be pressed without first scrolling or
/// dragging, which is what the card did before.
///
/// Both ends of the corpus, at both ends of the text-size range. A card that
/// fits and a card that cannot fit fail this differently, and the accessibility
/// size is where the pinned bar itself grows enough to be a problem: an earlier
/// version of it pinned the CC BY-SA credit too, and at AX5 that took four
/// lines, swallowed half the screen and truncated this button to "BACK TO
/// THE...".
final class RevealButtonReach: XCTestCase {

    /// The longest entry in `Data/etymology.tsv` at 1,787 characters, and the
    /// shortest at 34. Named rather than played, because reaching these two
    /// through real play means waiting for two particular days to come round.
    private static let longest = "withdraw"
    private static let shortest = "manually"

    private func reveal(word: String, size: String) -> XCUIElement {
        let app = XCUIApplication()
        app.launchArguments = ["-resetProgress", "1",
                               "-revealCard", word,
                               "-UIPreferredContentSizeCategoryName", size]
        app.launch()
        XCTAssertTrue(app.staticTexts["You found the Peach of a Word!"]
            .waitForExistence(timeout: 30), "the reveal never opened for \(word)")
        // Matched case-insensitively: the label is uppercased for display, and
        // this should not fail the day that styling changes.
        return app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "back to the")
        ).firstMatch
    }

    func testTheLongestCardOpensWithItsButtonReachable() {
        let button = reveal(word: Self.longest, size: "UICTContentSizeCategoryL")
        XCTAssertTrue(button.waitForExistence(timeout: 10), "no dismiss button")
        XCTAssertTrue(button.isHittable,
                      "the longest card opened with its way out off screen")
    }

    func testTheLongestCardIsStillReachableAtTheLargestTextSize() {
        let button = reveal(word: Self.longest,
                            size: "UICTContentSizeCategoryAccessibilityXXXL")
        XCTAssertTrue(button.waitForExistence(timeout: 10), "no dismiss button")
        XCTAssertTrue(button.isHittable,
                      "the longest card at AX5 opened with its way out off screen")
    }

    func testTheShortestCardIsReachableToo() {
        let button = reveal(word: Self.shortest, size: "UICTContentSizeCategoryL")
        XCTAssertTrue(button.waitForExistence(timeout: 10), "no dismiss button")
        XCTAssertTrue(button.isHittable)
    }

    func testTheShortestCardIsReachableAtTheLargestTextSize() {
        let button = reveal(word: Self.shortest,
                            size: "UICTContentSizeCategoryAccessibilityXXXL")
        XCTAssertTrue(button.waitForExistence(timeout: 10), "no dismiss button")
        XCTAssertTrue(button.isHittable)
    }
}
