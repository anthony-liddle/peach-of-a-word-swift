import SwiftUI
import PeachEngine

/// How a found word is displayed. The source word is a set word that also
/// carries its own mark, so the display category splits it out while the score
/// still reads the underlying rung.
enum WordCategory: Hashable {
    case source
    case set
    case uncommon
    case rare
    case mythic

    /// True for an off-page ladder word: shown with inline points, marked by
    /// shape, and never counted in a group's "X of Y".
    var isOffPage: Bool {
        switch self {
        case .source, .set: false
        case .uncommon, .rare, .mythic: true
        }
    }

    /// Spoken name. The mark carries the category visually and is decorative, so
    /// this is the only place a screen reader can learn it.
    var spokenName: String {
        switch self {
        case .source: "source word"
        case .set: "on the page"
        case .uncommon: "Uncommon"
        case .rare: "Rare"
        case .mythic: "Mythic"
        }
    }

    var tint: Color {
        switch self {
        case .source: Cute.crown
        case .set: Cute.accent          // --good, the "in the set" heart
        case .uncommon, .rare, .mythic: Cute.discovery
        }
    }

    /// The colour of the *word*, which is not the colour of its mark.
    ///
    /// The two diverge in both directions and that is deliberate on the web,
    /// which this now mirrors. A set word carries a pink heart and is set in
    /// plain ink, because colouring every set word pink would leave the list
    /// with no quiet default to read against. The source word inverts it: the
    /// mark is the peach and the text is the deeper `crownDeep`, since a fill
    /// that reads well as a shape does not read well as a sentence.
    ///
    /// Only the off-page rungs share one colour between mark and text, which is
    /// the whole point of the discovery ink: one colour, one job. That is what
    /// Bea was seeing the absence of. The app painted every word `ink`, so the
    /// purple stopped at the mark.
    var textTint: Color {
        switch self {
        case .source: Cute.crownDeep
        case .set: Cute.ink
        case .uncommon, .rare, .mythic: Cute.discovery
        }
    }
}

/// One classified find.
struct FoundWord: Identifiable, Hashable {
    var word: String
    var category: WordCategory
    var score: Int
    var id: String { word }
}

/// One length group: the "X of Y" row and the chips beneath it.
struct LengthGroup: Identifiable {
    var length: Int
    /// Set words of this length that exist (the "of Y").
    var setTotal: Int
    /// Set and source finds of this length: the population the count describes.
    var setWords: [FoundWord]
    /// Off-page finds of this length: shown, never inside the set count.
    var offPageWords: [FoundWord]
    var id: Int { length }

    /// The "X" of "X of Y".
    var setFound: Int { setWords.count }

    /// Only a group carrying both needs the divider. A set-only group stays
    /// clean and label-free.
    var needsAlsoFound: Bool { !setWords.isEmpty && !offPageWords.isEmpty }
}

/// Classify every find once.
///
/// Everything downstream (the length groups, the rung tallies, the inline
/// points) reads this one array, so the readouts cannot disagree with each
/// other: they are views of a single pass, not separate passes that happen to
/// call the same function. That is the shape the web version settled on, and
/// this project has already found two bugs caused by doing otherwise.
func classifyFound(_ found: [String], in puzzle: Puzzle) -> [FoundWord] {
    found.map { word in
        let rung = classifyWord(word, in: puzzle)
        let byRung: WordCategory = switch rung {
        case .set: .set
        case .uncommon: .uncommon
        case .rare: .rare
        case .mythic: .mythic
        }
        let category: WordCategory = word == puzzle.sourceWord ? .source : byRung
        // Scored by the single rarity-aware path, so a chip's inline points
        // match the bar and the total rather than being a local sum.
        return FoundWord(word: word, category: category, score: findScore(word, rung: rung))
    }
}

/// Group finds by length, longest first.
///
/// Every length that has set words appears, plus any length with an off-page
/// find, so an uncracked length still shows what is missing.
func buildGroups(_ words: [FoundWord], in puzzle: Puzzle) -> [LengthGroup] {
    var setTotalByLength: [Int: Int] = [:]
    for word in puzzle.commonWords {
        setTotalByLength[word.count, default: 0] += 1
    }

    var foundByLength: [Int: [FoundWord]] = [:]
    for word in words {
        foundByLength[word.word.count, default: []].append(word)
    }

    let lengths = Set(setTotalByLength.keys).union(foundByLength.keys)
    return lengths.sorted(by: >).map { length in
        let inGroup = (foundByLength[length] ?? []).sorted { $0.word < $1.word }
        return LengthGroup(
            length: length,
            setTotal: setTotalByLength[length] ?? 0,
            setWords: inGroup.filter { !$0.category.isOffPage },
            offPageWords: inGroup.filter { $0.category.isOffPage }
        )
    }
}

/// The rarity mark: a small shape before the word.
///
/// Colour is never the only signal. The cute theme marks by glyph (heart, star,
/// sparkle, gem) where the letterpress theme uses drawn shapes; these are the
/// cute ones, since that is what v1 ships.
///
/// The source word is the peach itself, ported from the web's own artwork. See
/// `PeachMark`.
struct RarityMark: View {
    let category: WordCategory
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 13

    var body: some View {
        Group {
            switch category {
            case .source:
                // The face turns to mud at mark size, so the silhouette carries
                // it here. The card shows the full peach.
                PeachMark(showsFace: false).frame(width: size, height: size)
            case .set:
                Text("\u{2665}")      // heart
            case .uncommon:
                Text("\u{2605}")      // star
            case .rare:
                Text("\u{2726}")      // sparkle
            case .mythic:
                Text("\u{2756}")      // faceted gem
            }
        }
        .font(.system(size: size))
        .foregroundStyle(category.tint)
        .frame(width: size, alignment: .center)
        .accessibilityHidden(true)
    }
}
