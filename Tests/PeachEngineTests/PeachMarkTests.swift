import Foundation
import Testing
@testable import PeachEngine

/// `App/PeachMark.swift` draws the peach from the growing peach's Perfectly
/// Peachy stage, the table both apps pin, and holds no outline of its own.
///
/// **Which way it guards, and how far.** `PeachMark` used to draw eight Swift
/// paths and circles copied by hand, and one handle of the highlight was
/// copied wrong for as long as it did. This holds that it draws the table's
/// parts, and has no numbers for a shape of its own that could drift again.
/// The table is held to the web's copy of it by
/// `GrowthStageTests.tableSHA256`, and the web's `peach.test.ts` holds that
/// copy to the web's own peach in `peachArt.ts`.
///
/// It reads the source as text, as `AppVocabularyTests` does: `App/` belongs
/// to the Xcode target, so there is nothing to import and draw.
@Suite("the peach is the table's")
struct PeachMarkTests {

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

    /// `struct PeachMark`, up to the preview after it.
    private static var peachMark: Substring {
        guard let start = source.range(of: "struct PeachMark: View {"),
              let end = source.range(of: "#Preview", range: start.upperBound..<source.endIndex)
        else { return "" }
        return source[start.lowerBound..<end.lowerBound]
    }

    @Test("the table's peach is the leaf, the body and the highlight, then the face")
    func tableShape() {
        let parts = GrowthStage.perfectlyPeachy.parts
        #expect(parts.count == 8)
        // The face goes where PeachMark drops it, at mark size and under a
        // costume that draws its own.
        #expect(parts.map(\.faceOnly) == [false, false, false, true, true, true, true, true])
    }

    @Test("PeachMark draws the table's parts, and the costume over them")
    func drawsTheTable() throws {
        let body = Self.peachMark
        try #require(!body.isEmpty, "PeachMark.swift has no PeachMark")
        #expect(body.contains("GrowthStage.perfectlyPeachy.parts"))
        #expect(body.contains("PartsLayer(parts: Self.parts"))
        #expect(body.contains("PartsLayer(parts: costume.parts"))
    }

    @Test("PeachMark.swift holds no outline of its own")
    func noOutlineOfItsOwn() {
        #expect(!Self.source.isEmpty, "PeachMark.swift was not found")
        for shape in ["Circle()", "Ellipse()", "Capsule()", "RoundedRectangle("] {
            #expect(!Self.source.contains(shape), "PeachMark.swift draws a \(shape)")
        }
        let literalPoint = #/CGPoint\(x: -?[0-9]/#
        #expect(Self.source.firstMatch(of: literalPoint) == nil,
                "PeachMark.swift has a point written as numbers")
        let placed = #/\.position\(x: -?[0-9]/#
        #expect(Self.source.firstMatch(of: placed) == nil,
                "PeachMark.swift places a part by numbers")
    }
}
