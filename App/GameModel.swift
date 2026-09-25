import Foundation
import Observation
import PeachEngine
#if DEBUG
import os
#endif

/// All the state the minimal app has.
///
/// Written the way SwiftUI wants it rather than as a port of the web version's
/// reducer, deliberately: porting the reducer would only prove the reducer
/// works. See docs/REPORT.md question 1 for the contrast.
///
/// `@Observable` is the macro that makes SwiftUI re-render when a property
/// changes. It replaced `ObservableObject` + `@Published`, and unlike that
/// older pair it tracks reads at the property level, so a view only re-renders
/// for the properties it actually touched. There is no React analogue: the
/// dependency tracking is automatic rather than declared in a hook.
///
/// `@MainActor` pins every member to the main thread. Swift 6 checks this at
/// compile time, so it is impossible to mutate this from a background task by
/// accident. The dictionary load below has to opt out explicitly.
@MainActor
@Observable
final class GameModel {
    enum Phase {
        case loading
        case ready
        case failed(String)
    }

    /// What just happened to a submitted guess. Drives the one-line feedback.
    enum Feedback: Equatable {
        case none
        case accepted(word: String, points: Int, rung: Rung)
        case sourceFound
        case rejected(String)

        /// What the message line says, in one place.
        ///
        /// The visible row and the VoiceOver announcement both read this, so
        /// they cannot drift into saying different things, and the announcement
        /// is never the shortened or truncated form. Truncation is something a
        /// frame does to a drawing at a text size that cannot fit it; it is not
        /// something that happens to the string, and the channel that does not
        /// have a width should not inherit the width's problems.
        var message: String? {
            switch self {
            case .none: nil
            case .accepted(let word, let points, let rung):
                "\(word), \(counted(points, "point"))" + (rung == .set ? "" : " (\(rung.rawValue))")
            case .sourceFound: Vocabulary.sourceFound
            case .rejected(let text): text
            }
        }
    }

    private(set) var phase: Phase = .loading
    private(set) var puzzle: Puzzle?
    /// Newest first, so the list reads as a history of what you just found.
    private(set) var found: [String] = []
    private(set) var feedback: Feedback = .none

    /// How many submits have been resolved. Bumped on every one, including a
    /// submit whose outcome repeats the last.
    ///
    /// It exists so the message can be announced to VoiceOver, and it has to
    /// exist because `Feedback` is `Equatable`: rejecting the same word twice
    /// produces an equal value, which is not a change, so nothing downstream
    /// fires and the second rejection is silent. That is exactly the case a
    /// player who cannot see the line is most likely to hit, since they have no
    /// way to notice they retyped the same word.
    ///
    /// The web hit this and answered it the same way, with `seq` on its
    /// announcement (`useGame.ts`, `bump(prev, body)`). A counter rather than a
    /// timestamp, so it stays deterministic and testable.
    private(set) var feedbackSeq = 0
    private(set) var loadMilliseconds: Double = 0

    /// What the reveal card shows for each crown, keyed by word.
    ///
    /// Populated from `Data/etymology.tsv`, which IS committed. This said it
    /// was empty "until the corpus ships, which is the state this repository is
    /// in today"; that stopped being true on 2026-08-14, when the licensing act
    /// was taken and the etymology row was added to `tools/update-lexicon.sh`.
    /// The comment outlived the state it described by twelve days.
    ///
    /// 799 entries, covering 615 of the 626 calendar crowns. The other eleven
    /// have no usable English etymology on Wiktionary and are skipped on
    /// purpose, so a dealt crown really can have no entry. `readSourceEntries`
    /// still treats a missing file as empty rather than as an error, which now
    /// covers a build without the data rather than the normal case.
    private(set) var sourceEntries: [String: SourceEntry] = [:]

    /// The gloss behind every tappable found-word chip, keyed by word.
    ///
    /// Populated from `Data/definitions.tsv`, 24,896 rows. **A whole-file read
    /// into one dictionary, where the web fetches one of 793 per-rack shards.**
    /// The shards are an HTTP optimisation: a browser downloads 4 KB rather
    /// than 1.5 MB and does it after the board is already playable. An app has
    /// shipped the entire binary before it opens, so the shards would buy
    /// nothing and cost 793 files in the bundle.
    ///
    /// **Coverage is a presence check and nothing more.** Measured over all 626
    /// calendar racks: every one of 21,988 set-word slots has a row, on all 626
    /// racks, with no distinct set word missing. That is exact and it means
    /// every set word has a ROW. Whether every row says something useful is
    /// unmeasured. 80 glosses of 3,444 were read by hand and three classes of
    /// defect turned up, one of them found only because `one` and `ten` happened
    /// to be in the sample, so there is no basis for believing a fourth class
    /// does not exist. See `DefinitionCard` for the three that are known.
    ///
    /// Rack-weighted coverage off the page: uncommon 99.54 percent, mythic
    /// 98.91 percent over the 614 racks that have any, rare 72.61 percent. The
    /// rare gap is the visible one and it is mostly not-words rather than a
    /// sourcing failure, which is the queue's problem rather than this table's.
    private(set) var definitions: [String: String] = [:]

    /// Which of those glosses this project wrote rather than derived from
    /// Wiktionary, from `Data/gloss-provenance.tsv`.
    ///
    /// **Empty is the safe answer and it is also a wrong one.** A build without
    /// the sidecar credits Wiktionary for all 24,896 rows, including the 38 it
    /// did not write. That under-claims this project's own words and
    /// over-credits nobody, which is the direction an attribution failure
    /// should fall, but it is still a false line on 38 cards. The shipped
    /// corpus is guarded by `ShippedGlossProvenanceTests` so the file's absence
    /// fails a test rather than quietly changing what the cards say.
    private(set) var glossProvenance = GlossProvenance(projectWords: [])

    /// The celebration currently on screen, if any.
    ///
    /// Two beats share this slot, and the hierarchy decides which wins when both
    /// land on the same submit (finding the source word last, which also
    /// completes the set): **completion is the peak, so it takes priority** and
    /// the peach card is dropped rather than queued behind it. Two sheets in a
    /// row would turn the biggest moment in the game into paperwork.
    ///
    /// Neither ends the game. Off-page words remain, the board stays live, and
    /// dismissing returns to it.
    var moment: Moment?

    enum Moment: Identifiable {
        case sourceWord(word: String)
        case completion(setTotal: Int, score: Int)
        /// A found word's definition, opened by tapping its chip.
        ///
        /// **Not a celebration, and it shares this slot anyway.** The other two
        /// arrive from a submit and compete with each other for one screen;
        /// this one arrives from a tap, when no submit is resolving and no
        /// other moment can be on screen, so it never enters that contest and
        /// the completion-wins rule above is untouched by it.
        ///
        /// The category rides along rather than being looked up again, because
        /// the card tints its rule by it and the chip that was tapped already
        /// knows. Re-deriving it would be a second classification pass, which
        /// is the exact shape `classifyFound` exists to prevent.
        case definition(word: String, category: WordCategory)

        var id: String {
            switch self {
            case .sourceWord(let word): "source-\(word)"
            case .completion: "completion"
            case .definition(let word, _): "definition-\(word)"
            }
        }
    }

    /// Open the right card for a tapped found word.
    ///
    /// **The crown keeps the crown card.** `classifyFound` marks a word
    /// `.source` if and only if it equals `puzzle.sourceWord`, so this reads the
    /// same fact the chip is already drawn from rather than a second one that
    /// could disagree. The peach, the celebration line, the etymology and the
    /// kicker are that word's, and a definition-only card for it would be a
    /// downgrade of the biggest beat in the game.
    ///
    /// Everything else gets the quiet card, including a set word, which the web
    /// also routes to its quiet register.
    func revealFound(_ found: FoundWord) {
        moment = found.category == .source
            ? .sourceWord(word: found.word)
            : .definition(word: found.word, category: found.category)
    }

    /// True once completion has been celebrated, so it fires on the transition
    /// and never again.
    ///
    /// Seeded at load from the restored board: reopening an already-complete
    /// day must not replay the peak.
    private var completionSeen = false

    /// The persisted streak, as of the day this session loaded.
    private(set) var streak: Int = 0

