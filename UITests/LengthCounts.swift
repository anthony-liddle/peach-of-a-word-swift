import XCTest

/// The basket's lengths and their counts: every length shows from the first
/// find, with its count, as the web's do, unless Word counts by length is off
/// in Settings (Antoine and Bea, 21 November 2026).
///
/// **On a basket of one word.** `-seedBoard 1` finds one basket word and
/// nothing off the page, so every other length in the basket is unfound: on,
/// each reads "0 of" its count; off, the one length found is the only one.
///
/// **Counted by the groups' headers,** not by searching for "0 of": off, a
/// length holding only an off-page find still reads "0 of" its count, and
/// rightly. The seed has no such find, so here the headers are the check.
final class LengthCounts: XCTestCase {
    /// Every length group's header: "5 letters, 0 of 2", say. The header is
    /// one element with its two texts combined, and XCUITest still lists the
    /// first text, "5 letters", on its own beside it, so only the combined
    /// labels are kept: with no off-page find, every group shown has a count.
    private func headers(_ app: XCUIApplication) -> [String] {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label MATCHES %@", "^[0-9]+ letters, [0-9]+ of [0-9]+$"))
            .allElementsBoundByIndex.map { $0.label }
    }

    private func waitForTheRack(_ app: XCUIApplication, file: StaticString = #filePath,
                                line: UInt = #line) {
        XCTAssertTrue(app.buttons.matching(
            NSPredicate(format: "label MATCHES %@", "^Letter [a-z].*")
        ).firstMatch.waitForExistence(timeout: 30), "the app never rendered a rack",
                      file: file, line: line)
    }

    private func unfound(_ headers: [String]) -> [String] {
        headers.filter { $0.range(of: "^[0-9]+ letters, 0 of [0-9]+$", options: .regularExpression) != nil }
    }

    /// On, as it is on a phone that has never set it: the lengths not found
    /// yet show, each with its count.
    func testAnUnfoundLengthShowsItsCountWithTheSettingOn() {
        let app = XCUIApplication()
        app.launchArguments = ["-resetProgress", "1", "-seedBoard", "1",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()
        waitForTheRack(app)
        let shown = headers(app)
        XCTAssertGreaterThan(shown.count, 1, "only the found length shows: \(shown)")
        XCTAssertFalse(unfound(shown).isEmpty, "no unfound length reads 0 of its count: \(shown)")
    }

    /// Off, from the switch in Settings: a length shows only once a word that
    /// long is found, so the one found length is the only one.
    func testAnUnfoundLengthDoesNotShowWithTheSettingOff() {
        let app = XCUIApplication()
        app.launchArguments = ["-showTitle", "1", "-resetProgress", "1", "-seedBoard", "1",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()
        let link = app.buttons["TitleSettings"]
        XCTAssertTrue(link.waitForExistence(timeout: 30), "no settings on the title")
        link.tap()
        let toggle = app.switches["SettingsLengthCounts"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10), "no word counts switch in settings")
        XCTAssertEqual(toggle.value as? String, "1", "word counts are not on by default")
        // The switch's own knob, as `SoundSwitch` taps Sound's.
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        XCTAssertEqual(toggle.value as? String, "0", "the switch did not turn off")
        app.buttons["SheetClose"].tap()

        let play = app.buttons["TitlePlay"]
        XCTAssertTrue(play.waitForExistence(timeout: 10), "Settings did not close to the title")
        let ready = expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: play)
        XCTAssertEqual(XCTWaiter().wait(for: [ready], timeout: 30), .completed,
                       "Play never became tappable")
        play.tap()
        // How to play, on a phone that has never played.
        let done = app.buttons["HowToPlayDone"]
        if done.waitForExistence(timeout: 10) { done.tap() }
        waitForTheRack(app)
        let shown = headers(app)
        XCTAssertEqual(shown.count, 1, "more than the found length shows: \(shown)")
        XCTAssertEqual(unfound(shown), [], "an unfound length shows: \(shown)")
    }
}
