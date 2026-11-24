import XCTest

/// The board's top row and the found list's best word keep every word whole,
/// at every text size: a line may break at a space, never inside a word.
///
/// At AX5 on an iPhone 17 Pro and an SE the top row read "First Spro" over
/// "ut", and on the SE "point" over "s" (24 November 2026). The found list's
/// best word read "acin" over "g" on an iPhone 17 Pro Max (21 November). The
/// row and the best word each split their width between two things, and at
/// the largest sizes that left one of them narrower than a word.
///
/// XCUITest can't see where a line breaks, so the numbers come from
/// `-exposeWordBreaks 1`: each probed text's widest word on one line, against
/// the width the text was laid out in. Its report names the texts, never the
/// board's words, so a failure prints nothing of the day.
final class WholeWordsAtEverySize: XCTestCase {
    /// Two boards: an empty one, whose rank is the longest first name, "First
    /// Sprout", and one with finds, which has a best word. The texts each
    /// probes, as the report names them.
    static let boards: [(seed: [String], probed: [String])] = [
        ([], ["points", "rank"]),
        (["-seedBoard", "6"], ["best", "points", "rank"]),
    ]

    private func report(_ size: String, seed: [String], probed: [String]) -> String? {
        let app = XCUIApplication()
        app.launchArguments = ["-resetProgress", "1", "-exposeWordBreaks", "1",
                               "-UIPreferredContentSizeCategoryName", size] + seed
        app.launch()
        defer { app.terminate() }
        let probe = app.staticTexts["DebugWordBreaks"]
        guard probe.waitForExistence(timeout: 60) else { return nil }
        // Read once every probed text has reported both numbers.
        for _ in 0..<40 {
            let label = probe.label
            if probed.allSatisfy({ label.contains("\($0)=whole") || label.contains("\($0)=broken") }) {
                return label
            }
            usleep(250_000)
        }
        return probe.label
    }

    func testEveryWordIsWholeAtEverySize() {
        for size in RackAtLargeText.sizes {
            for board in Self.boards {
                let name = size.replacingOccurrences(of: "UICTContentSizeCategory", with: "")
                    + (board.seed.isEmpty ? ", nothing found" : ", with finds")
                guard let label = report(size, seed: board.seed, probed: board.probed) else {
                    XCTFail("\(name): the word break probe never appeared")
                    continue
                }
                for text in board.probed {
                    XCTAssertTrue(label.contains("\(text)=whole"),
                                  "\(name): \(text) has a word wider than its room: \(label)")
                }
            }
        }
    }
}
