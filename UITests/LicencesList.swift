import XCTest

/// Licences is a list, and each entry opens its text.
///
/// It was one long page until 22 October 2026. The list's four rows must sit
/// on one screen at L, which on an iPhone SE, the smallest window, is the real
/// question; on a larger phone it holds trivially. Each row opens a page that
/// starts with its own text. That each page shows its text whole is the
/// engine's to check, `PlayerLicencesTests`, against the files themselves.
final class LicencesList: XCTestCase {
    /// Each entry, by its identifier, a line from its page's first text, and
    /// for the typefaces a line from its second.
    private let entries: [(id: String, lines: [String])] = [
        ("soundscape", ["MIT License"]),
        ("word-lists", ["ENABLE (Enhanced North American Benchmark LExicon) is in the public domain."]),
        ("wiktionary", ["A few definitions were written for this game"]),
        ("typefaces", ["Copyright 2016 The Fredoka Project Authors",
                       "Copyright 2014 The Nunito Project Authors"]),
    ]

    private func licences() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-resetProgress", "1", "-openSettings", "1", "-openLicences", "1",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()
        return app
    }

    private func pageHas(_ app: XCUIApplication, _ line: String) -> Bool {
        app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", line))
            .firstMatch.waitForExistence(timeout: 10)
    }

    func testTheListFitsOneScreenAndEachEntryOpensItsText() {
        let app = licences()
        for entry in entries {
            let row = app.buttons["Licence-\(entry.id)"]
            XCTAssertTrue(row.waitForExistence(timeout: 30), "no \(entry.id) on the list")
            XCTAssertTrue(row.isHittable, "\(entry.id) is not on the list's first screen")
        }
        for entry in entries {
            app.buttons["Licence-\(entry.id)"].tap()
            for line in entry.lines {
                XCTAssertTrue(pageHas(app, line), "\(entry.id)'s page does not show \"\(line)\"")
            }
            app.navigationBars.buttons.element(boundBy: 0).tap()
            XCTAssertTrue(app.buttons["Licence-\(entry.id)"].waitForExistence(timeout: 10),
                          "\(entry.id)'s page did not go back to the list")
        }
    }

    /// Soundscape's page leads on to the notices of the code it adapts.
    func testSoundscapesPageLeadsToTheNotices() {
        let app = licences()
        let row = app.buttons["Licence-soundscape"]
        XCTAssertTrue(row.waitForExistence(timeout: 30))
        row.tap()
        let notices = app.buttons["Licence-soundscape-notices"]
        XCTAssertTrue(notices.waitForExistence(timeout: 10), "Soundscape's page has no way to the notices")
        var swipes = 0
        while !notices.isHittable && swipes < 10 { app.swipeUp(); swipes += 1 }
        notices.tap()
        XCTAssertTrue(pageHas(app, "Soundscape is MIT licensed: see LICENSE."),
                      "the notices' page does not show them")
    }
}
