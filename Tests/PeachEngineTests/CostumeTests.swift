import CryptoKit
import Foundation
import Testing
@testable import PeachEngine

/// The costumes, held to the peach's box and to the web's table.
@Suite("the costumes")
struct CostumeTests {
    /// The SHA-256 of `canonicalCostumeTable()`. The web pins the same value in
    /// `src/ui/costumes.test.ts`, so a costume or a day changed in one app and
    /// not the other fails in the one that was not changed.
    static let tableSHA256 = "6ce9309b2de3cbd9d651cb6213ef02a4e3bff819f299e62c130a403e66cf97a0"

    @Test("every part is absolute M, L, C and Z, and parses", arguments: Costume.allCases)
    func parses(costume: Costume) throws {
        for part in costume.parts {
            let letters = part.d.filter(\.isLetter)
            #expect(letters.allSatisfy { "MLCZ".contains($0) }, "\(costume): \(part.d)")
            #expect(try !costumeCommands(part.d).isEmpty, "\(costume): \(part.d)")
        }
    }

    /// A cubic lies inside the hull of its four points, so every point inside
    /// the box, less half the stroke, keeps every edge of the costume inside the
    /// peach's footprint.
    @Test("every point stays inside the peach's box, strokes included", arguments: Costume.allCases)
    func staysInTheBox(costume: Costume) throws {
        for part in costume.parts {
            let pad = (part.strokeWidth ?? 0) / 2
            for command in try costumeCommands(part.d) {
                for (x, y) in command.points {
                    #expect((pad...(100 - pad)).contains(x), "\(costume): x \(x) in \(part.d)")
                    #expect((pad...(100 - pad)).contains(y), "\(costume): y \(y) in \(part.d)")
                }
            }
        }
    }

    @Test("each says what the peach is wearing, differently")
    func spoken() {
        let spoken = Costume.allCases.map(\.spoken)
        #expect(Set(spoken).count == Costume.allCases.count)
        #expect(spoken.allSatisfy { $0.count > 4 })
    }

    @Test("is the table the web pins")
    func sameAsTheWeb() {
        let digest = SHA256.hash(data: Data(canonicalCostumeTable().utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        #expect(hex == Self.tableSHA256)
    }

    @Test("reads SVG numbers as SVG does")
    func parser() throws {
        #expect(try costumeCommands("M1 2 L3 4 C5 6 7 8 9 10 Z") == [
            .move(1, 2), .line(3, 4), .curve(c1: (5, 6), c2: (7, 8), to: (9, 10)), .close,
        ])
        #expect(try costumeCommands("M1.5-2 L-3,4") == [.move(1.5, -2), .line(-3, 4)])
        #expect(throws: CostumePathError.self) { try costumeCommands("m1 2 l3 4") }
        #expect(throws: CostumePathError.self) { try costumeCommands("M1 2 C3 4 5 6") }
    }
}
