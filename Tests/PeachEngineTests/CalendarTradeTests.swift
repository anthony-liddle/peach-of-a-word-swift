import CryptoKit
import Foundation
import Testing
@testable import PeachEngine

/// The recorded trades of future days, Antoine's amendment to the append-only
/// calendar: one on 2026-10-20, so the peach's Halloween board is `skeleton`,
/// then on 2026-10-27 a year of holiday words, with the words held back for
/// next year moved past it. A trade re-dates its two days and no other. The web
/// records them in `scripts/data-raw/calendar-trades.tsv` and pins the same
/// hashes in `scripts/build-calendar.test.ts`, so the two copies of the
/// calendar cannot drift apart.
@Suite("the recorded trades of future days")
struct CalendarTradeTests {
    /// Every trade, in order: the day it was made, then each day and the word
    /// it takes. Each applies to the calendar the trades above it left.
    static let trades: [(made: String, first: String, firstWord: String, second: String, secondWord: String)] = [
        ("2026-10-20", "2026-10-31", "skeleton", "2027-05-17", "genetics"),
        ("2026-10-27", "2026-11-26", "thankful", "2027-02-12", "irritate"),
        ("2026-10-27", "2026-12-21", "daylight", "2027-12-15", "football"),
        ("2026-10-27", "2026-12-24", "wondrous", "2027-09-19", "spectrum"),
        ("2026-10-27", "2026-12-25", "wrapping", "2027-05-23", "blasting"),
        ("2026-10-27", "2026-12-31", "midnight", "2027-06-23", "artistic"),
        ("2026-10-27", "2027-01-01", "calendar", "2027-06-27", "proclaim"),
        ("2026-10-27", "2027-02-06", "lifetime", "2027-02-18", "misprint"),
        ("2026-10-27", "2027-02-14", "romantic", "2027-09-04", "bankrupt"),
        ("2026-10-27", "2027-03-20", "fountain", "2028-01-22", "planning"),
        ("2026-10-27", "2027-04-01", "disguise", "2026-12-18", "smoothly"),
        ("2026-10-27", "2027-04-16", "birthday", "2026-12-12", "premises"),
        ("2026-10-27", "2027-04-22", "mountain", "2027-05-27", "rephrase"),
        ("2026-10-27", "2027-06-15", "together", "2027-12-02", "inventor"),
        ("2026-10-27", "2027-06-21", "sunshine", "2027-12-20", "outgoing"),
        ("2026-10-27", "2027-06-23", "original", "2028-02-23", "artistic"),
        ("2026-10-27", "2027-08-24", "gorgeous", "2027-08-28", "learning"),
        ("2026-10-27", "2027-10-31", "frighten", "2027-09-30", "northern"),
        ("2026-10-27", "2026-11-19", "chemical", "2027-11-04", "eternity"),
        ("2026-10-27", "2026-12-02", "keyboard", "2027-11-09", "alphabet"),
        ("2026-10-27", "2027-01-03", "intimate", "2027-11-16", "laughing"),
        ("2026-10-27", "2027-01-07", "constant", "2027-11-19", "umbrella"),
        ("2026-10-27", "2027-01-12", "anecdote", "2027-11-24", "faithful"),
        ("2026-10-27", "2027-02-04", "redefine", "2027-12-01", "generous"),
        ("2026-10-27", "2027-02-09", "detector", "2027-12-06", "delicate"),
        ("2026-10-27", "2027-02-11", "previous", "2027-12-12", "grateful"),
        ("2026-10-27", "2027-02-13", "personal", "2027-12-17", "freezing"),
        ("2026-10-27", "2027-02-24", "suppress", "2027-12-23", "sunlight"),
        ("2026-10-27", "2027-03-13", "sufferer", "2027-12-28", "farewell"),
        ("2026-10-27", "2027-04-18", "distract", "2028-01-02", "heritage"),
        ("2026-10-27", "2027-04-23", "marriage", "2028-01-09", "newcomer"),
        ("2026-10-27", "2027-05-11", "regional", "2028-01-14", "sinister"),
        ("2026-10-27", "2027-05-18", "puncture", "2028-01-19", "emerging"),
        ("2026-10-27", "2027-05-25", "formally", "2028-01-24", "vacation"),
        ("2026-10-27", "2027-06-10", "supplier", "2028-01-29", "postcard"),
        ("2026-10-27", "2027-06-29", "instruct", "2028-02-04", "universe"),
        ("2026-10-27", "2027-07-03", "consumer", "2028-02-09", "cheerful"),
        ("2026-10-27", "2027-07-06", "discover", "2028-02-15", "peculiar"),
        ("2026-10-27", "2027-08-23", "distress", "2028-02-20", "goodness"),
        ("2026-10-27", "2027-08-26", "document", "2028-02-25", "stuffing"),
        ("2026-10-27", "2027-09-23", "suddenly", "2028-03-01", "creation"),
        ("2026-10-27", "2027-09-24", "paranoia", "2028-03-07", "elephant"),
    ]

