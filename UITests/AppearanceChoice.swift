import XCTest

/// The appearance setting chooses what is drawn: Dark draws the page dark,
/// Light draws it light, and System draws it as the phone is.
///
/// **Through Settings, not a launch argument.** A launch argument sits in the
/// argument domain and would win over what a tap writes, so the test would pass
/// whatever the choices did. So it taps a choice, as a player does, and
/// relaunches to see the choice kept.
///
/// **What is drawn, read from the screen.** The page beside Settings' cards, by
/// brightness rather than by exact colour, since a screenshot can come back in
/// Display P3. Light's page is near white and Cocoa's near black, so the two
/// can't be mistaken for each other.
final class AppearanceChoice: XCTestCase {
    private func launch(_ arguments: [String], size: String = "UICTContentSizeCategoryL") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments + ["-openSettings", "1",
                                           "-UIPreferredContentSizeCategoryName", size]
        app.launch()
        XCTAssertTrue(card(app).waitForExistence(timeout: 30), "no appearance in Settings")
        return app
    }

    private func card(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["SettingsAppearanceCard"]
    }

    /// A choice, by its name, as a button in the Appearance card.
    private func choice(_ name: String, in app: XCUIApplication) -> XCUIElement {
        card(app).buttons[name]
    }

    private func choose(_ name: String, in app: XCUIApplication,
                        file: StaticString = #filePath, line: UInt = #line) {
        let choice = choice(name, in: app)
        XCTAssertTrue(choice.waitForExistence(timeout: 5), "no \(name) in the card",
                      file: file, line: line)
        if !choice.isHittable { app.swipeUp() }
        choice.tap()
        XCTAssertTrue(choice.isSelected, "\(name) isn't selected after its tap", file: file, line: line)
    }

    /// The page's brightness, 0 to 1, beside the cards: a strip 8 points in
    /// from the left edge, halfway down the screen, averaged over 10 points.
    private func pageBrightness(_ app: XCUIApplication) -> Double {
        // A moment for the change to be drawn, and the sheet to settle.
        Thread.sleep(forTimeInterval: 1)
        let image = app.screenshot().image
        guard let cg = image.cgImage else { return -1 }
        let scale = Double(cg.width) / Double(image.size.width)
        let x = Int(8 * scale), y0 = cg.height / 2, span = Int(10 * scale)
        guard let data = cg.dataProvider?.data, let bytes = CFDataGetBytePtr(data) else { return -1 }
        let perPixel = cg.bitsPerPixel / 8, perRow = cg.bytesPerRow
        var sum = 0.0
        for y in y0..<(y0 + span) {
            let i = y * perRow + x * perPixel
            // Red, green and blue in either byte order: a mean doesn't care.
            sum += (Double(bytes[i]) + Double(bytes[i + 1]) + Double(bytes[i + 2])) / (3 * 255)
        }
        return sum / Double(span)
    }

    func testTheChoiceChoosesWhatIsDrawn() {
        let app = launch(["-resetProgress", "1"])
        XCTAssertTrue(choice("System", in: app).isSelected, "a fresh install isn't on System")
        let phone = pageBrightness(app)

        choose("Dark", in: app)
        XCTAssertLessThan(pageBrightness(app), 0.25, "Dark didn't draw the page dark")

        choose("Light", in: app)
        XCTAssertGreaterThan(pageBrightness(app), 0.85, "Light didn't draw the page light")

        // System goes back to the phone's, whichever that is.
        choose("System", in: app)
        XCTAssertEqual(pageBrightness(app), phone, accuracy: 0.05,
                       "System didn't go back to how the phone draws it")
    }

    func testTheChoiceIsKept() {
        let first = launch(["-resetProgress", "1"])
        choose("Dark", in: first)
        first.terminate()

        let again = launch([])
        XCTAssertTrue(choice("Dark", in: again).isSelected, "Dark wasn't kept")
        XCTAssertLessThan(pageBrightness(again), 0.25, "the kept Dark didn't draw the page dark")
    }

    /// At the largest text, each choice grows with its name: at least as tall
    /// as the Sound switch's row, whose name is set the same size. iOS's
    /// segmented control, the picker until 12 November 2026, stays its own
    /// height at every size (Antoine's call that day: a list, with a
    /// checkmark).
    func testTheChoicesGrowWithTheLargestText() {
        let app = launch(["-resetProgress", "1"], size: "UICTContentSizeCategoryAccessibilityXXXL")
        let sound = app.switches["SettingsSound"]
        XCTAssertTrue(sound.waitForExistence(timeout: 5), "no Sound switch in Settings")
        for name in ["System", "Light", "Dark"] {
            let row = choice(name, in: app)
            XCTAssertTrue(row.waitForExistence(timeout: 5), "no \(name) in the card")
            XCTAssertGreaterThanOrEqual(row.frame.height, sound.frame.height,
                                        "\(name) is \(row.frame.height) points tall at the largest text, " +
                                        "and the Sound row \(sound.frame.height)")
        }
        // Chosen by a tap there too, and the choice moves.
        choose("Dark", in: app)
        XCTAssertFalse(choice("System", in: app).isSelected, "System is still selected beside Dark")
    }
}
