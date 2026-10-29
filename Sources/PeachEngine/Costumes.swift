import Foundation

/// What the peach can wear: the web's `src/ui/costumes.ts`, the same table.
///
/// **One drawing for two apps.** Each part is SVG path data in the peach's own
/// 100x100 box, in absolute M, L, C and Z only, and the app draws it by parsing
/// these strings rather than keeping a second transcription that could drift.
/// `CostumeTests` pins the table to the hash the web pins, so a costume changed
/// in one repository fails the other's suite until it matches.
///
/// It lives in the engine, not the app, because the app target cannot be
/// tested from `swift test`, and the two properties worth testing are here:
/// that a costume never leaves the peach's box, and that it is the web's.
public enum Costume: String, CaseIterable, Sendable {
    case witchHat = "witch-hat"
    case lantern
    case ghost
    case pieCrust = "pie-crust"
    case antlers
    case topHat = "top-hat"

    public var spoken: String { table.spoken }
    /// The peach's own face is hidden, because the costume draws another.
    public var replacesFace: Bool { table.replacesFace }
    public var parts: [CostumePart] { table.parts }

    private var table: CostumeTable {
        switch self {
        case .witchHat: return Self.witchHatTable
        case .lantern: return Self.lanternTable
        case .ghost: return Self.ghostTable
        case .pieCrust: return Self.pieCrustTable
        case .antlers: return Self.antlersTable
        case .topHat: return Self.topHatTable
        }
    }
}

public struct CostumePart: Sendable, Equatable {
    /// SVG path data, absolute M, L, C and Z only.
    public let d: String
    /// `#RRGGBB`, as the web writes it.
    public let fill: String?
    public let opacity: Double?
    public let stroke: String?
    public let strokeWidth: Double?
    /// Drawn only where the peach shows its face: the face is dropped at mark
    /// size, where it turns to mud, and a costume's face goes with it.
    public let faceOnly: Bool

    init(_ d: String, fill: String? = nil, opacity: Double? = nil,
         stroke: String? = nil, strokeWidth: Double? = nil, faceOnly: Bool = false) {
        self.d = d
        self.fill = fill
        self.opacity = opacity
        self.stroke = stroke
        self.strokeWidth = strokeWidth
        self.faceOnly = faceOnly
    }
}

struct CostumeTable: Sendable {
    let spoken: String
    let replacesFace: Bool
    let parts: [CostumePart]
}

private let cocoa = "#7A4A33"
private let leaf = "#8FD3B6"

extension Costume {
    static let witchHatTable = CostumeTable(
        spoken: "in a witch's hat",
        replacesFace: false,
        parts: [
            CostumePart("M33 27 C37 19 41 11 47 7 C54 2 63 1 72 3 C65 6 61 11 61 18 L66 27 Z",
                        fill: "#5B3F8C"),
            CostumePart("M47 7 C54 2 63 1 72 3 C64 5 57 8 52 14 Z", fill: "#8A6BC9", opacity: 0.8),
            CostumePart("M35 24 C45 27 55 27 64 24 L62 19 C54 22 46 22 37 19 Z", fill: leaf),
            CostumePart("M16 29 C16 22 84 22 84 29 C84 35 16 35 16 29 Z", fill: "#4B3470"),
            CostumePart("M20 27 C30 23 70 23 80 27", stroke: "#8A6BC9", strokeWidth: 2),
            CostumePart("M52 9 L53.6 12.6 L57.4 12.9 L54.5 15.4 L55.4 19.1 L52 17.1 L48.6 19.1 L49.5 15.4 L46.6 12.9 L50.4 12.6 Z",
                        fill: "#FFE08A", faceOnly: true),
        ]
    )