    /// Every day the year of words changed, and the word it now has.
    static let changed: [(day: String, word: String)] = [
        ("2026-11-19", "chemical"),
        ("2026-11-26", "thankful"),
        ("2026-12-02", "keyboard"),
        ("2026-12-12", "premises"),
        ("2026-12-18", "smoothly"),
        ("2026-12-21", "daylight"),
        ("2026-12-24", "wondrous"),
        ("2026-12-25", "wrapping"),
        ("2026-12-31", "midnight"),
        ("2027-01-01", "calendar"),
        ("2027-01-03", "intimate"),
        ("2027-01-07", "constant"),
        ("2027-01-12", "anecdote"),
        ("2027-02-04", "redefine"),
        ("2027-02-06", "lifetime"),
        ("2027-02-09", "detector"),
        ("2027-02-11", "previous"),
        ("2027-02-12", "irritate"),
        ("2027-02-13", "personal"),
        ("2027-02-14", "romantic"),
        ("2027-02-18", "misprint"),
        ("2027-02-24", "suppress"),
        ("2027-03-13", "sufferer"),
        ("2027-03-20", "fountain"),
        ("2027-04-01", "disguise"),
        ("2027-04-16", "birthday"),
        ("2027-04-18", "distract"),
        ("2027-04-22", "mountain"),
        ("2027-04-23", "marriage"),
        ("2027-05-11", "regional"),
        ("2027-05-18", "puncture"),
        ("2027-05-23", "blasting"),
        ("2027-05-25", "formally"),
        ("2027-05-27", "rephrase"),
        ("2027-06-10", "supplier"),
        ("2027-06-15", "together"),
        ("2027-06-21", "sunshine"),
        ("2027-06-23", "original"),
        ("2027-06-27", "proclaim"),
        ("2027-06-29", "instruct"),
        ("2027-07-03", "consumer"),
        ("2027-07-06", "discover"),
        ("2027-08-23", "distress"),
        ("2027-08-24", "gorgeous"),
        ("2027-08-26", "document"),
        ("2027-08-28", "learning"),
        ("2027-09-04", "bankrupt"),
        ("2027-09-19", "spectrum"),
        ("2027-09-23", "suddenly"),
        ("2027-09-24", "paranoia"),
        ("2027-09-30", "northern"),
        ("2027-10-31", "frighten"),
        ("2027-11-04", "eternity"),
        ("2027-11-09", "alphabet"),
        ("2027-11-16", "laughing"),
        ("2027-11-19", "umbrella"),
        ("2027-11-24", "faithful"),
        ("2027-12-01", "generous"),
        ("2027-12-02", "inventor"),
        ("2027-12-06", "delicate"),
        ("2027-12-12", "grateful"),
        ("2027-12-15", "football"),
        ("2027-12-17", "freezing"),
        ("2027-12-20", "outgoing"),
        ("2027-12-23", "sunlight"),
        ("2027-12-28", "farewell"),
        ("2028-01-02", "heritage"),
        ("2028-01-09", "newcomer"),
        ("2028-01-14", "sinister"),
        ("2028-01-19", "emerging"),
        ("2028-01-22", "planning"),
        ("2028-01-24", "vacation"),
        ("2028-01-29", "postcard"),
        ("2028-02-04", "universe"),
        ("2028-02-09", "cheerful"),
        ("2028-02-15", "peculiar"),
        ("2028-02-20", "goodness"),
        ("2028-02-23", "artistic"),
        ("2028-02-25", "stuffing"),
        ("2028-03-01", "creation"),
        ("2028-03-07", "elephant"),
    ]

    static let yearOfWords = trades.filter { $0.made == "2026-10-27" }

    static func raw() throws -> String {
        try String(contentsOf: dataDirectory.appendingPathComponent("daily-calendar.json"), encoding: .utf8)
    }

