import XCTest

/// Every entry in the found list's key fits inside it, at every text size.
///
/// The key's last entry became "the peach of a word" in November 2026, the
/// word's one name in the game, and it's 49pt wider than "source word" at the
/// default size. `FlowLayout` puts each entry on one line at its own width and
/// never wraps its words, so an entry too wide for the key runs past its edge
/// rather than wrapping. Antoine's call (5 November 2026): if it doesn't fit at
/// some size, the size and the options go to him, and the words aren't
/// shortened.
///
/// The key is hidden from VoiceOver, so its numbers come from `-exposeKeyFit`,
/// which reports the layout's own, not XCUITest's frames. Every size, and the
/// largest on a costume day too, whose peach mark is drawn differently.
final class KeyAtEverySize: XCTestCase {
    static let sizes = [
        "UICTContentSizeCategoryXS",
        "UICTContentSizeCategoryS",
        "UICTContentSizeCategoryM",
    ] + RackAtLargeText.sizes

    /// How far the widest entry reaches and how wide the key is, at one size.
    private func fit(_ size: String, _ extra: [String] = []) -> (reach: Double, room: Double)? {
        let app = XCUIApplication()
        app.launchArguments = ["-resetProgress", "1", "-seedBoard", "almost", "-exposeKeyFit", "1",
                               "-UIPreferredContentSizeCategoryName", size] + extra
        app.launch()
        defer { app.terminate() }
        let probe = app.staticTexts["DebugKeyFit"]
        guard probe.waitForExistence(timeout: 60) else { return nil }
        // Read once the layout has reported both numbers.
        for _ in 0..<40 {
            let numbers = probe.label.split(separator: " ")
                .compactMap { Double($0.split(separator: "=").last ?? "") }
            if numbers.count == 2, numbers[0] > 0, numbers[1] > 0 { return (numbers[0], numbers[1]) }
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
            print("KeyAtEverySize \(name): reach \(fit.reach), room \(fit.room)")
            XCTAssertLessThanOrEqual(fit.reach, fit.room + 0.5,
                                     "an entry runs \(fit.reach - fit.room)pt past the key at \(name)")
        }
    }
}