    static let lanternTable = CostumeTable(
        spoken: "carved as a jack-o'-lantern",
        replacesFace: true,
        parts: [
            CostumePart("M50 16 C70 16 84 32 84 52 C84 74 68 90 50 90 C32 90 16 74 16 52 C16 32 30 16 50 16 Z",
                        fill: "#FF9A3D", opacity: 0.55),
            CostumePart("M38 19 C27 34 27 72 38 88", opacity: 0.75, stroke: "#E07A2A", strokeWidth: 2.5),
            CostumePart("M62 19 C73 34 73 72 62 88", opacity: 0.75, stroke: "#E07A2A", strokeWidth: 2.5),
            CostumePart("M50 17 C46 38 46 68 50 89", opacity: 0.45, stroke: "#E07A2A", strokeWidth: 2.5),
            CostumePart("M46 18 L47 9 C48 6 53 6 54 9 L55 18 Z", fill: "#7A5230"),
            CostumePart("M33 53 L45 53 L39 43 Z", fill: cocoa, faceOnly: true),
            CostumePart("M55 53 L67 53 L61 43 Z", fill: cocoa, faceOnly: true),
            CostumePart("M47.5 61 L52.5 61 L50 57 Z", fill: cocoa, faceOnly: true),
            CostumePart("M29 64 C38 76 62 76 71 64 L65 66 L62 70 L58 67 L54 72 L50 68 L46 72 L42 67 L38 70 L35 66 Z",
                        fill: cocoa, faceOnly: true),
        ]
    )

    static let ghostTable = CostumeTable(
        spoken: "in a ghost sheet",
        replacesFace: true,
        parts: [
            CostumePart("M50 9 C72 9 85 26 85 48 L85 80 C81.1 76 77.2 76 73.3 80 C69.4 84 65.6 84 61.7 80 "
                        + "C57.8 76 53.9 76 50 80 C46.1 84 42.2 84 38.3 80 C34.4 76 30.6 76 26.7 80 "
                        + "C22.8 84 18.9 84 15 80 L15 48 C15 26 28 9 50 9 Z",
                        fill: "#FFFFFF", stroke: "#D6C9EE", strokeWidth: 2.5),
            CostumePart("M50 12 C54 4 64 3 68 8 C66 14 59 17 54 16 Z", fill: leaf),
            CostumePart("M35 46 C35 38 45 38 45 46 C45 54 35 54 35 46 Z", fill: cocoa),
            CostumePart("M55 46 C55 38 65 38 65 46 C65 54 55 54 55 46 Z", fill: cocoa),
            CostumePart("M47 61 C47 56 53 56 53 61 C53 66 47 66 47 61 Z", fill: cocoa, faceOnly: true),
            CostumePart("M27 58 C27 53 35 53 35 58 C35 63 27 63 27 58 Z",
                        fill: "#FF9DAE", opacity: 0.6, faceOnly: true),
            CostumePart("M65 58 C65 53 73 53 73 58 C73 63 65 63 65 58 Z",
                        fill: "#FF9DAE", opacity: 0.6, faceOnly: true),
        ]
    )

    static let pieCrustTable = CostumeTable(
        spoken: "wearing a pie crust hat",
        replacesFace: false,
        parts: [
            CostumePart("M17 21 L83 21 L76 30 C64 33.5 36 33.5 24 30 Z", fill: "#B66E2C"),
            CostumePart("M18 21 C19 7 34 3 50 3 C66 3 81 7 82 21 Z", fill: "#9C3434"),
            CostumePart("M30.5 6.1 L69.5 6.1 L76 9.9 L24 9.9 Z", fill: "#F6C677"),
            CostumePart("M21.5 12.7 L78.5 12.7 L80.5 16.5 L19.5 16.5 Z", fill: "#F6C677"),
            CostumePart("M27.7 7.7 L32.3 5.8 L32.3 21 L27.7 21 Z", fill: "#F6C677"),
            CostumePart("M41.2 4.1 L45.8 3.7 L45.8 21 L41.2 21 Z", fill: "#F6C677"),
            CostumePart("M54.2 3.7 L58.8 4.1 L58.8 21 L54.2 21 Z", fill: "#F6C677"),
            CostumePart("M67.7 5.8 L72.3 7.7 L72.3 21 L67.7 21 Z", fill: "#F6C677"),
            CostumePart("M15 25.5 L15 19.5 C15.8 15.5 22 15.5 22.8 19.5 C23.6 15.5 29.8 15.5 30.6 19.5 "
                        + "C31.3 15.5 37.6 15.5 38.3 19.5 C39.1 15.5 45.3 15.5 46.1 19.5 "
                        + "C46.9 15.5 53.1 15.5 53.9 19.5 C54.7 15.5 60.9 15.5 61.7 19.5 "
                        + "C62.4 15.5 68.7 15.5 69.4 19.5 C70.2 15.5 76.4 15.5 77.2 19.5 C78 15.5 84.2 15.5 85 19.5 "
                        + "L85 25.5 C70 27.5 30 27.5 15 25.5 Z",
                        fill: "#E09A48", stroke: "#8A4E1E", strokeWidth: 1.4),
            CostumePart("M18 21 C19 7 34 3 50 3 C66 3 81 7 82 21", stroke: "#8A4E1E", strokeWidth: 1.4),
        ]
    )