    /// Local persistence. Injected so previews and tests can hand in an
    /// in-memory store instead of touching real UserDefaults.
    private let storage: GameStorage

    /// The day this board belongs to, in `storageEpoch` days.
    ///
    /// Captured once at load and then used for every save. It is deliberately
    /// NOT recomputed at write time: if midnight passes while the app is open,
    /// the board on screen is still yesterday's, and its words must be saved
    /// under yesterday's key rather than leaking into today.
    private var storageDayIndex: Int?

    /// The moment this board was built for. Captured with the day index, for the
    /// same reason: if midnight passes while the app is open the board on screen
    /// is still yesterday's, and a share of it must say yesterday's date.
    private(set) var boardDate = Date()

    /// Whether the board on screen came from the archive rather than being
    /// today's daily.
    ///
    /// Read by the rollover, which must leave a past board alone, and by the
    /// screen, which says which day is being played.
    private(set) var isArchiveBoard = false

    /// The word lists, held for the life of the app. See `Lexicon`.
    private var lexicon: Lexicon?

    /// Whether past boards can be opened.
    ///
    /// **The seam, and the only thing a paywall would have to replace.** Every
    /// entry point goes through `openArchiveDay`, which asks this once, so
    /// gating the archive later is one implementation swapped in at `init`
    /// rather than an audit of every call site. Today's board is never gated:
    /// this governs the past only, and the live daily is the free game.
    private let access: ArchiveAccess

    var canPlayArchive: Bool { access.canPlayArchive }

    /// The first day that has a board, in storage days.
    ///
    /// The two epochs differ by a fixed number of days, so the offset falls out
    /// of the two indices for today and needs no date arithmetic and no time
    /// zone. It moves only if `dailyEpoch` is re-anchored, which is exactly when
    /// it should.
    nonisolated static var firstPlayableStorageIndex: Int {
        todayStorageIndex - todayDailyIndex
    }

    /// How many times progress has been written this session.
    ///
    /// Exists to prove a property rather than to implement one: taps, delete,
    /// clear and shuffle must not write. The plist modification time cannot show
    /// this, because cfprefsd batches UserDefaults writes to disk, so the count
    /// is taken at the point of the call instead.
    private(set) var saveCount = 0

    /// The streak is recorded at most once per session, matching the web's ref
    /// guard, so reaching the rank and then finding more words does not
    /// repeatedly rewrite it.
    private var streakRecordedThisSession = false

    init(
        storage: GameStorage = GameStorage(store: UserDefaultsStore()),
        access: ArchiveAccess = FreeArchive()
    ) {
        self.storage = storage
        self.access = access
    }

    /// "Now", shiftable in debug builds by `-dayOffset N`.
    ///
    /// The daily rollover is the core loop of a daily game and had never run in
    /// life: every session so far has been the same puzzle on the same day.
    /// Shifting the date here drives the whole chain the way a real midnight
    /// would: a new day index, a new source word from the calendar, a new
    /// storage key, the streak comparison, and the fourteen-day prune.
    ///
    /// What this does NOT exercise is the one call to `Date()` itself, which is
    /// Foundation rather than our code. A real clock change is still worth doing
    /// once on a device; see docs/REPORT.md.
    nonisolated static var now: Date {
        #if DEBUG
        var offset = UserDefaults.standard.integer(forKey: "dayOffset")
        // `-dayOffsetOnResume 1` moves the clock forward the first time the app
        // is foregrounded, and not before.
        //
        // The rollover only happens when the day changes while the app is away,
        // which no launch argument can reproduce: a fixed `-dayOffset` is the
        // same on both sides of a backgrounding, so the day never changes and
        // the path never runs. This is the smallest thing that makes the real
        // sequence reachable, which is the same argument as `-revealCard` and
        // `-holdLoading`.
        if hasResumed { offset += UserDefaults.standard.integer(forKey: "dayOffsetOnResume") }
        if offset != 0 {
            return Foundation.Calendar.current.date(byAdding: .day, value: offset, to: Date()) ?? Date()
        }
        #endif
        return Date()
    }

    #if DEBUG
    /// Set the first time the app is foregrounded after launch. See `now`.
    ///
    /// `nonisolated(unsafe)` for the same reason `UserDefaultsStore.diagnostic`
    /// is: it is written once from the main actor and read from `now`, which is
    /// nonisolated so that the day can be computed without hopping actors.
    nonisolated(unsafe) static var hasResumed = false
    #endif

    /// Bound directly to the debug text field, so this one is `var`. Tapping is
    /// the primary path; this stays only because it makes headless testing of
    /// arbitrary strings possible.
    var guess: String = ""

    // MARK: Composition
    //
    // Ported from the web version's `useGame.ts`, and the shape is the whole
    // point: composition is a list of tile IDs, never letters.
    //
    //   tiles      id -> letter, built once from the sorted rack
    //   rackOrder  the ids in display order, which is all Shuffle touches
    //   composing  the ids placed so far, in the order they were placed
    //
    // This is what makes duplicate letters work. `motorway` has two separate
    // `o` tiles; tapping one must consume that specific tile and leave the other
    // available. A letter-keyed model would either consume both or lose track of
    // which remained.
    //
    // It also makes Shuffle correct for free: reordering `rackOrder` cannot
    // disturb `composing`, because they refer to each other only by id.

    struct Tile: Identifiable, Sendable {
        let id: Int
        let letter: String
    }

    private(set) var tiles: [Tile] = []
    private(set) var rackOrder: [Int] = []
    private(set) var composing: [Int] = []

    /// The word currently on the stick.
    var composedWord: String {
        composing.compactMap { id in tiles.first { $0.id == id }?.letter }.joined()
    }

    /// True if this specific tile is already placed. The web version derives the
    /// same thing with `state.composing.includes(id)` on every render.
    func isPlaced(_ id: Int) -> Bool {
        composing.contains(id)
    }

    /// The current standing, recomputed from scratch on every access.
    ///
    /// Wasteful in principle and free in practice: `computeTier` is a loop over
    /// the found words, which is at most a few dozen. Recomputing beats caching
    /// a second copy of a fact the engine already owns, which is exactly the
    /// bug class the engine port found in the web version twice.
    var standing: TierStanding? {
        guard let puzzle else { return nil }
        return computeTier(found: Set(found), puzzle: puzzle)
    }

    /// The rack, as individual letters for display.
    var rackLetters: [String] {
        guard let puzzle else { return [] }
        return puzzle.sourceWord.sorted().map(String.init)
    }

    func load() async {
        let clock = ContinuousClock()
        var loaded: Result<Lexicon, Error>?
        // The corpus read is inside the measurement deliberately: it is part of
        // what launch costs, and a load timer that excludes half the load is
        // worse than one that grows. Note that it does grow. Today the file is
        // absent and this is one failed stat; the day it ships,
        // loadMilliseconds gains the parse, and the numbers in
        // docs/MEASUREMENTS.md were taken before it existed.
        let elapsed = await clock.measure {
            loaded = await Self.loadLexicon()
            sourceEntries = await Self.loadSourceEntries()
            definitions = await Self.loadDefinitions()
            glossProvenance = await Self.loadGlossProvenance()
        }

        // 1 millisecond is 1e15 attoseconds. An earlier version of this scaled
        // the two components inconsistently and silently underreported any
        // duration of a second or more, which is exactly the range that turned
        // out to matter. Kept explicit rather than clever.
        let (wholeSeconds, attoseconds) = elapsed.components
        let milliseconds = Double(wholeSeconds) * 1000 + Double(attoseconds) * 1e-15
        loadMilliseconds = (milliseconds * 1000).rounded() / 1000
        // Also written to a file in the app container, so a script can read the
        // number with `simctl get_app_container` instead of screenshotting the
        // debug row. `print` was tried first and does not reach
        // `simctl launch --console-pty` reliably.
        if let docs = try? FileManager.default.url(
            for: .documentDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        ) {
            try? "\(loadMilliseconds)".write(
                to: docs.appendingPathComponent("load_ms.txt"),
                atomically: true, encoding: .utf8
            )
        }

        #if DEBUG
        // Hold the splash open, so the loading line can actually be looked at.
        //
        // The dictionary loads in about 200ms on a Mac, which is far too quick
        // to screenshot by racing it: the attempt caught the launch animation
        // instead. A string nobody can see is a string nobody can check, and
        // this one had been missing entirely without anyone noticing.
        //
        // Debug only, like every other launch hook here, so it cannot reach a
        // shipping build.
        let holdSeconds = UserDefaults.standard.double(forKey: "holdLoading")
        if holdSeconds > 0 {
            try? await Task.sleep(for: .seconds(holdSeconds))
        }
        #endif

        switch loaded {
        case .success(let lex):
            lexicon = lex
            guard let p = await Self.buildPuzzle(
                dailyIndex: Self.todayDailyIndex, lexicon: lex
            ) else {
                phase = .failed("the daily calendar is empty")
                return
            }
            // Before the board is adopted, so a day left in the daily blob by
            // a session that ended yesterday is already where it belongs when
            // the back-fill goes looking for it.
            storage.retirePastDays(todayIndex: Self.todayStorageIndex)
            adopt(p, storageDay: Self.todayStorageIndex, isArchive: false)
            // Once, and only until it has run. See `backFillArchive`.
            await backFillArchive()
            #if DEBUG
            // Awaited here rather than in `runLaunchArguments`, which runs after
            // the app says it is ready. This seed writes the archive's input and
            // then expands it, and the sheet sizes itself to the result.
            if UserDefaults.standard.string(forKey: "seedArchive") == "bea" {
                await seedBea()
            }
            #endif
            phase = .ready
            writeDebugState()
            runLaunchArguments()
        case .failure(let error):
            phase = .failed(String(describing: error))
        case nil:
            phase = .failed("load produced no result")
        }
    }

