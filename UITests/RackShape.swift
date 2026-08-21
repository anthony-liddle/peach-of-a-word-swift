import XCTest

/// What shape is the rack in?
///
/// The rack is eight tiles in a fixed number of columns, and there are exactly
/// two shapes it is allowed to take: 4+4 at normal text sizes, 3+3+2 at
/// accessibility sizes. The second is a deliberate response to Dynamic Type.
/// The first is the one that has been lost before.
///
/// It was lost by making the tiles shorter. An earlier version fixed the tile
/// HEIGHT and let the width follow, so each tile demanded a width the container
/// could not supply four of, and a 390pt phone broke to 3+3+2 at default size
/// with nobody having asked for three columns. The fix was to invert it: width
/// drives, height follows through the 3:4 ratio, and any cap is a cap on height
/// only. That inversion is easy to undo by accident, because "make the tiles a
/// bit shorter" is a reasonable sentence that has two implementations and only
/// one of them is safe.
///
/// So this measures the shape rather than the sizes. Sizes are allowed to
/// change, and this test says nothing about them. What it pins is that eight
/// tiles land in the rows they are supposed to, which is the part that has
/// regressed and the part a player would notice.
///
/// Rows are read off the tiles' own frames, by grouping on `minY`, rather than
/// from anything the layout code exposes. A test that asked the view how many
/// columns it thinks it has would agree with the bug.
final class RackShape: XCTestCase {

    /// Tile counts per row, top to bottom.
    private func rowShape(at size: String) -> [Int] {
        let app = XCUIApplication()
        app.launchArguments = ["-resetProgress", "1",
                               "-UIPreferredContentSizeCategoryName", size]
        app.launch()
        let tiles = app.buttons.matching(
            NSPredicate(format: "label MATCHES %@", "^Letter [a-z].*"))
        guard tiles.firstMatch.waitForExistence(timeout: 30) else { return [] }

        // Grouped on the row's top edge, rounded, so a half point of rendering
        // difference does not read as a new row.
        var rows: [CGFloat: Int] = [:]
        for tile in tiles.allElementsBoundByIndex {
            rows[(tile.frame.minY).rounded(), default: 0] += 1
        }
        let shape = rows.sorted { $0.key < $1.key }.map(\.value)
        print("RACK \(size) shape=\(shape) tileHeight=\(tiles.firstMatch.frame.height)")
        return shape
    }

    func testFourAndFourAtDefaultSize() {
        XCTAssertEqual(rowShape(at: "UICTContentSizeCategoryL"), [4, 4],
                       "the rack is not 4+4 at default size")
    }

    /// The largest size in the normal range, which is where the width squeeze
    /// is worst before the deliberate three-column reflow takes over.
    func testStillFourAndFourAtTheTopOfTheNormalRange() {
        XCTAssertEqual(rowShape(at: "UICTContentSizeCategoryXXXL"), [4, 4],
                       "the rack broke out of 4+4 inside the normal size range")
    }

    func testThreeColumnsAtAccessibilitySizes() {
        XCTAssertEqual(rowShape(at: "UICTContentSizeCategoryAccessibilityXXXL"), [3, 3, 2],
                       "the accessibility reflow is not 3+3+2")
    }
}
