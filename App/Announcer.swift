import SwiftUI
import UIKit

/// What the game says to VoiceOver, one line at a time: a find's line, a
/// refusal, and a run's start, pause, time calls and end.
///
/// **Every line goes at high priority,** which Apple's header gives as
/// "cannot be interrupted once started". At default priority a line is
/// "interruptible if a new speech utterance is started", and after Pick word
/// one always is: Pick word clears the well, so the button VoiceOver is on
/// turns dimmed in the same update, and VoiceOver says so over the line. On a
/// phone, "dimmed" was all VoiceOver said after Pick word, on the board and
/// in a run, while the run's time calls, already at high priority, were heard
/// (Antoine, 26 November).
///
/// **And one at a time.** Two high-priority lines at once have no documented
/// outcome, so while VoiceOver is on, a line waits until VoiceOver says the
/// one before it is finished (`announcementDidFinishNotification`), or until
/// that one's deadline if it never does. A time call waits ahead of the lines
/// still waiting, never in front of the one being said, so "10 seconds left."
/// isn't held behind a find that landed first.
///
/// With VoiceOver off there's nobody to wait for, and each line goes as it
/// comes.
@MainActor
final class Announcer {
    private var waiting: [(text: String, urgent: Bool)] = []
    /// The line VoiceOver is saying, until it says it's done.
    private var saying: String?
    private var deadline: Task<Void, Never>?

    init() {
        // For the app's life: the model holds the one announcer.
        NotificationCenter.default.addObserver(
            forName: UIAccessibility.announcementDidFinishNotification, object: nil, queue: .main
        ) { [weak self] note in
            let value = note.userInfo?[UIAccessibility.announcementStringValueUserInfoKey]
            let text = (value as? String) ?? (value as? NSAttributedString)?.string
            MainActor.assumeIsolated { self?.finished(text) }
        }
    }

    /// Say `text` once the line before it is done. `urgent`, for the run's
    /// time calls, goes ahead of whatever is still waiting.
    func say(_ text: String, urgent: Bool = false) {
        if urgent {
            let behind = waiting.firstIndex { !$0.urgent } ?? waiting.endIndex
            waiting.insert((text, true), at: behind)
        } else {
            waiting.append((text, false))
        }
        sayNext()
    }

    private func sayNext() {
        while saying == nil, !waiting.isEmpty {
            let text = waiting.removeFirst().text
            var spoken = AttributedString(text)
            spoken.accessibilitySpeechAnnouncementPriority = .high
            AccessibilityNotification.Announcement(spoken).post()
            #if DEBUG
            SpeechLog.shared.posted(spoken)
            #endif
            guard Self.voiceOverOn else { continue }
            saying = text
            deadline = Task { [weak self] in
                try? await Task.sleep(for: .seconds(Self.longest(text)))
                guard !Task.isCancelled else { return }
                self?.finished(text)
            }
        }
    }

    /// VoiceOver is done with `text`. One that comes without its line counts
    /// for the one being said, since VoiceOver says one at a time.
    ///
    /// The next line goes on the main actor's next turn, not inside the
    /// notification, so everything else listening sees this one finish before
    /// the next is posted. Inside it, `SpeechLog` listed the next line ahead
    /// of this one's "done", which read as two lines at once.
    private func finished(_ text: String?) {
        guard let saying, text == nil || text == saying else { return }
        deadline?.cancel()
        self.saying = nil
        Task { [weak self] in self?.sayNext() }
    }

    /// How long a line is waited on if VoiceOver never says it's done: a
    /// second for every six characters, at least 6 seconds and at most 12.
    /// Only a net, since VoiceOver reports each line, and generous, because
    /// giving up while a slow voice is still speaking hands it a second line
    /// mid-sentence. It also sits above `-fakeSpeech 5`, the collision test's
    /// stand-in, so that test is answered by the finish report, not the net.
    private static func longest(_ text: String) -> Double {
        min(12, max(6, Double(text.count) / 6))
    }

    private static var voiceOverOn: Bool {
        #if DEBUG
        if SpeechLog.fakeSeconds > 0 { return true }
        #endif
        return UIAccessibility.isVoiceOverRunning
    }
}
