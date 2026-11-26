#if DEBUG
import SwiftUI
import UIKit

/// `-exposeSpeech 1`: every line the game handed VoiceOver, with the priority
/// it carried, and every line VoiceOver reported finished, oldest first, as
/// "high: Not in the word list." and "done: Not in the word list.".
///
/// **Handed over and reported, not heard.** The simulator has no VoiceOver,
/// so a test can hold the game to what it posts and when, and only a phone
/// can say what was spoken. The priority is read off the very value posted.
///
/// **`-fakeSpeech 3` stands in for VoiceOver's timing:** each line reports
/// itself finished 3 seconds after it was posted, through the notification
/// VoiceOver sends, `announcementDidFinishNotification`, so a test can see
/// whether a line was posted while another was still being said.
@MainActor @Observable
final class SpeechLog {
    static let shared = SpeechLog()

    private(set) var lines: [String] = []

    /// How long a faked line takes to say, in seconds; 0 when not faking.
    static var fakeSeconds: Double { UserDefaults.standard.double(forKey: "fakeSpeech") }

    private init() {
        NotificationCenter.default.addObserver(
            forName: UIAccessibility.announcementDidFinishNotification, object: nil, queue: .main
        ) { note in
            let text = note.userInfo?[UIAccessibility.announcementStringValueUserInfoKey] as? String
            MainActor.assumeIsolated { Self.shared.lines.append("done: \(text ?? "")") }
        }
    }

    /// One line, as it goes to VoiceOver.
    func posted(_ spoken: AttributedString) {
        let text = String(spoken.characters)
        let priority = switch spoken.accessibilitySpeechAnnouncementPriority {
        case .high: "high"
        case .low: "low"
        default: "default"
        }
        lines.append("\(priority): \(text)")
        let seconds = Self.fakeSeconds
        guard seconds > 0 else { return }
        Task {
            try? await Task.sleep(for: .seconds(seconds))
            NotificationCenter.default.post(
                name: UIAccessibility.announcementDidFinishNotification, object: nil,
                userInfo: [UIAccessibility.announcementStringValueUserInfoKey: text,
                           UIAccessibility.announcementWasSuccessfulUserInfoKey: true])
        }
    }
}
#endif
