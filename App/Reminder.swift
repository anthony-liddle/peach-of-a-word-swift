import Foundation
import Observation
import PeachEngine
import SwiftUI
import UserNotifications

/// The daily reminder: a local notification at a time the player picks, off
/// until they turn it on in Settings.
///
/// **On a day with no words, and only then.** `ReminderSchedule` lays out a
/// fortnight of single notifications and leaves out every day already played,
/// so this asks for the schedule again whenever it could have changed: on
/// every open (`refresh`, from `ContentView`'s return to the foreground, which
/// runs after the day's rollover), when the clock or the zone changes or the
/// day turns over while the game is open (`significantTimeChangeNotification`),
/// when the switch or the time changes, and at the day's first find.
///
/// **Nothing leaves the phone.** It is scheduled on the phone, by the phone,
/// with no server and no push token, so "Data Not Collected" stays true. The
/// switch and the time are two `UserDefaults` keys, which the privacy manifest
/// already declares (`CA92.1`).
@MainActor @Observable
final class Reminder {
    static let shared = Reminder()

    nonisolated static let onKey = "reminderOn"
    nonisolated static let minutesKey = "reminderMinutes"
    /// Every request this schedules starts with this, so a tap on one can be
    /// told from anything else iOS hands over.
    nonisolated static let prefix = "daily-reminder-"

    /// The switch. Off until the player turns it on.
    private(set) var isOn: Bool
    /// The time, in minutes after midnight on the phone's clock.
    private(set) var minutes: Int
    /// iOS has notifications off for the game, so the switch cannot stay on:
    /// Settings says where to change it.
    private(set) var refused = false
    /// Raised by a tap on a reminder, cold or warm, and lowered by
    /// `ContentView` once the title is up.
    var titleRequested = false

    /// Whether a storage day has words. `ContentView` points this at the store
    /// before anything schedules.
    var played: (Int) -> Bool = { _ in false }

    #if DEBUG
    /// What was last handed to iOS, so `-exposeReminder 1` can show a test.
    private(set) var handedOver: [DateComponents] = []
    #endif

    private let gate: NotificationGate

    private init(defaults: UserDefaults = .standard) {
        isOn = defaults.bool(forKey: Self.onKey)
        // `integer(forKey:)`, not `as? Int`: a launch argument arrives as a
        // string, which the cast would drop for the default without a word.
        minutes = defaults.object(forKey: Self.minutesKey) == nil
            ? ReminderSchedule.defaultMinutes : defaults.integer(forKey: Self.minutesKey)
        #if DEBUG
        if let answer = defaults.string(forKey: AnswerGate.argument) {
            gate = AnswerGate(granted: answer == "granted")
            return
        }
        #endif
        gate = SystemGate()
    }

    /// The switch, turned. On asks iOS first, and a refusal turns it back off.
    func switched(on: Bool) {
        setOn(on)
        refused = false
        guard on else {
            reschedule()
            return
        }
        Task { await askAndSchedule() }
    }

    /// The time, changed.
    func timeChanged(to minutes: Int) {
        self.minutes = minutes
        UserDefaults.standard.set(minutes, forKey: Self.minutesKey)
        reschedule()
    }

    /// On every open: what iOS says now, then the schedule. If notifications
    /// were turned off in iOS's own Settings, the switch goes off too: a switch
    /// left on would promise a reminder that cannot come.
    func refresh() async {
        let status = await gate.status()
        if Self.allows(status) {
            refused = false
        } else if status == .denied {
            refused = true
            if isOn { setOn(false) }
        }
        reschedule()
    }

