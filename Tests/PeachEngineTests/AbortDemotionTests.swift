import Foundation
import Testing
@testable import PeachEngine

/// The `abort` demotion, asserted against the lists this app actually ships.
///
/// `abortion` was demoted out of the common pool on 2026-08-02. `abort` was
/// flagged then as the one clear remaining candidate, because requiring the
/// stem while the derived form is demoted is incoherent.
///
/// Demote, not deny. `abort` means to stop a process before completion and is
/// ordinary technical vocabulary. It stays valid, stays scoreable, and grades
/// as an off-page find. It stops being required to complete the two boards it
/// binds on.
///
/// **This is the first time this repository's word lists changed because
/// orchard cut a release, rather than because someone re-snapshotted by hand.**
/// That is why the assertions here are about what a player would notice rather
/// than about the file containing a line: the interesting claim is not that the
/// bytes arrived, it is that the decision did, and that it means the same thing
/// on this side as it does on the web.
@Suite("abort is demoted, not denied")
struct AbortDemotionTests {

    static let word = "abort"
    static let racks = ["bathroom", "portable"]

    /// A puzzle built from the shipped lists, the way the app builds one.
    static func puzzle(for rack: String) throws -> Puzzle {
        let boundary = try readWordList("enable.txt") + readWordList("scowl95-additions.txt")
        return createPuzzle(
            sourceWord: rack,
            dictionary: ListDictionary(boundary),
            commonPool: ListWordSource(try readWordList("common-pool.txt")),
            beyond70Pool: ListWordSource(try readWordList("beyond-size-70.txt")),
            beyond95Pool: ListWordSource(try readWordList("beyond-size-95.txt"))
        )
    }

    @Test("it left the common pool, so it is never required")
    func absentFromCommonPool() throws {
        #expect(!(try readWordList("common-pool.txt").contains(Self.word)))
    }

    @Test("it is still in the validation boundary, so it is still a word")
    func stillValid() throws {
        let boundary = try readWordList("enable.txt") + readWordList("scowl95-additions.txt")
        #expect(boundary.contains(Self.word))
    }

    @Test("still accepted and still scores", arguments: racks)
    func stillAcceptedAndScores(rack: String) throws {
        let p = try Self.puzzle(for: rack)
        // Destructured rather than compared to a literal: the valid case
        // carries the score and the rung, and both are the point here.
        guard case let .valid(_, score, rung, _) =
            validateGuess(Self.word, puzzle: p, found: []) else {
            Issue.record("\(Self.word) is no longer accepted on \(rack)")
            return
        }
        #expect(score > 0)
        #expect(rung != .set)
    }

    @Test("grades off-page, not as a set word", arguments: racks)
    func gradesOffPage(rack: String) throws {
        let p = try Self.puzzle(for: rack)
        #expect(!p.commonWords.contains(Self.word))
        #expect(classifyWord(Self.word, in: p) != .set)
    }

    // MARK: - A player mid-board is not harmed

    /// Completion is computed, never stored. `computeTier` takes the found set
    /// and the current puzzle, so a pool change re-grades old progress rather
    /// than invalidating it. Verified rather than assumed, because "no
    /// migration needed" is cheap to assert and expensive to be wrong about.

    @Test("a board one word short of the old set now reads complete", arguments: racks)
    func previouslyOneShortNowCompletes(rack: String) throws {
        let p = try Self.puzzle(for: rack)
        // The player who found every set word except abort: one short before,
        // everything now.
        let standing = computeTier(found: p.commonWords, puzzle: p)
        #expect(standing.setFound == standing.setTotal)
    }

    @Test("a player who already found abort keeps their completion", arguments: racks)
    func alreadyFoundItKeepsCompletion(rack: String) throws {
        let p = try Self.puzzle(for: rack)
        // Stored progress from before the demotion. abort now grades off-page:
        // it must not inflate setFound past setTotal, and must not be lost.
        var found = p.commonWords
        found.insert(Self.word)
        let standing = computeTier(found: found, puzzle: p)
        #expect(standing.setFound == standing.setTotal)
        #expect(standing.offPagePoints > 0)
    }

    @Test("a partial board stays partial rather than breaking", arguments: racks)
    func partialStaysPartial(rack: String) throws {
        let p = try Self.puzzle(for: rack)
        var found = Set(p.commonWords.sorted().prefix(3))
        found.insert(Self.word)
        let standing = computeTier(found: found, puzzle: p)
        #expect(standing.setFound == 3)
        #expect(standing.setTotal == p.commonWords.count)
        #expect(standing.setFound < standing.setTotal)
    }
}
