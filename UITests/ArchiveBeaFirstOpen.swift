import XCTest

/// The calendar the back-fill writes on the first launch after a merge.
///
/// **This is a one-shot write on somebody's phone.** `backFillOutcomes` runs
/// once, marks itself done, and never revises a day. The words it reads are
/// pruned to a fortnight, so what it does not take now it cannot take later. The
/// seed reproduces the inputs rather than the result: a live streak pair and the
/// found words the prune would still be holding, expanded by the real code.
final class ArchiveBeaFirstOpen: XCTestCase {
    private func open(month: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-seedArchive", "bea", "-openArchive", "1", "-archiveMonth", month,
        ]
        app.launch()
        XCTAssertTrue(app.buttons["Back to the basket"].waitForExistence(timeout: 60),
                      "the archive sheet never opened")
        return app
    }

    private func dayLabels(_ app: XCUIApplication) -> [String] {
        let all = app.buttons.matching(
            NSPredicate(format: "identifier == %@ OR identifier == %@",
                        "ArchiveDayCell", "ArchiveTodayCell"))
        return (0..<all.count).map { all.element(boundBy: $0).label }
    }

    /// The day number a cell's label starts with, as in "July 2, Finished".
    private func dayNumber(_ label: String) -> Int? {
        Int(label.split(separator: ",").first?
            .split(separator: " ").last.map(String.init) ?? "")
    }

    /// `-archiveMonth`'s key for the month holding the day `daysAgo` before
    /// today, written as `ArchiveSheet.monthKey` writes it. A key the sheet does
    /// not know opens the current month without complaint.
    ///
    /// On the phone's calendar rather than UTC's: the runner shares the
    /// simulator with the app, and `ui-tests-off-utc` runs this class in a zone
    /// whose date is not UTC's.
    private func monthKey(daysAgo: Int) -> String {
        let calendar = Calendar.current
        let day = calendar.date(byAdding: .day, value: -daysAgo, to: TestClock.now)!
        let parts = calendar.dateComponents([.year, .month], from: day)
        return String(format: "%04d-%02d", parts.year!, parts.month!)
    }

    /// **The claim the whole seed exists to check.** The run starts on 2 July
    /// and runs through yesterday, so every day in between is either expanded or
    /// rebuilt, and none of them may read as a day that was never played.
    ///
    /// Today is not in the run and is not expected to be. The seed leaves it
    /// alone deliberately: on merge day her board for the day is unplayed when
    /// the app first opens, and "Still on the tree" is the true thing to say
    /// about it. An earlier version of this test asserted over today as well and
    /// failed on exactly that.
    ///
    /// The run's first three months are fixed by the snapshot, and every day in
    /// them is expanded. The rebuilt days are the thirteen behind today
    /// (`GameModel.seededDayCount`), so their months are worked out from today.
    /// Naming only July to September stopped checking the rebuild once those
    /// days moved into October, and nothing failed to say so.
    func testNoDayInTheRunReadsAsStillOnTheTree() {
        var months = ["2026-07", "2026-08", "2026-09"]
        for daysAgo in [13, 1] {
            let rebuilt = monthKey(daysAgo: daysAgo)
            if !months.contains(rebuilt) { months.append(rebuilt) }
        }
        for month in months {
            let app = open(month: month)
            for label in dayLabels(app) {
                guard let day = dayNumber(label) else { continue }
                let beforeTheRun = month == "2026-07" && day < 2
                // Days after today are "Not yet" and are not the run's business,
                // and today itself is past the run's last day.
                if beforeTheRun || label.contains("Not yet") || label.contains("today") {
                    continue
                }
                XCTAssertFalse(label.contains("Still on the tree"),
                               "\(month) day \(day) lost its record: \(label)")
            }
            app.terminate()
        }
    }

    /// The other half of the same claim. The run does not reach 1 July, so that
    /// day and everything before it must still read as untouched.
    func testTheDayBeforeTheRunIsStillOnTheTree() {
        let app = open(month: "2026-07")
        let first = dayLabels(app).first { dayNumber($0) == 1 }
        XCTAssertNotNil(first, "1 July was not on the page")
        XCTAssertTrue(first?.contains("Still on the tree") == true,
                      "the run was expanded past its first day: \(first ?? "")")
    }

    /// **The point of reading the found words at all.** A day the streak alone
    /// establishes can only ever say `cleared`. A basket can only have come from
    /// the words still in the blob, so if the rebuild is not running, there is no
    /// heart anywhere in the month.
    ///
    /// Yesterday's month, because the seed fills the basket on yesterday's board
    /// and on the boards four and nine days ago. This used to name September,
    /// which held one of those only until 9 October and failed on every run
    /// after. A launch that crosses midnight moves the baskets a day later, to
    /// today and three and eight days ago, and one of those is still in
    /// yesterday's month.
    func testARecentDayKeepsTheBasketTheRunCannotExpress() {
        let app = open(month: monthKey(daysAgo: 1))
        let baskets = dayLabels(app).filter { $0.contains("full") }
        XCTAssertFalse(baskets.isEmpty,
                       "no day was rebuilt from its words, so every basket was lost")
    }

    /// The rename. An expanded day says what the run knows, and the run does not
    /// know where the board was played.
    func testAnExpandedDayCreditsTheStreakRatherThanTheWeb() {
        let app = open(month: "2026-07")
        let expanded = dayLabels(app).filter { $0.contains("kept by your streak") }
        XCTAssertFalse(expanded.isEmpty, "no day credited the streak")
        for label in dayLabels(app) {
            XCTAssertFalse(label.contains("on the web"),
                           "a day still claims the web played it: \(label)")
        }
    }
}
