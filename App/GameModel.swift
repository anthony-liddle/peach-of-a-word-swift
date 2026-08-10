import Foundation
import Observation
import PeachEngine

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
    }

    private(set) var phase: Phase = .loading
    private(set) var puzzle: Puzzle?
    /// Newest first, so the list reads as a history of what you just found.
    private(set) var found: [String] = []
    private(set) var feedback: Feedback = .none
    private(set) var loadMilliseconds: Double = 0

    /// The source word, once found, until the card is dismissed.
    ///
    /// On most days this fires in the opening seconds: the source word is what
    /// gets cracked on sight. So it is a moment, not a gate, and clearing it
    /// must return to a fully playable board.
    var celebration: Celebration?

    struct Celebration: Identifiable {
        let word: String
        let points: Int
        var id: String { word }
    }

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

    init(storage: GameStorage = GameStorage(store: UserDefaultsStore())) {
        self.storage = storage
    }

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
        var built: Result<Puzzle, Error>?
        let elapsed = await clock.measure {
            built = await Self.buildTodaysPuzzle()
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

        switch built {
        case .success(let p):
            puzzle = p
            // Tile ids are indices into the sorted rack, matching the web
            // version's `tilesFor`. The initial rack order is shuffled so the
            // answer is not sitting in alphabetical order on screen.
            tiles = p.letters.enumerated().map { Tile(id: $0.offset, letter: String($0.element)) }
            rackOrder = tiles.map(\.id).shuffled()

            // Progress and the streak are keyed off storageEpoch, which never
            // moves, NOT off dailyEpoch, which a calendar regeneration can
            // re-anchor. Keying on the daily epoch would renumber every stored
            // day and cost a streak. See StorageEpochTests.
            let day = dayIndex(Date(), epoch: storageEpoch, timeZone: .current)
            storageDayIndex = day
            found = storage.loadDayProgress(dayIndex: day, sourceWord: p.sourceWord)
            streak = storage.currentStreak(todayIndex: day)

            phase = .ready
            writeDebugState()
            runLaunchArguments()
        case .failure(let error):
            phase = .failed(String(describing: error))
        case nil:
            phase = .failed("load produced no result")
        }
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
            foundDidChange()
        }
        // `-replaySource 1` clears the day and then plays the source word
        // through the ordinary path: compose it tile by tile and submit. That
        // means the haptic, the feedback line, the card and the save all happen
        // exactly as they would in play, rather than the card being poked
        // directly into view.
        if UserDefaults.standard.bool(forKey: "replaySource"), let puzzle {
            found.removeAll()
            clear()
            for letter in puzzle.sourceWord { addLetter(String(letter)) }
            submit()
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
        if spec == "almost" {
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

        // Newest first, matching how a real find lands.
        for word in picks where !found.contains(word) {
            found.insert(word, at: 0)
        }
        foundDidChange()
    }
    #endif

    // MARK: Tile actions

    /// Place a specific tile. A tile already on the stick is ignored, matching
    /// the web reducer's `ADD_TILE` guard.
    func addTile(_ id: Int) {
        guard !composing.contains(id) else { return }
        composing.append(id)
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
    func shuffleRack() {
        rackOrder.shuffle()
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
        storage.saveDayProgress(dayIndex: day, sourceWord: puzzle.sourceWord, found: found)

        let standing = computeTier(found: Set(found), puzzle: puzzle)
        if standing.index >= streakTierIndex && !streakRecordedThisSession {
            streakRecordedThisSession = true
            storage.recordDailyCleared(dayIndex: day)
            streak = storage.currentStreak(todayIndex: day)
        }
        writeDebugState()
    }

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

        // An exhaustive switch over the engine's enum. Adding a case to
        // GuessResult would fail to compile here rather than silently falling
        // through, which is the whole point of it being an enum with associated
        // values rather than an object with a `kind` string.
        switch result {
        case .valid(let word, let score, let rung, let isSourceWord):
            found.insert(word, at: 0)
            if isSourceWord {
                feedback = .sourceFound
                celebration = Celebration(word: word, points: score)
                Feel.sourceWord()
            } else {
                feedback = .accepted(word: word, points: score, rung: rung)
                Feel.find()
            }
            foundDidChange()
        case .tooShort:
            feedback = .rejected("Too short. Three letters or more.")
            Feel.reject()
        case .notAWord:
            feedback = .rejected("Not a word you can make from these letters.")
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
    nonisolated static func buildTodaysPuzzle() async -> Result<Puzzle, Error> {
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

                // TimeZone.current is the app's call to make, and it is why the
                // engine takes the zone as a parameter instead of reaching for
                // Calendar.current internally. The daily rolls over at the
                // player's local midnight.
                let word = try dailySourceWord(
                    calendar: calendar,
                    date: Date(),
                    epoch: dailyEpoch,
                    timeZone: .current
                )

                return .success(createPuzzle(
                    sourceWord: word,
                    dictionary: ListDictionary(enable + additions),
                    commonPool: ListWordSource(common),
                    beyond70Pool: ListWordSource(beyond70),
                    beyond95Pool: ListWordSource(beyond95)
                ))
            } catch {
                return .failure(error)
            }
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
