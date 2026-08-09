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
    enum Feedback {
        case none
        case accepted(word: String, points: Int, rung: Rung)
        case rejected(String)
    }

    private(set) var phase: Phase = .loading
    private(set) var puzzle: Puzzle?
    /// Newest first, so the list reads as a history of what you just found.
    private(set) var found: [String] = []
    private(set) var feedback: Feedback = .none
    private(set) var loadMilliseconds: Double = 0

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
            phase = .ready
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
    }

    // MARK: Tile actions

    /// Place a specific tile. A tile already on the stick is ignored, matching
    /// the web reducer's `ADD_TILE` guard.
    func addTile(_ id: Int) {
        guard !composing.contains(id) else { return }
        composing.append(id)
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

    private func resolve(_ result: GuessResult?) {
        guard let result else { return }

        // An exhaustive switch over the engine's enum. Adding a case to
        // GuessResult would fail to compile here rather than silently falling
        // through, which is the whole point of it being an enum with associated
        // values rather than an object with a `kind` string.
        switch result {
        case .valid(let word, let score, let rung, _):
            found.insert(word, at: 0)
            feedback = .accepted(word: word, points: score, rung: rung)
        case .tooShort:
            feedback = .rejected("Too short. Three letters or more.")
        case .notAWord:
            feedback = .rejected("Not a word you can make from these letters.")
        case .alreadyFound:
            feedback = .rejected("Already found.")
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
