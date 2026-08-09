import Testing
@testable import PeachEngine

@Suite("eligibility")
struct EligibilityTests {
    /// Distinct strings formable from `rack` (each letter used at most once),
    /// length 3, used to build synthetic pools with a known set size.
    func formableTriples(_ rack: String, count: Int) -> [String] {
        let letters = Array(rack)
        var out: [String] = []
        for i in 0..<letters.count {
            for j in (i + 1)..<letters.count {
                for k in (j + 1)..<letters.count {
                    out.append(String([letters[i], letters[j], letters[k]]))
                    if out.count == count { return out }
                }
            }
        }
        fatalError("rack too small for requested count")
    }

    let rack = "abcdefgh"
    let empty = ListWordSource([])

    @Test("counts the set the game would build (crown-inclusive)")
    func setSize() {
        let words = formableTriples(rack, count: minSetSize)
        #expect(sourceSetSize(rack,
                              dictionary: ListDictionary(words),
                              commonPool: ListWordSource(words),
                              beyond70Pool: empty,
                              beyond95Pool: empty) == minSetSize)
    }

    @Test("is eligible at the floor and ineligible one below it",
          arguments: [(15, true), (14, false)])
    func floor(size: Int, expected: Bool) {
        let words = formableTriples(rack, count: size)
        #expect(isEligibleSource(rack,
                                 dictionary: ListDictionary(words),
                                 commonPool: ListWordSource(words),
                                 beyond70Pool: empty,
                                 beyond95Pool: empty) == expected)
    }

    @Test("keeps only candidates whose set clears the floor, in input order")
    func filters() {
        // Disjoint letter sets: 'abcdefgh' forms 15 set words, 'ijklmnop' 14.
        let rich = formableTriples("abcdefgh", count: 15)
        let thin = formableTriples("ijklmnop", count: 14)
        let all = rich + thin
        #expect(eligibleSourceWords(["abcdefgh", "ijklmnop"],
                                    dictionary: ListDictionary(all),
                                    commonPool: ListWordSource(all),
                                    beyond70Pool: empty,
                                    beyond95Pool: empty) == ["abcdefgh"])
    }
}
