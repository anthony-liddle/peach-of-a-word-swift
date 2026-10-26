import XCTest

/// A Mythic find's line in the well, `❖ tel, 5 points`, at every text size:
/// the well keeps its height, and a fixed rack stays where it was.
///
/// **The mark adds width to the row with the least room,** so this measures
/// rather than trusts the fixed frame. The line itself is not in the tree (the
/// well ignores its children, and says the find by announcement), so the well
/// is measured by the label it carries when no letters are picked, before and
/// after the find. Its pictures, one per size, are written when `MATRIX_SHOTS`
/// names a directory (passed as `TEST_RUNNER_MATRIX_SHOTS`).
///
/// On 24 October 2026's board, `literary`, opened as today. TEL is Mythic
/// there, and spelled by tapping its tiles, as a player would.
final class MarkInTheWell: XCTestCase {
    /// The `-dayOffset` that makes 24 October 2026 today.
    static var octoberTwentyFourth: String {
        let cal = Calendar.current
        let target = cal.date(from: DateComponents(year: 2026, month: 10, day: 24))!
        return String(cal.dateComponents([.day], from: cal.startOfDay(for: TestClock.now),
                                          to: target).day!)
    }

    static let sizes = ["XS", "S", "M", "L", "XL", "XXL", "XXXL",
                        "AccessibilityM", "AccessibilityL", "AccessibilityXL",
                        "AccessibilityXXL", "AccessibilityXXXL"]

    /// Spell a word on the rack and pick it. Each letter's first unpicked tile.
    static func pick(_ word: String, in app: XCUIApplication) {
        for letter in word {
            let tile = app.buttons.matching(
                NSPredicate(format: "label == %@", "Letter \(letter)")).firstMatch
            guard tile.waitForExistence(timeout: 5) else {
                let rack = app.buttons.allElementsBoundByIndex.map { $0.label }
                    .filter { $0.hasPrefix("Letter ") }
                XCTFail("no unpicked \(letter) for \(word): \(rack)")
                return
            }
            tile.tap()
        }
        app.buttons["Pick word"].firstMatch.tap()
    }

    func testTheWellKeepsItsHeightAtEverySize() {
        var report: [String] = []
        for size in Self.sizes {
            let app = XCUIApplication()
            app.launchArguments = [
                "-resetProgress", "1", "-dayOffset", Self.octoberTwentyFourth,
                "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategory\(size)",
            ]
            app.launch()

            let well = app.descendants(matching: .any)["No letters picked yet"].firstMatch
            let tile = LayoutBudget.rackTile(app)
            XCTAssertTrue(well.waitForExistence(timeout: 30), "\(size): no well")
            XCTAssertTrue(tile.waitForExistence(timeout: 10), "\(size): no rack")
            let fixed = LayoutBudget.rackIsFixed(app)
            let before = (well: well.frame.height, rack: tile.frame.minY)

            Self.pick("tel", in: app)
            let chip = app.buttons.matching(
                NSPredicate(format: "label BEGINSWITH %@", "tel, Mythic, ")).firstMatch
            XCTAssertTrue(chip.waitForExistence(timeout: 10), "\(size): TEL was not found")
            let after = (well: well.frame.height, rack: tile.frame.minY)

            XCTAssertEqual(after.well, before.well, accuracy: 0.01,
                           "\(size): the Mythic line changed the well's height")
            // A scrolling layout may scroll to reach a tile, which moves it
            // without anything having pushed it. Only a fixed rack must stay.
            if fixed {
                XCTAssertEqual(after.rack, before.rack, accuracy: 0.01,
                               "\(size): the Mythic line moved the rack")
            }
            report.append(String(format: "%@ well=%.2f→%.2f rack=%@", size,
                                 before.well, after.well, fixed ? "fixed" : "scrolls"))
            if let dir = ProcessInfo.processInfo.environment["MATRIX_SHOTS"] {
                let url = URL(fileURLWithPath: dir).appendingPathComponent("well-\(size).png")
                try? app.screenshot().pngRepresentation.write(to: url)
            }
            app.terminate()
        }
        print("WELL " + report.joined(separator: " | "))
    }
}
