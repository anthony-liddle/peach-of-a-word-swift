import XCTest

/// The way back to the title costs the board's top row nothing, at every text
/// size.
///
/// **The budget a gear on this row already failed.** The row has about 2pt to
/// spare on an iPhone SE at XXXL (`The Meter's Budget`, 2026-09-23), and the
/// design pass of 2026-10-21 measured a peach ahead of the rank's name taking
/// that phone into the scrolling layout there. The peach takes the calendar's
/// old slot instead, an overlay in a width the row already reserved.
///
/// **Held against a copy of the meter, not against a table.** `-exposeTopRow 1`
/// lays out a hidden copy with no way back at the same width, and prints both
/// heights; they must match. A table of heights would differ by phone and by
/// runtime and need keeping current. Shown red first with the peach placed
/// ahead of the name: the SE at XXXL measured the real meter taller than the
/// copy, as the design pass's sweep had.
///
/// The control is looked up as well, so a run where the way back is missing
/// cannot pass by measuring two bare meters.
final class TopRowCostsNothing: XCTestCase {
    static let sizes = [
        "UICTContentSizeCategoryL", "UICTContentSizeCategoryXL",
        "UICTContentSizeCategoryXXL", "UICTContentSizeCategoryXXXL",
        "UICTContentSizeCategoryAccessibilityM", "UICTContentSizeCategoryAccessibilityL",
        "UICTContentSizeCategoryAccessibilityXL", "UICTContentSizeCategoryAccessibilityXXL",
        "UICTContentSizeCategoryAccessibilityXXXL",
    ]

    /// "real=73.50 bare=73.50", as two numbers.
    static func heights(_ label: String) -> (real: Double, bare: Double)? {
        let parts = label.split(separator: " ").compactMap { $0.split(separator: "=").last }
            .compactMap { Double($0) }
        return parts.count == 2 ? (parts[0], parts[1]) : nil
    }

    func testTheWayBackCostsTheTopRowNothingAtEverySize() {
        for size in Self.sizes {
            let app = XCUIApplication()
            // The near-complete board, whose rank's name is the longest below
            // the crown, so the row is at its tightest.
            app.launchArguments = ["-resetProgress", "1", "-seedBoard", "almost",
                                   "-exposeTopRow", "1",
                                   "-UIPreferredContentSizeCategoryName", size]
            app.launch()

            let home = app.buttons["BoardHome"]
            XCTAssertTrue(home.waitForExistence(timeout: 30), "\(size): no way back on the board")
            XCTAssertTrue(home.isHittable, "\(size): the way back is not hittable")

            let probe = app.staticTexts["DebugTopRow"]
            XCTAssertTrue(probe.waitForExistence(timeout: 10), "\(size): no top-row probe")
            // Both heights arrive after the first layout pass.
            var read = Self.heights(probe.label)
            let deadline = Date().addingTimeInterval(5)
            while (read?.real ?? 0) == 0 || (read?.bare ?? 0) == 0, Date() < deadline {
                Thread.sleep(forTimeInterval: 0.2)
                read = Self.heights(probe.label)
            }
            guard let read, read.real > 0, read.bare > 0 else {
                XCTFail("\(size): the probe read \(probe.label)"); continue
            }
            print(String(format: "TOPROW %@ real=%.2f bare=%.2f", size, read.real, read.bare))
            XCTAssertEqual(read.real, read.bare, accuracy: 0.5,
                           "\(size): the meter with the way back is \(read.real)pt tall, "
                           + "without it \(read.bare)pt")
            app.terminate()
        }
    }
}
