/// A sound the game can ask for, named as the cue file names it.
///
/// The cue file is `Data/peach.cues.json`, the web game's own, pinned by commit
/// and hash in `tools/update-cues.sh`. Its 34 names are the web's
/// (`SoundscapeAudioEngine.ts`), and this is the half of them the app can play:
/// 28, every one but the six `found-<length>-mythic-letterpress`, since cute is
/// the only theme this app has. `CueFileTests` holds the two to each other.
///
/// The names live here, in the engine, so a test can reach every one without
/// the app and without the player; only the app plays them.
public enum Cue: Hashable, Sendable {
    /// A tile placed.
    case tick
    /// A word found that is neither the source word nor the one completing
    /// the basket.
    case found(length: Int, rung: Rung)
    /// The source word.
    case source
    /// Completion: the find that fills the basket.
    case edition
    /// A rejection, any of the three.
    case invalid

    /// The lengths the file has a found cue for. A find outside them plays the
    /// nearest, as the web holds it (`playFound`), though a rack of eight
    /// letters and a three-letter floor mean none ever falls outside.
    public static let foundLengths = 3...8

    /// The cue's name in the file.
    ///
    /// A mythic find plays the cute theme's, a fifth note "a glint at five
    /// times its pitch". The web picks between `-cute` and `-letterpress` by
    /// the theme on screen; if letterpress ever reaches this app, the theme
    /// picks here too.
    public var name: String {
        switch self {
        case .tick: "tick"
        case .source: "source"
        case .edition: "edition"
        case .invalid: "invalid"
        case .found(let length, .mythic): "found-\(Self.held(length))-mythic-cute"
        case .found(let length, let rung): "found-\(Self.held(length))-\(rung.rawValue)"
        }
    }

    private static func held(_ length: Int) -> Int {
        min(max(length, foundLengths.lowerBound), foundLengths.upperBound)
    }
}

/// The one cue a submit plays, with the web's precedence (`useGame.ts`
/// `submit`): any rejection plays `invalid`; a find that completes the basket
/// plays `edition`, over the source word's cue and over its own; otherwise the
/// source word plays `source`, and any other find its length and rung.
///
/// **Built on `findBeat`, not beside it,** so the haptic and the sound read one
/// rule and cannot disagree about which beat a find was. `completesBasket` is
/// the same fact the beat takes: whether this find reached the peak, as
/// `resolve()` works it out.
public func cue(for result: GuessResult, completesBasket: Bool) -> Cue {
    switch result {
    case .valid(let word, _, let rung, let isSourceWord):
        switch findBeat(isSourceWord: isSourceWord, completesBasket: completesBasket) {
        case .completion: .edition
        case .sourceWord: .source
        case .find: .found(length: word.count, rung: rung)
        }
    case .tooShort, .notAWord, .alreadyFound:
        .invalid
    }
}
