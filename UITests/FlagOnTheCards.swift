import XCTest

/// The flag on both cards (step 5 of "Flagging Words From The Cards"): the
/// icon at the foot of a card, the picker as a sheet over it, the card's line
/// once flagged, and Your flags, from the card and from Settings.
///
/// **No flag reaches the live store from here.** UI tests run a Debug build,
/// whose flags go to `FlagServer`'s stand-in: `-flagServer took` answers as the
/// server does, and with no argument nothing answers, so a flag waits.
///
/// **No word is ever printed.** These boards are real days and CI's logs are
/// public, so a message says which element, never what it says.
final class FlagOnTheCards: XCTestCase {
    private func launch(_ arguments: [String], size: String = "L") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategory\(size)"]
            + arguments
        app.launch()
        return app
    }

    /// A basket word's card, from its chip, as `DefinitionCardExits` opens it.
    private func openBasketWordsCard(_ app: XCUIApplication) {
        XCTAssertTrue(app.staticTexts["FoundSummaryCount"].waitForExistence(timeout: 40), "no board")
        let chip = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", ", in the basket, ", " point")
        ).firstMatch
        XCTAssertTrue(chip.exists, "no basket word's chip")
        chip.tap()
        XCTAssertTrue(app.staticTexts["DefinitionProse"].waitForExistence(timeout: 10), "the card did not open")
    }

    /// The card's flag, scrolled into view: it sits at the foot of the card's
    /// scrolling content, under the credit.
    private func cardFlag(_ app: XCUIApplication) -> XCUIElement {
        let flag = app.buttons["CardFlag"]
        XCTAssertTrue(flag.waitForExistence(timeout: 10), "the card has no flag")
        for _ in 0..<6 where !isWhollyOnScreen(flag, app) {
            app.scrollViews.containing(.button, identifier: "CardFlag").firstMatch.swipeUp()
        }
        XCTAssertTrue(isWhollyOnScreen(flag, app), "the card's flag can't be scrolled into view")
        return flag
    }

    /// A picture for the PR, written to the host when `MATRIX_SHOTS` names a
    /// directory (passed as `TEST_RUNNER_MATRIX_SHOTS`), and nothing otherwise.
    private func shoot(_ app: XCUIApplication, _ name: String) {
        guard let dir = ProcessInfo.processInfo.environment["MATRIX_SHOTS"] else { return }
        sleep(1)
        let url = URL(fileURLWithPath: dir).appendingPathComponent("\(name).png")
        try? app.screenshot().pngRepresentation.write(to: url)
    }

    private func isWhollyOnScreen(_ e: XCUIElement, _ app: XCUIApplication) -> Bool {
        e.exists && e.isHittable && app.windows.firstMatch.frame.contains(e.frame)
    }

    private func button(_ app: XCUIApplication, _ label: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    private func text(_ app: XCUIApplication, containing part: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", part)).firstMatch
    }

    /// Scrolls the picker until the element is wholly on screen, or gives up.
    private func reach(_ e: XCUIElement, in app: XCUIApplication) -> Bool {
        let picker = app.scrollViews["FlagPicker"]
        for _ in 0..<8 where !isWhollyOnScreen(e, app) { picker.swipeUp() }
        return isWhollyOnScreen(e, app)
    }

    // MARK: - A found word's card

    func testAFoundWordIsFlaggedFromItsCardAndTakenBackFromYourFlags() {
        let app = launch(["-resetProgress", "1", "-seedBoard", "almost", "-flagServer", "took"])
        openBasketWordsCard(app)
        let flag = cardFlag(app)
        XCTAssertEqual(flag.label, "Flag this word")
        shoot(app, "L-1-card-flag")
        flag.tap()

        XCTAssertTrue(app.scrollViews["FlagPicker"].waitForExistence(timeout: 10), "the picker did not open")
        shoot(app, "L-2-picker")
        for heading in ["Take it out", "Fix its card", "Its grade"] {
            XCTAssertTrue(app.staticTexts[heading].exists, "the picker has no heading \(heading)")
        }
        XCTAssertTrue(button(app, "It's rarer than a basket word").exists, "a basket word can't be flagged rarer")
        XCTAssertFalse(text(app, containing: "more common than").exists, "a basket word is offered more common")
        XCTAssertTrue(app.staticTexts["Sends the word, its day and your reason. Nothing about you."].exists)
        button(app, "It's not a real word").tap()

        XCTAssertTrue(app.scrollViews["FlagPicker"].waitForNonExistence(timeout: 10), "the picker stayed open")
        let line = text(app, containing: "You flagged this: not a real word. Sent.")
        XCTAssertTrue(line.waitForExistence(timeout: 10), "the card doesn't say it was flagged and sent")
        XCTAssertTrue(app.staticTexts["DefinitionProse"].exists, "the card closed")
        shoot(app, "L-3-card-flagged")

        let link = button(app, "Your flags")
        XCTAssertTrue(link.exists, "the flagged card has no way to Your flags")
        link.tap()
        XCTAssertTrue(app.staticTexts["YourFlagsTitle"].waitForExistence(timeout: 10), "Your flags did not open")
        shoot(app, "L-4-your-flags-over-the-card")
        XCTAssertTrue(text(app, containing: ", not a real word").exists, "the list has no row for the flag")
        XCTAssertTrue(app.staticTexts["Sent"].exists, "the row doesn't say Sent")
        button(app, "Take back").tap()

        XCTAssertTrue(app.staticTexts["YourFlagsTitle"].waitForNonExistence(timeout: 10),
                      "taking back the last flag left the list open")
        XCTAssertTrue(app.staticTexts["DefinitionProse"].exists, "taking back closed the card")
        XCTAssertFalse(text(app, containing: "You flagged this").exists, "the card still says it was flagged")
        XCTAssertTrue(app.buttons["CardFlag"].waitForExistence(timeout: 5), "the flag didn't come back")
    }

    /// Antoine, 23 November: nothing may be cut off. At the default size the
    /// picker fits its content, so every choice and Cancel are on screen as it
    /// opens, and it doesn't take the whole screen.
    func testThePickerFitsItsContentAtTheDefaultSize() {
        let app = launch(["-resetProgress", "1", "-seedBoard", "almost"])
        openBasketWordsCard(app)
        cardFlag(app).tap()
        let picker = app.scrollViews["FlagPicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 10), "the picker did not open")
        sleep(1)
        shoot(app, "L-picker-fits")
        for label in ["It's not a real word", "It's offensive", "The definition is wrong",
                      "It's rarer than a basket word", "Cancel"] {
            XCTAssertTrue(isWhollyOnScreen(button(app, label), app), "\(label) isn't on screen as the picker opens")
        }
        let title = app.staticTexts["FlagPickerTitle"]
        XCTAssertGreaterThan(title.frame.minY, app.windows.firstMatch.frame.height * 0.2,
                             "the picker took the whole screen where its content fits in less")
    }

    /// At AX5 the flag is still a 44-point target, and every choice can be
    /// reached and taken, the last grade choice included.
    func testAtAX5TheFlagIsA44PointTargetAndEveryChoiceCanBeReached() {
        let app = launch(["-resetProgress", "1", "-seedBoard", "almost"], size: "AccessibilityXXXL")
        openBasketWordsCard(app)
        let flag = cardFlag(app)
        shoot(app, "AX5-1-card-flag")
        XCTAssertEqual(flag.frame.width, 44, accuracy: 0.5, "the flag's target isn't 44 points wide at AX5")
        XCTAssertEqual(flag.frame.height, 44, accuracy: 0.5, "the flag's target isn't 44 points tall at AX5")
        flag.tap()
        XCTAssertTrue(app.scrollViews["FlagPicker"].waitForExistence(timeout: 10), "the picker did not open")
        shoot(app, "AX5-2-picker-top")
        for label in ["It's not a real word", "It's offensive", "The definition is wrong", "Cancel",
                      "It's rarer than a basket word"] {
            XCTAssertTrue(reach(button(app, label), in: app), "\(label) can't be reached at AX5")
        }
        shoot(app, "AX5-3-picker-end")
        button(app, "It's rarer than a basket word").tap()
        XCTAssertTrue(text(app, containing: "You flagged this: rarer.").waitForExistence(timeout: 10),
                      "the last grade choice made no flag at AX5")
        guard ProcessInfo.processInfo.environment["MATRIX_SHOTS"] != nil else { return }

        // Pictures only from here: the flagged card, Your flags, and Settings' row.
        // Scrolled until the way to Your flags clears the pinned way out, so
        // the line above it shows whole.
        let link = button(app, "Your flags")
        let wayOut = app.buttons.matching(NSPredicate(format: "label ==[c] %@", "back to the basket")).firstMatch
        for _ in 0..<6 where !(link.exists && link.frame.maxY <= wayOut.frame.minY) {
            app.scrollViews.containing(.staticText, identifier: "DefinitionProse").firstMatch.swipeUp()
        }
        shoot(app, "AX5-4-card-flagged")
        link.tap()
        XCTAssertTrue(app.staticTexts["YourFlagsTitle"].waitForExistence(timeout: 10), "Your flags did not open")
        shoot(app, "AX5-5-your-flags")
        app.buttons["YourFlagsClose"].tap()
        app.buttons.matching(NSPredicate(format: "label ==[c] %@", "back to the basket")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["DefinitionProse"].waitForNonExistence(timeout: 10), "the card didn't close")
        app.buttons["BoardHome"].tap()
        XCTAssertTrue(app.buttons["TitleSettings"].waitForExistence(timeout: 10), "no settings on the title")
        app.buttons["TitleSettings"].tap()
        let row = app.buttons["SettingsFlags"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Settings has no row for Your flags")
        for _ in 0..<8 where !isWhollyOnScreen(row, app) { app.swipeUp() }
        shoot(app, "AX5-6-settings-row")
    }

    /// One grade flag per word: once it's flagged rarer, the grade's group goes.
    func testOneGradeFlagPerWord() {
        let app = launch(["-resetProgress", "1", "-seedBoard", "almost"])
        openBasketWordsCard(app)
        cardFlag(app).tap()
        XCTAssertTrue(app.scrollViews["FlagPicker"].waitForExistence(timeout: 10), "the picker did not open")
        button(app, "It's rarer than a basket word").tap()
        XCTAssertTrue(text(app, containing: "You flagged this: rarer. Waiting to send.").waitForExistence(timeout: 10),
                      "with no server, the flag doesn't wait")
        cardFlag(app).tap()
        XCTAssertTrue(app.scrollViews["FlagPicker"].waitForExistence(timeout: 10), "the picker did not open again")
        XCTAssertFalse(app.staticTexts["Its grade"].exists, "the grade's group is still offered")
        XCTAssertTrue(button(app, "It's not a real word").exists, "the other reasons went with it")
    }

    /// The card a rung sheet opens is the same card, reached another way, so
    /// its flag has to be there too, with the word's own grade: a Mythic word
    /// can only be more common. On 27 October 2026's board, as
    /// `RungSheetDefinitions` opens it, which has a Mythic word.
    func testARungSheetsCardHasTheFlagWithItsGrade() {
        let cal = Calendar.current
        let target = cal.date(from: DateComponents(year: 2026, month: 10, day: 27))!
        let offset = String(cal.dateComponents([.day], from: cal.startOfDay(for: TestClock.now),
                                               to: target).day!)
        let app = launch(["-resetProgress", "1", "-dayOffset", offset, "-seedBoard", "almost"])
        let tally = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Mythic")).firstMatch
        XCTAssertTrue(tally.waitForExistence(timeout: 40), "no Mythic tally to tap")
        tally.tap()
        let chips = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "point"))
        XCTAssertTrue(chips.firstMatch.waitForExistence(timeout: 10), "no word chips")
        guard let chip = chips.allElementsBoundByIndex.first(where: { $0.isHittable }) else {
            return XCTFail("no tappable word in the rung sheet")
        }
        chip.tap()
        XCTAssertTrue(app.staticTexts["DefinitionProse"].waitForExistence(timeout: 10), "the card did not open")
        cardFlag(app).tap()
        XCTAssertTrue(app.scrollViews["FlagPicker"].waitForExistence(timeout: 10), "the picker did not open")
        XCTAssertTrue(button(app, "It's more common than Mythic").exists, "a Mythic word can't be more common")
        XCTAssertFalse(text(app, containing: "rarer than").exists, "a Mythic word is offered rarer")
        button(app, "Cancel").tap()
    }

    // MARK: - The peach card

    func testThePeachCardOffersNoGradeAndNeverNotAWord() {
        let app = launch(["-resetProgress", "1", "-seedBoard", "hierarchy", "-findSource", "1"])
        XCTAssertTrue(app.staticTexts["RevealWord"].waitForExistence(timeout: 30), "no peach card")
        cardFlag(app).tap()
        XCTAssertTrue(app.scrollViews["FlagPicker"].waitForExistence(timeout: 10), "the picker did not open")
        XCTAssertTrue(button(app, "It's offensive").exists, "the peach can't be flagged offensive")
        XCTAssertTrue(button(app, "The definition or origin is wrong").exists, "the peach's card can't be fixed")
        XCTAssertFalse(button(app, "It's not a real word").exists, "the peach is offered not a real word")
        XCTAssertFalse(app.staticTexts["Its grade"].exists, "the peach is offered a grade")
        shoot(app, "L-peach-picker")
        button(app, "Cancel").tap()
        XCTAssertTrue(app.scrollViews["FlagPicker"].waitForNonExistence(timeout: 10), "Cancel left the picker open")
        XCTAssertFalse(text(app, containing: "You flagged this").exists, "Cancel made a flag")
    }

    // MARK: - Settings

    /// Settings shows only the row, with its count, never a flagged word; the
    /// list opens on its own (Antoine, 22 November). With nothing flagged, no row.
    func testSettingsShowsOnlyTheRowAndTheListOpensOnItsOwn() {
        var app = launch(["-showTitle", "1", "-resetProgress", "1"])
        let settings = app.buttons["TitleSettings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 30), "no settings on the title")
        settings.tap()
        XCTAssertTrue(app.buttons["SettingsPrivacy"].waitForExistence(timeout: 10), "no Settings")
        XCTAssertFalse(app.buttons["SettingsFlags"].exists, "a row for Your flags with nothing flagged")
        app.terminate()

        app = launch(["-resetProgress", "1", "-seedBoard", "almost"])
        openBasketWordsCard(app)
        cardFlag(app).tap()
        XCTAssertTrue(app.scrollViews["FlagPicker"].waitForExistence(timeout: 10), "the picker did not open")
        button(app, "It's offensive").tap()
        XCTAssertTrue(text(app, containing: "You flagged this: offensive. Waiting to send.")
            .waitForExistence(timeout: 10), "the flag wasn't made")
        // Back to the board, then to the title, where Settings is: the title
        // shows once a day, so a relaunch wouldn't open on it.
        app.buttons.matching(NSPredicate(format: "label ==[c] %@", "back to the basket")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["DefinitionProse"].waitForNonExistence(timeout: 10), "the card didn't close")
        app.buttons["BoardHome"].tap()
        XCTAssertTrue(app.buttons["TitleSettings"].waitForExistence(timeout: 10), "no settings on the title")
        app.buttons["TitleSettings"].tap()
        let row = app.buttons["SettingsFlags"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Settings has no row for Your flags")
        XCTAssertTrue(row.label.contains("Your flags"), "the row isn't Your flags")
        XCTAssertTrue(row.label.contains("1"), "the row doesn't count the flag")
        XCTAssertFalse(text(app, containing: "offensive").exists, "Settings shows a flag itself")
        for _ in 0..<4 where !isWhollyOnScreen(row, app) { app.swipeUp() }
        shoot(app, "L-5-settings-row")
        row.tap()
        XCTAssertTrue(app.staticTexts["YourFlagsTitle"].waitForExistence(timeout: 10), "the list didn't open")
        shoot(app, "L-6-your-flags-waiting")
        XCTAssertTrue(app.staticTexts["Waiting to send"].exists, "the row doesn't say Waiting to send")
        XCTAssertTrue(text(app, containing: "You can take one back for 60 days.").exists, "the list has no note")
        app.buttons["YourFlagsClose"].tap()
        XCTAssertTrue(app.staticTexts["YourFlagsTitle"].waitForNonExistence(timeout: 10), "Close left the list open")
        XCTAssertTrue(app.buttons["SettingsFlags"].exists, "closing the list closed Settings")
    }
}
