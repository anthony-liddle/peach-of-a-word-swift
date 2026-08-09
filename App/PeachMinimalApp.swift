import SwiftUI

/// The entry point.
///
/// `@main` on a type conforming to `App` replaces the AppDelegate lifecycle
/// entirely. There is no main.swift, no UIApplicationMain, and no storyboard.
/// The whole app is this struct plus whatever view it returns.
@main
struct PeachMinimalApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
