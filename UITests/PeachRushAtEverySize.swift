import XCTest

/// Peach rush at every text size: the run's clock, its rack and its controls
/// all on screen at rest, and on the title, its button under Play where the
/// title fits.
///
/// On an SE at AX5 the prototype measured half a point between the rack's last
/// row and the pinned controls (`reports/2026-11-24 Timed Mode.md`). This holds
/// the row above the controls at every size, and says so when it isn't.
final class PeachRushAtEverySize: XCTestCase {
    private func launch(_ size: String, _ extra: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-resetProgress", "1", "-UIPreferredContentSizeCategoryName", size] + extra
        app.launch()
        return app
    }

    private func name(_ size: String) -> String {
        size.replacingOccurrences(of: "UICTContentSizeCategory", with: "")
    }

    func testTheRunFitsAtRestAtEverySize() {
        for size in RackAtLargeText.sizes {
            let app = launch(size, ["-timedRun", "running", "-timedRunFreeze", "52"])
            defer { app.terminate() }
            let at = name(size)
            let window = app.windows.firstMatch.frame
            let clock = app.staticTexts["RunClock"]
            guard clock.waitForExistence(timeout: 60) else {
                XCTFail("\(at): no run")
                continue
            }
            XCTAssertTrue(window.contains(clock.frame), "\(at): the clock isn't on screen")
            let tiles = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Letter'"))
                .allElementsBoundByIndex
            XCTAssertEqual(tiles.count, 8, "\(at): not every letter is there")
            let controls = [app.buttons["Clear"], app.buttons["Delete last letter"]]
            for control in controls {
                XCTAssertTrue(window.contains(control.frame), "\(at): \(control.label) isn't on screen")
            }
            let rackFoot = tiles.map { $0.frame.maxY }.max() ?? 0
            let controlsTop = ([app.buttons["Shuffle"]] + controls).map { $0.frame.minY }.min() ?? 0
            XCTAssertLessThanOrEqual(rackFoot, controlsTop + 0.5,
                                     "\(at): the rack's last row runs under the controls by \(rackFoot - controlsTop)pt")
        }
    }

    /// At L, the title fits on every phone, and the run's button is directly
    /// under Play, above Past days.
    func testTheRunsButtonIsUnderPlayAtL() {
        let app = launch("UICTContentSizeCategoryL", ["-showTitle", "1", "-titleLastShownDay", "never"])
        defer { app.terminate() }
        let run = app.buttons["TitleRun"]
        XCTAssertTrue(run.waitForExistence(timeout: 60), "no run on the title")
        let play = app.buttons["TitlePlay"].frame
        let pastDays = app.buttons["TitlePastDays"].frame
        XCTAssertGreaterThanOrEqual(run.frame.minY, play.maxY, "the run's button isn't under Play")
        XCTAssertLessThan(run.frame.minY - play.maxY, 24, "something sits between Play and the run's button")
        XCTAssertGreaterThan(pastDays.minY, run.frame.maxY, "the run's button isn't above Past days")
        XCTAssertTrue(app.windows.firstMatch.frame.contains(pastDays), "the title scrolls at L")
    }
}
