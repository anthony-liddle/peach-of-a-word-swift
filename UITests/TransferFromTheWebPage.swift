import XCTest

/// The web's transfer page handing a streak to the app, end to end in the
/// simulator: Safari opens the page, Send, iOS's "Open in" question, and the
/// app taking the streak. Checks 3, 4 and 6 of the build report's phone checks,
/// `reports/2026-11-15 Moving From The Web To The App Build.md` in the vault.
///
/// **They need the web's page served on this Mac,** which CI doesn't have, so
/// run them with `tools/transfer-checks/run.sh`. It builds the page from a web
/// checkout, serves it at `http://localhost:PORT` with no Vercel sign-in, runs
/// the computer half of check 4 in a desktop browser, and hands both addresses
/// to these tests as `TRANSFER_PAGE` and `TRANSFER_ADDRESS`. Without them,
/// every test here skips, and says why.
///
/// **What they don't cover:** Chrome on an iPhone (checks 1 and 2), which a
/// simulator doesn't have, and the Home Screen icon (check 5), which waits for
/// the game's footer link.
final class TransferFromTheWebPage: XCTestCase {
    private let environment = ProcessInfo.processInfo.environment
    private var safari: XCUIApplication { XCUIApplication(bundleIdentifier: "com.apple.mobilesafari") }
    private var springboard: XCUIApplication { XCUIApplication(bundleIdentifier: "com.apple.springboard") }

    private var page: String { environment["TRANSFER_PAGE"] ?? "" }

    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipIf(page.isEmpty, "no transfer page served; run tools/transfer-checks/run.sh")
    }

    /// A fresh app, left in the background, so the link reaches it warm: the
    /// streak has to show at once, without a fresh start.
    private func freshAppInTheBackground() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-resetProgress", "1"]
        app.launch()
        let board = app.buttons["BoardHome"]
        let title = app.buttons["TitlePlay"]
        XCTAssertTrue(board.waitForExistence(timeout: 60) || title.exists, "the app never came up")
        XCUIDevice.shared.press(.home)
        return app
    }

    /// Safari is launched first, then handed the address. On a fresh
    /// simulator, an address handed to Safari as it first starts stayed behind
    /// its Start Page, with the address bar still being edited, and the page
    /// never showed.
    private func openInSafari(_ address: String) throws {
        let url = try XCTUnwrap(URL(string: address), "not an address: \(address)")
        safari.launch()
        XCTAssertTrue(safari.wait(for: .runningForeground, timeout: 30), "Safari didn't start")
        XCUIDevice.shared.system.open(url)
        XCTAssertTrue(safari.wait(for: .runningForeground, timeout: 30), "Safari didn't open \(address)")
    }

    /// The page shows the count, then Send, then iOS's question: Open.
    private func sendFromThePage(count: Int) {
        XCTAssertTrue(safari.staticTexts[String(count)].waitForExistence(timeout: 30),
                      "the page didn't show the streak of \(count)")
        let send = safari.links["Send it to the app"]
        XCTAssertTrue(send.waitForExistence(timeout: 10), "the page offered no Send it to the app")
        send.tap()

        // iOS asks before a page opens an app: "Open in "Peach of a Word"?",
        // with Cancel and Open. Its Open isn't exposed as an alert's button,
        // so it's found among Safari's buttons, or SpringBoard's on an iOS
        // that draws it there.
        let inSafari = safari.buttons["Open"]
        let inSpringBoard = springboard.buttons["Open"]
        let deadline = Date().addingTimeInterval(15)
        while !inSafari.exists, !inSpringBoard.exists, Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        if inSafari.exists { inSafari.tap() } else if inSpringBoard.exists { inSpringBoard.tap() }
        else { XCTFail("iOS never asked to open the app") }
    }

    /// The app forward, and on its title the streak the page sent.
    private func titleShows(_ app: XCUIApplication, streak count: Int) {
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20), "the app didn't come forward")
        let home = app.buttons["BoardHome"]
        if home.waitForExistence(timeout: 5) { home.tap() }
        let streak = app.descendants(matching: .any).matching(identifier: "TitleStreak").firstMatch
        guard streak.waitForExistence(timeout: 10) else {
            XCTFail("no streak on the title: the app didn't take it")
            return
        }
        XCTAssertEqual(streak.label, "Streak, \(count) days")
    }

    /// Check 3: the page in Safari finds the save, and Safari hands the link
    /// to the app, which takes the streak at once (check 6's first half).
    func testSafariSendsTheStreakToTheApp() throws {
        let app = freshAppInTheBackground()
        try openInSafari("\(page)/seed?count=5")
        sendFromThePage(count: 5)
        titleShows(app, streak: 5)
    }

    /// Check 4: the address a desktop browser offered, carrying the streak
    /// after its #, opened on the phone, where the page reads the streak from
    /// it and sends it on. The desktop half ran before this, in
    /// `tools/transfer-checks/desktop.mjs`.
    func testTheComputersAddressSendsTheStreakFromThePhone() throws {
        let address = try XCTUnwrap(environment["TRANSFER_ADDRESS"].flatMap { $0.isEmpty ? nil : $0 },
                                    "no address from the desktop browser")
        let count = try XCTUnwrap(
            address.components(separatedBy: "count=").last?.split(separator: "&").first.flatMap { Int($0) },
            "no count in \(address)")
        let app = freshAppInTheBackground()
        try openInSafari(address)
        sendFromThePage(count: count)
        titleShows(app, streak: count)
    }

    /// Check 6: after a cold launch, Past days shows the streak's days as
    /// finished, kept by the streak. The run is three days ending today, so the
    /// days in this month are checked; one that falls in the month before is
    /// left out.
    func testTheStreaksDaysShowAsFinishedAfterAColdLaunch() throws {
        // Both halves report, so a run with the link handler off shows the
        // cold launch failing too, not only the streak at once.
        continueAfterFailure = true
        var app = freshAppInTheBackground()
        try openInSafari("\(page)/seed?count=3")
        sendFromThePage(count: 3)
        titleShows(app, streak: 3)

        app.terminate()
        app = XCUIApplication()
        app.launchArguments = ["-openArchive", "1"]
        app.launch()
        let cells = app.buttons.matching(
            NSPredicate(format: "identifier == %@ OR identifier == %@", "ArchiveDayCell", "ArchiveTodayCell"))
        XCTAssertTrue(app.buttons["ArchiveTodayCell"].waitForExistence(timeout: 60), "Past days never opened")

        let formatter = DateFormatter()
        formatter.calendar = .current
        formatter.setLocalizedDateFormatFromTemplate("MMMM d")
        let month = Calendar.current.component(.month, from: Date())
        var checked = 0
        for back in 0..<3 {
            let day = Calendar.current.date(byAdding: .day, value: -back, to: Date())!
            guard Calendar.current.component(.month, from: day) == month else { continue }
            let prefix = formatter.string(from: day) + ","
            let cell = cells.allElementsBoundByIndex.first { $0.label.hasPrefix(prefix) }
            let label = cell?.label ?? "no cell"
            XCTAssertTrue(label.contains("Finished") && label.contains("kept by your streak"),
                          "\(prefix) isn't finished by the streak: \(label)")
            checked += 1
        }
        XCTAssertGreaterThan(checked, 0)
    }
}
