import Foundation

/// When the title screen appears: each new day's first open, and the first
/// launch after installing. Within a day the app opens on the board.
///
/// **The day it last appeared is kept in `UserDefaults`,** as a storage day
/// index, the same count progress and the streak are keyed on, so `-dayOffset`
/// moves it with everything else. No key at all is a first launch, which on a
/// phone updating into this build is also a new day, so the two rules agree.
/// The privacy manifest already declares `UserDefaults` (`CA92.1`), and the
/// privacy page names no keys for the app, only "your settings".
///
/// A new day's first open is a cold launch on a new day, or a resume across
/// midnight, where `rollOverIfNewDay` swaps the board under a foregrounding
/// app. A past board left open across midnight is exempt from that swap, and
/// the title still appears over it: it is still the new day's first open, and
/// Play goes to today.
enum TitleSchedule {
    static let lastShownKey = "titleLastShownDay"

    /// Whether the title is due today, recording that it has been shown when
    /// it is. Asked at launch and on every return to the foreground.
    static func claim(today: Int, defaults: UserDefaults = .standard) -> Bool {
        #if DEBUG
        if skipsThisProcess {
            defaults.set(today, forKey: lastShownKey)
            return false
        }
        #endif
        guard defaults.object(forKey: lastShownKey) as? Int != today else { return false }
        defaults.set(today, forKey: lastShownKey)
        return true
    }

    #if DEBUG
    /// **Any seed and `-resetProgress` start on the board,** as every UI test
    /// written before the title expects; `-showTitle 1` opts back in. For the
    /// whole process, and today is recorded as shown, so a test that relaunches
    /// without its seeds still lands on the board that day.
    static let skipsThisProcess: Bool = {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: "showTitle") { return false }
        return defaults.bool(forKey: "resetProgress")
            || ["seedArchive", "seedBoard"].contains { defaults.string(forKey: $0) != nil }
    }()

    /// The keys a fresh install would not have, cleared by `-resetProgress`
    /// before anything reads them, so a launch that starts from a phone that
    /// has never been played really does. `GameStorage.eraseAll` covers the
    /// game's own store and not these.
    static func resetForFreshInstall(defaults: UserDefaults = .standard) {
        guard defaults.bool(forKey: "resetProgress") else { return }
        for key in [lastShownKey] { defaults.removeObject(forKey: key) }
    }
    #endif
}
