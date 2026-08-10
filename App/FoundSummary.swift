import SwiftUI
import PeachEngine

/// The status row: the completion count, then a tally per rarity rung.
///
/// **Pinned above the scroll rather than inside it.** It used to be the first
/// row of the found list, on the reasoning that the tier meter above already
/// carried the essential status and a second fixed row would cost vertical
/// space that was already tight. Bea plays this daily and missed it, which
/// settles it: the counts are what she checks, and a status line you have to go
/// looking for is not a status line.
///
/// **Never a denominator on the rarity rungs.** Counts only, never "5 of 47
/// Rare". Advertising how many off-page words a rack holds turns open-ended
/// discovery into a grind, which is the thing the rarity model exists to
/// prevent. Completion is the set, and that is the one place an "X of Y"
/// belongs. This holds in the sheet as firmly as it holds here.
struct FoundSummary: View {
    let puzzle: Puzzle
    let found: [String]
    let standing: TierStanding
    var boardDate: Date = Date()

    /// The off-page finds bucketed by rung, alphabetical within each.
    ///
    /// One classification pass, shared by the tallies and by whatever the sheet
    /// shows, so the number on the row and the length of the list it opens are
    /// the same data. The count can never overstate the list.
    private let buckets: [WordCategory: [FoundWord]]
    private let allWords: [FoundWord]

    @State private var openRung: RungSelection?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(puzzle: Puzzle, found: [String], standing: TierStanding,
         boardDate: Date = Date()) {
        self.puzzle = puzzle
        self.found = found
        self.standing = standing
        self.boardDate = boardDate
        let classified = classifyFound(found, in: puzzle)
        self.allWords = classified
        var b: [WordCategory: [FoundWord]] = [.uncommon: [], .rare: [], .mythic: []]
        for w in classified where b[w.category] != nil { b[w.category]?.append(w) }
        for key in b.keys { b[key]?.sort { $0.word < $1.word } }
        self.buckets = b
    }

    /// All three rungs, always, in ladder order.
    ///
    /// The web shows a rung with nothing at it as a plain tally rather than
    /// hiding it, and that matters more here than it does there: this row is now
    /// pinned, so a row that grows a new item the first time she finds a Rare
    /// would shift under her thumb mid-play. The tier caption was fixed for
    /// exactly that reason and the same argument applies. A stable row costs a
    /// little width and buys never moving.
    private static let rungs: [(WordCategory, String)] = [
        (.uncommon, "Uncommon"), (.rare, "Rare"), (.mythic, "Mythic"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                RarityMark(category: .set)
                Text("\(standing.setFound) of \(counted(standing.setTotal, "word"))")
                    .font(CuteFont.body(15, weight: "SemiBold", relativeTo: .subheadline))
                    .foregroundStyle(Cute.ink)
                    .monospacedDigit()
                Spacer(minLength: 8)
                ShareSummaryButton(puzzle: puzzle, found: found,
                                   standing: standing, boardDate: boardDate)
            }

            // Three across normally, stacked at accessibility sizes. Side by
            // side they crowd and truncate, which is the failure the tier
            // caption and the sheet header both had: a tally reading "46 Rar..."
            // is worse than one on its own line.
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(Self.rungs.enumerated()), id: \.offset) { _, entry in
                            rungTally(entry.0, name: entry.1)
                        }
                    }
                } else {
                    HStack(spacing: 6) {
                        ForEach(Array(Self.rungs.enumerated()), id: \.offset) { index, entry in
                            if index > 0 {
                                Text("\u{00B7}").foregroundStyle(Cute.inkFaint)
                            }
                            rungTally(entry.0, name: entry.1)
                        }
                    }
                }
            }
            .font(CuteFont.body(13, relativeTo: .footnote))
            .foregroundStyle(Cute.inkSoft)
        }
        #if DEBUG
        // Opening a sheet needs a tap, and simctl cannot tap. Same reasoning as
        // the other launch hooks here, and unreachable in a shipping build.
        .onAppear {
            guard let name = UserDefaults.standard.string(forKey: "openRung"),
                  let match = Self.rungs.first(where: {
                      $0.1.lowercased() == name.lowercased()
                  }),
                  !(buckets[match.0] ?? []).isEmpty
            else { return }
            openRung = RungSelection(category: match.0, name: match.1)
        }
        #endif
        .sheet(item: $openRung) { selection in
            RungSheet(
                rung: selection.category,
                name: selection.name,
                words: buckets[selection.category] ?? []
            ) { openRung = nil }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    /// One rung's tally, a control only when there is something to show.
    ///
    /// A rung she has nothing at is a tally, not a control: plain text, so it
    /// neither looks tappable nor appears to VoiceOver as a button that does
    /// nothing. The count gates the trigger, which also means the sheet can
    /// never open empty.
    @ViewBuilder
    private func rungTally(_ category: WordCategory, name: String) -> some View {
        let items = buckets[category] ?? []
        if items.isEmpty {
            HStack(spacing: 4) {
                RarityMark(category: category)
                Text("0 \(name)")
            }
            .accessibilityElement(children: .combine)
        } else {
            Button {
                openRung = RungSelection(category: category, name: name)
            } label: {
                HStack(spacing: 4) {
                    RarityMark(category: category)
                    Text("\(items.count) \(name)")
                }
                // The visible tally stays a tally. The full target is taken by
                // padding the hit region rather than the box, so the row keeps
                // its height. Unlike the found-list chips, which sit at 24pt
                // under the WCAG 2.5.8 inline exception, these are standalone
                // controls in a status row, so the full 44pt applies.
                .padding(.vertical, 11)
                .padding(.horizontal, 6)
                .contentShape(Rectangle())
                .padding(.vertical, -11)
                .padding(.horizontal, -6)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            // The action is spoken but not printed, the way the web does it.
            .accessibilityLabel("\(counted(items.count, name, plural: name)), show the words you found")
        }
    }
}

/// The rung a sheet is open on. `Identifiable` because `.sheet(item:)` needs it,
/// and a struct rather than the bare category so the display name travels with
/// it instead of being looked up twice.
struct RungSelection: Identifiable {
    let category: WordCategory
    let name: String
    var id: String { name }
}
