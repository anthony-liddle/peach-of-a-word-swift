import XCTest

/// The refused word's flag (step 6 of "Flagging Words From The Cards"): on
/// "Not in the word list." only, a flag over the well's trailing edge that
/// never moves the refusal; the system's alert asks first; only its Suggest
/// makes a flag; and the line becomes the confirmation until the next letter.
///
/// **On 24 October 2026's board, opened as today,** as `MarkInTheWell` opens
/// it, so the rack's letters are known. "ytrl" is made of them and is nobody's
/// word, so it's refused, and no real word is printed or sent.
///
/// **No flag reaches the live store from here:** a Debug build's flags go to
/// `FlagServer`'s stand-in, `-flagServer took` or nothing at all.
///
/// `-exposeWellLine 1` puts the well's line, its words' frame and the flag's
/// target and glyph frames in the well's accessibility value, in the well's
/// own points, which the refusal's shake can't move. The well ignores its
/// children for VoiceOver, so this is the only way a test can measure them.
final class RefusedWordFlag: XCTestCase {
    static let refused = "ytrl"
    static let refusal = "Not in the word list."

    private func launch(size: String = "L", _ extra: [String] = [], reset: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = (reset ? ["-resetProgress", "1"] : []) + [
            "-dayOffset", MarkInTheWell.octoberTwentyFourth,
            "-exposeAnnounced", "1", "-exposeWellLine", "1",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategory\(size)",
        ] + extra
        app.launch()
        XCTAssertTrue(well(app).waitForExistence(timeout: 30), "no well")
        return app
    }

    private func well(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["ComposingWell"].firstMatch
    }

    /// What the well reports with `-exposeWellLine 1`.
    struct Probe {
        var shown: String?
        var line: CGRect?
        var target: CGRect?
        var glyph: CGRect?
    }

    private func probe(_ app: XCUIApplication) -> Probe {
        var p = Probe()
        let value = (well(app).value as? String) ?? ""
        for part in value.split(separator: "|") {
            let pair = part.split(separator: "=", maxSplits: 1).map(String.init)
            guard pair.count == 2 else { continue }
            let n = pair[1].split(separator: ",").compactMap { Double($0) }
            let rect = n.count == 4 ? CGRect(x: n[0], y: n[1], width: n[2], height: n[3]) : nil
            switch pair[0] {
            case "shown": p.shown = pair[1]
            case "line": p.line = rect
            case "target": p.target = rect
            case "glyph": p.glyph = rect
            default: break
            }
        }
        return p
    }