    /// Make a puzzle the board, for whatever day it is now.
    ///
    /// Shared by the first load and by a rollover, so the two cannot set the
    /// board up differently. They did not, when the rollover was written as its
    /// own copy of this, and they would have the first time either changed.
    private func adopt(_ p: Puzzle, storageDay: Int, isArchive: Bool) {
        puzzle = p
        // Tile ids are indices into the sorted rack, matching the web
        // version's `tilesFor`.
        tiles = p.letters.enumerated().map { Tile(id: $0.offset, letter: String($0.element)) }
        // Seeded from the source word, not drawn at random, so every player
        // opens the same rack on a given day AND the rack never leads with the
        // crown. An unseeded draw did both wrong: it re-dealt on every launch,
        // and one launch in 20,160 spelled the answer outright.
        rackOrder = dailyRackOrder(letters: p.letters, word: p.sourceWord)

        // Progress and the streak are keyed off storageEpoch, which never
        // moves, NOT off dailyEpoch, which a calendar regeneration can
        // re-anchor. Keying on the daily epoch would renumber every stored day
        // and cost a streak. See StorageEpochTests.
        storageDayIndex = storageDay
        isArchiveBoard = isArchive
        boardDate = Self.date(forStorageDay: storageDay)
        found = storage.loadDayProgress(dayIndex: storageDay, sourceWord: p.sourceWord)

        // **Today's index, not the board's.** This read `currentStreak(todayIndex:
        // day)`, which was correct only because `day` was always today. Handed a
        // past board it would report the streak as of that past day, which is a
        // display bug rather than a data one and would therefore survive review:
        // the number is plausible, just answering a different question.
        streak = storage.currentStreak(todayIndex: Self.todayStorageIndex)

        // A day already complete has had its moment. Only the transition
        // celebrates.
        //
        // **Seeded from the stored outcome, not from the restored found list**,
        // and the substitution is the point. The found list is pruned and the
        // outcome is not, so a board completed once and reopened after its words
        // have aged out restores an empty list, seeds false, and fires the whole
        // peak a second time while the calendar is already drawing that day
        // filled. The outcome remembers what the found list is allowed to
        // forget; see `completionAlreadySeen`.
        completionSeen = completionAlreadySeen(outcome: storage.outcome(dayIndex: storageDay))
    }

    /// The date a storage day index falls on.
    ///
    /// Derived by offsetting from today rather than by counting from the epoch,
    /// so `Calendar` handles the daylight-saving arithmetic and `-dayOffset`
    /// keeps working. Only the share block reads it, and only to print a date.
    nonisolated static func date(forStorageDay day: Int) -> Date {
        Foundation.Calendar.current.date(
            byAdding: .day, value: day - todayStorageIndex, to: now
        ) ?? now
    }

    /// Bring the board to today, if today is no longer the day it was built for.
    ///
    /// **The rule that the day does not roll over mid-session still holds, and
    /// this is not that.** Swapping the rack under someone's fingers at
    /// midnight is worse than letting them finish on yesterday's board, and the
    /// day index is still captured once per board and never recomputed while
    /// one is in play, so a rollover cannot leak yesterday's words into today's
    /// key.
    ///
    /// What that reasoning missed is that backgrounding is not the middle of a
    /// session. It is one session ending and another beginning, and iOS does
    /// not announce the difference: the app is simply resumed, with whatever
    /// was on screen still on screen. Bea opened the app the next morning to
    /// yesterday's puzzle, and force-quitting fixed it, which is the shape of a
    /// state that is only ever rebuilt at launch.
    ///
    /// **No transitional screen.** Every puzzle is in the bundle, so a message
    /// about fetching a fresh basket would describe work that is not happening
    /// and invent a delay to explain. The phase stays `.ready` and the board
    /// changes under a foregrounding app, which is what she is expecting to
    /// see: today's board when she opens it.
    ///
    /// **Composed letters are thrown away.** If it is a new day, it is a new
    /// day, and she was not mid-word a day later.
    ///
    /// Yesterday's words need no saving here: progress is written on every
    /// find, under the day index the board was built for, so they were on disk
    /// long before this ran. They do need moving, out of the blob that holds the
    /// board in play and into the one that keeps every past day, and that is
    /// `retirePastDays` below.
    func rollOverIfNewDay() async {
        guard let board = storageDayIndex, let lexicon else { return }  // nothing loaded yet
        let today = Self.todayStorageIndex

        // **An archive board is exempt, and this is the single most likely bug
        // in the archive.** The rule below is "rebuild when the board's day is
        // not today", which is right for every board that existed before the
        // archive and wrong for every board the archive opens: a past board
        // differs from today by definition, so without this the first
        // foregrounding would swap her July board for today's while she was
        // still playing it. Nothing about that would look wrong in review.
        guard shouldRollOver(boardDayIndex: board, todayIndex: today,
                             isArchive: isArchiveBoard) else { return }

        guard let p = await Self.buildPuzzle(
            dailyIndex: Self.todayDailyIndex, lexicon: lexicon
        ) else {
            // Keep yesterday's board rather than emptying the screen. A failure
            // here is a bundle that could not be read, which a relaunch will
            // report properly; showing nothing would be a worse answer than
            // showing a board she can still play.
            return
        }
        // The board she was playing is about to leave the screen. Its words go
        // with it, into the key that keeps them.
        storage.retirePastDays(todayIndex: today)
        adopt(p, storageDay: today, isArchive: false)
        // The new day has not recorded a streak yet, and this flag is what
        // stops one session recording twice. Left set, the first clear of the
        // new day would be dropped.
        streakRecordedThisSession = false
        clear()
        moment = nil
        feedback = .none
        writeDebugState()
    }

