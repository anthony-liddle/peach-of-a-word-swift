import Foundation
import Testing
@testable import PeachEngine

/// Text the light theme drew below WCAG 2.2's 4.5:1, found by the dark mode
/// discovery pass on 11 November 2026, held at 4.5:1 or more.
///
/// **Read from the app's own sources, as `CrownTests` reads `Cute.crown`.**
/// This bundle has no host app, so it can't ask a view for its colour. Each
/// test takes the colour from the line that draws the text, resolves it through
/// `CuteTheme.swift`, and measures it against the page it sits on: both ends of
/// the page's gradient, since the title scrolls and the board's meter sits on
/// whatever part of it is behind it.
@Suite("light theme contrast")
struct LightContrastTests {

    // MARK: - The app's sources

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

    /// Every `Cute` colour's light value, written `static let name = Color(light: 0x…, …)`.
    private static let palette: [String: UInt32] = {
        var out: [String: UInt32] = [:]
        let line = #/static let (\w+) = Color\(light: 0x([0-9A-Fa-f]{6})/#
        for match in appSource("CuteTheme.swift").matches(of: line) {
            out[String(match.output.1)] = UInt32(match.output.2, radix: 16)
        }
        return out
    }()

    private static func token(_ name: Substring) throws -> UInt32 {
        try #require(palette[String(name)], "Cute.\(name) has no hex in CuteTheme.swift")
    }

    /// The page's gradient, top and foot: `Cute.pageBackground`.
    private static func page() throws -> [UInt32] {
        [try token("paper"), try token("pageFoot")]
    }

    // MARK: - WCAG 2.2

    private static func luminance(_ rgb: UInt32) -> Double {
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

    /// `top` at `opacity` over `under`, per channel on the encoded values, as
    /// SwiftUI composites an `.opacity` fill.
    static func over(_ top: UInt32, opacity: Double, _ under: UInt32) -> UInt32 {
        var out: UInt32 = 0
        for shift: UInt32 in [16, 8, 0] {
            let t = Double((top >> shift) & 0xFF), u = Double((under >> shift) & 0xFF)
            out |= UInt32((opacity * t + (1 - opacity) * u).rounded()) << shift
        }
        return out
    }

    private static func hex(_ rgb: UInt32) -> String { String(format: "#%06X", rgb) }

    private static func ratio(_ r: Double) -> String { String(format: "%.2f:1", r) }

    // MARK: - The three

    @Test("the rank's name, once the basket is full, reads at 4.5:1 on the page")
    func fullRankName() throws {
        let meter = Self.appSource("TierMeterView.swift")
        try #require(!meter.isEmpty, "TierMeterView.swift was not found")
        let site = #/Text\(label\)[\s\S]*?\.foregroundStyle\(completed \? Cute\.(\w+) : Cute\.\w+\)/#
        let name = try #require(meter.firstMatch(of: site), "the rank name's colour").output.1
        let ink = try Self.token(name)
        for ground in try Self.page() {
            let r = Self.contrast(ink, ground)
            #expect(r >= 4.5, "Cute.\(name) \(Self.hex(ink)) on \(Self.hex(ground)) is \(Self.ratio(r))")
        }
    }

    @Test("the meter's streak reads at 4.5:1 on the page")
    func meterStreak() throws {
        let meter = Self.appSource("TierMeterView.swift")
        try #require(!meter.isEmpty, "TierMeterView.swift was not found")
        let site = #/Image\(systemName: "flame\.fill"\)[\s\S]*?\.foregroundStyle\(Cute\.(\w+)\)/#
        let name = try #require(meter.firstMatch(of: site), "the streak's colour").output.1
        let ink = try Self.token(name)
        for ground in try Self.page() {
            let r = Self.contrast(ink, ground)
            #expect(r >= 4.5, "Cute.\(name) \(Self.hex(ink)) on \(Self.hex(ground)) is \(Self.ratio(r))")
        }
    }

    /// The cell is drawn over whatever is behind it: Past days' flat paper, or
    /// in the title's week strip, the page's gradient wherever the strip falls.
    @Test("a finished day's number reads at 4.5:1 on any part of the page, the week strip's included")
    func finishedDay() throws {
        let cell = Self.appSource("ArchiveSheet.swift")
        try #require(!cell.isEmpty, "ArchiveSheet.swift was not found")
        let fillSite = #/private var fill: Color \{[\s\S]*?case \.cleared: Cute\.(\w+)(?:\.opacity\(([0-9.]+)\))?\n/#
        let fill = try #require(cell.firstMatch(of: fillSite), "a finished day's fill").output
        let numberSite = #/private var numberColor: Color \{[\s\S]*?case [^\n]*\.cleared[^\n]*: Cute\.(\w+)\n/#
        let number = try #require(cell.firstMatch(of: numberSite), "a finished day's number").output.1
        let ink = try Self.token(number)
        let colour = try Self.token(fill.1)
        let opacity = try fill.2.map { try #require(Double($0)) } ?? 1
        for ground in try Self.page() {
            let face = Self.over(colour, opacity: opacity, ground)
            let r = Self.contrast(ink, face)
            #expect(r >= 4.5, "Cute.\(number) on \(Self.hex(face)), Cute.\(fill.1) at \(opacity) over \(Self.hex(ground)), is \(Self.ratio(r))")
        }
    }
}
