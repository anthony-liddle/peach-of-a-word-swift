import XCTest

/// The ways back from the board to the title screen: the chevron before the
/// rank's name, and the swipe from the left edge, on today's board and on a
/// past one. And what the swipe must leave alone: a tile at the edge, a swipe
/// that does not start at the edge, and the calendar's own swipe.
final class BackToTheTitle: XCTestCase {
    private func board(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-resetProgress", "1",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"] + extra
        app.launch()
        XCTAssertTrue(app.buttons["BoardHome"].waitForExistence(timeout: 30), "no board")
        return app
    }

    private func titleOpened(_ app: XCUIApplication, timeout: TimeInterval = 5) -> Bool {
        app.buttons["TitlePlay"].waitForExistence(timeout: timeout)
    }

    /// From x 0, the screen's very edge, three quarters of the way across.
    private func swipeFromTheEdge(_ app: XCUIApplication) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.45))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.45))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    func testTheChevronOpensTheTitle() {
        let app = board()
        let back = app.buttons["BoardHome"]
        XCTAssertEqual(back.label, "Back to the title screen")
        XCTAssertTrue(back.isHittable, "the chevron is not hittable")
        back.tap()
        XCTAssertTrue(titleOpened(app), "the chevron did not open the title")
    }

    func testTheChevronOpensTheTitleFromAPastBoard() {
        let app = board(["-seedArchive", "showcase", "-archiveDay", "7"])
        XCTAssertTrue(app.buttons["Back to today"].waitForExistence(timeout: 30), "no past board")
        app.buttons["BoardHome"].tap()
        XCTAssertTrue(titleOpened(app), "the chevron did not open the title from a past board")
    }

    func testTheSwipeFromTheLeftEdgeOpensTheTitle() {
        let app = board()
        swipeFromTheEdge(app)
        XCTAssertTrue(titleOpened(app), "the swipe from the left edge did not open the title")
    }

    func testTheSwipeFromTheLeftEdgeOpensTheTitleFromAPastBoard() {
        let app = board(["-seedArchive", "showcase", "-archiveDay", "7"])
        XCTAssertTrue(app.buttons["Back to today"].waitForExistence(timeout: 30), "no past board")
        swipeFromTheEdge(app)
        XCTAssertTrue(titleOpened(app), "the swipe did not open the title from a past board")
    }

    /// The same drag, begun a third of the way in: not the edge's, so nothing.
    func testASwipeThatStartsOnTheBoardDoesNothing() {
        let app = board()
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.45))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.45))
        start.press(forDuration: 0.05, thenDragTo: end)
        XCTAssertFalse(titleOpened(app, timeout: 3), "a swipe from mid-board opened the title")
    }

    /// The rack's first column sits nearest the edge. A swipe that begins on
    /// that tile, 2pt in from its edge, is a tap on the tile or a swipe back,
    /// never both: the letter and the title, together, would be a letter
    /// placed on the way out.
    func testASwipeBegunOnTheEdgeTileIsOneThingNotTwo() {
        let app = board(["-seedBoard", "3"])
        let tiles = app.buttons.matching(NSPredicate(format: "label MATCHES %@", "^Letter [a-z](, already picked)?$"))
        XCTAssertTrue(tiles.firstMatch.waitForExistence(timeout: 10), "no rack")
        let leftmost = tiles.allElementsBoundByIndex.min { $0.frame.minX < $1.frame.minX }!
        let start = app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: leftmost.frame.minX + 2, dy: leftmost.frame.midY))
        let end = app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: app.windows.firstMatch.frame.width * 0.75, dy: leftmost.frame.midY))
        start.press(forDuration: 0.05, thenDragTo: end)
        let wentBack = titleOpened(app, timeout: 3)
        if wentBack {
            app.buttons["TitlePlay"].tap()
            XCTAssertTrue(app.buttons["BoardHome"].waitForExistence(timeout: 10))
        }
        let placed = app.buttons.matching(NSPredicate(format: "label ENDSWITH %@", ", already picked")).count
        print(String(format: "EDGE swipe from x %.1f: title %@, letters placed %d",
                     leftmost.frame.minX + 2, wentBack ? "yes" : "no", placed))
        XCTAssertNotEqual(wentBack, placed == 1, "the swipe went back and placed a letter, or did neither")
    }

    /// The rack's first column sits nearest the edge. A tap on it still places
    /// its letter, and only that, and a swipe back begun on the edge beside it
    /// places nothing.
    func testTheTileNearestTheEdgeStillLandsAndASwipeBackPlacesNothing() {
        // A few finds, so the title's Play goes back to the board rather than
        // to How to play's first showing.
        let app = board(["-seedBoard", "3"])
        let tiles = app.buttons.matching(NSPredicate(format: "label MATCHES %@", "^Letter [a-z](, already picked)?$"))
        XCTAssertTrue(tiles.firstMatch.waitForExistence(timeout: 10), "no rack")
        let leftmost = tiles.allElementsBoundByIndex.min { $0.frame.minX < $1.frame.minX }!
        print(String(format: "EDGE tile minX %.1f", leftmost.frame.minX))
        leftmost.tap()
        let placed = app.buttons.matching(NSPredicate(format: "label ENDSWITH %@", ", already picked"))
        XCTAssertEqual(placed.count, 1, "a tap on the leftmost tile did not place exactly its letter")
        XCTAssertFalse(titleOpened(app, timeout: 2), "a tap on the leftmost tile opened the title")

        app.buttons["Clear"].tap()
        let edge = app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: 0, dy: leftmost.frame.midY))
        edge.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0))
            .withOffset(CGVector(dx: 0, dy: leftmost.frame.midY)))
        XCTAssertTrue(titleOpened(app), "the swipe beside the rack did not open the title")
        app.buttons["TitlePlay"].tap()
        XCTAssertTrue(app.buttons["BoardHome"].waitForExistence(timeout: 10))
        XCTAssertEqual(placed.count, 0, "the swipe back placed a letter on its way")
    }

    /// Over the calendar the edge is the calendar's: a swipe from it leaves the
    /// calendar up, and the title stays shut.
    func testTheSwipeOverTheCalendarLeavesTheCalendar() {
        let app = board(["-dayOffset", TestClock.midMonthDayOffset])
        app.buttons["Past days"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Back to the basket"].waitForExistence(timeout: 10), "no calendar")
        swipeFromTheEdge(app)
        XCTAssertTrue(app.buttons["Back to the basket"].exists, "the swipe closed the calendar")
        XCTAssertFalse(titleOpened(app, timeout: 2), "the swipe opened the title over the calendar")
    }
}
