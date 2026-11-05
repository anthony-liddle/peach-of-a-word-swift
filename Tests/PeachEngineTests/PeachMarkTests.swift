import Foundation
import Testing
@testable import PeachEngine

/// `App/PeachMark.swift`'s peach, held to the growing peach's Perfectly Peachy
/// stage: the peach at full size, in the table both apps pin.
///
/// **Which way it guards, and how far.** `PeachMark` is the peach transcribed
/// by hand into Swift, and nothing held it to anything. One handle of the
/// highlight was copied as (73, 31) where the drawing has (66, 31), so the
/// iPhone's highlight sagged on its right. This holds all eight parts of the
/// transcription, with their paint, to the table: the three paths, the four
/// circles of the face, and the smile. The table is held to the web's copy of
/// it by `GrowthStageTests.tableSHA256`. Nothing yet holds that copy to the
/// web's own peach in `peachArt.ts`.
///
/// It reads the source as text, as `AppVocabularyTests` does: `App/` belongs
/// to the Xcode target, so there is nothing to import.
@Suite("the peach is the table's")
struct PeachMarkTests {

    private struct Unreadable: Error, CustomStringConvertible {
        let description: String
    }

    // MARK: - Reading PeachMark.swift

    /// The source tree first, then the copy bundled for Xcode Cloud.
    private static let source: String = {
        var candidates = [repositoryRoot.appendingPathComponent("App/PeachMark.swift")]
        for bundle in Bundle.allBundles {
            if let resources = bundle.resourceURL {
                candidates.append(resources.appendingPathComponent("App/PeachMark.swift"))
            }
        }
        for url in candidates {
            if let text = try? String(contentsOf: url, encoding: .utf8) { return text }
        }
        return ""
    }()

    /// The table's peach: leaf, body, highlight, the eyes and the cheeks left
    /// then right, and the smile.
    private static let table = GrowthStage.perfectlyPeachy.parts

    /// `private var <name>: Path { ... }`, up to the next declaration.
    private static func declaration(_ name: String) throws -> Substring {
        guard let start = source.range(of: "private var \(name): Path {") else {
            throw Unreadable(description: "PeachMark.swift has no `\(name)` path")
        }
        let rest = source[start.upperBound...]
        return rest[..<(rest.range(of: "\n    private var ")?.lowerBound ?? rest.endIndex)]
    }

    /// The face, up to the preview after it.
    private static func face() throws -> Substring {
        guard let start = source.range(of: "private var face: some View {"),
              let end = source.range(of: "#Preview", range: start.upperBound..<source.endIndex)
        else { throw Unreadable(description: "PeachMark.swift has no face") }
        return source[start.upperBound..<end.lowerBound]
    }

