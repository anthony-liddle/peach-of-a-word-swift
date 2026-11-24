#if DEBUG
import SwiftUI

/// What `-exposeWordBreaks 1` reports: for each probed text, the widest of its
/// words drawn on one line, against the width the text was laid out in.
///
/// SwiftUI breaks a word across lines only when that word alone is wider than
/// the room it's given, so a text whose widest word fits its room has every
/// word whole, however many lines it takes. XCUITest can't see where a line
/// breaks, and its frames are the ink, not the layout, so the numbers come
/// from the layout itself, as `KeyFitProbe`'s do.
@MainActor
@Observable
final class WordBreakReadings {
    static let shared = WordBreakReadings()

    var room: [String: CGFloat] = [:]
    var widest: [String: CGFloat] = [:]

    /// "points=whole rank=broken", by name. The words themselves are left
    /// out: a board's words have no place in a test's log.
    var summary: String {
        let names = Set(room.keys).union(widest.keys).sorted()
        guard !names.isEmpty else { return "none" }
        return names.map { name in
            guard let room = room[name], let widest = widest[name], room > 0, widest > 0 else {
                return "\(name)=unread"
            }
            // Half a point for rounding: a word that fits draws in its room.
            let verdict = widest <= room + 0.5 ? "whole" : "broken"
            return "\(name)=\(verdict)(\(String(format: "%.1f", widest))/\(String(format: "%.1f", room)))"
        }
        .joined(separator: " ")
    }
}

/// Probes one text: the room it was laid out in, and its widest word drawn
/// alone on one line by `draw`, in the text's own font.
struct WordBreakProbe<Word: View>: ViewModifier {
    static var isOn: Bool { UserDefaults.standard.bool(forKey: "exposeWordBreaks") }

    let name: String
    let words: [String]
    @ViewBuilder let draw: (String) -> Word

    func body(content: Content) -> some View {
        if Self.isOn {
            content
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: {
                    WordBreakReadings.shared.room[name] = $0
                }
                .background(alignment: .topLeading) {
                    ZStack(alignment: .topLeading) {
                        ForEach(Array(words.enumerated()), id: \.offset) { _, word in
                            draw(word).fixedSize()
                        }
                    }
                    .fixedSize()
                    .hidden()
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: {
                        WordBreakReadings.shared.widest[name] = $0
                    }
                }
        } else {
            content
        }
    }
}

extension View {
    /// Probes this text for a word broken across lines, under
    /// `-exposeWordBreaks 1`. A no-op otherwise.
    func probingWordBreaks<Word: View>(
        _ name: String, words: [String], @ViewBuilder draw: @escaping (String) -> Word
    ) -> some View {
        modifier(WordBreakProbe(name: name, words: words, draw: draw))
    }
}
#else
import SwiftUI

extension View {
    /// Nothing outside Debug.
    func probingWordBreaks<Word: View>(
        _ name: String, words: [String], @ViewBuilder draw: @escaping (String) -> Word
    ) -> some View {
        self
    }
}
#endif
