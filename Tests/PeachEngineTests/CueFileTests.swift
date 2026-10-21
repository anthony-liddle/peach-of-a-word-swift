import Foundation
import Testing
@testable import PeachEngine

/// The cue file the app ships, and the names the app can ask it for.
///
/// **A name the file lacks plays nothing and says nothing.** The player throws
/// for it, the app ignores the throw rather than crash a game over a sound, and
/// the find goes silent. Nothing on screen changes, so a misspelt name would
/// ship. This is what stops it: every name `Cue` can produce, over every case
/// and every length, must be one of the file's.
///
/// The file is read through `dataDirectory`, so this runs from the bundled copy
/// on Xcode Cloud, which has no checkout.
@Suite("the cue file and the cues the app asks for")
struct CueFileTests {
    /// The file's cue names, read with Foundation. Soundscape reads the file
    /// with its own JSON reader, which disagrees with Foundation's on repeated
    /// keys and number forms; neither reaches a list of names.
    static func fileNames() throws -> Set<String> {
        let data = try Data(contentsOf: dataDirectory.appendingPathComponent("peach.cues.json"))
        let document = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let cues = try #require(document["cues"] as? [String: Any])
        return Set(cues.keys)
    }

    /// Every name the app can ask for: each case, and a found cue at every
    /// length from none to well past the rack, at every rung. Lengths outside
    /// the file's are in the sweep on purpose, since the web holds them to the
    /// nearest and so must this.
    static let askable: Set<String> = {
        var cues: [Cue] = [.tick, .source, .edition, .invalid]
        for length in 0...16 {
            for rung in Rung.allCases { cues.append(.found(length: length, rung: rung)) }
        }
        return Set(cues.map(\.name))
    }()

    @Test("has the web's 34 cues")
    func thirtyFour() throws {
        #expect(try Self.fileNames().count == 34)
    }

    @Test("has every cue the app can ask for")
    func everyAskableNameIsInTheFile() throws {
        let missing = Self.askable.subtracting(try Self.fileNames())
        #expect(missing.isEmpty, "the app can ask for cues the file lacks: \(missing.sorted())")
    }

    /// The other direction, so a cue the app should play and never asks for
    /// fails too: of the 34, the app plays 28, and the six it leaves are the
    /// letterpress theme's mythic finds, at each length.
    @Test("leaves unasked only the letterpress theme's mythic cues")
    func theUnaskedAreLetterpress() throws {
        let unasked = try Self.fileNames().subtracting(Self.askable)
        #expect(Self.askable.count == 28)
        #expect(unasked == Set(Cue.foundLengths.map { "found-\($0)-mythic-letterpress" }))
    }

    /// The web reads the lengths off the file's names (`FOUND_LENGTHS` in
    /// `SoundscapeAudioEngine.ts`); this app writes them down. A file that grew
    /// a `found-9-set` would leave the app holding nine-letter finds to eight,
    /// asking only for names that exist, so the sweep above would pass. This
    /// is what fails.
    @Test("covers exactly the lengths the app holds a find to")
    func foundLengths() throws {
        let lengths = try Self.fileNames().compactMap { name -> Int? in
            guard name.hasPrefix("found-"), name.hasSuffix("-set") else { return nil }
            return Int(name.dropFirst("found-".count).dropLast("-set".count))
        }
        #expect(Set(lengths) == Set(Cue.foundLengths))
    }
}
