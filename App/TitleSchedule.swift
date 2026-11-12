import Foundation

/// When the title screen appears: each new day's first open, the first launch
/// after installing, and a launch the same day after she left the app on the
/// title. Otherwise, within a day, the app opens on the board, the one she was
/// on: a past day too (see `GameModel.load`).
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

    /// The day the title was last left up, kept while it is up and removed
    /// when it steps aside. See `remember(up:today:)`.
    static let leftUpKey = "titleLeftUpDay"

    /// Whether the app opens on the title: due today, or left up earlier
    /// today. Asked once, at launch.
    ///
    /// **The app reopens where she left it** (Antoine, 5 November 2026). #123
    /// brought her back to a past day she was on; closed from the title over
    /// that day, it brought her back to the board too, which she had already
    /// left. The title is a place she leaves the app on like any board, so a
    /// launch the same day finds it again. Under it the board is today's,
    /// since the title is for today.
    static func atLaunch(today: Int, defaults: UserDefaults = .standard) -> Bool {
        if claim(today: today, defaults: defaults) { return true }
        #if DEBUG
        if skipsThisProcess { return false }
        #endif
        return defaults.object(forKey: leftUpKey) as? Int == today
    }

    /// Remember whether the title is up, each time that changes, so a launch
    /// later today reopens on it. Written on every change rather than on the
    /// way to the background, since a swipe from the app switcher ends the app
    /// without a word.
    static func remember(up: Bool, today: Int, defaults: UserDefaults = .standard) {
        if up {
            defaults.set(today, forKey: leftUpKey)
        } else {
            defaults.removeObject(forKey: leftUpKey)
        }
    }

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
    /// without its seeds still lands on the board that day, unless it left
    /// the title up: then, like any launch, it reopens there.
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
        for key in [lastShownKey, leftUpKey, SoundSetting.key, HowToPlayFirstRun.key, AppearanceSetting.key]
            + Reminder.freshInstallKeys {
            defaults.removeObject(forKey: key)
        }
    }
    #endif
}