    /// Waits for the well's line to read as given.
    @discardableResult
    private func lineReads(_ text: String, _ app: XCUIApplication, timeout: TimeInterval = 10) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if probe(app).shown == text { return true }
            usleep(200_000)
        }
        return false
    }

    private func refuse(_ app: XCUIApplication) {
        MarkInTheWell.pick(Self.refused, in: app)
        XCTAssertTrue(lineReads(Self.refusal, app), "the made-up word wasn't refused as not in the list")
    }

    private func hasFlag(_ app: XCUIApplication) -> Bool { probe(app).target != nil }

    /// A picture for the PR, written to the host when `MATRIX_SHOTS` names a
    /// directory (passed as `TEST_RUNNER_MATRIX_SHOTS`), and nothing otherwise.
    private func shoot(_ app: XCUIApplication, _ name: String) {
        guard let dir = ProcessInfo.processInfo.environment["MATRIX_SHOTS"] else { return }
        sleep(1)
        try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
    }

    /// Taps the flag, and once more if no popup came: iOS sometimes never acts
    /// on a tap, as #147 found for the reminder. A second tap can't send
    /// anything, since the popup ignores a tap outside it.
    private func tapFlag(_ app: XCUIApplication) {
        for _ in 0..<2 {
            guard let t = probe(app).target else { return XCTFail("no flag to tap") }
            let w = well(app).frame
            app.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: w.minX + t.midX, dy: w.minY + t.midY)).tap()
            if app.alerts.firstMatch.waitForExistence(timeout: 3) { return }
        }
    }

    private func announced(_ app: XCUIApplication) -> String {
        app.staticTexts["DebugAnnounced"].label
    }

    private var question: String { "Suggest “\(Self.refused)” for the dictionary?" }

    // MARK: - Where the flag is

    func testTheFlagIsOnlyOnNotInTheWordListAndGoesWithTheNextLetter() {
        // Two letters, submitted at launch (Pick word won't take them), are
        // refused as too short, which has no flag.
        let app = launch(["-tapWords", "yt"])
        XCTAssertTrue(lineReads("Three letters or more.", app), "two letters weren't refused as too short")
        XCTAssertFalse(hasFlag(app), "a flag on Three letters or more.")
        refuse(app)
        XCTAssertTrue(hasFlag(app), "no flag on Not in the word list.")
        XCTAssertEqual(well(app).label, "No letters picked yet", "the well's label changed")
        app.buttons.matching(NSPredicate(format: "label == %@", "Letter y")).firstMatch.tap()
        XCTAssertFalse(hasFlag(app), "the flag stayed after the next letter")
    }

    // MARK: - The popup

    func testNothingIsSentWithoutThePopupsSuggest() {
        let app = launch(["-flagServer", "took"])
        refuse(app)
        shoot(app, "L-1-refusal-with-flag")
        tapFlag(app)
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 10), "the flag didn't ask first")
        shoot(app, "L-2-popup")
        XCTAssertEqual(alert.label, question)
        XCTAssertTrue(alert.buttons["Cancel"].exists, "the popup has no Cancel")
        XCTAssertTrue(alert.buttons["Suggest"].exists, "the popup has no Suggest")
        alert.buttons["Cancel"].tap()
        XCTAssertTrue(alert.waitForNonExistence(timeout: 5), "Cancel left the popup open")
        XCTAssertTrue(lineReads(Self.refusal, app), "Cancel changed the line")
        XCTAssertTrue(hasFlag(app), "Cancel took the flag away")
        XCTAssertFalse(announced(app).contains("Suggested"), "Cancel suggested the word")

        tapFlag(app)
        XCTAssertTrue(alert.waitForExistence(timeout: 10), "the flag didn't ask again")
        alert.buttons["Suggest"].tap()
        XCTAssertTrue(lineReads("✓ Suggestion sent.", app), "Suggest didn't say sent")
        shoot(app, "L-3-sent")
        XCTAssertTrue(announced(app).hasSuffix("Suggested. Sent."), "VoiceOver didn't hear it sent")
        XCTAssertFalse(hasFlag(app), "the flag stayed on the confirmation")

        // The confirmation goes with the next letter, and the letters type.
        app.buttons.matching(NSPredicate(format: "label == %@", "Letter y")).firstMatch.tap()
        XCTAssertEqual(well(app).label, "Picked so far: y", "the next letter didn't type after the popup")
    }

    /// One line for every suggestion that didn't go (Antoine, 23 November):
    /// here, with no server answering.
    func testASuggestionThatDidntGoSaysSavedAndSendsLater() {
        let app = launch()
        refuse(app)
        tapFlag(app)
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 10), "the flag didn't ask first")
        alert.buttons["Suggest"].tap()
        XCTAssertTrue(lineReads("✓ Suggestion saved. It'll send later.", app), "an unsent suggestion didn't say saved")
        shoot(app, "L-4-saved")
        XCTAssertTrue(announced(app).hasSuffix("Suggested. Waiting to send."),
                      "VoiceOver didn't hear it waiting")
    }

    /// A word already suggested from this phone is refused with no flag.
    func testAWordAlreadySuggestedHasNoFlag() {
        let app = launch(["-flagServer", "took"])
        refuse(app)
        tapFlag(app)
        app.alerts.firstMatch.buttons["Suggest"].tap()
        XCTAssertTrue(lineReads("✓ Suggestion sent.", app), "Suggest didn't say sent")
        refuse(app)
        XCTAssertFalse(hasFlag(app), "a word already suggested has its flag again")
    }

    // MARK: - The refusal never moves

    /// The refusal's words are in the same place with and without the flag,
    /// within half a point, and clear of the flag's target. Without it: the
    /// same word refused again once suggested, which has no flag.
    ///
    /// **Refused at launch, by `-tapWords`, not by tapping tiles.** On an SE
    /// at AX5 the board scrolls and the rack sits under the pinned controls, so
    /// a tile tap can land on Shuffle. The suggestion is kept on the phone, so
    /// the second launch, with no reset, refuses the word again with no flag.
    private func refusalStaysPut(size: String) {
        let refusedAtLaunch = ["-flagServer", "took", "-tapWords", Self.refused]
        var app = launch(size: size, refusedAtLaunch)
        XCTAssertTrue(lineReads(Self.refusal, app), "\(size): the made-up word wasn't refused at launch")
        let wellHeight = well(app).frame.height
        guard let withFlag = probe(app).line, let target = probe(app).target else {
            return XCTFail("\(size): no line or no flag")
        }
        XCTAssertLessThanOrEqual(withFlag.maxX, target.minX, "\(size): the flag's target overlaps the words")
        tapFlag(app)
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 10), "\(size): the flag didn't ask first")
        alert.buttons["Suggest"].tap()
        XCTAssertTrue(lineReads("✓ Suggestion sent.", app), "\(size): Suggest didn't say sent")
        app.terminate()

        app = launch(size: size, refusedAtLaunch, reset: false)
        XCTAssertTrue(lineReads(Self.refusal, app), "\(size): the word wasn't refused again")
        XCTAssertFalse(hasFlag(app), "\(size): a word already suggested has its flag again")
        guard let without = probe(app).line else { return XCTFail("\(size): no line") }
        for (a, b, what) in [(withFlag.minX, without.minX, "left"), (withFlag.maxX, without.maxX, "right"),
                             (withFlag.minY, without.minY, "top"), (withFlag.maxY, without.maxY, "bottom")] {
            XCTAssertEqual(a, b, accuracy: 0.5, "\(size): the refusal's \(what) edge moved with the flag")
        }
        XCTAssertEqual(well(app).frame.height, wellHeight, accuracy: 0.5, "\(size): the well changed height")
    }

    func testTheRefusalStaysPutWithTheFlagAtTheDefaultSize() { refusalStaysPut(size: "L") }

    func testTheRefusalStaysPutWithTheFlagAtAX5() { refusalStaysPut(size: "AccessibilityXXXL") }

    /// At AX5 the flag is a 44-point target and its glyph is no wider than it:
    /// Antoine's cap, where the mock drew it 49 points wide.
    func testAtAX5TheFlagIsA44PointTargetWithItsGlyphInside() {
        // Refused at launch, for the reason `refusalStaysPut` gives.
        let app = launch(size: "AccessibilityXXXL", ["-tapWords", Self.refused])
        XCTAssertTrue(lineReads(Self.refusal, app), "the made-up word wasn't refused at launch")
        shoot(app, "AX5-1-refusal-with-flag")
        guard let target = probe(app).target, let glyph = probe(app).glyph else {
            return XCTFail("no flag at AX5")
        }
        XCTAssertEqual(target.width, 44, accuracy: 0.5, "the target isn't 44 points wide")
        XCTAssertEqual(target.height, 44, accuracy: 0.5, "the target isn't 44 points tall")
        XCTAssertLessThanOrEqual(glyph.width, 44.5, "the glyph is wider than its target")
        let bounds = CGRect(origin: .zero, size: well(app).frame.size)
        XCTAssertTrue(bounds.insetBy(dx: -0.5, dy: -0.5).contains(target), "the flag sticks out of the well")
        guard ProcessInfo.processInfo.environment["MATRIX_SHOTS"] != nil else { return }

        // Pictures only from here: the popup and the saved line at AX5.
        tapFlag(app)
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 10), "the flag didn't ask first")
        shoot(app, "AX5-2-popup")
        app.alerts.firstMatch.buttons["Suggest"].tap()
        XCTAssertTrue(lineReads("✓ Suggestion saved. It'll send later.", app), "an unsent suggestion didn't say saved")
        shoot(app, "AX5-3-saved")
    }
}