    /// Test affordance: `-guesses motorway,tram,zzz` submits those words at
    /// launch, so the whole loop can be driven from the terminal.
    ///
    /// This exists because there is no supported way to type into a SwiftUI
    /// text field from the command line. `simctl` has no keyboard input, and
    /// driving the Simulator with AppleScript needs the field focused first and
    /// accessibility permissions granted. A launch argument was faster than
    /// either. `UserDefaults` reads `-key value` launch arguments for free,
    /// which is the standard trick for this.
    private func runLaunchArguments() {
        #if DEBUG
        // `-seedArchive showcase` fills the calendar so it can be looked at.
        //
        // Runs before the guesses, and the order is load-bearing: the seed
        // replaces the whole outcome map, so a find recorded before it is
        // wiped by it. Seeding the world and then playing in it is also the
        // only order that means anything.
        //
        // Seeding the outcome map directly rather than playing boards, because
        // the alternative is seventy-nine loads of the word lists and seventy-
        // nine completed racks to produce a picture. The outcome map IS the
        // archive's whole state, so writing it is not a shortcut around the
        // feature, it is the feature's input.
        // `-seedArchive bea` is handled in the load path instead, because it
        // has to finish before the app reports itself ready.
        if let spec = UserDefaults.standard.string(forKey: "seedArchive") {
            seedArchive(spec)
        }
        // `-archiveDay 7` opens the board from seven days ago at launch.
        //
        // The board itself cannot be reached without a tap, and the meter grows
        // a row on an archive board, so without this the layout budget for that
        // row could only be reasoned about. Same argument as `-revealCard`.
        let back = UserDefaults.standard.integer(forKey: "archiveDay")
        if back > 0 {
            Task { await self.openArchiveDay(storageDay: Self.todayStorageIndex - back) }
        }
        // `-guesses a,b,c` goes through the typed path, so arbitrary strings
        // (including ones the rack cannot spell) can still be tested.
        if let raw = UserDefaults.standard.string(forKey: "guesses") {
            for word in raw.split(separator: ",") {
                guess = String(word)
                submitTyped()
            }
        }
        // `-tapWords motorway,tram` goes through the TILE path: each letter is
        // resolved to a specific unused tile id and placed, exactly as tapping
        // would. This is what verifies duplicate-letter handling headlessly,
        // since `motorway` needs two distinct `o` tiles.
        if let raw = UserDefaults.standard.string(forKey: "tapWords") {
            for word in raw.split(separator: ",") {
                clear()
                for letter in word { addLetter(String(letter)) }
                submit()
            }
        }
        // `-resetProgress 1` wipes today's saved words so the board starts
        // empty and the source word can be found for real. The celebration only
        // fires on a genuine find, so replaying it needs the day cleared first.
        if UserDefaults.standard.bool(forKey: "resetProgress") {
            found.removeAll()
            // Otherwise a day that was already complete keeps `completionSeen`
            // from load, and finishing the fresh board would celebrate nothing.
            completionSeen = false
            foundDidChange()
        }
        // `-replaySource 1` clears the day and then plays the source word
        // through the ordinary path: compose it tile by tile and submit. That
        // means the haptic, the feedback line, the card and the save all happen
        // exactly as they would in play, rather than the card being poked
        // directly into view.
        if UserDefaults.standard.bool(forKey: "replaySource"), let puzzle {
            found.removeAll()
            completionSeen = false
            clear()
            for letter in puzzle.sourceWord { addLetter(String(letter)) }
            submit()
        }
        // `-revealCard withdraw` opens the source reveal for a named word,
        // whatever today's crown is.
        //
        // `-replaySource 1` above is the honest path and stays the way to check
        // the moment itself. It can only ever show today's card, though, and
        // the question the reveal's detent asks is about content length: the
        // shortest entry in the corpus is 34 characters and the longest is
        // 1,787, and reaching both through real play would mean waiting for two
        // particular days to come round. This pokes the card into view for a
        // chosen word so that both ends can be looked at in one sitting.
        //
        // Every entry is loaded into `sourceEntries`, so a named word gets its
        // real definition and etymology rather than a stand-in. An unknown word
        // opens the no-entry fallback, which is a case worth being able to see
        // on demand too.
        if let word = UserDefaults.standard.string(forKey: "revealCard") {
            moment = .sourceWord(word: word)
        }
        // `-hapticLadder 1` plays all four rungs in order, spaced far enough
        // apart to be told apart: tile tap, find, source word, completion.
        //
        // Judging a find on its own says nothing. The question the change was
        // made to answer is whether it sits clearly above a tap and clearly
        // below the crown, and that is a question about three gaps rather than
        // one strength, so all four have to arrive in one sitting.
        //
        // The spacing is set by the patterns rather than by taste: the source
        // word runs 0.5s and the completion 1.1s, so 1.8s leaves a clear rest
        // between the end of one and the start of the next. None of it is felt
        // on a simulator, which has no haptics hardware at all.
        if UserDefaults.standard.bool(forKey: "hapticLadder") {
            Task { @MainActor in
                Feel.tilePress()
                try? await Task.sleep(for: .seconds(1.8))
                Feel.find()
                try? await Task.sleep(for: .seconds(1.8))
                Feel.sourceWord()
                try? await Task.sleep(for: .seconds(1.8))
                Feel.completion()
            }
        }
        // `-seedBoard almost` or `-seedBoard 24`.
        if let spec = UserDefaults.standard.string(forKey: "seedBoard") {
            seedBoard(spec)
        }
        // `-tapTiles 4,1,6` places those rack POSITIONS, exercising `addTile`
        // itself rather than the letter lookup, and leaves the result on the
        // stick without submitting. Positions, not ids, so a caller does not
        // need to know the internal numbering.
        if let raw = UserDefaults.standard.string(forKey: "tapTiles") {
            clear()
            for token in raw.split(separator: ",") {
                if let position = Int(token), rackOrder.indices.contains(position) {
                    addTile(rackOrder[position])
                }
            }
        }
        #endif
    }

    #if DEBUG
    /// Fill the board with a realistic set of finds, for judging the visual
    /// work without playing a game by hand first.
    ///
    /// The next work is the found list, the rarity colours and the tier meter,
    /// and none of that can be judged against a board holding three words. The
    /// preview loop is about three seconds; replaying a board by hand is
    /// minutes, and that asymmetry is the reason this exists.
    ///
    /// Two specs, because they answer different questions:
    ///
    ///   `almost`  every set word but one, plus a third of each off-page rung.
    ///             The most interesting state for the tier meter: high, with the
    ///             completion crown still out of reach.
    ///   `<count>` roughly that many words, spread across the four bands in
    ///             proportion to their sizes, so the rarity mix looks like real
    ///             play rather than one colour repeated.
    ///
    /// Deliberately deterministic (bands are sorted, picks are strided) so two
    /// screenshots of the same spec are comparable. Random picks would make
    /// every visual diff noisy.
    ///
    /// It writes through `foundDidChange`, the same path a real find takes, so
    /// seeding exercises persistence rather than bypassing it. That makes this
    /// a live check of the thing it sits next to, and means it cannot drift into
    /// a second way of writing saved state.
    ///
    /// `#if DEBUG` compiles it out of Release, so it is unreachable in any build
    /// that ships. It is also therefore unavailable on the device builds, which
    /// are Release.
    func seedBoard(_ spec: String) {
        guard let puzzle else { return }

        /// Every nth word of a sorted band, so the choice is stable.
        func stride(_ band: Set<String>, keeping fraction: Int) -> [String] {
            let sorted = band.sorted()
            guard fraction > 1 else { return sorted }
            return sorted.enumerated().compactMap { $0.offset % fraction == 0 ? $0.element : nil }
        }

        var picks: [String]
        if spec == "hierarchy" {
            // Everything except the source word and one other set word, so a
            // single session can reach both remaining beats: find the source
            // word for level three, then the last set word for level four.
            // Tile taps and an ordinary find come free on the way.
            picks = puzzle.commonWords.sorted()
                .filter { $0 != puzzle.sourceWord }
                .dropLast()
                .map { $0 }
            picks += stride(puzzle.uncommonWords, keeping: 4)
        } else if spec == "almost" {
            // All but one set word: the meter sits just under the crown.
            picks = puzzle.commonWords.sorted().dropLast().map { $0 }
            picks += stride(puzzle.uncommonWords, keeping: 3)
            picks += stride(puzzle.rareWords, keeping: 3)
            picks += stride(puzzle.mythicWords, keeping: 3)
        } else if let target = Int(spec), target > 0 {
            // Weighted toward the set, because that is what real play looks
            // like: common words come first and off-page finds are the
            // occasional bonus. An earlier version spread proportionally to
            // BAND SIZE, which is dominated by the rare band, and produced
            // boards with four set words against twenty off-page. That is a
            // board no player would ever have.
            let setShare = Int((Double(target) * 0.62).rounded())
            picks = Array(puzzle.commonWords.sorted().prefix(setShare))

            // The remainder favours the rungs in the order they are actually
            // stumbled into: mostly uncommon, some rare, the odd mythic.
            let remainder = max(0, target - picks.count)
            let weights: [(Set<String>, Double)] = [
                (puzzle.uncommonWords, 0.55),
                (puzzle.rareWords, 0.33),
                (puzzle.mythicWords, 0.12),
            ]
            for (band, weight) in weights {
                let share = Int((Double(remainder) * weight).rounded())
                picks += Array(band.sorted().prefix(share))
            }
        } else {
            return
        }

        // **The day is cleared first.** Seeding means "the board is exactly
        // this", so it overwrites rather than merges.
        //
        // The bug this fixes: seeding used to add to whatever was restored from
        // storage, so on a day already saved as complete every seeded word was
        // already present and the flag silently did nothing. The board looked
        // untouched and the flag looked broken. A seed that no-ops when a save
        // exists is worse than no seed, because it looks like it worked.
        //
        // Clearing here rather than requiring `-resetProgress` alongside it,
        // because the correct behaviour should not depend on remembering to
        // pass a second flag. `-resetProgress` still exists for an empty board.
        found.removeAll()
        for word in picks {
            found.insert(word, at: 0)
        }
        // Recomputed from the SEEDED board, not carried over from the saved one.
        // A seed that lands short of completion must still be able to celebrate
        // when it is finished, and a seed that lands complete must not
        // celebrate a peak that was not played.
        completionSeen = isComplete(computeTier(found: Set(found), puzzle: puzzle))
        foundDidChange()
    }
    #endif

