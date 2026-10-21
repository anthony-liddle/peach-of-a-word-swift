import XCTest

/// The caption at the top of the ladder says what the bar measures.
///
/// It said "Basket full" whenever the rank ladder topped out, and the ladder
/// tops out long before the basket does: on one board measured on 2026-09-27,
/// at 16 of 36 basket words. That is a claim about the basket the bar does not
/// make, the kind of untrue claim App Review guideline 2.3 is about. "Top rung"
/// says where the bar is, and "Basket full" is kept for the one state where it
/// is true.
final class MeterTopRung: XCTestCase {
    private func launch(seed: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-resetProgress", "1", "-seedBoard", seed]
        app.launch()
        XCTAssertTrue(app.staticTexts["MeterPoints"].waitForExistence(timeout: 30),
                      "the meter never appeared")
        return app
    }

    /// `almost` is every set word but one, so on every board the ladder is
    /// topped and the basket is not full.
    func testTheTopOfTheLadderDoesNotClaimTheBasket() {
        let app = launch(seed: "almost")
        XCTAssertTrue(app.staticTexts["Top rung"].waitForExistence(timeout: 10),
                      "the topped ladder did not say Top rung")
        XCTAssertFalse(app.staticTexts["Basket full"].exists,
                       "the meter said the basket was full with a set word still to find")
    }

    /// `full` is every set word, so the basket is full and may say so.
    func testAFullBasketStillSaysSo() {
        let app = launch(seed: "full")
        XCTAssertTrue(app.staticTexts["Basket full"].waitForExistence(timeout: 10),
                      "a full basket did not say so")
        XCTAssertFalse(app.staticTexts["Top rung"].exists,
                       "a full basket said only that the ladder was topped")
    }
}
