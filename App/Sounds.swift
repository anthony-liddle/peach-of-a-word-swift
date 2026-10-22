import Foundation
import PeachEngine
import SoundscapePlayer

/// The game's sounds: the web's cue file, played by Soundscape's cue player.
///
/// **Which cue a moment plays is decided in the engine**, `Cue` and
/// `cue(for:completesBasket:)`, with the web's precedence. This only plays it.
/// `GameModel` calls it beside each haptic: `tick` as a tile lands, a find's
/// cue where its beat is chosen, `invalid` beside a rejection's.
///
/// **On by default, and a mute is remembered** (`SoundSetting`, D5). The player
/// puts the audio session in the `.ambient` category, so the Ring/Silent switch
/// silences the cues too, and other apps' music keeps playing under them.
///
/// **Off spends nothing.** No cue reaches the player (`GameModel.sound`), the
/// engine is stopped when the switch is turned off, and a launch with sound off
/// renders no cues until the switch is turned on. A find in the first moment
/// after turning it on is silent while the cues render, as a find in the first
/// moment after launch always has been.
///
/// **The app writes no AVFoundation callback.** In Swift 6 a closure written
/// inside a main-actor method is main-actor isolated, and the sound spike's
/// mixer tap trapped at runtime when the audio thread called one. The player's
/// own callbacks are its business, and `onEvent`, the one it offers, is called
/// on the main actor. Anything that taps the engine from here would have to be
/// made outside main-actor code.
@MainActor
final class Sounds {
    private let player = CuePlayer()

    /// Whether the cues are rendered, or being rendered, so the switch going
    /// on and off again does not render them twice.
    private var loadStarted = false

    /// Read the cue file and render every cue, at the output's own rate.
    ///
    /// Called at launch beside the word lists, and not awaited by them: the
    /// board does not wait for its sounds. The file is read off the main
    /// thread, and the player renders off it too. What runs on the main actor
    /// is the player building its engine and setting the session's category.
    /// Only when sound is on; otherwise when the switch is turned on.
    func load() async {
        guard !loadStarted else { return }
        loadStarted = true
        guard let text = await Self.readCueFile() else { return }
        // Throws only for a document the validator refuses, or an output the
        // player cannot build. Either way the game plays on in silence: a
        // sound is not worth a failed launch, and CueFileTests and
        // `update-cues.sh --check` stand between a bad file and a build.
        try? await player.load(parsing: text)
    }

    /// The switch, turned. Off stops the engine now, and a later cue would
    /// start it again, but none comes while it is off. On renders the cues if
    /// they never were.
    func setOn(_ on: Bool) {
        if on {
            Task { await load() }
        } else {
            player.stop()
        }
    }

    /// Play a cue now.
    ///
    /// **Before the cues have loaded, nothing plays.** The player throws
    /// `notLoaded` at once and queues nothing, so a find in the first moments
    /// after launch is silent rather than late.
    func play(_ cue: Cue) {
        do {
            try player.play(cue.name)
        } catch CuePlayerError.notLoaded {
            // Still loading, or the file never loaded: silent by design.
        } catch {
            // A name the file lacks, or an engine that cannot start, as during
            // a phone call. Neither is worth interrupting a game for. The
            // first is what CueFileTests exists to make impossible.
            #if DEBUG
            print("[Sounds] \(cue.name) did not play: \(error)")
            #endif
        }
    }

    nonisolated private static func readCueFile() async -> String? {
        await Task.detached(priority: .userInitiated) {
            guard let data = try? GameModel.bundledDataDirectory() else { return nil }
            return try? String(contentsOf: data.appendingPathComponent("peach.cues.json"),
                               encoding: .utf8)
        }.value
    }
}

/// The sound switch: on by default, and a mute remembered (D5).
///
/// **Absent means on.** `bool(forKey:)` reads false for a key never written,
/// which would have muted every phone that updated into this build, Bea's
/// included. So the key is read as set or not first.
enum SoundSetting {
    static let key = "soundOn"

    static var isOn: Bool {
        let defaults = UserDefaults.standard
        return defaults.object(forKey: key) == nil ? true : defaults.bool(forKey: key)
    }
}