    private static var call: Regex<(Substring, Substring, Substring)> { #/p\.(move|addLine|addCurve|closeSubpath)\(((?:[^()]|\([^()]*\))*)\)/# }
    private static var point: Regex<(Substring, Substring, Substring, Substring)> { #/(to|control1|control2): CGPoint\(x: (-?[\d.]+), y: (-?[\d.]+)\)/# }

    /// The path calls in a stretch of source, as the table's commands. Each
    /// point is read by its argument label, since `addCurve` names its end
    /// first and path data names it last.
    private static func commands(in text: Substring) throws -> [CostumeCommand] {
        try text.matches(of: call).map { m in
            var at: [Substring: (Double, Double)] = [:]
            for p in m.output.2.matches(of: point) {
                guard let x = Double(p.output.2), let y = Double(p.output.3) else {
                    throw Unreadable(description: "unreadable point: \(p.output.0)")
                }
                at[p.output.1] = (x, y)
            }
            func the(_ label: Substring) throws -> (Double, Double) {
                guard let p = at[label] else {
                    throw Unreadable(description: "no `\(label)` in \(m.output.0)")
                }
                return p
            }
            switch m.output.1 {
            case "move": return .move(try the("to").0, try the("to").1)
            case "addLine": return .line(try the("to").0, try the("to").1)
            case "addCurve":
                return .curve(c1: try the("control1"), c2: try the("control2"), to: try the("to"))
            default: return .close
            }
        }
    }

    /// A path as one line of path data, so a failure shows both drawings.
    private static func pathData(_ commands: [CostumeCommand]) -> String {
        func n(_ v: Double) -> String { v == v.rounded() ? String(Int(v)) : String(v) }
        return commands.map { command in
            switch command {
            case let .move(x, y): "M\(n(x)) \(n(y))"
            case let .line(x, y): "L\(n(x)) \(n(y))"
            case let .curve(c1, c2, to):
                "C\(n(c1.0)) \(n(c1.1)) \(n(c2.0)) \(n(c2.1)) \(n(to.0)) \(n(to.1))"
            case .close: "Z"
            }
        }.joined(separator: " ")
    }

    private static var fill: Regex<(Substring, Substring, Substring, Substring?)> { #/(\w+)\.fill\(Color\(hex: 0x([0-9A-Fa-f]{6})\)(?:\.opacity\(([\d.]+)\))?\)/# }
    private static var circle: Regex<(Substring, Substring, Substring?, Substring, Substring, Substring, Substring)> { #/Circle\(\)\.fill\(Color\(hex: 0x([0-9A-Fa-f]{6})\)(?:\.opacity\(([\d.]+)\))?\)\s*\.frame\(width: ([\d.]+), height: ([\d.]+)\)\.position\(x: ([\d.]+), y: ([\d.]+)\)/# }
    private static var stroke: Regex<(Substring, Substring, Substring)> { #/\.stroke\(Color\(hex: 0x([0-9A-Fa-f]{6})\), style: StrokeStyle\(lineWidth: ([\d.]+)/# }

    // MARK: - The guards

    @Test("the table's peach is the eight parts this file reads it as")
    func tableShape() {
        #expect(Self.table.count == 8)
        #expect(Self.table.map(\.faceOnly) == [false, false, false, true, true, true, true, true])
    }

    @Test("the leaf, the body and the highlight are the table's, in its paint",
          arguments: zip(["leaf", "body_", "highlight"], 0...2))
    func paths(name: String, index: Int) throws {
        let part = Self.table[index]
        let drawn = Self.pathData(try Self.commands(in: Self.declaration(name)))
        let shared = Self.pathData(try costumeCommands(part.d))
        #expect(drawn == shared, "\(name)")

        let paint = try #require(Self.source.matches(of: Self.fill).first { $0.output.1 == name },
                                 "\(name) is never filled")
        #expect("#" + paint.output.2.uppercased() == part.fill, "\(name)'s fill")
        #expect(paint.output.3.flatMap { Double($0) } == part.opacity, "\(name)'s opacity")
    }

    @Test("the eyes and the cheeks are the table's circles, in its order and paint")
    func circles() throws {
        let drawn = try Self.face().matches(of: Self.circle)
        let parts = Array(Self.table[3...6])
        try #require(drawn.count == parts.count, "\(drawn.count) circles in the face")
        for (m, part) in zip(drawn, parts) {
            let points = try costumeCommands(part.d).flatMap(\.points)
            let xs = points.map(\.0)
            let ys = points.map(\.1)
            let (minX, maxX, minY, maxY) = (xs.min()!, xs.max()!, ys.min()!, ys.max()!)
            let at = "the circle at \(m.output.5), \(m.output.6)"
            let close = { (a: Substring, b: Double) in abs((Double(a) ?? .nan) - b) < 1e-9 }
            #expect(close(m.output.3, maxX - minX), "\(at): width")
            #expect(close(m.output.4, maxY - minY), "\(at): height")
            #expect(close(m.output.5, (minX + maxX) / 2), "\(at): centre x")
            #expect(close(m.output.6, (minY + maxY) / 2), "\(at): centre y")
            #expect("#" + m.output.1.uppercased() == part.fill, "\(at): fill")
            #expect(m.output.2.flatMap { Double($0) } == part.opacity, "\(at): opacity")
        }
    }

    @Test("the smile is the table's, in its stroke")
    func smile() throws {
        let face = try Self.face()
        let part = Self.table[7]
        let drawn = Self.pathData(try Self.commands(in: face))
        let shared = Self.pathData(try costumeCommands(part.d))
        #expect(drawn == shared)
        let line = try #require(face.firstMatch(of: Self.stroke), "the smile is never stroked")
        #expect("#" + line.output.1.uppercased() == part.stroke)
        #expect(Double(line.output.2) == part.strokeWidth)
    }
}
