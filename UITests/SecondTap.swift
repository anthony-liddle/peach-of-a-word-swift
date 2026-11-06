import UIKit
import XCTest

/// A second tap, after a first the app did not answer, put on the record every
/// time one is made.
///
/// **Why a record, not a print.** A retry that passes hides what it retried: a
/// run whose first tap was lost and whose second landed reads just like a run
/// with nothing lost. On 5 November 2026 one tap on Past days opened nothing,
/// once, in `BackToTheDayYouWereOn`, and Antoine asked that each later one
/// leave a record with the run and the device, so a real lost tap cannot hide
/// behind the second.
///
/// **The record is an activity in the result bundle,** titled with `prefix`,
/// what was tapped again, and the simulator with its iOS. `plan.py verify`
/// reads every shard's bundle and turns each one into a warning on the run,
/// naming the run, the attempt and the shard, and the `ui-tests` job's summary
/// lists them. Locally, `tools/ui-tests.sh` prints them after the run. A run's
/// warnings expire with it, so `reports/2026-11-01 The Lost Tap.md` in the
/// vault keeps each one, with its run.
enum SecondTap {
    static let prefix = "SECOND TAP: "

    /// Record a second tap on `what`, in the test running now.
    static func record(_ what: String) {
        let env = ProcessInfo.processInfo.environment
        let device = env["SIMULATOR_DEVICE_NAME"] ?? UIDevice.current.name
        let system = env["SIMULATOR_RUNTIME_VERSION"] ?? UIDevice.current.systemVersion
        let title = "\(prefix)\(what), on \(device), iOS \(system)"
        print(title)
        XCTContext.runActivity(named: title) { _ in }
    }
}
