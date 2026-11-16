import Foundation

/// A web player's days and streak, as the web's transfer page copies them for
/// the app's paste: "Peach of a Word days: ", then base64url of
/// `{"v":1,"streak":{...},"days":{...}}`, in the web save's own shape.
///
/// **Nothing here is trusted.** The text comes off a clipboard by way of
/// whatever the player sent it through. The parse decides whether it's a days
/// payload at all, and keeps what has the shape of a day: whether a day's crown
/// and words belong is `GameStorage.planImport`'s and `applyImport`'s job.
///
/// **Unauthenticated, for the reason `StreakTransfer` gives,** and under the same
/// condition: if players' scores ever become comparable, sign it or remove it
/// before that ships. What changes with days is that one paste writes many
/// values the app never lowers, so the import asks first and checks every word
/// against its day's board.
public struct DaysTransfer: Equatable, Sendable {
    public struct Streak: Equatable, Sendable {
        public let count: Int
        public let lastClearedDayIndex: Int

        public init(count: Int, lastClearedDayIndex: Int) {
            self.count = count
            self.lastClearedDayIndex = lastClearedDayIndex
        }
    }

    public struct Day: Equatable, Sendable {
        public let sourceWord: String
        /// Each word once, in the order the web found them.
        public let found: [String]

        public init(sourceWord: String, found: [String]) {
            self.sourceWord = sourceWord
            self.found = found
        }
    }

    /// The opening, matched with all whitespace removed from the text first, so
    /// a payload a mail program wraps across lines, the opening included, still
    /// reads.
    static let opening = "PeachofaWorddays:"

    /// The longest text read at all, checked before any decoding. A year of
    /// days at the most words the lists allow is about 750,000 characters.
    public static let maxLength = 2_000_000

    /// The only version this reads. Required, not defaulted, as `StreakTransfer`
    /// requires `v`: a later format is refused rather than read for the fields
    /// this build happens to recognise.
    static let version = 1

    public let streak: Streak?
    public let days: [Int: Day]
    /// Words dropped for their shape: not three to eight lowercase letters.
    public let unreadableWords: Int

    public init(streak: Streak?, days: [Int: Day], unreadableWords: Int) {
        self.streak = streak
        self.days = days
        self.unreadableWords = unreadableWords
    }

    /// Nil when the text isn't a days payload this build reads.
    public init?(text: String) {
        guard text.utf8.count <= Self.maxLength + 64 else { return nil }
        let compact = String(text.unicodeScalars.filter {
            !CharacterSet.whitespacesAndNewlines.contains($0)
        }.map(Character.init))
        guard compact.hasPrefix(Self.opening), compact.count <= Self.maxLength else { return nil }

        var body = String(compact.dropFirst(Self.opening.count))
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        body += String(repeating: "=", count: (4 - body.count % 4) % 4)
        guard !body.isEmpty,
              let data = Data(base64Encoded: body),
              let object = try? JSONSerialization.jsonObject(with: data),
              let root = object as? [String: Any],
              Self.wholeNumber(root["v"]) == Self.version
        else { return nil }

        var unreadable = 0
        var days: [Int: Day] = [:]
        for (key, value) in root["days"] as? [String: Any] ?? [:] {
            guard key.allSatisfy(\.isASCII), key.allSatisfy(\.isNumber), let day = Int(key),
                  let entry = value as? [String: Any],
                  let crown = entry["sourceWord"] as? String, Self.isCrown(crown),
                  let found = entry["found"] as? [Any]
            else { continue }
            var words: [String] = []
            var seen = Set<String>()
            for item in found {
                guard let word = item as? String, Self.isWord(word) else {
                    unreadable += 1
                    continue
                }
                if seen.insert(word).inserted { words.append(word) }
            }
            if !words.isEmpty { days[day] = Day(sourceWord: crown, found: words) }
        }

        var streak: Streak?
        if let pair = root["streak"] as? [String: Any],
           let count = Self.wholeNumber(pair["count"]), count > 0,
           let last = Self.wholeNumber(pair["lastClearedDayIndex"]), last >= 0 {
            streak = Streak(count: count, lastClearedDayIndex: last)
        }

        self.init(streak: streak, days: days, unreadableWords: unreadable)
    }

    /// A JSON number that's a whole number, and not a Boolean, which
    /// `JSONSerialization` also hands back as an `NSNumber`.
    private static func wholeNumber(_ value: Any?) -> Int? {
        guard let number = value as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID()
        else { return nil }
        let double = number.doubleValue
        guard double.rounded() == double, abs(double) < 1e15 else { return nil }
        return Int(double)
    }

    private static func isLowercaseLetters(_ s: String) -> Bool {
        s.unicodeScalars.allSatisfy { ("a"..."z").contains($0) }
    }

    private static func isCrown(_ s: String) -> Bool {
        s.unicodeScalars.count == 8 && isLowercaseLetters(s)
    }

    private static func isWord(_ s: String) -> Bool {
        (3...8).contains(s.unicodeScalars.count) && isLowercaseLetters(s)
    }
}