    // MARK: Tile actions

    /// Place a specific tile. A tile already on the stick is ignored, matching
    /// the web reducer's `ADD_TILE` guard.
    /// A tile refused because it is already on the stick.
    ///
    /// The token exists so two refusals of the same tile in a row are two
    /// events rather than one unchanged value, which a view can animate from.
    struct Refusal: Equatable {
        let tile: Int
        let token: Int
    }

    private(set) var refusal: Refusal?
    private var refusalCount = 0

    func addTile(_ id: Int) {
        guard !composing.contains(id) else {
            // Previously a silent return. A used tile now answers, because
            // "nothing happened" is indistinguishable from a dropped tap, and
            // on a rack with two of a letter this is an ordinary thing to do.
            refusalCount += 1
            refusal = Refusal(tile: id, token: refusalCount)
            #if TAP_RECORDER
            TapRecorder.shared.record(
                .refused, tile: id, letter: tiles.first { $0.id == id }?.letter ?? "?"
            )
            #endif
            Feel.refuse()
            return
        }
        composing.append(id)
        // Starting a word ends the last one's message.
        //
        // The feedback and the composed word now share one slot: the message
        // renders inside the compose well, where it replaces the placeholder.
        // See `ComposingStick`. Merely hiding it while letters are on the stick
        // would look equivalent and is not, because deleting back to an empty
        // well would bring a stale rejection back.
        //
        // `feedbackSeq` is deliberately NOT bumped. That counter drives the
        // VoiceOver announcement, and clearing a message is not an event worth
        // speaking; bumping it here would announce the empty string every time
        // a tile landed.
        feedback = .none
        #if TAP_RECORDER
        TapRecorder.shared.record(
            .commit, tile: id, letter: tiles.first { $0.id == id }?.letter ?? "?"
        )
        #endif
        Feel.tilePress()
    }

    /// Place the first unused tile bearing this letter, in rack order.
    ///
    /// The keyboard path in the web version, kept here for the tap-driven test
    /// hook. "First unused in rack order" is what makes typing `oo` consume two
    /// different tiles rather than failing on the second.
    func addLetter(_ letter: String) {
        guard let id = rackOrder.first(where: { id in
            tiles.first { $0.id == id }?.letter == letter && !composing.contains(id)
        }) else { return }
        composing.append(id)
        // The same clearing `addTile` does, for the same reason. See there.
        feedback = .none
    }

    /// Remove the last placed tile, returning it to the rack.
    func removeLast() {
        guard !composing.isEmpty else { return }
        composing.removeLast()
    }

    /// Empty the stick.
    func clear() {
        composing.removeAll()
    }

    /// Reorder the rack for display.
    ///
    /// Note what this deliberately does not touch: `composing`. Because both
    /// lists hold ids, shuffling the display order cannot disturb a composition
    /// in progress. That correctness falls out of the id-based model rather than
    /// needing to be arranged.
    /// The button must stay unpredictable, so it cannot walk the daily's seed
    /// stream: it redraws at random and rejects, where the daily takes the next
    /// seeded permutation. Different recovery, same predicate, which is the half
    /// that has to agree. The rejection is silent by design; a "reshuffled you"
    /// tell would confirm the answer the rack just leaked.
    func shuffleRack() {
        guard let puzzle else { return }
        var draw = rackOrder
        rackOrder = guardedRackOrder(
            letters: puzzle.letters,
            word: puzzle.sourceWord
        ) { _ in
            draw.shuffle()
            return draw
        }
    }

    /// Submit whatever is on the stick.
    func submit() {
        resolve(attempt(composedWord))
        // The web version clears the stick on every outcome, valid or not, so a
        // rejected word does not have to be picked apart by hand.
        clear()
    }

    /// Submit the debug text field. Tapping is the primary path; this is kept
    /// only for headless testing of strings the rack cannot spell.
    func submitTyped() {
        resolve(attempt(guess))
        guess = ""
    }

    private func attempt(_ word: String) -> GuessResult? {
        guard let puzzle else { return nil }
        return validateGuess(word, puzzle: puzzle, found: Set(found))
    }

    /// Everything that runs after `found` changes.
    ///
    /// This is the ONLY place progress is written, and it is reached only from a
    /// successful find. Tile taps, delete, clear and shuffle all mutate
    /// `composing`, never `found`, so none of them touches the disk. That is the
    /// same split the web version arrived at after a per-tap synchronous write
    /// caused input lag: key persistence on durable state, never on the
    /// keystroke path.
    private func foundDidChange() {
        guard let puzzle, let day = storageDayIndex else { return }
        saveCount += 1
        // The same fact `recordDailyCleared` needs, and for a related reason:
        // it decides which store the words belong in, not only whether the
        // streak may move. See `saveDayProgress`.
        storage.saveDayProgress(dayIndex: day, sourceWord: puzzle.sourceWord,
                                found: found, fromArchive: isArchiveBoard)

        let standing = computeTier(found: Set(found), puzzle: puzzle)
        let today = Self.todayStorageIndex

        // The peak. Checked here rather than in `resolve` so it sees the board
        // after the find has landed, and so seeding reaches it too.
        if isComplete(standing) && !completionSeen {
            completionSeen = true
            moment = .completion(setTotal: standing.setTotal, score: standing.score)
            Feel.completion()
        }

        // The archive's whole substance: what this board reached, kept.
        recordOutcome(standing: standing, day: day, today: today)

        if standing.index >= streakTierIndex && !streakRecordedThisSession {
            streakRecordedThisSession = true
            // Three facts, because the two indices are not enough. Yesterday
            // crossed at midnight and yesterday tapped in the calendar are the
            // same pair of numbers, and only this side knows which happened.
            // The engine decides what to do with that; see `recordDailyCleared`.
            storage.recordDailyCleared(dayIndex: day, todayIndex: today, fromArchive: isArchiveBoard)
            streak = storage.currentStreak(todayIndex: today)
        }
        writeDebugState()
    }

    /// Write how far this board got, under the archive's own key.
    ///
    /// **Never downgrades.** A completed day reopened after its words have been
    /// pruned starts from an empty list and climbs back up, and the first find on
    /// it must not overwrite the full basket it already earned with "played". The
    /// stored rung is the high-water mark, not the current one.
    ///
    /// `on` is today rather than the board's day, so a board caught up later says
    /// so and the calendar can tell "completed on the day" from "completed after
    /// the day". For the live daily the two are the same number.
    private func recordOutcome(standing: TierStanding, day: Int, today: Int) {
        // `played` means "found at least one word", which is the narrowed
        // definition of Incomplete. The `-resetProgress` hook calls
        // `foundDidChange` with an emptied board, and an empty board must not
        // claim to have been played: that is the difference between "no record"
        // and "you did not finish", which the calendar draws differently and
        // which is the whole reason the zero-find case was conceded.
        guard !found.isEmpty else { return }

        let reached = rungReached(standing)

        if let existing = storage.outcome(dayIndex: day), existing.reached >= reached { return }
        storage.recordOutcome(
            dayIndex: day, DayOutcome(reached: reached, on: today, fromStreak: false)
        )
    }

