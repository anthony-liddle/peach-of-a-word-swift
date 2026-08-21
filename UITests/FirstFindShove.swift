import XCTest

/// Does the first find of a fresh day move the found list?
///
/// It did, and not the way it looked. The report was a shift "on the row that
/// shows meet, 3 points", which points at the message line, and the message
/// line was innocent: `MessageLineShove` reserves its height and every anchor
/// above the list measured identical to the hundredth of a point either side of
/// the find. The mover was the summary row, which was gated on
/// `!found.isEmpty`. On an empty board SwiftUI collapsed the row and its 10pt
/// padding together, so the first find inserted 52.67pt at once and the found
/// list, the only flexible element in the fixed layout, absorbed all of it:
/// top 512.00 -> 564.67, height 207.00 -> 154.33, measured on an iPhone 17 at
/// default size. The rack did not move because the insertion is below it; the
/// controls did not move because the list gave up exactly what the row took.
///
/// **This is what `MessageLineShove` cannot see, and it is worth being precise
/// about why, because at a glance the two tests look like the same test.** That
/// one submits eight shuffled letters, which is a rejection: `found` stays
/// empty, so the summary never appears there at all. It also asserts on the
/// rack, which sits above the insertion point and is exactly the element this
/// bug leaves alone. Two independent reasons, either one enough.
///
/// So the anchor here is the found list rather than the rack. The list is where
/// the movement went, and an assertion on furniture that cannot move by
/// construction is an assertion that passes for free.
final class FirstFindShove: XCTestCase {

    /// A word today's rack can spell, learned from the app rather than from the
    /// engine, which this target does not link. `-seedBoard 3` puts three real
    /// finds on the board, deterministically, and their chips carry the words.
    ///
    /// The shortest is taken, which also keeps this off the source word:
    /// finding that opens the reveal card over the screen, which would be a
    /// second thing happening inside the measurement. Measured against the
    /// number of tiles actually on the rack rather than against a literal 8,
    /// because the source word is "as long as the rack" whatever today's rack
    /// happens to be, and a hardcoded length would admit it on any day that
    /// deals a shorter one.
    private func aWordForTodaysRack() -> String? {
        let app = XCUIApplication()
        app.launchArguments = ["-resetProgress", "1", "-seedBoard", "3",
                               "-UIPreferredContentSizeCategoryName",
                               "UICTContentSizeCategoryL"]
        app.launch()
        guard app.staticTexts["FoundSummaryCount"].waitForExistence(timeout: 30) else {
            return nil
        }
        // Chips combine their children, so each one is a single element whose
        // label starts with the word: "amp, on the page, 1 point".
        let rackSize = app.buttons.matching(
            NSPredicate(format: "label MATCHES %@", "^Letter [a-z].*")).count
        let words = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@", " point")
        ).allElementsBoundByIndex.compactMap { element -> String? in
            let word = element.label.split(separator: ",").first.map(String.init) ?? ""
            guard word.count >= 3, word.count < rackSize, word.allSatisfy(\.isLetter) else {
                return nil
            }
            return word.lowercased()
        }
        app.terminate()
        return words.min { $0.count < $1.count }
    }

    func testTheFirstFindDoesNotMoveTheFoundList() throws {
        let word = try XCTUnwrap(aWordForTodaysRack(),
                                 "could not learn a word today's rack can spell")

        let app = XCUIApplication()
        app.launchArguments = ["-resetProgress", "1",
                               "-UIPreferredContentSizeCategoryName",
                               "UICTContentSizeCategoryL"]
        app.launch()

        let tiles = app.buttons.matching(
            NSPredicate(format: "label MATCHES %@", "^Letter [a-z].*"))
        XCTAssertTrue(tiles.firstMatch.waitForExistence(timeout: 30), "no rack tile found")

        // The summary row on an EMPTY board, which is the fix stated directly:
        // the row that used to arrive with the first word is there before it.
        let summary = app.staticTexts["FoundSummaryCount"]
        XCTAssertTrue(summary.exists,
                      "the summary row is absent on a fresh board, so its height "
                      + "still arrives with the first find")

        // Only the fixed layout is measured. In the scrolling fallback the whole
        // screen is one scroll view, so "the found list's top" is not a frame
        // that means anything. Told apart by structure rather than by a height
        // threshold: in the fallback the rack is INSIDE the scroll view, and in
        // the fixed layout the only scroll view is the list below it.
        //
        // Deliberately not witnessed on the summary row, though that would read
        // more naturally. The summary is the element under test: on the code
        // this test was written against it is absent here, and a skip condition
        // that reads a missing element's frame turns a failing assertion into a
        // test that cannot run at all.
        try XCTSkipIf(app.scrollViews.firstMatch.frame.minY < tiles.element(boundBy: 0).frame.minY,
                      "scrolling fallback; the pinned row does not exist here")

        // A placed tile is disabled, so a repeated letter needs its own tile.
        var used = Set<Int>()
        let all = tiles.allElementsBoundByIndex
        for letter in word {
            guard let index = all.indices.first(where: {
                !used.contains($0) && all[$0].label.hasPrefix("Letter \(letter)")
            }) else {
                XCTFail("today's rack cannot spell \(word): stuck at \(letter)")
                return
            }
            used.insert(index)
            all[index].tap()
        }

        // Measured either side of the submit alone. Composing changes the well
        // above the rack, and attributing that to the find would be measuring
        // two things and blaming one. Same discipline as MessageLineShove.
        let listBefore = app.scrollViews.firstMatch.frame.minY
        let rackBefore = tiles.element(boundBy: 0).frame.minY

        app.buttons["Pick word"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label ENDSWITH %@", "letters")
        ).firstMatch.waitForExistence(timeout: 10),
                      "\(word) was not accepted, so this measured no find")

        let listAfter = app.scrollViews.firstMatch.frame.minY
        XCTAssertEqual(
            listAfter, listBefore, accuracy: 0.5,
            "the first find pushed the found list down by \(listAfter - listBefore)pt"
        )
        // The guarantee MessageLineShove makes for a rejected guess, made here
        // for an accepted one.
        let rackAfter = tiles.element(boundBy: 0).frame.minY
        XCTAssertEqual(
            rackAfter, rackBefore, accuracy: 0.5,
            "the first find moved the rack by \(rackAfter - rackBefore)pt"
        )
    }
}
