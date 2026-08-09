import Testing
@testable import PeachEngine

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

    // The array-backed variant must agree with the inline one everywhere. If
    // these ever disagree, the Task 15 measurement is comparing two different
    // functions rather than two representations of the same one.
    @Test("the array-backed variant agrees with the inline one",
          arguments: ["sneer", "eased", "zebra", "eee", "eeee", "serenade", "ad", ""])
    func variantsAgree(word: String) {
        #expect(rack.canForm(LetterCounts(word))
                == canFormArray(letterCountsArray("serenade"), word))
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
