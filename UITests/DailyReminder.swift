import XCTest

/// The daily reminder: off until turned on, asked of iOS when it is, one a day
/// on days with no words at the time picked, kept across a launch, and a tap
/// on one lands on the title.
///
/// **iOS's permission alert is stood in for** by `-notificationAnswer granted`
/// or `denied`, since a UI test cannot answer the system's own alert, and once
/// answered on a simulator it stays answered for every later test. The
/// answer is remembered across launches as iOS remembers it.
///
/// **The schedule is read from `-exposeReminder 1`:** the switch, whether iOS
/// said no, and every date handed to iOS, as `yyyy-MM-dd HH:mm`.
final class DailyReminder: XCTestCase {
    /// The `-dayOffset` that makes 17 July 2026 today: `courtesy`'s board,
    /// whose letters the first-find test spells.
    static var julySeventeenth: String {
        let cal = Calendar.current
        let target = cal.date(from: DateComponents(year: 2026, month: 7, day: 17))!
        return String(cal.dateComponents([.day], from: cal.startOfDay(for: TestClock.now),
                                          to: target).day!)
    }

    private func launch(_ arguments: [String], reset: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = (reset ? ["-resetProgress", "1"] : [])
            + ["-exposeReminder", "1",
               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
            + arguments
        app.launch()
        return app
    }

    private func reminderSwitch(_ app: XCUIApplication, file: StaticString = #filePath,
                                line: UInt = #line) -> XCUIElement {
        let toggle = app.switches["SettingsReminder"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 30), "no reminder switch in settings",
                      file: file, line: line)
        return toggle
    }

    private func isOn(_ toggle: XCUIElement) -> Bool {
        (toggle.value as? String) == "1"
    }

    /// The switch's own knob, at the row's trailing end: a tap on the label's
    /// text does not always reach a SwiftUI toggle.
    ///
    /// **Then waits for it to answer,** by moving or with the refusal's line,
    /// and taps once more if neither comes. On 24 October 2026 one flip in the
    /// Pro Max's whole suite never reached the app: the tap was synthesized on
    /// the knob, `switched(on:)` never ran, and the app logged nothing. The
    /// cause was not found. The same test passed ten times alone and three
    /// times in its class's order. A second tap that misses too still fails,
    /// at the caller's check.
    private func flip(_ toggle: XCUIElement, in app: XCUIApplication) {
        let wasOn = isOn(toggle)
        tapKnob(toggle)
        if answered(toggle, wasOn: wasOn, in: app) { return }
        print("REMINDERFLIP the flip did not reach the switch: once more")
        tapKnob(toggle)
    }

    private func tapKnob(_ toggle: XCUIElement) {
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
    }

