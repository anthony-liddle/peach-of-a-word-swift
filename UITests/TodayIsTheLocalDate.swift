import XCTest

/// The app's today is the phone's local calendar date, for both day indices.
///
/// **Silent in UTC by construction.** When the phone's zone is UTC, a day
/// computed from UTC and one computed from the local calendar are the same
/// number, so this passes there whatever the app does. It earns its place in
/// the `ui-tests-off-utc` job, which sets the simulator to a zone whose date is
/// not UTC's; there a day index computed from UTC is off by one and this fails.
///
/// The runner lives in the same simulator as the app and inherits its zone, so
/// `Calendar.current` here is the phone's calendar.
final class TodayIsTheLocalDate: XCTestCase {
    /// Days from an epoch to the local date of `now`, counted in whole
    /// calendar days: the same rule the app's `dayIndex` states.
    private func days(from epoch: DateComponents, to now: Date) -> Int {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let local = Calendar.current.dateComponents([.year, .month, .day], from: now)
        let start = utc.date(from: epoch)!
        let end = utc.date(from: local)!
        return utc.dateComponents([.day], from: start, to: end).day!
    }

    private func expected(at now: Date) -> String {
        let storage = days(from: DateComponents(year: 2026, month: 1, day: 1), to: now)
        let daily = days(from: DateComponents(year: 2026, month: 6, day: 23), to: now)
        return "\(storage) \(daily)"
    }

    func testBothDayIndicesAreTheLocalDate() {
        let app = XCUIApplication()
        app.launchArguments = ["-resetProgress", "1", "-exposeToday", "1"]
        // Read on both sides of the launch, so a midnight crossing during it
        // cannot fail the test.
        let before = expected(at: Date())
        app.launch()
        let probe = app.staticTexts["DebugToday"]
        XCTAssertTrue(probe.waitForExistence(timeout: 30), "the app never exposed its day")
        let after = expected(at: Date())

        let zone = TimeZone.current.identifier
        XCTAssertTrue([before, after].contains(probe.label),
                      "the app's day indices are \(probe.label); the local date in \(zone) gives \(after)")
    }
}
