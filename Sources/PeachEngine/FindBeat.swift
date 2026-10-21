/// What one accepted find is felt as, and from pass 2 heard as.
///
/// **One beat per find.** A find that is both the source word and the last set
/// word used to play the source word's haptic and then completion's, so the two
/// patterns started together. The cards already gave completion precedence,
/// dropping the peach card for the completion card, and so do the web's sounds
/// (`useGame.ts` `submit`): completion, else the source word, else an ordinary
/// find. This is that rule, in one place, so the haptic and the sound cannot
/// disagree about which beat a find was.
public enum FindBeat: String, Sendable, CaseIterable {
    case find
    case sourceWord
    case completion
}

/// The one beat an accepted find plays: completion over the source word over
/// an ordinary find.
///
/// `completesBasket` is whether this find is the one that reached the peak, not
/// whether the board is complete: a find on a board already complete is an
/// ordinary find, as on the web.
public func findBeat(isSourceWord: Bool, completesBasket: Bool) -> FindBeat {
    if completesBasket { return .completion }
    return isSourceWord ? .sourceWord : .find
}
