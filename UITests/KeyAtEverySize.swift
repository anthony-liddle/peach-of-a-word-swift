import XCTest

/// Every entry in the found list's key fits inside it, at every text size, and
/// wraps onto a second line only where one line can't fit.
///
/// The key's last entry became "the peach of a word" in November 2026, the
/// word's one name in the game, and it's 49pt wider than "source word" at the
/// default size. On one line it ran past the key at AccessibilityXXL on the SE
/// and at AccessibilityXXXL on every iPhone. Antoine's call (5 November 2026):
/// the words aren't shortened, and the entry wraps onto a second line at full
/// size there, as the web's flex items do. Everywhere else the key is as it was.
///
/// The key is hidden from VoiceOver, so its numbers come from `-exposeKeyFit`,
/// which reports the layout's own, not XCUITest's frames. Reach alone can't
/// tell a wrapped entry from one cut short with an ellipsis, so the probe also
/// gives the widest entry's one-line width and the most lines any entry takes.
/// Every size, and the largest on a costume day too, whose peach mark is drawn
/// differently.
final class KeyAtEverySize: XCTestCase {
    static let sizes = [
        "UICTContentSizeCategoryXS",
        "UICTContentSizeCategoryS",
        "UICTContentSizeCategoryM",
    ] + RackAtLargeText.sizes

    private struct Fit {
        /// How far the farthest entry reaches, and how wide the key is.
        let reach, room: Double
        /// The widest entry's width on one line, and the most lines any takes.
        let wide: Double
        let lines: Int
    }

    private func fit(_ size: String, _ extra: [String] = []) -> Fit? {
        let app = XCUIApplication()
        app.launchArguments = ["-resetProgress", "1", "-seedBoard", "almost", "-exposeKeyFit", "1",
                               "-UIPreferredContentSizeCategoryName", size] + extra
        app.launch()
        defer { app.terminate() }
        let probe = app.staticTexts["DebugKeyFit"]
        guard probe.waitForExistence(timeout: 60) else { return nil }
        // Read once the layout has reported every number.
        for _ in 0..<40 {
            let numbers = probe.label.split(separator: " ")
                .compactMap { Double($0.split(separator: "=").last ?? "") }
            if numbers.count == 4, numbers.allSatisfy({ $0 > 0 }) {
                return Fit(reach: numbers[0], room: numbers[1], wide: numbers[2], lines: Int(numbers[3]))
            }
            usleep(250_000)
        }
        return nil
    }

    func testEveryEntryFitsTheKey() {
        let runs = Self.sizes.map { ($0, [String]()) }
            + [(Self.sizes.last!, ["-costumeDate", "2026-10-31"])]
        for (size, extra) in runs {
            let name = size.replacingOccurrences(of: "UICTContentSizeCategory", with: "")
                + (extra.isEmpty ? "" : ", costume")
            guard let fit = fit(size, extra) else {
                XCTFail("the key reported no layout at \(name)")
                continue
            }
            print("KeyAtEverySize \(name): reach \(fit.reach), room \(fit.room), "
                  + "one line \(fit.wide), lines \(fit.lines)")
            XCTAssertLessThanOrEqual(fit.reach, fit.room + 0.5,
                                     "an entry runs \(fit.reach - fit.room)pt past the key at \(name)")
            if fit.wide <= fit.room {
                XCTAssertEqual(fit.lines, 1, "an entry wraps at \(name), where it fits on one line")
            } else {
                XCTAssertEqual(fit.lines, 2, "the entry \(fit.wide - fit.room)pt too wide for one line "
                               + "takes \(fit.lines) at \(name), not two at full size")
            }
        }
    }
}
