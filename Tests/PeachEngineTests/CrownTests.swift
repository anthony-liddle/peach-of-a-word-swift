import CryptoKit
import Foundation
import Testing
@testable import PeachEngine

/// The completion card's crown, held to the web's and to the card that draws
/// it.
///
/// **Which way it guards, and how far.** The hash holds `CompletionCrown` to
/// the web's `CROWN` and `CROWN_ON_PEACH`, both ways: the web's `crown.test.ts`
/// pins the same value. The text checks hold `App/CompletionCard.swift` to
/// drawing that outline at that placement, with no crown of its own, and
/// `Cute.crown` to the table's colour, which the card fills it with.
@Suite("the completion card's crown")
struct CrownTests {
    /// The SHA-256 of `canonicalCrown()`. The web's `CROWN_SHA256` in
    /// `src/ui/crown.test.ts` is the same value.
    static let crownSHA256 = "ce4b0ab3088cfb3039a39bf2c48d15b2358b891659bc15e6ebd8301dd587f75d"

    @Test("is the crown the web pins")
    func approved() {
        let digest = SHA256.hash(data: Data(canonicalCrown().utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        #expect(hex == Self.crownSHA256)
    }

    @Test("its outline is absolute M, L, C and Z, and parses")
    func parses() throws {
        let letters = CompletionCrown.d.filter(\.isLetter)
        #expect(letters.allSatisfy { "MLCZ".contains($0) }, "\(CompletionCrown.d)")
        #expect(letters.first == "M" && letters.last == "Z", "\(CompletionCrown.d)")
        #expect(try !costumeCommands(CompletionCrown.d).isEmpty)
    }

    /// The web's guard, in the peach's own 100 by 100 units: inside the
    /// peach's width, and no higher above its box than the card allows, 18 of
    /// a 112-point peach. A filled outline lies inside the hull of its points,
    /// so the points decide it.
    @Test("stays inside the peach's width, and rises above it no higher than the card allows")
    func staysOnThePeach() throws {
        let c = CompletionCrown.self
        let unit = 100 / Double(c.peach)
        let x0 = Double(c.peach - c.width) / 2 * unit
        let y0 = Double(c.offsetY - c.paddingTop) * unit
        let w = Double(c.width) * unit, h = Double(c.height) * unit
        let rise = Double(c.paddingTop - c.offsetY) / Double(c.peach) * 100
        for command in try costumeCommands(c.d) {
            for (x, y) in command.points {
                let (px, py) = (x0 + x * w / 100, y0 + y * h / 100)
                #expect((0...100).contains(px), "x \(px)")
                #expect(py >= -rise - 1e-9 && py <= 100, "y \(py)")
            }
        }
    }

    /// The source tree first, then the copy bundled for Xcode Cloud.
    private static func appSource(_ name: String) -> String {
        var candidates = [repositoryRoot.appendingPathComponent("App/\(name)")]
        for bundle in Bundle.allBundles {
            if let resources = bundle.resourceURL {
                candidates.append(resources.appendingPathComponent("App/\(name)"))
            }
        }
        for url in candidates {
            if let text = try? String(contentsOf: url, encoding: .utf8) { return text }
        }
        return ""
    }

    @Test("the card fills it with the table's colour")
    func colour() throws {
        let theme = Self.appSource("CuteTheme.swift")
        try #require(!theme.isEmpty, "CuteTheme.swift was not found")
        // The same peach in both appearances: the crown doesn't change in dark.
        let line = #/static let crown = Color\(light: 0x([0-9A-Fa-f]{6}), dark: 0x([0-9A-Fa-f]{6})\)/#
        let match = try #require(theme.firstMatch(of: line), "no Cute.crown").output
        #expect("#" + match.1.uppercased() == CompletionCrown.fill)
        #expect("#" + match.2.uppercased() == CompletionCrown.fill)
    }

    @Test("the card draws the table's outline, where the table places it")
    func cardDrawsTheTable() throws {
        let card = Self.appSource("CompletionCard.swift")
        try #require(!card.isEmpty, "CompletionCard.swift was not found")
        #expect(card.contains("costumeCommands(CompletionCrown.d)"))
        for field in ["peach", "paddingTop", "width", "height", "offsetY"] {
            #expect(card.contains("Place.\(field)"), "the ornament doesn't use \(field)")
        }
        // No crown of its own: no point written as numbers, and no fraction of
        // the frame, as the hand-copied shape had.
        #expect(card.firstMatch(of: #/CGPoint\(x: -?[0-9]/#) == nil,
                "CompletionCard.swift has a point written as numbers")
        #expect(card.firstMatch(of: #/[0-9]\.[0-9]+ \* [wh]\b/#) == nil,
                "CompletionCard.swift has a fraction of a frame")
    }
}