    /// Take a streak handed over by the web build, if the accept rule allows it.
    ///
    /// The rule itself lives in `GameStorage.adoptStreak`, where the other
    /// streak rules live and where the dead-streak rejection can be tested. All
    /// this adds is the two things only the model knows: what day it is, and
    /// that the displayed number needs refreshing.
    ///
    /// Today is computed here rather than read from `storageDayIndex`, which is
    /// nil until `load()` has run. A link can arrive before that on a cold
    /// launch, which would otherwise drop the transfer silently. `Self.now` so
    /// `-dayOffset` drives this path too, the same as every other day-sensitive
    /// call.
    ///
    /// See `StreakTransfer` for why this exists and when it should be removed.
    @discardableResult
    func adoptTransferredStreak(_ transfer: StreakTransfer) -> Bool {
        let today = dayIndex(Self.now, epoch: storageEpoch, timeZone: .current)
        let took = storage.adoptStreak(
            count: transfer.count,
            lastClearedDayIndex: transfer.lastClearedDayIndex,
            todayIndex: today
        )
        // `streak` is a snapshot taken at load, so a warm app that accepts a
        // transfer would write storage and go on showing the old number.
        if took { streak = storage.currentStreak(todayIndex: today) }
        return took
    }

    // MARK: The archive

    /// Expand a transferred streak run into per-day outcomes. Once.
    ///
    /// Called at every launch and does nothing after the first, because the run
    /// it reads is destroyed by the first clear after a missed day: a streak is a
    /// run-length encoding of cleared days, and `recordDailyCleared` sets the
    /// count back to 1 rather than remembering what it was. Adopting a transfer
    /// re-arms it, since the link can land after the app has already launched.
    ///
    /// The clamp matters more than it looks: Bea's seventy days start nine days
    /// after the daily epoch, so today nothing is trimmed, and a longer run or a
    /// re-anchored `dailyEpoch` would otherwise write outcomes for dates that
    /// have no board at all.
    /// Build the archive's history once, on the first launch that has one.
    ///
    /// **The days that still hold words are classified before the run fills the
    /// rest, and that ordering is the whole point.** The streak establishes only
    /// that a day reached the rank; a day whose words survive can say whether the
    /// basket filled. Those words are pruned to a fortnight and this write is
    /// never revised, so a recent basket day either keeps its heart here or
    /// loses it permanently.
    ///
    /// The puzzles are built first, off the main actor, because classifying
    /// needs one per day and the engine's hook is synchronous. At most fourteen,
    /// bounded by the prune rather than by the length of the run.
    @discardableResult
    private func backFillArchive() async -> BackFillCounts {
        guard let lexicon else { return BackFillCounts(fromPlay: 0, fromStreak: 0) }
        // Asked before the puzzles are built, not after. The engine would refuse
        // a second expansion anyway, but only once this has already rebuilt a
        // fortnight of boards to hand it a classifier it will not call.
        guard !storage.hasBackFilledOutcomes() else {
            return BackFillCounts(fromPlay: 0, fromStreak: 0)
        }

        // Four at a time. `createPuzzle` is 93.5ms in Release and 887ms in
        // Debug on this Mac, measured by `peach-bench`, so a fortnight of them
        // in a row is about 1.3 seconds added to the one launch that does this.
        // Built concurrently it is a quarter of that, and the expansion still
        // finishes before anything can see a half filled calendar.
        // **Capped, where the prune used to cap it.** `daysWithProgress` was
        // bounded at fourteen by the prune, and the back-fill relied on that
        // without saying so. With every past day keeping its words the walk is
        // unbounded, and each day it walks costs a puzzle build. Held to the
        // most recent days, so the launch that does this costs what it was
        // measured at; the streak accounts for every day beyond, which is what
        // it was always going to do for days with no words at all.
        let days = Array(storage.daysWithProgress().prefix(GameStorage.backFillWalkDayCount))
        var puzzles: [Int: Puzzle] = [:]
        await withTaskGroup(of: (Int, Puzzle?).self) { group in
            var next = 0
            func submit() {
                guard next < days.count else { return }
                let day = days[next]
                next += 1
                let daily = day - Self.firstPlayableStorageIndex
                guard daily >= 0 else { return submit() }
                group.addTask {
                    (day, await Self.buildPuzzle(dailyIndex: daily, lexicon: lexicon))
                }
            }
            for _ in 0..<min(4, days.count) { submit() }
            while let (day, puzzle) = await group.next() {
                if let puzzle { puzzles[day] = puzzle }
                submit()
            }
        }

        return storage.backFillOutcomes(
            firstPlayableDayIndex: Self.firstPlayableStorageIndex
        ) { day, storedSourceWord, found in
            // The same mismatch rule `loadDayProgress` applies: a different
            // source word means the calendar moved and these words belong to
            // another puzzle.
            guard let puzzle = puzzles[day], puzzle.sourceWord == storedSourceWord else {
                return nil
            }
            return rungReached(computeTier(found: Set(found), puzzle: puzzle))
        }
    }

    /// Every day the calendar can draw, oldest first.
    ///
    /// Read once per sheet presentation rather than per cell: `allOutcomes`
    /// decodes the whole map, and doing that inside a `ForEach` over ninety rows
    /// is the kind of thing that is free at seventy-nine days and is not at four
    /// hundred.
    func archiveDays() -> [ArchiveDay] {
        #if DEBUG
        // **A walk of the whole archive, counted so it can be kept off the
        // launch path.** It decodes every stored outcome and computes a mark
        // for every day in history to draw one month, so where it is called
        // from is worth knowing. A launch that never opens the archive must
        // report zero. See `ArchiveDaysCount`.
        #endif
        let outcomes = storage.allOutcomes()
        let today = Self.todayStorageIndex
        var indices = archiveDayIndices(
            firstPlayableDayIndex: Self.firstPlayableStorageIndex, todayIndex: today
        )

        // Draw the rest of the current month, so a month page is a whole month.
        //
        // **This used to stop at the end of today's week, and that cap was a
        // landing requirement rather than a calendar one.** The sheet scrolled
        // every month at once and had to put today's row at the end of the
        // content, so anything drawn below today pushed it off the bottom. The
        // sheet now shows one month at a time and has nothing to land on, so the
        // cap bought nothing and cost the shape of a calendar: a month page that
        // stops mid-month is not a page of a calendar.
        //
        // Days after today are `.notYet`, which is the state that needed
        // somewhere to appear in the first place.
        let calendar = Foundation.Calendar.current
        let todayDate = Self.date(forStorageDay: today)
        let daysLeft = calendar.range(of: .day, in: .month, for: todayDate).flatMap { month in
            calendar.dateComponents([.day], from: todayDate).day.map { month.count - $0 }
        } ?? 0
        if daysLeft > 0 { indices += (1...daysLeft).map { today + $0 } }

        return indices.map { day in
            ArchiveDay(
                day: day,
                date: Self.date(forStorageDay: day),
                mark: dayMark(for: day, outcome: outcomes[day], todayIndex: today),
                isToday: day == today
            )
        }
    }

    /// Open a past board.
    ///
    /// **The one gate.** Every route to a past board comes through here, so the
    /// StoreKit version of `ArchiveAccess` is a swap rather than an audit.
    ///
    /// A future day is refused outright rather than trusted to the grid: the
    /// calendar is computable arbitrarily far ahead, and handing out tomorrow's
    /// board is the one mistake this cannot take back.
    @discardableResult
    func openArchiveDay(storageDay: Int) async -> Bool {
        guard access.canPlayArchive, let lexicon else { return false }
        let today = Self.todayStorageIndex
        guard storageDay >= Self.firstPlayableStorageIndex, storageDay <= today else {
            return false
        }

        let daily = storageDay - Self.firstPlayableStorageIndex
        guard let p = await Self.buildPuzzle(dailyIndex: daily, lexicon: lexicon) else {
            return false
        }
        adopt(p, storageDay: storageDay, isArchive: storageDay != today)
        // A past board has its own streak state to record, or rather has none:
        // this flag guards one write per session and the session is now on a
        // different board.
        streakRecordedThisSession = false
        clear()
        moment = nil
        feedback = .none
        writeDebugState()
        return true
    }

