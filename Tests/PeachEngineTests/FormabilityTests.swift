import Testing
@testable import PeachEngine

/// A deliberately naive letter counter, used only to check `LetterCounts`
/// against a second opinion.
///
/// This used to live in the library as `letterCountsArray` / `canFormArray`,
/// because `LetterCounts` was backed by `InlineArray` and the pair existed to
/// measure the two representations against each other. `LetterCounts` is now
/// itself `[Int8]`-backed, so a second `[Int8]` implementation in the library
/// would be pure duplication: two computations of one fact with nothing forcing
/// them to agree, which is the exact bug shape this project has now found five
/// times in the web repo.
///
/// A reference implementation is still worth having. It just belongs in the
/// tests, where being a duplicate is the point, rather than in the shipped API.
private func referenceCanForm(rack: String, word: String) -> Bool {
    func counts(_ s: String) -> [Int] {
        var out = [Int](repeating: 0, count: 26)
        for byte in s.utf8 where byte >= 97 && byte <= 122 {
            out[Int(byte) - 97] += 1
        }
        return out
    }
    let have = counts(rack)
    let need = counts(word)
    return (0..<26).allSatisfy { need[$0] <= have[$0] }
}

@Suite("canForm")
struct CanFormTests {
    // `let` properties on a @Suite struct replace vitest's module-level consts.
    // Swift Testing creates a fresh instance per test, so this is also the
    // `beforeEach` replacement: no shared mutable state between tests.
    let rack = LetterCounts("serenade")  // s e r e n a d e -> three e's

    @Test("forms a word using available tiles")
    func forms() {
        #expect(rack.canForm(LetterCounts("sneer")))
        #expect(rack.canForm(LetterCounts("eased")))
    }

    @Test("respects tile multiplicity")
    func multiplicity() {
        #expect(!LetterCounts("eeen").canForm(LetterCounts("eeee")))
        #expect(rack.canForm(LetterCounts("eee")))
    }

    @Test("rejects words needing a letter not in the rack")
    func missingLetter() {
        #expect(!rack.canForm(LetterCounts("zebra")))
    }

    @Test("agrees with an independent reference implementation",
          arguments: ["sneer", "eased", "zebra", "eee", "eeee", "serenade", "ad", ""])
    func matchesReference(word: String) {
        #expect(rack.canForm(LetterCounts(word))
                == referenceCanForm(rack: "serenade", word: word))
    }
}

@Suite("formableFrom")
struct FormableFromTests {
    @Test("keeps formable words of length 3 and up, in input order")
    func filters() {
        let words = ["ad", "sea", "sneer", "zebra", "serene"]
        // "ad" is too short; "zebra" needs a z. "serene" needs three e's, and
        // "serenade" has exactly three.
        #expect(formableFrom(rack: "serenade", words: words) == ["sea", "sneer", "serene"])
    }
}