    static let antlersTable = CostumeTable(
        spoken: "wearing antlers and a red nose",
        replacesFace: false,
        parts: [
            CostumePart("M37 22 L31 13 L25 3.5", stroke: "#9A6238", strokeWidth: 6.5),
            CostumePart("M63 22 L69 13 L75 3.5", stroke: "#9A6238", strokeWidth: 6.5),
            CostumePart("M31.5 14 L19 11.5", stroke: "#9A6238", strokeWidth: 6.5),
            CostumePart("M68.5 14 L81 11.5", stroke: "#9A6238", strokeWidth: 6.5),
            CostumePart("M27.5 7.5 L18.5 4", stroke: "#9A6238", strokeWidth: 6.5),
            CostumePart("M72.5 7.5 L81.5 4", stroke: "#9A6238", strokeWidth: 6.5),
            CostumePart("M33 26 C27 22 19 22 15 25 C19 30 27 31 33 26 Z", fill: "#C98D5E", faceOnly: true),
            CostumePart("M67 26 C73 22 81 22 85 25 C81 30 73 31 67 26 Z", fill: "#C98D5E", faceOnly: true),
            CostumePart("M31 26 C27 24 22 24 19 25.3 C22 28 27 28.5 31 26 Z", fill: "#F2B9A8", faceOnly: true),
            CostumePart("M69 26 C73 24 78 24 81 25.3 C78 28 73 28.5 69 26 Z", fill: "#F2B9A8", faceOnly: true),
            CostumePart("M45.4 61.5 C45.4 59 47.5 56.9 50 56.9 C52.5 56.9 54.6 59 54.6 61.5 "
                        + "C54.6 64 52.5 66.1 50 66.1 C47.5 66.1 45.4 64 45.4 61.5 Z",
                        fill: "#E5383B", faceOnly: true),
            CostumePart("M47.1 59.9 C47.1 59.2 47.7 58.6 48.4 58.6 C49.1 58.6 49.7 59.2 49.7 59.9 "
                        + "C49.7 60.6 49.1 61.2 48.4 61.2 C47.7 61.2 47.1 60.6 47.1 59.9 Z",
                        fill: "#FFFFFF", opacity: 0.85, faceOnly: true),
        ]
    )

    static let topHatTable = CostumeTable(
        spoken: "wearing a top hat",
        replacesFace: false,
        parts: [
            CostumePart("M21.2 20.5 C21.8 16 79.3 24.1 78.6 28.5 C78 33 20.6 24.9 21.2 20.5 Z", fill: "#2E2A3A"),
            CostumePart("M35 1.7 C35.2 0.2 70.8 5.2 70.6 6.7 L65.8 26.2 L34.2 21.8 Z", fill: "#2E2A3A"),
            CostumePart("M34.5 14.8 L67.4 19.4 L66.1 24.7 L34.4 20.3 Z", fill: "#FFD34D"),
            CostumePart("M36.3 2.9 L35.8 21", stroke: "#6C6588", strokeWidth: 1.6),
            CostumePart("M23.4 19.3 C34.6 18.8 66.3 23.3 76.9 26.8", stroke: "#6C6588", strokeWidth: 1.4),
            CostumePart("M20 4.5 C21.4 10.7 21.4 10.7 27.5 12 C21.4 13.3 21.4 13.3 20 19.5 "
                        + "C18.6 13.3 18.6 13.3 12.5 12 C18.6 10.7 18.6 10.7 20 4.5 Z",
                        fill: "#FFD34D", stroke: "#D9A52B", strokeWidth: 1.1),
        ]
    )
}

// MARK: - Reading the path data

/// One command of a costume's path, in the 100x100 box.
public enum CostumeCommand: Equatable, Sendable {
    case move(Double, Double)
    case line(Double, Double)
    case curve(c1: (Double, Double), c2: (Double, Double), to: (Double, Double))
    case close

