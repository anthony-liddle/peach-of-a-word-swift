import XCTest

/// What VoiceOver skips because the screen already says it: the meter's bar,
/// whose percentage is written beside it, and the crown card's confetti,
/// which is pictures falling. Each was an element VoiceOver could land on
/// (vault, `reports/2026-11-25 Accessibility Labels.md`, findings 3 and 4).
///
/// Nothing here names a board's word, and every failure says what failed.
final class HiddenFromVoiceOver: XCTestCase {
    private func launch(_ extra: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-resetProgress", "1", "-howToPlaySeen", "1"] + extra
        app.launch()
        return app
    }

    /// The audit flagged the bar on every board, as an element with no
    /// description and a hit area too small to press. Only its issues fail
    /// this test; the audit's others are the report's to weigh.
    func testTheMetersBarIsNotAnElement() throws {
        let app = launch(["-seedBoard", "24"])
        XCTAssertTrue(app.staticTexts["MeterPoints"].waitForExistence(timeout: 60), "no board")
        try app.performAccessibilityAudit(for: [.sufficientElementDescription, .hitRegion]) { issue in
            guard let element = issue.element, element.exists else { return true }
            return element.identifier != "MeterTrack"
        }
    }

    /// While the crown card's confetti falls, VoiceOver can land on none of
    /// its hearts, stars and sparkles. XCUITest's tree lists hidden elements
    /// too, and the audit's Dynamic Type check flags hidden text, so neither
    /// can tell; `-exposeSpokenMarks` counts what VoiceOver could reach, the
    /// way VoiceOver walks the window. The basket's own marks are hidden, so
    /// any mark it counts is a falling piece.
    func testTheConfettiIsNotAnElement() {
        let app = launch(["-seedBoard", "source-last", "-findSource", "1", "-exposeSpokenMarks", "1"])
        XCTAssertTrue(app.staticTexts["CompletionHeadline"].waitForExistence(timeout: 60), "no crown card")
        let probe = app.staticTexts["DebugSpokenMarks"]
        XCTAssertTrue(probe.waitForExistence(timeout: 5), "no probe")
        // Read through the fall, about 3.6 seconds, a few times a second.
        var most = 0
        for _ in 0..<12 {
            most = max(most, Int(probe.label.dropFirst("marks=".count)) ?? -1)
            usleep(250_000)
        }
        XCTAssertEqual(most, 0, "VoiceOver could land on the confetti's pieces as they fell")
    }
}
