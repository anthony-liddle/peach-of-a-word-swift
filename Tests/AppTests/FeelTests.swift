import Foundation
import Testing
import UIKit

/// The Vibration switch: off, none of `Feel`'s functions plays anything.
///
/// A stand-in takes the place of the feedback generators and of
/// `Haptics.shared`'s patterns, and lists what each function asked it for. A
/// simulator has no haptics hardware, so what a device would feel can't be
/// read here, but what the game hands over can.
///
/// **Both paths of each function,** since four of them play a pattern and fall
/// back to the generators when the pattern can't play: once with the stand-in's
/// patterns playing, once with them failing, so the fallback is held too.
///
/// **And a control:** with the switch on, every function asks for something.
/// Without it, a stand-in that nothing ever reached would pass the switch-off
/// test on nothing.
@MainActor
@Suite("the vibration switch", .serialized)
struct FeelTests {
    /// Every function in `Feel` that plays something, by name.
    static let functions: [(name: String, play: @MainActor () -> Void)] = [
        ("tilePress", Feel.tilePress),
        ("find", Feel.find),
        ("refuse", Feel.refuse),
        ("reject", Feel.reject),
        ("sourceWord", Feel.sourceWord),
        ("completion", Feel.completion),
        ("runTen", Feel.runTen),
        ("runEnd", Feel.runEnd),
    ]

    /// Lists what it's asked to play, and plays nothing.
    final class StandIn: HapticPlayer {
        var asked: [String] = []
        /// Whether a pattern plays, or fails so the caller falls back.
        var patternsPlay: Bool

        init(patternsPlay: Bool) { self.patternsPlay = patternsPlay }

        func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle, intensity: CGFloat?) {
            asked.append("impact")
        }

        func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
            asked.append("notify")
        }

        func play(_ pattern: Haptics.Pattern) -> Bool {
            asked.append("pattern")
            return patternsPlay
        }
    }

    /// What one function asked for, with the switch as given (nil for a phone
    /// that has never written it) and the stand-in in place. Both are put
    /// back after.
    private func asked(by play: @MainActor () -> Void, switchOn: Bool?,
                       patternsPlay: Bool) -> [String] {
        let defaults = UserDefaults.standard
        let before = defaults.object(forKey: VibrationSetting.key)
        let player = Feel.player
        defer {
            Feel.player = player
            if let before { defaults.set(before, forKey: VibrationSetting.key) }
            else { defaults.removeObject(forKey: VibrationSetting.key) }
        }
        if let switchOn { defaults.set(switchOn, forKey: VibrationSetting.key) }
        else { defaults.removeObject(forKey: VibrationSetting.key) }
        let standIn = StandIn(patternsPlay: patternsPlay)
        Feel.player = standIn
        play()
        return standIn.asked
    }

    @Test("off, none of Feel's functions plays anything", arguments: [true, false])
    func offPlaysNothing(patternsPlay: Bool) {
        for function in Self.functions {
            #expect(asked(by: function.play, switchOn: false, patternsPlay: patternsPlay) == [],
                    "\(function.name) played with Vibration off")
        }
    }

    @Test("on, every one of Feel's functions plays", arguments: [true, false])
    func onPlaysEach(patternsPlay: Bool) {
        for function in Self.functions {
            #expect(!asked(by: function.play, switchOn: true, patternsPlay: patternsPlay).isEmpty,
                    "\(function.name) played nothing with Vibration on")
        }
    }

    /// Absent means on, as Sound's does: a phone updating into this build has
    /// never written the key, and must keep its haptics.
    @Test("on for a phone that has never set it")
    func onByDefault() {
        for function in Self.functions {
            #expect(!asked(by: function.play, switchOn: nil, patternsPlay: true).isEmpty,
                    "\(function.name) played nothing on a phone that never set the switch")
        }
    }
}
