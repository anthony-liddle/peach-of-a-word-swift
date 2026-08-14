import XCTest

/// Does filling the message line move the rack?
///
/// It did. A rejected guess put "Not a word you can make from these letters."
/// into a slot whose frame said `minHeight: 20`, the sentence wrapped to two
/// lines, and everything below it (rack, summary, list, controls) dropped
/// 18.8pt while a thumb was already moving toward a tile. Measured here, on a
/// tall phone at XXXL, where the fixed layout is in use and the rack is
/// supposed to be furniture that does not move.
///
/// It runs on whatever simulator it is given, with no skip, and that is a
/// property rather than an oversight: CI takes the first iPhone image the
/// runner happens to have. The claim holds in both layouts. In the fixed layout
/// the message sits above the rack, which is where the bug was. In the
/// scrolling fallback it sits below the rack, where it structurally cannot push
/// it. So there is no device this test needs to opt out of, and no
/// `XCTSkipIf` to get wrong.
///
/// The assertion is on the rack rather than on the message, deliberately: the
/// message is allowed to change wording, shrink, or truncate, and none of that
/// is a bug. The rack moving is the bug, whatever the message says, so that is
/// what is pinned. A future string long enough to wrap would fail this test
/// without anyone having to predict which string it would be.
final class MessageLineShove: XCTestCase {

    func testFeedbackDoesNotMoveTheRack() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-resetProgress", "1",
            // XXXL rather than the default, because that is where the sentence
            // ran out of width on a 402pt phone. At default size the same
            // string fits on one line and the bug is invisible.
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryXXXL",
        ]
        app.launch()

        // The rack tiles, by the label they already carry. `app.buttons`, not
        // every descendant: the rack container is labelled "Letter tiles" and
        // a loose query matches it first. See RackScrollTests for the same trap.
        let tiles = app.buttons.matching(
            NSPredicate(format: "label MATCHES %@", "^Letter [a-z].*"))
        XCTAssertTrue(tiles.firstMatch.waitForExistence(timeout: 20), "no rack tile found")

        // The whole rack, in display order. A fresh board has nothing found, so
        // this cannot come back "already found", and eight shuffled letters are
        // not a word, so it comes back rejected: the longest message the slot
        // carries. If it ever does spell the source word, the assertion below
        // still holds, because no message may move the rack.
        for i in 0..<8 where tiles.count > i {
            tiles.element(boundBy: i).tap()
        }

        // Measured either side of the submit alone, not either side of the
        // whole interaction. Composing also changes the well above the rack,
        // and attributing that to the message line would be measuring two
        // things and blaming one.
        let before = tiles.element(boundBy: 0).frame.minY
        app.buttons["Pick word"].firstMatch.tap()

        let after = tiles.element(boundBy: 0).frame.minY
        XCTAssertEqual(
            after, before, accuracy: 0.5,
            "the message line grew and pushed the rack down by \(after - before)pt"
        )
    }
}