    /// Go back to the live daily.
    func returnToToday() async {
        await openArchiveDay(storageDay: Self.todayStorageIndex)
    }

    #if DEBUG
    /// Fill the calendar with a history worth looking at.
    ///
    /// **`showcase` is shaped like Bea's, not like a swatch sheet.** Seventy
    /// consecutive transferred days and then a short tail of days played here,
    /// because a long stretch of one state is what her calendar actually is and
    /// the question worth asking of it is whether that reads as achievement or
    /// as a wall. A grid with one of each state evenly spaced would answer a
    /// question nobody has.
    ///
    /// Everything is written straight into the outcome map. That is not a
    /// shortcut past the feature: the map is the feature's entire persisted
    /// state, and the alternative is completing seventy-nine racks to produce a
    /// picture.
    func seedArchive(_ spec: String) {
        guard spec == "showcase" else { return }
        let first = Self.firstPlayableStorageIndex
        let today = Self.todayStorageIndex
        guard today - first >= 9 else { return }

        // Built whole and written once, so the seed is authoritative. Adding to
        // whatever is already on the device produced a calendar with two cells
        // that were meant to be empty showing an earlier seed's values, which is
        // a picture that lies about the thing it exists to let you look at.
        var seeded: [Int: DayOutcome] = [:]

        // The transferred run: cleared, never a basket, because the web never
        // recorded basket completion and the back-fill cannot invent it.
        let runEnd = today - 9
        for day in max(first, runEnd - 69)...runEnd {
            seeded[day] = DayOutcome(reached: DayOutcome.cleared, on: day, fromStreak: true)
        }

        // The tail, played here. One of each remaining state, adjacent, so they
        // are judged against each other rather than one at a time.
        let tail: [(offset: Int, reached: Int, caughtUpLater: Bool)] = [
            (8, DayOutcome.played, false),    // started, below the rank
            (6, DayOutcome.cleared, false),   // finished on the day
            (5, DayOutcome.basket, false),    // basket on the day
            (4, DayOutcome.cleared, true),    // finished after the day
            (3, DayOutcome.basket, true),     // basket after the day
            (1, DayOutcome.cleared, false),   // finished on the day
        ]
        for entry in tail {
            let day = today - entry.offset
            seeded[day] = DayOutcome(
                reached: entry.reached,
                on: entry.caughtUpLater ? today : day,
                fromStreak: false
            )
        }
        storage.seeding.replaceOutcomes(seeded)
        // Offsets 7, 2 and 0 are deliberately left unwritten: two gaps and
        // today itself, so "no record" and the today ring are both on screen.
    }

    /// Bea's phone as it will be on merge day, before its first open.
    ///
    /// **The showcase seed plants the answer; this one plants the question.** It
    /// writes the inputs the back-fill reads, a live streak pair and the found
    /// words the prune is still holding, then runs the back-fill exactly as the
    /// first launch after a merge will. What appears on the calendar is the
    /// feature's own output rather than a picture of what it is supposed to
    /// produce, which is the only way to see the one write that is never
    /// revised before it happens on her phone.
    ///
    /// The run is anchored on the snapshot: 70 days ending at storage day 251,
    /// which is 2026-09-09, extended to yesterday because the run is still
    /// alive. Nothing here is hard-coded to today's date.
    func seedBea() async {
        guard let lexicon else { return }
        let first = Self.firstPlayableStorageIndex
        let today = Self.todayStorageIndex
        // Alive through yesterday, which is what keeps the pair live without
        // claiming today's board has been cleared.
        let last = today - 1
        guard last >= Self.snapshotLastCleared else { return }
        let count = 70 + (last - Self.snapshotLastCleared)
        guard last - count + 1 >= first else { return }

        // No outcomes, and the expansion not yet run. Armed explicitly rather
        // than through `adoptStreak`, which re-arms only when it takes: run
        // twice, it refuses a count that does not beat the live one, and the
        // seed would clear the days without arming anything.
        storage.seeding.rearmBackFill()
        _ = storage.adoptStreak(count: count, lastClearedDayIndex: last, todayIndex: today)

        // The days the prune would still be holding words for. Fourteen is the
        // cap; today is left alone because the live board owns it.
        for back in 1...(Self.seededDayCount) {
            let day = today - back
            guard day >= first else { continue }
            guard let puzzle = await Self.buildPuzzle(
                dailyIndex: day - first, lexicon: lexicon
            ) else { continue }

            // The basket days are every set word the rack can spell, taken from
            // the puzzle rather than invented, because a plausible looking list
            // that is one word short reconstructs as `cleared` and the heart
            // never appears.
            let setWords = puzzle.commonWords.sorted()
            let found: [String]
            switch back {
            case 1, 4, 9: found = setWords
            case 13: found = Array(setWords.prefix(1))
            default: found = Self.wordsReachingTheRank(in: puzzle, from: setWords)
            }
            storage.saveDayProgress(
                dayIndex: day, sourceWord: puzzle.sourceWord, found: found,
                fromArchive: true
            )
        }

        await backFillArchive()
    }

    /// Days of found words the seed writes behind today.
    ///
    /// Its own number rather than the back-fill's cap, which it used to borrow.
    /// The two were the same while the prune bounded both; they answer different
    /// questions and only coincidentally agreed.
    static let seededDayCount = 13

    /// The storage day index of 2026-09-09, the day the streak snapshot was
    /// taken, when the stored pair read `count: 70, lastClearedDayIndex: 251`.
    static let snapshotLastCleared = 251

    /// The shortest prefix of the set words that reaches the streak rank.
    ///
    /// Built by asking the real rule rather than by guessing a count: the rank
    /// is a fraction of par, so how many words it takes differs per board.
    static func wordsReachingTheRank(in puzzle: Puzzle, from words: [String]) -> [String] {
        var found: [String] = []
        for word in words {
            found.append(word)
            if rungReached(computeTier(found: Set(found), puzzle: puzzle)) >= DayOutcome.cleared {
                return found
            }
        }
        return found
    }
    #endif

    /// A small JSON dump beside load_ms.txt, so relaunch and rollover checks can
    /// be scripted with `simctl get_app_container` rather than read off a
    /// screenshot. Debug builds only.
    private func writeDebugState() {
        #if DEBUG
        guard let docs = try? FileManager.default.url(
            for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        ) else { return }
        let payload = """
        {"storageDay":\(storageDayIndex ?? -1),"found":\(found.count),"streak":\(streak),"saves":\(saveCount)}
        """
        try? payload.write(to: docs.appendingPathComponent("state.json"),
                           atomically: true, encoding: .utf8)
        #endif
    }

    private func resolve(_ result: GuessResult?) {
        guard let result else { return }
        feedbackSeq += 1

        // An exhaustive switch over the engine's enum. Adding a case to
        // GuessResult would fail to compile here rather than silently falling
        // through, which is the whole point of it being an enum with associated
        // values rather than an object with a `kind` string.
        switch result {
        case .valid(let word, let score, let rung, let isSourceWord):
            found.insert(word, at: 0)
            if isSourceWord {
                feedback = .sourceFound
                moment = .sourceWord(word: word)
                Feel.sourceWord()
            } else {
                feedback = .accepted(word: word, points: score, rung: rung)
                Feel.find()
            }
            // May replace the peach moment with the completion one, which is
            // the intended precedence.
            foundDidChange()
        case .tooShort:
            // The rule without the scolding. "Too short." said nothing the
            // rest of the sentence did not, and cost 204pt of width at AX5 to
            // say it, which is the whole difference between a line that fits
            // the reserved height and one that truncates: 0.81 against 0.55,
            // measured against a 0.6 floor.
            //
            // The full stop stays, because the other two rejections have one
            // and all three land in the same slot. It costs 9.8pt at AX5,
            // which is 0.83 to 0.81, and buys the slot one voice.
            feedback = .rejected("Three letters or more.")
            Feel.reject()
        case .notAWord:
            // Shortened to fit the message line's reserved height. The web has
            // no cute value to copy: `themeCopy.ts` deliberately leaves the
            // rejections unskinned, and the plain string at `useGame.ts:238`
            // ("Not in the word list. Try another.") is longer than what it
            // would replace and names the other half of the case. Same
            // information, a third of the width.
            feedback = .rejected("Not from these letters.")
            Feel.reject()
        case .alreadyFound:
            feedback = .rejected("Already found.")
            Feel.reject()
        }
    }
}

