import SwiftUI

/// The entry point.
///
/// `@main` on a type conforming to `App` replaces the AppDelegate lifecycle
/// entirely. There is no main.swift, no UIApplicationMain, and no storyboard.
/// The whole app is this struct plus whatever view it returns.
@main
struct PeachMinimalApp: App {
    #if DEBUG
    /// Says which commit this binary came from, once, at launch.
    ///
    /// **A screenshot carries no provenance and a scroll position is not a
    /// signature.** Two reports compared a `simctl` launch against an XCUITest
    /// run as though one binary produced both, when they were built by two
    /// schemes into two derived-data trees, and nothing in either picture could
    /// have shown the difference. This line can. The stamp is written into the
    /// built bundle by a script phase, so a Release build carries no such key
    /// and this code is not compiled into one anyway.
    init() {
        // Its own file, not an Info.plist key: the plist is regenerated late in
        // an incremental build and silently loses anything a script phase added.
        let stamp = Bundle.main.url(forResource: "BuildStamp", withExtension: "txt")
            .flatMap { try? String(contentsOf: $0, encoding: .utf8) }
        print("PEACH BUILD \(stamp ?? "unstamped")")
    }
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
