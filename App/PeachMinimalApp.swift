import PeachEngine
import SwiftUI

/// The entry point.
///
/// `@main` on a type conforming to `App` replaces the AppDelegate lifecycle.
/// There is no main.swift, no UIApplicationMain, and no storyboard. The whole
/// app is this struct plus whatever view it returns, and one small delegate
/// adapted in for the reminder's taps, which only a delegate hears in time.
@main
struct PeachMinimalApp: App {
    /// Only so a tap on the daily reminder is heard from the first moment of a
    /// launch. See `AppDelegate`.
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

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

        // **Every seed and `-resetProgress` start from a phone that has never
        // been played**, so what a test sees cannot depend on what ran before
        // it (#73). Here, once a process, before any view: the title draws from
        // the store at once, and when this ran in the load path, after the
        // word lists, a reset launch's title drew the last test's stage, streak
        // and week first.
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: "resetProgress") || defaults.string(forKey: "seedArchive") != nil {
            GameStorage.appDefault.seeding.eraseAll()
        }
    }
    #endif

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            // `-costumeGallery 1`: every costume at every size, in place of the
            // game. See `CostumeGallery`.
            if UserDefaults.standard.bool(forKey: "costumeGallery") {
                CostumeGallery()
            } else {
                ContentView()
            }
            #else
            ContentView()
            #endif
        }
    }
}
