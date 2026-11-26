import Foundation
import Testing
import UIKit

/// The order the game's lines are handed to VoiceOver (`Announcer`): one at a
/// time, and a time call ahead of the lines still waiting, never over the one
/// being said.
///
/// There's no VoiceOver here, so `-fakeSpeech` stands in for it being on: a
/// long one, so no line reports itself finished, and each test says when
/// VoiceOver is done with a line by posting the notification VoiceOver sends.
/// What was handed over is read off `SpeechLog`, the Debug log the UI tests
/// read. The UI tests (`PeachRush`) hold the same order in a run, where the
/// clock decides when a line lands; here the test does.
@MainActor
@Suite("what VoiceOver is handed, in order", .serialized)
final class AnnouncerTests {
    private let voice: Announcer
    private let start: Int

    init() {
        UserDefaults.standard.set(600.0, forKey: "fakeSpeech")
        voice = Announcer()
        start = SpeechLog.shared.lines.count
    }

    deinit { UserDefaults.standard.removeObject(forKey: "fakeSpeech") }

    /// What was handed over and reported finished since the test began.
    private var said: [String] { Array(SpeechLog.shared.lines.dropFirst(start)) }

    /// VoiceOver is done with `text`, or with whatever it was saying when
    /// `text` is nil. The next line goes on the main actor's next turn.
    private func finish(_ text: String?) async {
        var info: [AnyHashable: Any] = [UIAccessibility.announcementWasSuccessfulUserInfoKey: true]
        if let text { info[UIAccessibility.announcementStringValueUserInfoKey] = text }
        NotificationCenter.default.post(
            name: UIAccessibility.announcementDidFinishNotification, object: nil, userInfo: info)
        try? await Task.sleep(for: .milliseconds(100))
    }

    @Test func aTimeCallGoesAheadOfAWaitingFindButNeverOverTheLineBeingSaid() async {
        voice.say("Started. 1 minute 30 seconds on the clock.")
        voice.say("Mythic find: tel, 5 points.")
        voice.say("10 seconds left.", urgent: true)
        #expect(said == ["high: Started. 1 minute 30 seconds on the clock."])

        await finish("Started. 1 minute 30 seconds on the clock.")
        #expect(said.suffix(2) == ["done: Started. 1 minute 30 seconds on the clock.",
                                   "high: 10 seconds left."])

        await finish("10 seconds left.")
        #expect(said.suffix(2) == ["done: 10 seconds left.", "high: Mythic find: tel, 5 points."])
    }

    @Test func aLineWaitsForTheOneBeingSaidAndNotForAnotherLinesFinish() async {
        voice.say("Mythic find: tel, 5 points.")
        voice.say("Not in the word list.")
        await finish("Already found.")
        #expect(said == ["high: Mythic find: tel, 5 points.", "done: Already found."])

        await finish("Mythic find: tel, 5 points.")
        #expect(said.last == "high: Not in the word list.")
    }

    @Test func aFinishThatDoesntNameItsLineCountsForTheOneBeingSaid() async {
        voice.say("Mythic find: tel, 5 points.")
        voice.say("Already found.")
        await finish(nil)
        #expect(said.last == "high: Already found.")
    }

    @Test func withVoiceOverOffEachLineGoesAsItComes() {
        UserDefaults.standard.removeObject(forKey: "fakeSpeech")
        voice.say("Started. 1 minute 30 seconds on the clock.")
        voice.say("Mythic find: tel, 5 points.")
        voice.say("10 seconds left.", urgent: true)
        #expect(said == ["high: Started. 1 minute 30 seconds on the clock.",
                         "high: Mythic find: tel, 5 points.",
                         "high: 10 seconds left."])
    }
}
