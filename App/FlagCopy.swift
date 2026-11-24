import Foundation
import PeachEngine

/// The flag's words: the wording pass in "Flagging Words From The Cards", with
/// Antoine's lines (21, 22 and 23 November), the same as the web's
/// `src/flags/model.ts`.
///
/// **Nothing here names anyone.** The game's own screens never say who reads a
/// flag; the support page does.
///
/// A basket word's grade is the container's own word, from `Vocabulary`, so it
/// changes with it. The rungs are named as the game shows them.
enum FlagCopy {
    // MARK: The card's flag

    static let flagLabel = "Flag this word"
    static let flagHint = "Report a problem with this word"

    // MARK: The picker

    static func pickerTitle(_ word: String) -> String { "Flag “\(word)”" }

    static func heading(_ kind: FlagGroup.Kind) -> String {
        switch kind {
        case .takeItOut: "Take it out"
        case .fixItsCard: "Fix its card"
        case .itsGrade: "Its grade"
        }
    }

    static func choice(_ reason: FlagReason, card: FlagCard, grade: Rung?) -> String {
        switch reason {
        case .notAWord: "It's not a real word"
        case .offensive: "It's offensive"
        case .shouldCount: "It should count"
        case .definition:
            switch card {
            case .peach: "The definition or origin is wrong"
            case .noDefinition: "It needs a definition"
            case .definition: "The definition is wrong"
            }
        case .rarer:
            switch grade {
            case .set, nil: "It's rarer than a \(Vocabulary.container) word"
            case .some(let rung): "It's rarer than \(rungName(rung))"
            }
        case .moreCommon:
            "It's more common than \(rungName(grade == nil || grade == .set ? .uncommon : grade!))"
        }
    }

    /// The rarity rungs by the names the game shows. A basket word has none of
    /// these; it's asked of only for "rarer".
    private static func rungName(_ rung: Rung) -> String {
        switch rung {
        case .set, .uncommon: "Uncommon"
        case .rare: "Rare"
        case .mythic: "Mythic"
        }
    }

    /// A summary: the platform, the version and the flag's random ID go too,
    /// and the privacy page lists everything.
    static let pickerNote = "Sends the word, its day and your reason. Nothing about you."
    static let cancel = "Cancel"

    // MARK: A flagged card

    /// The same reason, in a line about a flag already made.
    static func shortForm(_ reason: FlagReason) -> String {
        switch reason {
        case .notAWord: "not a real word"
        case .offensive: "offensive"
        case .definition: "its definition"
        case .shouldCount: "suggested"
        case .rarer: "rarer"
        case .moreCommon: "more common"
        }
    }

    /// The card's line once flagged, without its glyph, which is decorative.
    static func cardLine(_ reasons: [FlagReason], waiting: Bool) -> String {
        "You flagged this: \(reasons.map(shortForm).joined(separator: ", ")). "
            + (waiting ? "Waiting to send." : "Sent.")
    }

    /// What VoiceOver says once a flag is made: "Flagged.", then its state.
    static func spoken(sent: Bool) -> String {
        "Flagged. " + (sent ? "Sent." : "Waiting to send.")
    }

    // MARK: Your flags

    static let yourFlags = "Your flags"

    static func state(_ state: DeviceFlag.State) -> String {
        switch state {
        case .sent: "Sent"
        case .waiting: "Waiting to send"
        }
    }

    static func row(word: String, reason: FlagReason) -> String {
        "\(word), \(shortForm(reason))"
    }

    static let takeBack = "Take back"
    static let listNote = "Flags send right away, or once you're back online. "
        + "You can take one back for 60 days."
    static let full = "\(FlagStore.maxWaiting) flags are waiting to send. They'll go once you're online."

    // MARK: The refused word

    /// The flag over the well's trailing edge, on "Not in the word list." only.
    static let suggestLabel = "Suggest this word"

    /// The popup, the system's alert: it asks first, so only its Suggest
    /// sends anything (Antoine, 21 November).
    static func suggestQuestion(_ word: String) -> String { "Suggest “\(word)” for the dictionary?" }
    static let suggestCancel = "Cancel"
    static let suggestSend = "Suggest"

    /// The line that takes the refusal's place once the word is suggested.
    /// "Sent" only once the server has it; one line for every other case,
    /// offline or not, since "when you're online" would be false with the
    /// server busy or switched off (Antoine, 23 November).
    static func suggestedLine(sent: Bool) -> String {
        sent ? "✓ Suggestion sent." : "✓ Suggestion saved. It'll send later."
    }

    /// What VoiceOver hears: "Suggested.", then the state, as a card's flag says it.
    static func suggestedSpoken(sent: Bool) -> String {
        sent ? "Suggested. Sent." : "Suggested. Waiting to send."
    }
}
