import XCTest

/// The daily reminder once for real, with no stand-ins: iOS's own alert
/// answered Allow, a real reminder two minutes out, the game closed, the
/// banner tapped on the home screen, and the cold launch it starts landing on
/// the title.
///
/// **The only test that reaches the notification delegate.** `DailyReminder`'s
/// tap hooks call `Reminder.opened` directly, so they could not see the crash
/// this found on its first run: the delegate's `async` form handed iOS's
/// completion handler back on a cooperative thread, and UIKit aborted the
/// launch. See `AppDelegate`.
///
/// Up to three minutes, most of it waiting for the clock. It leaves the
/// simulator allowing the game's notifications, which no other test asks
/// about. Its last launch resets, which turns the reminder off, and that
/// launch's open clears what was scheduled.
final class ReminderEndToEnd: XCTestCase {
    func testARealReminderTappedFromColdLandsOnTheTitle() throws {
        // A moved Debug clock moves the dates the reminder is scheduled on,
        // and none would fall two minutes from now.
        try XCTSkipIf(TestClock.dayOffset != 0, "the Debug clock is moved")
        let cal = Calendar.current
        let now = Date()
        let at = cal.date(byAdding: .minute, value: 2, to: now)!
        let parts = cal.dateComponents([.year, .month, .day, .hour, .minute], from: at)
        try XCTSkipIf(parts.day != cal.component(.day, from: now), "too close to midnight")
        let minutes = parts.hour! * 60 + parts.minute!

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let app = XCUIApplication()
        app.launchArguments = ["-resetProgress", "1", "-openSettings", "1", "-exposeReminder", "1",
                               "-reminderMinutes", String(minutes),
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()
        let toggle = app.switches["SettingsReminder"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 30), "no reminder switch in settings")
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()

        // iOS's own alert, the first time this simulator is asked.
        let allow = springboard.buttons["Allow"]
        if allow.waitForExistence(timeout: 10) { allow.tap() }

        // The reminder two minutes out, handed to iOS. The probe says
        // "allowed" until iOS refuses, so "on allowed" alone is also an alert
        // still up, or one that never came: only the date proves the ask was
        // answered. On 25 October 2026 a simulator whose notification service
        // never answered passed "on allowed" and failed 200 seconds later as
        // "no reminder came".
        let stamp = String(format: "%04d-%02d-%02d %02d:%02d",
                           parts.year!, parts.month!, parts.day!, parts.hour!, parts.minute!)
        let probe = app.staticTexts["DebugReminder"]
        XCTAssertTrue(probe.waitForExistence(timeout: 10), "no reminder probe")
        let deadline = Date().addingTimeInterval(10)
        while !probe.label.contains(stamp), Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        let scheduled = probe.label.contains(stamp)
        XCTAssertTrue(scheduled, "the reminder was not scheduled for \(stamp): \(probe.label)")
        // The same day, recorded as shown by the seeded launch, so a launch
        // with no tap would open on the board: landing on the title is the
        // tap's doing.
        app.terminate()

        // Nothing scheduled, nothing to wait for: straight on to the reset.
        if scheduled {
            let banner = springboard.descendants(matching: .any)
                .matching(NSPredicate(format: "label CONTAINS %@", "still on the tree")).firstMatch
            XCTAssertTrue(banner.waitForExistence(timeout: 200), "no reminder came")
            banner.tap()

            XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30), "the tap did not open the game")
            XCTAssertTrue(app.buttons["TitleSettings"].waitForExistence(timeout: 30),
                          "a real reminder tapped from cold did not land on the title")
        }

        // Nothing left scheduled: the reset turns the reminder off, and every
        // open clears iOS's pending list before scheduling anything. Hygiene,
        // not a check: the probe reads "none" before any schedule runs too.
        app.terminate()
        app.launchArguments = ["-resetProgress", "1"]
        app.launch()
        XCTAssertTrue(app.buttons["BoardHome"].waitForExistence(timeout: 30), "the reset launch did not open")
    }
}
