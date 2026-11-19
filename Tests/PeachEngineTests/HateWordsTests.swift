import Foundation
import Testing
@testable import PeachEngine

/// Hate salutes, symbols and group names, denied in orchard v1.11.2 (Antoine,
/// 19 November 2026: "They'll find no representation in this game."), asserted
/// against the lists and the corpus this app ships.
///
/// The racks here are made up, so no test names a real day's board.
@Suite("hate salutes, symbols and group names are not words here")
struct HateWordsTests {

    static let denied = [
        "heil", "heiled", "heiling", "heils",
        "nazi", "nazis", "nazism", "naziism",
        "nazify", "nazified", "nazifies", "nazifying", "nazification", "nazifications",
        "denazify", "denazified", "denazifies", "denazifying", "denazification", "denazifications",
        "klan", "klans", "klanism", "klansman", "klansmen",
    ]

    /// Unrelated words that only share the letters.
    static let kept = ["nazir", "nazirs", "nazirite", "nazim", "heild", "klang"]

    static func boundary() throws -> Set<String> {
        Set(try readWordList("enable.txt") + readWordList("scowl95-additions.txt"))
    }

    /// A puzzle built from the shipped lists, the way the app builds one.
    static func puzzle(for rack: String) throws -> Puzzle {
        createPuzzle(
            sourceWord: rack,
            dictionary: ListDictionary(Array(try boundary())),
            commonPool: ListWordSource(try readWordList("common-pool.txt")),
            beyond70Pool: ListWordSource(try readWordList("beyond-size-70.txt")),
            beyond95Pool: ListWordSource(try readWordList("beyond-size-95.txt"))
        )
    }

    @Test("heil, nazi and klansman are answered as if they were not words")
    func refused() throws {
        let salute = try Self.puzzle(for: "heilnazi")
        #expect(validateGuess("heil", puzzle: salute, found: []) == .notAWord)
        #expect(validateGuess("nazi", puzzle: salute, found: []) == .notAWord)
        let group = try Self.puzzle(for: "klansman")
        #expect(validateGuess("klansman", puzzle: group, found: []) == .notAWord)
    }

    @Test("nazir and klang, which only share the letters, are still words")
    func lookAlikesKept() throws {
        if case .valid = validateGuess("nazir", puzzle: try Self.puzzle(for: "nazirhel"), found: []) {
        } else {
            Issue.record("nazir should be a word")
        }
        if case .valid = validateGuess("klang", puzzle: try Self.puzzle(for: "klangzip"), found: []) {
        } else {
            Issue.record("klang should be a word")
        }
        let boundary = try Self.boundary()
        for word in Self.kept { #expect(boundary.contains(word), "\(word)") }
    }

    @Test("no list carries any form of them")
    func inNoList() throws {
        for name in ["enable.txt", "scowl95-additions.txt", "common-pool.txt",
                     "beyond-size-70.txt", "beyond-size-95.txt"] {
            let list = Set(try readWordList(name))
            for word in Self.denied { #expect(!list.contains(word), "\(word) in \(name)") }
        }
    }

    @Test("no card ships for any of them")
    func noCard() {
        let definitions = readDefinitions()
        #expect(!definitions.isEmpty)
        for word in Self.denied { #expect(definitions[word] == nil, "\(word)") }
    }

    /// The half of the two-list rule this app lacked: a word the lists no
    /// longer accept goes from a saved day when the day opens, with its points.
    /// It used to stay, graded Mythic, since `classifyWord` grades anything
    /// outside the three bands that way.
    @Test("a saved find of one goes when its day opens, and so do its points")
    func savedFindGoes() throws {
        let puzzle = try Self.puzzle(for: "heilnazi")
        let kept = ["hail", "nail"]
        for word in kept { #expect(puzzle.validationWords.contains(word), "\(word)") }
        let restored = restoredFinds(["heil", "hail", "nail", "nazi"], on: puzzle)
        #expect(restored == kept)
        #expect(computeTier(found: Set(restored), puzzle: puzzle).score
                == computeTier(found: Set(kept), puzzle: puzzle).score)
    }
}
