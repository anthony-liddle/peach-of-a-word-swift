import CryptoKit
import Foundation
import Testing
@testable import PeachEngine

/// 31 October 2026 stays exactly as it is: `skeleton`'s board, its basket, its
/// reveal and every found-word card on its board, held to what shipped for the
/// ghost sheet. A dictionary release must not touch Halloween. The web pins the
/// same day in `scripts/halloween.test.ts`, and orchard pins the same board and
/// basket at the source.
@Suite("31 October 2026, skeleton")
struct HalloweenBoardTests {
    static func sha256(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    static func puzzle() throws -> Puzzle {
        let boundary = try readWordList("enable.txt") + readWordList("scowl95-additions.txt")
        return createPuzzle(
            sourceWord: "skeleton",
            dictionary: ListDictionary(boundary),
            commonPool: ListWordSource(try readWordList("common-pool.txt")),
            beyond70Pool: ListWordSource(try readWordList("beyond-size-70.txt")),
            beyond95Pool: ListWordSource(try readWordList("beyond-size-95.txt"))
        )
    }

    @Test("keeps its board of 241 words and its basket of 47")
    func boardAndBasket() throws {
        let p = try Self.puzzle()
        let board = p.validationWords.sorted()
        let basket = p.commonWords.sorted()
        #expect(board.count == 241)
        #expect(Self.sha256(board.joined(separator: "\n"))
            == "5ea4bfeb47fa097b9508aae2c39d553ad77f1ad4176032913d5cff961ceee1ab")
        #expect(basket.count == 47)
        #expect(Self.sha256(basket.joined(separator: "\n"))
            == "53a525cb65b7a093778f12c7d2dd19c07aa805ce527e8adf9f5173ba366d1d15")
    }

    @Test("keeps its reveal, and every found-word card on its board")
    func cards() throws {
        let row = try String(contentsOf: dataDirectory.appendingPathComponent("etymology.tsv"), encoding: .utf8)
            .split(separator: "\n").first { $0.hasPrefix("skeleton\t") }
        #expect(Self.sha256(String(row ?? "")) == "2d582608a4094cfb21f335359bb010a60113d08b14629a8302b6144ffd35d492")

        let definitions = readDefinitions()
        let cards = try Self.puzzle().validationWords.sorted()
            .compactMap { word in definitions[word].map { "\(word)\t\($0)" } }
        #expect(cards.count == 211)
        #expect(Self.sha256(cards.joined(separator: "\n"))
            == "a4d850b77a7e696fbd1dd5bcdbe565be4f46d0228c599d5d8ec4135413baf513")
    }
}
