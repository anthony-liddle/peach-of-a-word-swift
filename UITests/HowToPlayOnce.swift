import XCTest

/// How to play: once, unasked, on a phone that has never played; never unasked
/// on one that has, or on one that has read it from the title's link; and
/// always from the link.
///
/// **Two launches.** A fresh install taps Play and gets the card, whose "Pick
/// the peaches" goes on to the board; back at the title, Play goes straight to
/// the board. A phone with progress taps Play and gets the board; back at the
/// title, the link opens the card, which ends with Close.
final class HowToPlayOnce: XCTestCase {
    private func tile(_ app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label MATCHES %@", "^Letter [a-z].*")).firstMatch
    }

    private func tapPlay(_ app: XCUIApplication, file: StaticString = #filePath,
                         line: UInt = #line) {
        let play = app.buttons["TitlePlay"]
        XCTAssertTrue(play.waitForExistence(timeout: 30), "no title", file: file, line: line)
        let wait = expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: play)
        XCTAssertEqual(XCTWaiter().wait(for: [wait], timeout: 30), .completed,
                       "Play never became tappable", file: file, line: line)
        play.tap()
    }

    func testAFreshInstallSeesTheCardOnce() {
        let app = XCUIApplication()
        app.launchArguments = ["-showTitle", "1", "-resetProgress", "1",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()
        tapPlay(app)
        let done = app.buttons["HowToPlayDone"]
        XCTAssertTrue(done.waitForExistence(timeout: 10), "a fresh install's Play did not open the card")
        XCTAssertEqual(done.label, "Pick the peaches", "the first run's card does not go on to play")
        done.tap()
        XCTAssertTrue(tile(app).waitForExistence(timeout: 10), "the card did not go on to the board")

        app.buttons["BoardHome"].tap()
        tapPlay(app)
        XCTAssertTrue(tile(app).waitForExistence(timeout: 10), "Play did not open the board")
        XCTAssertFalse(done.exists, "the card came back unasked")
    }

    /// Read from the link first, the card counts as seen: Play goes straight to
    /// the board. A fresh install's walk-through found the same card twice, the
    /// second time unasked, which reads as the first not having taken.
    func testAFreshInstallThatReadItFromTheLinkIsNotShownItAgain() {
        let app = XCUIApplication()
        app.launchArguments = ["-showTitle", "1", "-resetProgress", "1",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()
        let link = app.buttons["TitleHowToPlay"]
        XCTAssertTrue(link.waitForExistence(timeout: 30), "no How to play on the title")
        link.tap()
        let done = app.buttons["HowToPlayDone"]
        XCTAssertTrue(done.waitForExistence(timeout: 10), "the link did not open the card")
        done.tap()
        XCTAssertTrue(done.waitForNonExistence(timeout: 10), "Close did not close the card")

        tapPlay(app)
        XCTAssertTrue(tile(app).waitForExistence(timeout: 10), "Play did not open the board")
        XCTAssertFalse(done.exists, "the card read from the link came back unasked")
    }

    func testAPhoneWithProgressSeesItOnlyWhenAsked() {
        let app = XCUIApplication()
        app.launchArguments = ["-showTitle", "1", "-resetProgress", "1", "-seedBoard", "3",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()
        tapPlay(app)
        XCTAssertTrue(tile(app).waitForExistence(timeout: 10), "Play did not open the board")
        XCTAssertFalse(app.buttons["HowToPlayDone"].exists, "a phone with progress saw the card unasked")

        app.buttons["BoardHome"].tap()
        let link = app.buttons["TitleHowToPlay"]
        XCTAssertTrue(link.waitForExistence(timeout: 10), "no How to play on the title")
        link.tap()
        let done = app.buttons["HowToPlayDone"]
        XCTAssertTrue(done.waitForExistence(timeout: 10), "the link did not open the card")
        XCTAssertEqual(done.label, "Close", "the card from the link does not end with Close")
    }
}