    public static func == (a: CostumeCommand, b: CostumeCommand) -> Bool {
        switch (a, b) {
        case let (.move(x1, y1), .move(x2, y2)), let (.line(x1, y1), .line(x2, y2)):
            return x1 == x2 && y1 == y2
        case let (.curve(a1, a2, a3), .curve(b1, b2, b3)):
            return a1 == b1 && a2 == b2 && a3 == b3
        case (.close, .close):
            return true
        default:
            return false
        }
    }

    /// Every point the command names, control points included.
    public var points: [(Double, Double)] {
        switch self {
        case let .move(x, y), let .line(x, y): return [(x, y)]
        case let .curve(c1, c2, to): return [c1, c2, to]
        case .close: return []
        }
    }
}

public enum CostumePathError: Error, Equatable {
    /// A command other than absolute M, L, C or Z, or numbers that do not make
    /// whole points for it.
    case unsupported(String)
}

/// Parse a costume's path data. Absolute M, L, C and Z only, which is all the
/// table uses and all `CostumeTests` allows; anything else throws rather than
/// drawing something the web does not.
public func costumeCommands(_ d: String) throws -> [CostumeCommand] {
    var out: [CostumeCommand] = []
    var op: Character?
    var numbers: [Double] = []
    var token = ""

    func flushNumber() {
        if !token.isEmpty, let n = Double(token) { numbers.append(n) }
        token = ""
    }
    func flushCommand() throws {
        guard let c = op else { return }
        switch c {
        case "M", "L":
            guard !numbers.isEmpty, numbers.count % 2 == 0 else { throw CostumePathError.unsupported(d) }
            for i in stride(from: 0, to: numbers.count, by: 2) {
                let point = (numbers[i], numbers[i + 1])
                // Extra pairs after an M are lines, as in SVG.
                out.append(c == "M" && i == 0 ? .move(point.0, point.1) : .line(point.0, point.1))
            }
        case "C":
            guard !numbers.isEmpty, numbers.count % 6 == 0 else { throw CostumePathError.unsupported(d) }
            for i in stride(from: 0, to: numbers.count, by: 6) {
                out.append(.curve(c1: (numbers[i], numbers[i + 1]),
                                  c2: (numbers[i + 2], numbers[i + 3]),
                                  to: (numbers[i + 4], numbers[i + 5])))
            }
        case "Z":
            guard numbers.isEmpty else { throw CostumePathError.unsupported(d) }
            out.append(.close)
        default:
            throw CostumePathError.unsupported(d)
        }
        numbers = []
    }

    for ch in d {
        if ch.isLetter {
            flushNumber()
            try flushCommand()
            op = ch
        } else if ch == " " || ch == "," {
            flushNumber()
        } else if ch == "-" && !token.isEmpty {
            flushNumber()
            token = "-"
        } else {
            token.append(ch)
        }
    }
    flushNumber()
    try flushCommand()
    return out
}

// MARK: - The table both apps hash

/// The table as one canonical text, exactly as the web's
/// `canonicalCostumeTable()` writes it, the days included, so a day changed in
/// one app fails the other's suite as a drawing does. Fields are joined by `|`,
/// empty where unset:
///
/// - each costume's own line, then one line per part;
/// - then one line per day, in `costumeDays`' order: month, day, weekday, nth,
///   costume and occasion.
public func canonicalCostumeTable() -> String {
    var lines: [String] = []
    for costume in Costume.allCases {
        lines.append("\(costume.rawValue)|\(costume.spoken)|\(costume.replacesFace)")
        for p in costume.parts {
            lines.append([
                costume.rawValue,
                p.d,
                p.fill ?? "",
                p.opacity.map(jsNumber) ?? "",
                p.stroke ?? "",
                p.strokeWidth.map(jsNumber) ?? "",
                String(p.faceOnly),
            ].joined(separator: "|"))
        }
    }
    for d in costumeDays {
        lines.append([
            String(d.month),
            d.day.map(String.init) ?? "",
            d.weekday.map(String.init) ?? "",
            d.nth.map(String.init) ?? "",
            d.costume.rawValue,
            d.occasion,
        ].joined(separator: "|"))
    }
    return lines.joined(separator: "\n")
}

