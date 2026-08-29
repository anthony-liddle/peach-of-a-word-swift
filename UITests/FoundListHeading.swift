import XCTest

/// Does the found list say what it is, and how many words are in it?
///
/// Three of Bea's notes after playing the app were the same defect from
/// different angles: the list did not match the web. Two of the three were
/// missing furniture rather than wrong furniture, a heading and a total, and
/// missing things are exactly what no existing test could fail on.
///
/// The heading and the total are asserted together because they were added
/// together and for the same reason. They also sit together deliberately: the
/// pinned summary above the list carries set progress ("35 of 85 words"), while
/// this total counts every find including off-page ones. Two different numbers,
/// so they are kept apart, and the new one lives with the heading in the
/// scrolling list where the web puts it.
///
/// Presence, not position, following `ColophonDedication`. The list scrolls and
/// where the heading lands is a decision that is allowed to change; that it
/// exists at all is not. The accessibility sizes matter here because the heading
/// and the total are a two-line stack, and the whole screen switches to the
/// scrolling fallback at those sizes.
final class FoundListHeading: XCTestCase {

    /// Launch at a given text size, seeded or empty, and wait for a real board.
    private func launch(size: String, seed: String?) -> XCUIApplication {
        let app = XCUIApplication()
        var args = ["-resetProgress", "1",
                    "-UIPreferredContentSizeCategoryName", size]
        if let seed { args += ["-seedBoard", seed] }
        app.launchArguments = args
        app.launch()
        // Wait on the rack, so a missing heading fails an assertion below rather
        // than timing out here and reading as a hung app.
        XCTAssertTrue(app.buttons.matching(
            NSPredicate(format: "label MATCHES %@", "^Letter [a-z].*")
        ).firstMatch.waitForExistence(timeout: 30), "the app never rendered a rack")
        return app
    }

    private func fragment(_ app: XCUIApplication, _ text: String) -> XCUIElement {
        // The heading and total are combined into one accessibility element, so
        // each is a fragment of that element's label rather than an element of
        // its own.
        app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    func testTheHeadingIsThereAtDefaultSize() {
        let app = launch(size: "UICTContentSizeCategoryL", seed: nil)
        XCTAssertTrue(fragment(app, "The basket").waitForExistence(timeout: 10),
                      "the found list has no heading")
    }

    /// The size where the whole screen switches to the scrolling fallback, so
    /// the heading is laid out by a different path than the one above.
    func testTheHeadingIsThereAtTheLargestAccessibilitySize() {
        let app = launch(size: "UICTContentSizeCategoryAccessibilityXXXL", seed: nil)
        XCTAssertTrue(fragment(app, "The basket").waitForExistence(timeout: 10),
                      "the found list has no heading at AX5")
    }

    /// The total counts every find, so it is asserted on a board with off-page
    /// words on it rather than on set words alone. Matched on the suffix, since
    /// the number depends on the day's rack.
    func testTheTotalAppearsWithFinds() {
        let app = launch(size: "UICTContentSizeCategoryL", seed: "almost")
        XCTAssertTrue(fragment(app, "words found").waitForExistence(timeout: 10),
                      "the found list shows no total")
    }

    func testTheTotalAppearsAtTheLargestAccessibilitySize() {
        let app = launch(size: "UICTContentSizeCategoryAccessibilityXXXL", seed: "almost")
        XCTAssertTrue(fragment(app, "words found").waitForExistence(timeout: 10),
                      "the found list shows no total at AX5")
    }

    /// An empty board keeps the heading and drops the total, which is what the
    /// web does: the heading names the list whether or not anything is in it,
    /// and a total of nothing is a wall of zeros rather than information.
    func testAnEmptyBoardHasTheHeadingAndNoTotal() {
        let app = launch(size: "UICTContentSizeCategoryL", seed: nil)
        XCTAssertTrue(fragment(app, "The basket").waitForExistence(timeout: 10),
                      "the heading should name the list even when it is empty")
        XCTAssertFalse(fragment(app, "words found").exists,
                       "an empty board should not print a total")
    }
}
