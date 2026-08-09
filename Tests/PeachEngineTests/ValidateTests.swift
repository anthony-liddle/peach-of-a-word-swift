import Testing
@testable import PeachEngine

@Suite("validateGuess")
struct ValidateTests {
    let puzzle = Fixture.puzzle
    let empty: Set<String> = []

    @Test("accepts a set word with the set rung")
    func setWord() {
        #expect(validateGuess("sea", puzzle: puzzle, found: empty)
                == .valid(word: "sea", score: 1, rung: .set, isSourceWord: false))
    }

    @Test("grades off-page words by rung",
          arguments: [("sneer", Rung.uncommon), ("eased", .rare), ("sane", .mythic)])
    func offPage(word: String, expected: Rung) {
        guard case .valid(_, _, let rung, _) = validateGuess(word, puzzle: puzzle, found: empty)
        else {
            Issue.record("expected \(word) to be valid")
            return
        }
        #expect(rung == expected)
    }

    @Test("flags the source word, still a set word")
    func sourceWord() {
        #expect(validateGuess("serenade", puzzle: puzzle, found: empty)
                == .valid(word: "serenade", score: 15, rung: .set, isSourceWord: true))
    }

    @Test("rejects words below the minimum length")
    func tooShort() {
        #expect(validateGuess("ad", puzzle: puzzle, found: empty) == .tooShort)
    }

    @Test("rejects a non-word and an unformable word the same way")
    func notAWord() {
        #expect(validateGuess("zebra", puzzle: puzzle, found: empty) == .notAWord)
        #expect(validateGuess("xyz", puzzle: puzzle, found: empty) == .notAWord)
    }

    @Test("rejects a word already found")
    func alreadyFound() {
        #expect(validateGuess("sea", puzzle: puzzle, found: ["sea"]) == .alreadyFound)
    }

    @Test("normalizes case and stray characters")
    func normalizes() {
        #expect(normalizeGuess(" SeA! ") == "sea")
        #expect(validateGuess(" SeA! ", puzzle: puzzle, found: empty)
                == .valid(word: "sea", score: 1, rung: .set, isSourceWord: false))
    }
}