extension GameModel {
    /// Build today's puzzle off the main thread.
    ///
    /// `nonisolated` opts this one function out of the `@MainActor` isolation
    /// above, so the ~200 ms of file reading does not block the first frame.
    /// It can only return a `Puzzle` across that boundary because `Puzzle` is
    /// `Sendable`, which the engine declared long before there was a UI to
    /// consume it. That is the protocol-boundary design paying off.
    /// The word lists, the rarity pools and the calendar, held together.
    ///
    /// **Retained for the life of the app, and the cost was measured rather than
    /// assumed.** These used to be locals inside the build: every one of them was
    /// read, used once, and dropped, so opening any board paid the whole cold
    /// path. That was invisible while the only board was today's, because the
    /// cost was already inside launch. The archive makes it visible, once per
    /// tap.
    ///
    /// Measured on 2026-09-09, release, `phys_footprint` because that is what
    /// iOS jetsam measures: holding all four costs **54 MB**, and takes a board
    /// build from the 362 ms `docs/MEASUREMENTS.md` records on an iPhone 13 to
    /// roughly 86 ms. 54 MB on the oldest device the iOS 17 floor admits, a 3 GB
    /// iPhone XR, is a small fraction of the budget before jetsam, and the app
    /// already retains the definitions table and the etymology corpus.
    ///
    /// Verify the app's total on device with Xcode's memory gauge: that
    /// measurement covered these structures, not the app around them.
    struct Lexicon: Sendable {
        let dictionary: ListDictionary
        let common: ListWordSource
        let beyond70: ListWordSource
        let beyond95: ListWordSource
        let calendar: [String]
    }

    /// Read every list once. The expensive half of what used to be
    /// `loadLexicon`.
    nonisolated static func loadLexicon() async -> Result<Lexicon, Error> {
        await Task.detached(priority: .userInitiated) {
            do {
                let data = try bundledDataDirectory()

                let enable = try readWordList("enable.txt", in: data)
                let additions = try readWordList("scowl95-additions.txt", in: data)
                let common = try readWordList("common-pool.txt", in: data)
                let beyond70 = try readWordList("beyond-size-70.txt", in: data)
                let beyond95 = try readWordList("beyond-size-95.txt", in: data)

                let calendarURL = data.appendingPathComponent("daily-calendar.json")
                let calendar = try JSONDecoder()
                    .decode(CalendarFile.self, from: Data(contentsOf: calendarURL))
                    .words

                return .success(Lexicon(
                    dictionary: ListDictionary(enable + additions),
                    common: ListWordSource(common),
                    beyond70: ListWordSource(beyond70),
                    beyond95: ListWordSource(beyond95),
                    calendar: calendar
                ))
            } catch {
                return .failure(error)
            }
        }.value
    }

    /// Build the board for a position in the daily sequence.
    ///
    /// Takes an index rather than a date. The archive holds a day as a number,
    /// and turning it into a `Date` so that `dayIndex` could turn it back would
    /// put the time-zone question back into a path that does not have one. The
    /// live board still resolves its index from `TimeZone.current`, which is the
    /// app's call to make and is why the engine takes the zone as a parameter
    /// rather than reaching for `Calendar.current`.
    nonisolated static func buildPuzzle(dailyIndex: Int, lexicon: Lexicon) async -> Puzzle? {
        await Task.detached(priority: .userInitiated) {
            guard let word = sourceWord(calendar: lexicon.calendar, dailyIndex: dailyIndex) else {
                return nil
            }
            return createPuzzle(
                sourceWord: word,
                dictionary: lexicon.dictionary,
                commonPool: lexicon.common,
                beyond70Pool: lexicon.beyond70,
                beyond95Pool: lexicon.beyond95
            )
        }.value
    }

    /// The daily index for right now, in the player's own zone.
    nonisolated static var todayDailyIndex: Int {
        dayIndex(now, epoch: dailyEpoch, timeZone: .current)
    }

    /// The storage index for right now. Keyed off `storageEpoch`, which never
    /// moves, so a calendar regeneration cannot renumber a stored day.
    nonisolated static var todayStorageIndex: Int {
        dayIndex(now, epoch: storageEpoch, timeZone: .current)
    }

    /// Read the reveal corpus off the main thread, from the app bundle.
    ///
    /// Its own detached task rather than a return value bolted onto
    /// `loadLexicon`, because the two answer different questions: that one
    /// builds the game and must fail loudly if the word lists are missing, and
    /// this one fetches something the card can do without. Folding them together
    /// would put a `Result` around a load that cannot fail.
    ///
    /// The bundle path is `bundledDataDirectory()` for the same reason the word
    /// lists use it: the engine's default `dataDirectory` is derived from
    /// `#filePath` and resolves only on the machine that compiled the package,
    /// which the iOS Simulator makes look correct and a device does not.
    nonisolated static func loadSourceEntries() async -> [String: SourceEntry] {
        await Task.detached(priority: .userInitiated) {
            guard let data = try? bundledDataDirectory() else { return [:] }
            return readSourceEntries(in: data)
        }.value
    }

    /// Read the definition corpus off the main thread, from the app bundle.
    ///
    /// The same shape as `loadSourceEntries` and for the same reasons: its own
    /// detached task, because this fetches something the game can do without
    /// and folding it into `loadLexicon` would put a `Result` around a
    /// load that cannot fail; and `bundledDataDirectory()` rather than the
    /// engine's `#filePath`-derived default, which resolves only on the machine
    /// that compiled the package and which the Simulator makes look correct.
    ///
    /// **Inside `load`'s clock, deliberately.** It is part of what launch costs.
    /// A load timer that excludes half the load is worse than one that grows,
    /// which is the argument already made for the corpus read beside it, and
    /// this file is thirty times that one's size.
    nonisolated static func loadDefinitions() async -> [String: String] {
        await Task.detached(priority: .userInitiated) {
            guard let data = try? bundledDataDirectory() else { return [:] }
            return readDefinitions(in: data)
        }.value
    }

    /// Read the provenance sidecar off the main thread, from the app bundle.
    ///
    /// The same shape as `loadDefinitions`, and inside the same clock, though
    /// it is 500 bytes against that file's 1.5 MB. It is read separately rather
    /// than folded into the definitions load because the two answer different
    /// questions: one is what a word means, the other is who wrote that. A
    /// single load returning both would be the one-parser shape
    /// `Definitions.swift` argues against, one level up.
    nonisolated static func loadGlossProvenance() async -> GlossProvenance {
        await Task.detached(priority: .userInitiated) {
            guard let data = try? bundledDataDirectory() else {
                return GlossProvenance(projectWords: [])
            }
            return GlossProvenance(projectWords: readGlossProvenance(in: data))
        }.value
    }

    private struct CalendarFile: Codable {
        let words: [String]
    }

    enum LoadError: Error, CustomStringConvertible {
        case noResourceDirectory

        var description: String {
            switch self {
            case .noResourceDirectory:
                "Bundle.main.resourceURL was nil, so the word lists could not be found."
            }
        }
    }

    /// Where the word lists live inside the app bundle.
    ///
    /// The engine's own `dataDirectory` is derived from `#filePath` and points
    /// at the repo on the machine that compiled it. That path happens to
    /// resolve in the iOS Simulator, because the simulator shares the Mac
    /// filesystem, so using the default would look fine here and break on a
    /// real device. This is the version that is actually correct.
    nonisolated static func bundledDataDirectory() throws -> URL {
        guard let resources = Bundle.main.resourceURL else {
            throw LoadError.noResourceDirectory
        }
        return resources.appendingPathComponent("Data")
    }
}
