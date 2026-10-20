import XCTest

/// One haptic pattern per accepted find, chosen once completion is known.
///
/// The source word that is also the last set word played the source word's
/// pattern and then completion's on the same submit, so the two started
/// together and read as one muddled buzz. The cards already drop the peach
/// card for the completion card, and the web's sounds play completion alone.
/// `-exposeFeel 1` lists every find beat played since launch, so this counts
/// what one submit started.
final class OneBeatPerFind: XCTestCase {
    /// Launch on `seed`, find the source word through the tile path, close the
    /// card it opens, and return the beats the probe recorded.
    private func beatsAfterFindingTheSource(seed: String) -> String {
        let app = XCUIApplication()
        app.launchArguments = [
            "-resetProgress", "1", "-seedBoard", seed, "-findSource", "1", "-exposeFeel", "1",
        ]
        app.launch()
        // The peach card's way out, or the completion card's.
        let close = app.buttons.matching(NSPredicate(
            format: "label == %@ OR label ==[c] %@", "Back to the basket", "Keep playing"
        )).firstMatch
        XCTAssertTrue(close.waitForExistence(timeout: 30), "finding the source word opened no card")
        close.tap()
        let probe = app.staticTexts["DebugFeel"]
        XCTAssertTrue(probe.waitForExistence(timeout: 10), "the app never exposed its beats")
        return probe.label
    }

    /// `source-last` is every set word but the source word, so finding it
    /// completes the basket.
    func testTheSourceWordThatCompletesTheBasketPlaysOnlyCompletion() {
        XCTAssertEqual(beatsAfterFindingTheSource(seed: "source-last"), "completion",
                       "the submit that completed the basket played more than completion's pattern")
    }

    /// `hierarchy` leaves one other set word unfound, so the source word does
    /// not complete the basket and keeps its own beat.
    func testTheSourceWordAlonePlaysTheSourceWord() {
        XCTAssertEqual(beatsAfterFindingTheSource(seed: "hierarchy"), "sourceWord",
                       "the source word on its own did not play its own pattern")
    }
}
