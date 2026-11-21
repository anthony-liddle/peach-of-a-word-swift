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
///
/// **It skips, rather than fails, when iOS's notification service never
/// answers.** Three times in October 2026 a simulator's service never answered
/// the game's request for its notification settings, so the game never got as
/// far as asking, and the test failed 200 seconds later as "no reminder came".
/// That is the simulator, not the game. A reminder never scheduled, or
/// scheduled for the wrong minute, with every request answered, still fails.
final class ReminderEndToEnd: XCTestCase {
    /// How long the reminder's date has to reach the probe once the alert is
    /// answered. A working service answers in milliseconds.
    static let serviceWait: TimeInterval = 20

    /// "asked 2 answered 1": a request iOS has not answered yet.
    static func unanswered(_ label: String) -> Bool {
        let n = label.split(separator: " ").compactMap { Int($0) }
        return n.count == 2 && n[0] > n[1]
    }

    /// Whether the tap on the switch arrived, within five seconds: the switch
    /// came on, or iOS's alert came up to ask, which only a switch turned on
    /// does.
    static func answered(_ toggle: XCUIElement, or allow: XCUIElement) -> Bool {
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            if allow.exists || (toggle.value as? String) == "1" { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        return false
    }

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
        let knob = toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5))
        knob.tap()

        // **Once more, if the switch didn't move,** as `DailyReminder`'s
        // `flip` does. A tap on the knob has left the switch off on 24 October
        // and 1 November 2026, and on 20 November in the third of five runs in
        // a row on an iOS 26.5 simulator, where nothing on screen changed after
        // it. A switch the game won't turn on still fails below, as "not
        // scheduled".
        let allow = springboard.buttons["Allow"]
        if !Self.answered(toggle, or: allow) {
            XCTContext.runActivity(named: "The switch didn't move: tap it again") { _ in
                print("ReminderEndToEnd: the switch didn't move 5 seconds after the tap, so it was tapped again")
                knob.tap()
            }
        }

        // iOS's own alert, the first time this simulator is asked.
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
        let asks = app.staticTexts["DebugReminderSettings"]
        XCTAssertTrue(probe.waitForExistence(timeout: 10), "no reminder probe")
        let deadline = Date().addingTimeInterval(Self.serviceWait)
        while !probe.label.contains(stamp), Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        let scheduled = probe.label.contains(stamp)
        // No date, and iOS still owes the game an answer about its settings:
        // the service never answered, which the skip below says. No date with
        // every request answered is the game's doing, and fails here.
        let silent = !scheduled && Self.unanswered(asks.label)
        if !silent {
            XCTAssertTrue(scheduled, "the reminder was not scheduled for \(stamp): "
                          + "\(probe.label), settings \(asks.label)")
        }
        let asked = silent ? asks.label : ""
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

            // **Once more, if the banner is still up.** A tap iOS acts on puts
            // the banner away at once and asks for the game. On CI, at least six
            // times since November, iOS never asked for the game. In the screen
            // recordings of #144's and #145's failures (20 November 2026) the
            // banner stayed still after the tap and went back up on its own
            // timer about six seconds later. So a banner still up two seconds
            // after the tap gets one more. A game that opens and then fails is
            // still caught below: by then its banner is gone, so there's no
            // second tap.
            if !banner.waitForNonExistence(timeout: 2), banner.exists, banner.isHittable {
                XCTContext.runActivity(named: "The banner is still up: tap it again") { _ in
                    print("ReminderEndToEnd: the banner was still up 2 seconds after the tap, so it was tapped again")
                    banner.tap()
                }
            }

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

        // After the reset, so a skip leaves the simulator as a pass would.
        if silent {
            throw XCTSkip("iOS's notification service did not answer the game's request for its "
                          + "notification settings within \(Int(Self.serviceWait)) seconds "
                          + "(\(asked)), so no reminder could be scheduled: the simulator, "
                          + "not the game")
        }
    }
}
