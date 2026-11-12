import Foundation
import Testing
@testable import PeachEngine

/// Every pair of colours a player reads, in light, in dark, and in dark with
/// Increase Contrast on, held to WCAG 2.2.
///
/// **Read from `CuteTheme.swift`, as `LightContrastTests` reads it.** This
/// bundle has no host app, so it can't ask a view for its colour. Each `Cute`
/// colour is written `Color(light: 0x…, dark: 0x…, darkHigh: 0x…)`, with
/// `darkHigh` only where Increase Contrast moves it, and the pairs are the dark
/// mode discovery pass's (vault, `reports/2026-11-11 Dark Mode.md`), by token.
///
/// The targets: text at 4.5:1 or more in light and in dark, and at 7:1 or more
/// in dark with Increase Contrast; a control's colour against what it sits on
/// at 3:1 or more in every appearance.
@Suite("appearance contrast")
struct AppearanceContrastTests {

    enum Appearance: String, CaseIterable, CustomStringConvertible {
        case light, dark, darkHigh
        var description: String { rawValue }
        var textFloor: Double { self == .darkHigh ? 7 : 4.5 }
    }

    // MARK: - The app's sources

    /// The source tree first, then the copy bundled for Xcode Cloud.
    static func appSource(_ name: String) -> String {
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

    /// The body of `enum Cute`, so a colour elsewhere in the file isn't read.
    static let cute: String = {
        let theme = appSource("CuteTheme.swift")
        guard let start = theme.range(of: "enum Cute {") else { return "" }
        let rest = theme[start.upperBound...]
        guard let end = rest.range(of: "\n}\n") else { return "" }
        return String(rest[..<end.lowerBound])
    }()

    /// Every `Cute` colour, by name, in each appearance.
    static let palette: [String: [Appearance: UInt32]] = {
        var out: [String: [Appearance: UInt32]] = [:]
        let line = #/static let (\w+) = Color\(light: 0x([0-9A-Fa-f]{6}), dark: 0x([0-9A-Fa-f]{6})(?:, darkHigh: 0x([0-9A-Fa-f]{6}))?\)/#
        for m in cute.matches(of: line) {
            let light = UInt32(m.output.2, radix: 16)!
            let dark = UInt32(m.output.3, radix: 16)!
            let high = m.output.4.flatMap { UInt32($0, radix: 16) } ?? dark
            out[String(m.output.1)] = [.light: light, .dark: dark, .darkHigh: high]
        }
        return out
    }()

    static func colour(_ name: String, _ a: Appearance) throws -> UInt32 {
        try #require(palette[name]?[a], "Cute.\(name) has no light and dark value in CuteTheme.swift")
    }

    // MARK: - WCAG 2.2

    static func luminance(_ rgb: UInt32) -> Double {
        func channel(_ shift: UInt32) -> Double {
            let c = Double((rgb >> shift) & 0xFF) / 255
            return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(16) + 0.7152 * channel(8) + 0.0722 * channel(0)
    }

    static func contrast(_ a: UInt32, _ b: UInt32) -> Double {
        let (la, lb) = (luminance(a), luminance(b))
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    /// `top` at `opacity` over `under`, per channel on the encoded values.
    static func over(_ top: UInt32, opacity: Double, _ under: UInt32) -> UInt32 {
        var out: UInt32 = 0
        for shift: UInt32 in [16, 8, 0] {
            let t = Double((top >> shift) & 0xFF), u = Double((under >> shift) & 0xFF)
            out |= UInt32((opacity * t + (1 - opacity) * u).rounded()) << shift
        }
        return out
    }

    // MARK: - The pairs

    struct Pair: CustomStringConvertible {
        let fg: String
        let bg: String
        var opacity: Double = 1
        let what: String
        var description: String { what }
    }

    /// Text, by the token it is drawn in and the one it is drawn on.
    static let text: [Pair] = [
        Pair(fg: "ink", bg: "paper", what: "text on the page's top"),
        Pair(fg: "ink", bg: "pageFoot", what: "text on the page's foot"),
        Pair(fg: "ink", bg: "paperDeep", what: "text on tiles, the well, pills and cards"),
        Pair(fg: "inkSoft", bg: "paper", what: "soft text on the page's top"),
        Pair(fg: "inkSoft", bg: "pageFoot", what: "soft text on the page's foot"),
        Pair(fg: "inkSoft", bg: "paperDeep", what: "soft text on pills"),
        Pair(fg: "inkFaint", bg: "paper", what: "faint text on the page's top, and a day with no record"),
        Pair(fg: "inkFaint", bg: "pageFoot", what: "faint text on the page's foot"),
        Pair(fg: "inkFaint", bg: "paperDeep", what: "the well's placeholder and disabled labels"),
        Pair(fg: "accent", bg: "paper", what: "pink text on the page's top"),
        Pair(fg: "accent", bg: "pageFoot", what: "pink text on the page's foot"),
        Pair(fg: "accent", bg: "paperDeep", what: "pink text in the well"),
        Pair(fg: "accentDeep", bg: "paper", what: "deep pink on the page's top: the subline, links"),
        Pair(fg: "accentDeep", bg: "pageFoot", what: "deep pink on the page's foot"),
        Pair(fg: "paper", bg: "button", what: "every big pink button's label"),
        Pair(fg: "paperDeep", bg: "accent", what: "the basket-full day's number"),
        Pair(fg: "crownDeep", bg: "paper", what: "the peach of a word, and the streaks, on the page's top"),
        Pair(fg: "crownDeep", bg: "pageFoot", what: "the peach of a word on the page's foot"),
        Pair(fg: "crownDeep", bg: "paperDeep", what: "the peach of a word on a card"),
        Pair(fg: "discovery", bg: "paper", what: "rarity text on the page's top"),
        Pair(fg: "discovery", bg: "pageFoot", what: "rarity text on the page's foot"),
        Pair(fg: "discovery", bg: "paperDeep", what: "rarity text in the well"),
        Pair(fg: "ink", bg: "paperEdge", what: "a started day's number"),
        Pair(fg: "ink", bg: "finishedDay", what: "a finished day's number"),
        Pair(fg: "ink", bg: "paper", opacity: 0.85, what: "No definition on hand"),
    ]

    /// A control's colour against what it sits on.
    static let controls: [Pair] = [
        Pair(fg: "accent", bg: "paperDeep", what: "the meter's pink fill, and a switch that is on"),
        Pair(fg: "discovery", bg: "paperDeep", what: "the meter's purple fill"),
        Pair(fg: "ink", bg: "paper", what: "the meter's outline, and today's ring"),
    ]

    static func ratio(_ p: Pair, _ a: Appearance) throws -> (Double, String) {
        let fg = try colour(p.fg, a), bg = try colour(p.bg, a)
        let ink = p.opacity < 1 ? over(fg, opacity: p.opacity, bg) : fg
        let r = contrast(ink, bg)
        return (r, String(format: "Cute.%@ on Cute.%@ in %@ is %.2f:1", p.fg, p.bg, a.rawValue, r))
    }

    // MARK: - The tests

    @Test("every Cute colour has a light and a dark value, and none is light only")
    func everyColourAdapts() throws {
        try #require(!Self.cute.isEmpty, "enum Cute was not found in CuteTheme.swift")
        #expect(Self.cute.firstMatch(of: #/Color\(hex:/#) == nil,
                "a Cute colour is still Color(hex:), so it stays light in dark")
        let declared = Self.cute.matches(of: #/static let (\w+) = Color\(/#).map { String($0.output.1) }
        #expect(!declared.isEmpty)
        for name in declared {
            #expect(Self.palette[name] != nil, "Cute.\(name) isn't Color(light:dark:)")
        }
    }

    @Test("the page's gradient runs from paper to pageFoot, so it adapts with them")
    func gradientUsesTheTokens() {
        #expect(Self.cute.contains("colors: [paper, pageFoot]"))
    }

    @Test("text reads at 4.5:1 in light and dark, and 7:1 in dark with Increase Contrast",
          arguments: Appearance.allCases)
    func textPairs(_ a: Appearance) throws {
        for p in Self.text {
            let (r, said) = try Self.ratio(p, a)
            #expect(r >= a.textFloor, "\(p.what): \(said)")
        }
    }

    @Test("controls read at 3:1 against what they sit on", arguments: Appearance.allCases)
    func controlPairs(_ a: Appearance) throws {
        for p in Self.controls {
            let (r, said) = try Self.ratio(p, a)
            #expect(r >= 3, "\(p.what): \(said)")
        }
    }

    /// The big pink buttons are the brightest thing on a dark page, and Antoine
    /// asked that they can be toned down in one place.
    @Test("every big pink button fills from Cute.button, one token")
    func pinkButtonsShareOneToken() throws {
        let names = ["CompletionCard.swift", "ContentView.swift", "RungSheet.swift", "HowItWorks.swift",
                     "SourceRevealCard.swift", "SettingsSheet.swift", "TitleScreen.swift"]
        for name in names {
            let source = Self.appSource(name)
            try #require(!source.isEmpty, "\(name) was not found")
            #expect(source.firstMatch(of: #/Capsule\(\)\.(fill|stroke)\([^)]*Cute\.accent\b/#) == nil,
                    "\(name) fills a pink button with Cute.accent, not Cute.button")
            #expect(source.contains("Cute.button"), "\(name) has no Cute.button")
        }
        // Pick word fills through `PillButton`'s own `fill` and `border`.
        let board = Self.appSource("ContentView.swift")
        #expect(board.contains("kind == .primary ? Cute.button"), "Pick word's fill isn't Cute.button")
        #expect(board.contains("case .primary: return Cute.button"), "Pick word's border isn't Cute.button")
        // Its own value, so it can move away from the pink in one place.
        #expect(Self.palette["button"] != nil, "Cute.button has no light and dark value")
    }
}