    static func sha256(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    /// The shipped bytes with these trades undone, last first, by swapping quoted words.
    static func undone(_ rows: [(made: String, first: String, firstWord: String, second: String, secondWord: String)]) throws -> String {
        try rows.reversed().reduce(raw()) { text, t in
            text.replacingOccurrences(of: "\"\(t.firstWord)\"", with: "\"\u{0}\"")
                .replacingOccurrences(of: "\"\(t.secondWord)\"", with: "\"\(t.firstWord)\"")
                .replacingOccurrences(of: "\"\u{0}\"", with: "\"\(t.secondWord)\"")
        }
    }

    static func words(_ json: String) throws -> [String] {
        struct File: Decodable { let words: [String] }
        return try JSONDecoder().decode(File.self, from: Data(json.utf8)).words
    }

    private let utc = TimeZone(identifier: "UTC")!

    private func date(_ iso: String) -> Date {
        var cal = Foundation.Calendar(identifier: .gregorian)
        cal.timeZone = utc
        let parts = iso.split(separator: "-").map { Int($0)! }
        return cal.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12))!
    }

    @Test("is the calendar the web ships, byte for byte")
    func sameAsTheWeb() throws {
        #expect(Self.sha256(try Self.raw())
            == "32c3ed91528d4c64857d8da41e3362b358789639aaf178bc1129d54faa460ec2")
    }

    @Test("records the Halloween trade and the year of words")
    func theRecord() {
        #expect(Self.trades.count == 42)
        #expect(Self.yearOfWords.count == 41)
        #expect(Self.changed.count == 81)
    }

    @Test("gives every changed day its new word")
    func everyChangedDay() throws {
        let words = try DailySequencePinTests.calendarWords()
        for (day, word) in Self.changed {
            #expect(try dailySourceWord(calendar: words, date: date(day), timeZone: utc) == word, "\(day)")
        }
    }

    @Test("keeps skeleton on 31 October 2026, and genetics on 17 May 2027")
    func halloweenStays() throws {
        let words = try DailySequencePinTests.calendarWords()
        #expect(try dailySourceWord(calendar: words, date: date("2026-10-31"), timeZone: utc) == "skeleton")
        #expect(try dailySourceWord(calendar: words, date: date("2027-05-17"), timeZone: utc) == "genetics")
    }

    @Test("traded only days still to come, and nothing before 8 November this time")
    func onlyFutureDays() {
        for t in Self.trades {
            #expect(t.first > t.made && t.second > t.made, "\(t.first) and \(t.second), made \(t.made)")
        }
        // A week past the last day these can merge, so Bea's phone has them first.
        for t in Self.yearOfWords {
            #expect(t.first >= "2026-11-08" && t.second >= "2026-11-08", "\(t.first) and \(t.second)")
        }
    }

    @Test("moved no other index: undone, it is the calendar before")
    func nothingElseMoved() throws {
        // Before the year of words: main as Halloween left it.
        #expect(Self.sha256(try Self.undone(Self.yearOfWords))
            == "ea5b0dc1855d28c947fecafc365f4c50095dfed1a59d46cc965590a6b719e8d2")
        // Before any trade: the calendar as the web's generator built it.
        #expect(Self.sha256(try Self.undone(Self.trades))
            == "dddc844300ab461a1ba1bd217daefa6fcc1e9e5a2abb23bdefbb841d73f17163")
    }

    @Test("holds the same words: none added, none lost, none repeated")
    func sameWords() throws {
        let now = try DailySequencePinTests.calendarWords()
        let before = try Self.words(Self.undone(Self.trades))
        #expect(now.sorted() == before.sorted())
        #expect(Set(now).count == now.count)
        #expect(now.count == 626)
    }

    @Test("moves only the traded words, in this cycle and every reshuffled one after it")
    func everyOtherDateStays() throws {
        // After 9 March 2028 the calendar reshuffles by index, so a traded word
        // takes its new index into every later cycle, and every other date stays.
        let now = try DailySequencePinTests.calendarWords()
        let before = try Self.words(Self.undone(Self.trades))
        // `becomes` holds that a word keeps its index into every cycle; `moved`
        // holds that only the words the record names change dates.
        let becomes = Dictionary(uniqueKeysWithValues: zip(before, now))
        let moved = Set(Self.trades.flatMap { [$0.firstWord, $0.secondWord] })
        var cal = Foundation.Calendar(identifier: .gregorian)
        cal.timeZone = utc
        let start = date("2026-06-23")
        var firstCycle = 0
        for d in 0..<(365 * 6) {
            let day = cal.date(byAdding: .day, value: d, to: start)!
            let today = try dailySourceWord(calendar: now, date: day, timeZone: utc)
            let then = try dailySourceWord(calendar: before, date: day, timeZone: utc)
            #expect(today == becomes[then], "\(day)")
            if !moved.contains(then) { #expect(today == then, "\(day)") }
            if d < now.count, today != then { firstCycle += 1 }
        }
        // The 81 days of the year of words and Halloween's two.
        #expect(firstCycle == 83)
    }
}