/// A number as JavaScript prints it: no ".0" on a whole one. The growing
/// peach's table is written the same way; see `canonicalGrowthTable`.
func jsNumber(_ n: Double) -> String {
    n.rounded() == n ? String(Int(n)) : String(n)
}

// MARK: - The days the peach dresses up

/// A day the peach dresses up, and what it wears: a fixed date, or a day that
/// moves, named by its weekday and which of the month's it is.
public struct CostumeDay: Sendable, Equatable {
    public let month: Int  // 1 to 12
    /// The day of the month, for a fixed date.
    public let day: Int?
    /// For a day that moves: 0 for Sunday to 6 for Saturday, as the web's
    /// `getUTCDay` counts, one less than `Calendar`'s weekday.
    public let weekday: Int?
    /// Which of the month's: 1 for the first.
    public let nth: Int?
    public let costume: Costume
    /// What the day is, for whoever reads this table. Never shown.
    public let occasion: String

    init(month: Int, day: Int, costume: Costume, occasion: String) {
        self.month = month
        self.day = day
        self.weekday = nil
        self.nth = nil
        self.costume = costume
        self.occasion = occasion
    }

    init(month: Int, weekday: Int, nth: Int, costume: Costume, occasion: String) {
        self.month = month
        self.day = nil
        self.weekday = weekday
        self.nth = nth
        self.costume = costume
        self.occasion = occasion
    }

    /// Whether it falls on `day` of its month in `year`.
    func falls(year: Int, day: Int) -> Bool {
        if let fixed = self.day { return fixed == day }
        guard let date = utcCalendar.date(from: DateComponents(year: year, month: month, day: day))
        else { return false }
        return utcCalendar.component(.weekday, from: date) - 1 == weekday && (day + 6) / 7 == nth
    }
}

private let thursday = 4

private let utcCalendar: Foundation.Calendar = {
    var utc = Foundation.Calendar(identifier: .gregorian)
    utc.timeZone = TimeZone(identifier: "UTC")!
    return utc
}()

/// The days the peach dresses up. Other occasions may follow; each is a row.
/// The web's `COSTUME_DAYS` holds the same rows.
///
/// The costume goes by the board's date, not today's: today's board on the day
/// wears it, and so does that day's board replayed later from the calendar,
/// while any other day's board does not, even if it is played on the day.
public let costumeDays: [CostumeDay] = [
    CostumeDay(month: 10, day: 31, costume: .ghost, occasion: "Halloween"),
    CostumeDay(month: 11, weekday: thursday, nth: 4, costume: .pieCrust, occasion: "Thanksgiving"),
    CostumeDay(month: 12, day: 24, costume: .antlers, occasion: "Christmas Eve"),
    CostumeDay(month: 12, day: 31, costume: .topHat, occasion: "New Year's Eve"),
    CostumeDay(month: 1, day: 1, costume: .topHat, occasion: "New Year's Day"),
]

/// The costume for a calendar date, or nil.
public func costume(year: Int, month: Int, day: Int) -> Costume? {
    costumeDays.first { $0.month == month && $0.falls(year: year, day: day) }?.costume
}

/// The costume for a board, by the board's own day.
///
/// - `storageDay` is the board's day as progress is keyed: days since
///   `storageEpoch`. A board with none never dresses.
/// - `preview`, `YYYY-MM-DD`, stands in for the board's date. The app passes
///   it from a Debug launch argument only; a malformed one is ignored.
public func boardCostume(storageDay: Int?, preview: String? = nil) -> Costume? {
    if let preview {
        let parts = preview.split(separator: "-").compactMap { Int($0) }
        if parts.count == 3, preview.count == 10 {
            return costume(year: parts[0], month: parts[1], day: parts[2])
        }
    }
    guard let storageDay else { return nil }
    guard let epoch = utcCalendar.date(from: DateComponents(
              year: storageEpoch.year, month: storageEpoch.month, day: storageEpoch.day)),
          let date = utcCalendar.date(byAdding: .day, value: storageDay, to: epoch)
    else { return nil }
    let parts = utcCalendar.dateComponents([.year, .month, .day], from: date)
    return costume(year: parts.year ?? 0, month: parts.month ?? 0, day: parts.day ?? 0)
}
