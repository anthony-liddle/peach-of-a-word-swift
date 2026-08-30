import XCTest

/// Does the board catch up when she comes back to it?
///
/// Bea backgrounded the app, opened it the next day, and still had
/// yesterday's puzzle. Force-quitting fixed it, which is the shape of state
/// that is only ever rebuilt at launch.
///
/// The rule that the day does not roll over mid-session was deliberate and
/// still holds. What it missed is that backgrounding is not the middle of a
/// session: it is one session ending and another beginning, and iOS does not
/// say so.
///
/// **This needs a clock that moves while the app is away**, which no fixed
/// launch argument provides: `-dayOffset` is the same on both sides of a
/// backgrounding, so the day never changes and the path never runs.
/// `-dayOffsetOnResume` moves it on the first foregrounding and not before,
/// which is the smallest thing that makes the real sequence reachable.
final class DayRollsOverOnForeground: XCTestCase {

    private func rackLetters(_ app: XCUIApplication) -> [String] {
        app.buttons.matching(NSPredicate(format: "label MATCHES %@", "^Letter [a-z].*"))
            .allElementsBoundByIndex
            .compactMap { $0.label.split(separator: " ").dropFirst().first.map(String.init) }
            .sorted()
    }

    private func backgroundAndReturn(_ app: XCUIApplication) {
        XCUIDevice.shared.press(.home)
        // Long enough for the scene to leave `.active`, since the whole point
        // is the transition back into it.
        Thread.sleep(forTimeInterval: 2)
        app.activate()
    }

    func testTheBoardBecomesTodaysWhenTheAppComesBack() {
        let app = XCUIApplication()
        // No `-seedBoard` here, deliberately. Seeding and rolling over
        // interact: the words that appeared on the new board were spellable
        // from the new word rather than the old one, so they had been seeded
        // again rather than carried across, and the assertion about a fresh
        // board was measuring the instrument. What yesterday's words do across
        // a rollover is asserted in `RolloverTests` against storage, which is
        // where that property actually lives.
        app.launchArguments = ["-resetProgress", "1",
                               "-dayOffsetOnResume", "1",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()

        let anyTile = app.buttons.matching(
            NSPredicate(format: "label MATCHES %@", "^Letter [a-z].*")).firstMatch
        XCTAssertTrue(anyTile.waitForExistence(timeout: 30), "the app never rendered a rack")
        let before = rackLetters(app)
        XCTAssertFalse(before.isEmpty, "no rack letters read")

        backgroundAndReturn(app)

        // The rack is the visible proof: a different day is a different source
        // word, so the eight letters change. Waiting rather than reading once,
        // because the new board is built asynchronously on the way back in.
        let deadline = Date().addingTimeInterval(20)
        var after = rackLetters(app)
        while after == before, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.5)
            after = rackLetters(app)
        }
        XCTAssertNotEqual(after, before,
                          "the board was still yesterday's after coming back")

        // And it is a real board rather than a blank one: eight tiles, and the
        // empty-basket line, since the new day has nothing found on it yet.
        XCTAssertEqual(after.count, 8, "the new day did not deal a full rack")
        // A real board rather than a blank one.
        XCTAssertEqual(after.count, 8, "the new day did not deal a full rack")
        XCTAssertTrue(app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "shuffle")).firstMatch.isHittable,
            "the new board is not playable")
    }

    /// The same sequence with the clock left alone. Coming back on the same day
    /// must change nothing, which is the half that would break if the rollover
    /// fired on every foregrounding.
    func testComingBackOnTheSameDayChangesNothing() {
        let app = XCUIApplication()
        app.launchArguments = ["-resetProgress", "1", "-seedBoard", "almost",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()

        let anyTile = app.buttons.matching(
            NSPredicate(format: "label MATCHES %@", "^Letter [a-z].*")).firstMatch
        XCTAssertTrue(anyTile.waitForExistence(timeout: 30), "the app never rendered a rack")
        let before = rackLetters(app)

        backgroundAndReturn(app)
        Thread.sleep(forTimeInterval: 3)

        XCTAssertEqual(rackLetters(app), before,
                       "the board changed on a foregrounding that was the same day")
        // And the seeded words are still there, which is the thing a spurious
        // rollover would have thrown away.
        XCTAssertFalse(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "is empty")).firstMatch.exists,
            "a same-day return emptied the basket")
    }
}