    /// Replace every pending reminder with the fortnight from now.
    ///
    /// **All of them:** the game schedules nothing else, so clearing every
    /// pending request is clearing its own. Synchronous, with no wait in
    /// the middle, so two calls close together cannot interleave a removal
    /// with the other's additions. The same day keeps the same identifier, so
    /// a request added twice is one request.
    ///
    /// Delivered ones go too: the game has been opened, which is all a
    /// reminder sitting in Notification Center was asking for.
    func reschedule() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
        let dates = isOn && !refused
            ? ReminderSchedule.fireDates(now: GameModel.now, minutes: minutes,
                                         calendar: .current, played: played)
            : []
        #if DEBUG
        handedOver = dates
        #endif
        for date in dates {
            let content = UNMutableNotificationContent()
            content.body = Vocabulary.reminderBody
            content.sound = .default
            content.threadIdentifier = "daily-reminder"
            let request = UNNotificationRequest(
                identifier: Self.prefix + Self.stamp(date),
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: date, repeats: false))
            center.add(request)
        }
    }

    /// A tap on a notification. A reminder's lands on the title.
    func opened(identifier: String) {
        guard identifier.hasPrefix(Self.prefix) else { return }
        titleRequested = true
    }

    private func askAndSchedule() async {
        var status = await gate.status()
        if status == .notDetermined {
            status = await gate.request() ? .authorized : .denied
        }
        // Turned off again while iOS was asking: that answer is the last word.
        guard isOn else { return }
        if !Self.allows(status) {
            setOn(false)
            refused = true
            AccessibilityNotification.Announcement(Vocabulary.reminderRefused).post()
        }
        reschedule()
    }

    private func setOn(_ on: Bool) {
        isOn = on
        UserDefaults.standard.set(on, forKey: Self.onKey)
    }

    private static func allows(_ status: UNAuthorizationStatus) -> Bool {
        status == .authorized || status == .provisional || status == .ephemeral
    }

    /// `2026-10-23 19:00`, the request's name and the probe's line.
    static func stamp(_ date: DateComponents) -> String {
        String(format: "%04d-%02d-%02d %02d:%02d", date.year ?? 0, date.month ?? 0,
               date.day ?? 0, date.hour ?? 0, date.minute ?? 0)
    }

    #if DEBUG
    /// The keys a fresh install would not have. See `TitleSchedule`.
    nonisolated static let freshInstallKeys = [onKey, minutesKey, AnswerGate.statusKey]
    #endif
}

/// What the reminder needs from iOS's notification permission, so a Debug
/// build can stand in for the system's alert, which a UI test cannot answer.
private protocol NotificationGate: Sendable {
    func status() async -> UNAuthorizationStatus
    func request() async -> Bool
}

private struct SystemGate: NotificationGate {
    func status() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    func request() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }
}

#if DEBUG
/// `-notificationAnswer granted` or `denied`: the answer iOS's alert would
/// have been given, remembered across launches the way iOS remembers it, and
/// forgotten by `-resetProgress` the way a fresh install forgets it.
private struct AnswerGate: NotificationGate {
    static let argument = "notificationAnswer"
    static let statusKey = "debugNotificationStatus"
    let granted: Bool

    func status() async -> UNAuthorizationStatus {
        guard let raw = UserDefaults.standard.object(forKey: Self.statusKey) as? Int else {
            return .notDetermined
        }
        return UNAuthorizationStatus(rawValue: raw) ?? .notDetermined
    }

    func request() async -> Bool {
        let answer: UNAuthorizationStatus = granted ? .authorized : .denied
        UserDefaults.standard.set(answer.rawValue, forKey: Self.statusKey)
        return granted
    }
}
#endif

/// The app's delegate, for the one thing SwiftUI's lifecycle cannot do: be the
/// notification center's delegate from the first moment of a launch.
///
/// **Set in `didFinishLaunching`,** because a tap on a reminder that launches
/// the game hands its response over once, early, before any view exists. A
/// delegate set from a view's `onAppear` would miss it. The tap raises
/// `Reminder.titleRequested`, which `ContentView` answers with the title.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil)
        -> Bool {
        UNUserNotificationCenter.current().delegate = self
        #if DEBUG
        // Before anything reads the reminder's keys, which a hook below does
        // ahead of `ContentView`'s own call.
        TitleSchedule.resetForFreshInstall()
        // `-reminderTapped 1` answers as a tap that launched the game would,
        // here, before any view; `-reminderTappedAfter N` as a tap N seconds in,
        // with the game open. Both through `opened`, as a real tap.
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: "reminderTapped") {
            Reminder.shared.opened(identifier: Reminder.prefix + "debug")
        }
        let after = defaults.double(forKey: "reminderTappedAfter")
        if after > 0 {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(after))
                Reminder.shared.opened(identifier: Reminder.prefix + "debug")
            }
        }
        #endif
        return true
    }

    /// With the game open, a reminder has nothing to say: show nothing.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([])
    }

    /// A tap on a notification, handed to `Reminder.opened` on the main thread.
    ///
    /// **The completion-handler form, not the `async` one Swift offers.** The
    /// `async` form, `nonisolated`, returned on a cooperative thread, and Swift
    /// called iOS's completion handler from there. UIKit asserts that handler
    /// runs on the main thread, so a reminder tapped from cold aborted the
    /// launch it had started: SIGABRT in
    /// `_updateSnapshotAndStateRestorationWithAction`, on 23 October 2026, from
    /// `ReminderEndToEnd`. The Debug hooks call `opened` directly and could
    /// never have seen it.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let identifier = response.notification.request.identifier
        // iOS's block, carried to the main queue and called only there.
        nonisolated(unsafe) let done = completionHandler
        DispatchQueue.main.async {
            MainActor.assumeIsolated { Reminder.shared.opened(identifier: identifier) }
            done()
        }
    }
}