    /// Whether the switch moved, or a refusal put it back and said so.
    private func answered(_ toggle: XCUIElement, wasOn: Bool, in app: XCUIApplication) -> Bool {
        let refusal = app.staticTexts["SettingsReminderRefused"]
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            if isOn(toggle) != wasOn || refusal.exists { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        return false
    }

    private func probe(_ app: XCUIApplication) -> XCUIElement {
        app.staticTexts["DebugReminder"]
    }

    /// Waits for the probe to read as `matches` says, and returns what it read.
    @discardableResult
    private func waitForProbe(_ app: XCUIApplication, timeout: TimeInterval = 15,
                              _ matches: @escaping (String) -> Bool) -> String {
        let element = probe(app)
        XCTAssertTrue(element.waitForExistence(timeout: 30), "no reminder probe")
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if matches(element.label) { return element.label }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        return element.label
    }

    /// The fire dates the probe lists, after the switch and the answer.
    private func dates(_ label: String) -> [String] {
        let parts = label.split(separator: " ", maxSplits: 2).map(String.init)
        guard parts.count == 3, parts[2] != "none" else { return [] }
        return parts[2].split(separator: ",").map(String.init)
    }

    /// The picker's popover: its hour and minute wheels, set, then put away.
    private func setTime(_ app: XCUIApplication, hour: String, minute: String, period: String) {
        XCTAssertTrue(isOn(app.switches["SettingsReminder"]), "the switch is off, so there is no time to set")
        let picker = app.datePickers["SettingsReminderTime"]
        XCTAssertTrue(picker.waitForExistence(timeout: 10), "no time once the switch is on")
        picker.buttons.firstMatch.tap()
        let wheels = app.pickerWheels
        XCTAssertTrue(wheels.firstMatch.waitForExistence(timeout: 10), "the time's wheels never opened")
        wheels.element(boundBy: 0).adjust(toPickerWheelValue: hour)
        wheels.element(boundBy: 1).adjust(toPickerWheelValue: minute)
        if wheels.count > 2 { wheels.element(boundBy: 2).adjust(toPickerWheelValue: period) }
        // Away from the wheels, on the sheet's title, to close the popover.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap()
    }

    // MARK: Off by default, and a refusal

    /// Refused: the switch goes back off, says where to change it, and hands
    /// nothing to iOS, and a relaunch finds it still off and still saying so.
    func testARefusalLeavesTheSwitchOff() {
        let app = launch(["-notificationAnswer", "denied", "-openSettings", "1"])
        let toggle = reminderSwitch(app)
        XCTAssertFalse(isOn(toggle), "the reminder is on before anyone turned it on")
        flip(toggle, in: app)
        XCTAssertTrue(app.staticTexts["SettingsReminderRefused"].waitForExistence(timeout: 10),
                      "a refusal did not say where to change it")
        XCTAssertFalse(isOn(toggle), "a refusal left the switch on")
        XCTAssertFalse(app.datePickers["SettingsReminderTime"].exists, "a refused reminder offers a time")
        XCTAssertEqual(waitForProbe(app) { $0 == "off refused none" }, "off refused none")
        app.terminate()

        let again = launch(["-notificationAnswer", "denied", "-openSettings", "1"], reset: false)
        XCTAssertFalse(isOn(reminderSwitch(again)), "the refused switch came back on after a launch")
        XCTAssertTrue(again.staticTexts["SettingsReminderRefused"].waitForExistence(timeout: 10),
                      "after a launch, the refusal no longer says where to change it")
    }

    // MARK: Days played

    /// Today has its reminder until today's first find, which takes it, and
    /// leaves tomorrow's. At 23:59, so today's is still to come whenever this
    /// runs, but in the last minutes of a day.
    func testTheDaysFirstFindTakesTodaysReminder() throws {
        let now = Calendar.current.dateComponents([.hour, .minute], from: Date())
        try XCTSkipIf(now.hour == 23 && (now.minute ?? 0) >= 57, "too close to midnight to hold today")
        let app = launch(["-notificationAnswer", "granted", "-dayOffset", Self.julySeventeenth,
                          "-reminderMinutes", "1439", "-openSettings", "1"])
        flip(reminderSwitch(app), in: app)
        let before = waitForProbe(app) { self.dates($0).first == "2026-07-17 23:59" }
        XCTAssertEqual(dates(before).first, "2026-07-17 23:59", "today, unplayed, has no reminder: \(before)")
        XCTAssertEqual(dates(before).count, 14, "not one a day for a fortnight: \(before)")

        app.buttons["SheetClose"].tap()
        for letter in "courtesy" {
            let tile = app.buttons["Letter \(letter)"]
            XCTAssertTrue(tile.waitForExistence(timeout: 10), "no tile for \(letter)")
            tile.tap()
        }
        app.buttons["Pick word"].tap()

        let after = waitForProbe(app) { self.dates($0).first == "2026-07-18 23:59" }
        XCTAssertEqual(dates(after).first, "2026-07-18 23:59", "the first find left today's reminder: \(after)")
        XCTAssertFalse(after.contains("2026-07-17"), "today, played, is still reminded: \(after)")
    }

    // MARK: The time

    /// Every date moves to the time picked.
    func testItMovesWithTheTime() {
        let app = launch(["-notificationAnswer", "granted", "-openSettings", "1"])
        flip(reminderSwitch(app), in: app)
        let first = waitForProbe(app) { !self.dates($0).isEmpty }
        // An empty list satisfies anything: without this, a switch that never
        // came on read as 7 pm.
        XCTAssertFalse(dates(first).isEmpty, "turned on, nothing was handed to iOS: \(first)")
        XCTAssertTrue(dates(first).allSatisfy { $0.hasSuffix(" 19:00") }, "not 7 pm by default: \(first)")

        setTime(app, hour: "8", minute: "30", period: "AM")
        let moved = waitForProbe(app) { label in
            !self.dates(label).isEmpty && self.dates(label).allSatisfy { $0.hasSuffix(" 08:30") }
        }
        XCTAssertTrue(!dates(moved).isEmpty && dates(moved).allSatisfy { $0.hasSuffix(" 08:30") },
                      "the reminders did not move to 8:30: \(moved)")
    }

    /// The switch and the time, both kept: the relaunch passes no reset and no
    /// time, so what it shows is what was stored.
    func testTheSwitchAndTimeSurviveARelaunch() {
        let app = launch(["-notificationAnswer", "granted", "-openSettings", "1"])
        flip(reminderSwitch(app), in: app)
        setTime(app, hour: "9", minute: "15", period: "PM")
        waitForProbe(app) { label in
            !self.dates(label).isEmpty && self.dates(label).allSatisfy { $0.hasSuffix(" 21:15") }
        }
        app.terminate()

        let again = launch(["-notificationAnswer", "granted", "-openSettings", "1"], reset: false)
        XCTAssertTrue(isOn(reminderSwitch(again)), "the switch was forgotten across a launch")
        let picker = again.datePickers["SettingsReminderTime"]
        XCTAssertTrue(picker.waitForExistence(timeout: 10), "no time after a launch")
        let label = waitForProbe(again) { label in
            !self.dates(label).isEmpty && self.dates(label).allSatisfy { $0.hasSuffix(" 21:15") }
        }
        XCTAssertTrue(!dates(label).isEmpty && dates(label).allSatisfy { $0.hasSuffix(" 21:15") },
                      "the time was forgotten across a launch: \(label)")
    }

    // MARK: A tap

    /// A tap that launches the game lands on the title, where the same launch
    /// without one opens on the board.
    func testATapThatLaunchesTheGameLandsOnTheTitle() {
        let plain = launch([])
        XCTAssertTrue(plain.buttons["BoardHome"].waitForExistence(timeout: 30),
                      "the control did not open on the board")
        plain.terminate()

        let app = launch(["-reminderTapped", "1"])
        XCTAssertTrue(app.buttons["TitleSettings"].waitForExistence(timeout: 30),
                      "a tap on a reminder did not land on the title")
    }

    /// A tap with the game open, in Settings over the board: Settings goes,
    /// and the title comes.
    func testATapWithTheGameOpenLandsOnTheTitle() {
        let app = launch(["-reminderTappedAfter", "8", "-openSettings", "1"])
        XCTAssertTrue(reminderSwitch(app).exists, "settings did not open over the board")
        XCTAssertTrue(app.buttons["TitleSettings"].waitForExistence(timeout: 30),
                      "a tap on a reminder did not land on the title")
        // Waited for, since the sheet animates away after the title is up.
        XCTAssertTrue(app.switches["SettingsReminder"].waitForNonExistence(timeout: 10),
                      "settings stayed up over the title")
    }
}
