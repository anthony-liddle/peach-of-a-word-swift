import Foundation
import Testing
@testable import PeachEngine

/// Parsing the days a web player pastes into the app.
///
/// The text comes off a clipboard, from the web's transfer page, by way of
/// whatever the player sent it through. Nothing in it is trusted: the parse
/// decides only whether it's a days payload at all, and keeps what has the
/// shape of a day. Whether a day's crown and words belong is the import's job.
@Suite("DaysTransfer parsing")
struct DaysTransferTests {
    /// A payload as the page writes one, from a JSON body.
    static func payload(_ json: String) -> String {
        "Peach of a Word days: " + Data(json.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// The web's own payloads, from the shared fixture by way of
    /// `scripts/days-payload-parity.mjs` in the web repo.
    ///
    /// **One direction, at three payloads:** that this parser reads what the
    /// page writes. The web's `days.test.ts` holds its writer to the same rows.
    /// Nothing keeps the two copies in step but that script.
    @Test("parses every payload the web's transfer page writes", arguments: daysPayloadVectors)
    func parsesTheWebsPayloads(vector: DaysPayloadVector) throws {
        let t = try #require(DaysTransfer(text: vector.text))
        #expect(t.streak?.count == vector.streak?.count)
        #expect(t.streak?.lastClearedDayIndex == vector.streak?.lastClearedDayIndex)
        #expect(t.days.count == vector.days.count)
        for (day, crown, found) in vector.days {
            #expect(t.days[day] == DaysTransfer.Day(sourceWord: crown, found: found))
        }
        #expect(t.unreadableWords == 0)
    }

    /// A mail program can wrap a long line anywhere, the opening included.
    @Test("whitespace anywhere is ignored, the opening's included")
    func whitespaceAnywhere() throws {
        let text = Self.payload(#"{"v":1,"days":{"300":{"sourceWord":"serenade","found":["sea","near"]}}}"#)
        var wrapped = ""
        for (i, ch) in text.enumerated() {
            wrapped.append(ch)
            if i % 7 == 3 { wrapped.append(i % 2 == 0 ? "\n" : " \r\n\t") }
        }
        let t = try #require(DaysTransfer(text: "  \n" + wrapped + "\n "))
        #expect(t.days[300]?.found == ["sea", "near"])
    }

    @Test(arguments: [
        "",
        "Hello",
        "eyJ2IjoxfQ",                                   // the body without the opening
        "Peach of a Word streak: eyJ2IjoxfQ",           // another opening
        "Peach of a Word days:",                        // the opening alone
        "Peach of a Word days: !!!not base64!!!",
        "Peach of a Word days: bm90IGpzb24",            // "not json"
    ])
    func refusesWhatIsntAPayload(text: String) {
        #expect(DaysTransfer(text: text) == nil)
    }

    /// Required, not defaulted: a later format must be refused rather than
    /// read for the fields this build happens to recognise.
    @Test(arguments: [
        #"{"days":{}}"#,
        #"{"v":2,"days":{}}"#,
        #"{"v":"1","days":{}}"#,
    ])
    func refusesAnotherVersion(json: String) {
        #expect(DaysTransfer(text: Self.payload(json)) == nil)
    }

    @Test("refuses text past the cap before decoding any of it")
    func refusesTooLong() {
        let text = "Peach of a Word days: " + String(repeating: "A", count: DaysTransfer.maxLength)
        #expect(DaysTransfer(text: text) == nil)
    }

    @Test("a year at the most words the lists allow fits under the cap")
    func aYearFits() throws {
        // About 205 words of eight letters a day, the ceiling's measure.
        let letters = Array("abcdefghij")
        let words = (0..<205).map { n in
            "w" + String(String(format: "%07d", n).map { letters[$0.wholeNumberValue!] })
        }
        let day = #"{"sourceWord":"serenade","found":["# + words.map { "\"\($0)\"" }.joined(separator: ",") + "]}"
        let days = (173..<538).map { "\"\($0)\":\(day)" }.joined(separator: ",")
        let text = Self.payload(#"{"v":1,"days":{"# + days + "}}")
        #expect(text.count < DaysTransfer.maxLength)
        let t = try #require(DaysTransfer(text: text))
        #expect(t.days.count == 365)
    }

    @Test("keeps what has a day's shape, and counts the words it drops")
    func keepsWhatHasTheShape() throws {
        let json = #"""
        {"v":1,"days":{
          "300":{"sourceWord":"serenade","found":["sea","NEAR","ne","toolongword","de an","near","sea"]},
          "301":{"sourceWord":"SERENADE","found":["sea"]},
          "302":{"sourceWord":"seren","found":["sea"]},
          "303":{"sourceWord":"serenade","found":"sea"},
          "soon":{"sourceWord":"serenade","found":["sea"]},
          "-4":{"sourceWord":"serenade","found":["sea"]},
          "304":{"sourceWord":"serenade","found":[]}
        }}
        """#
        let t = try #require(DaysTransfer(text: Self.payload(json)))
        #expect(Array(t.days.keys) == [300])
        // Each word once, in the order first seen.
        #expect(t.days[300]?.found == ["sea", "near"])
        #expect(t.unreadableWords == 4)
    }

    @Test("a streak is kept only as two whole numbers, the count above zero")
    func theStreak() throws {
        let going = try #require(DaysTransfer(text: Self.payload(#"{"v":1,"streak":{"count":4,"lastClearedDayIndex":318},"days":{}}"#)))
        #expect(going.streak == DaysTransfer.Streak(count: 4, lastClearedDayIndex: 318))
        for json in [
            #"{"v":1,"days":{}}"#,
            #"{"v":1,"streak":{"count":0,"lastClearedDayIndex":318},"days":{}}"#,
            #"{"v":1,"streak":{"count":4},"days":{}}"#,
            #"{"v":1,"streak":{"count":4.5,"lastClearedDayIndex":318},"days":{}}"#,
            #"{"v":1,"streak":"long","days":{}}"#,
        ] {
            let t = try #require(DaysTransfer(text: Self.payload(json)), "\(json)")
            #expect(t.streak == nil, "\(json)")
        }
    }
}
