import Foundation
import Testing
@testable import PeachEngine

/// What the explainer must and must not say.
///
/// The port of `HowItWorks.test.tsx`, which pins the model rather than the
/// prose. That is the right thing to pin: the wording is allowed to be
/// rewritten, and has been once already, since the app substitutes its own
/// container noun for the web's "set". What is not allowed to drift is the
/// account of how the game works, because an explainer that describes a
/// previous version of the rules is worse than no explainer.
///
/// Read as source text rather than by importing the app, for the same reason
/// `AppVocabularyTests` does it: the test bundle depends on `PeachEngine`, and
/// the copy lives in the app target.
@Suite("the explainer explains the current model")
struct ExplainerClaimsTests {

    /// `App/Copy.swift`, as text. The source tree first, then a bundled copy,
    /// so this survives Xcode Cloud's test phase having no checkout.
    private static let copyText: String = {
        let root = repositoryRoot.appendingPathComponent("App/Copy.swift")
        if let text = try? String(contentsOf: root, encoding: .utf8) { return text }
        for bundle in Bundle.allBundles {
            guard let resources = bundle.resourceURL else { continue }
            let candidate = resources.appendingPathComponent("App/Copy.swift")
            if let text = try? String(contentsOf: candidate, encoding: .utf8) { return text }
        }
        return ""
    }()

    /// Just the explainer paragraphs, so a phrase elsewhere in `Copy.swift`
    /// cannot satisfy or trip one of these.
    private static let body: String = {
        guard let start = copyText.range(of: "static let explainerParagraphs"),
              let end = copyText.range(of: "static let explainerLinks")
        else { return "" }
        return String(copyText[start.upperBound..<end.lowerBound])
    }()

    @Test("the paragraphs were found at all")
    func bodyIsReadable() {
        // Guards the two other tests: a rename that broke the slice above would
        // otherwise make every assertion below vacuously pass on empty text.
        #expect(Self.body.count > 800, "the explainer body could not be read from Copy.swift")
    }

    @Test("never names the retired Edition Complete win state")
    func noRetiredWinState() {
        #expect(!Self.body.lowercased().contains("edition complete"))
    }

    /// The bar fills toward par in points. Completion is a separate word-count
    /// peak above the named ladder, which is what the goal rebuild split apart.
    @Test("does not call completion the goal, nor what the bar fills toward")
    func completionIsNotTheGoal() {
        #expect(!Self.body.lowercased().contains("is the goal"))
        #expect(!Self.body.lowercased().contains("bar fills toward"))
    }

    @Test("says the ladder is climbed by points, with rarer words worth more")
    func ladderIsPoints() {
        #expect(Self.body.lowercased().contains("points"))
        #expect(Self.body.lowercased().contains("rarer"))
    }

    @Test("puts completion above the ladder and never calls it required")
    func completionSitsAbove() {
        #expect(Self.body.lowercased().contains("every common word"))
        #expect(Self.body.lowercased().contains("never required")
                || Self.body.lowercased().contains("not required"))
    }

    /// ENABLE union SCOWL 95 plus the curated patch layer, since Phase 1.
    /// Naming ENABLE alone was true once and has not been for a long time.
    @Test("names the real validation boundary, not ENABLE alone")
    func namesTheWholeBoundary() {
        #expect(!Self.body.contains("ENABLE is the dictionary that decides"))
        #expect(Self.body.contains("ENABLE"))
        #expect(Self.body.contains("SCOWL"))
        #expect(Self.body.lowercased().contains("patch"))
    }

    /// The app's own noun, not the web's.
    ///
    /// The web's body is unthemed and says "set" throughout; this app calls
    /// that collection the basket everywhere else, so the paragraphs are built
    /// from `Vocabulary.container`.
    ///
    /// **`AppVocabularyTests` would not have caught a verbatim port.** Its
    /// guard bans specific letterpress substrings, and a body full of "set"
    /// contains none of them, so it would have sailed through. It catches the
    /// wrong word, not the missing one. That limit is not worth widening,
    /// because "is this the app's vocabulary" is a judgement rather than a
    /// substring, but it is worth one assertion here where the substitution
    /// actually lives.
    @Test("uses the app's container noun rather than the web's")
    func usesTheAppsNoun() {
        #expect(Self.body.contains("\\(container)") || Self.body.contains("\\(containerCapitalized)"),
                "the paragraphs should be built from Vocabulary.container")
        // The web's noun, spelled out. Written with the surrounding words so
        // this cannot trip on "set" inside another word, or on the interpolation.
        for phrase in ["the day's set", "outside the set", "in the set"] {
            #expect(!Self.body.contains(phrase), "the web's noun survived the port: \(phrase)")
        }
    }

    /// Both surfaces shipped "about 430,000" against a `boundary` of 426,900.
    /// Corrected here; the web is filed separately.
    @Test("the word count matches the shipped boundary")
    func countIsRight() {
        #expect(Self.body.contains("427,000"))
        #expect(!Self.body.contains("430,000"))
    }
}
