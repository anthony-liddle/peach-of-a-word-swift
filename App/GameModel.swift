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

    /// Bound directly to the text field, so this one is `var`.
    var guess: String = ""

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
            phase = .ready
            submitLaunchArgumentGuesses()
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
    private func submitLaunchArgumentGuesses() {
        guard let raw = UserDefaults.standard.string(forKey: "guesses") else { return }
        for word in raw.split(separator: ",") {
            guess = String(word)
            submit()
        }
    }

    func submit() {
        guard let puzzle else { return }
        let result = validateGuess(guess, puzzle: puzzle, found: Set(found))

        // An exhaustive switch over the engine's enum. Adding a case to
        // GuessResult would fail to compile here rather than silently falling
        // through, which is the whole point of it being an enum with associated
        // values rather than an object with a `kind` string.
        switch result {
        case .valid(let word, let score, let rung, _):
            found.insert(word, at: 0)
            feedback = .accepted(word: word, points: score, rung: rung)
            guess = ""
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
