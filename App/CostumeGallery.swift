#if DEBUG
import PeachEngine
import SwiftUI

/// Every costume beside the plain peach, at every size the cute peach appears:
/// the reveal card's, the completion card's with its crown, the source word's
/// chip at the default text size and at the largest, and the confetti's.
///
/// `-costumeGallery 1` opens it in place of the game. Debug only, like every
/// launch hook, so no build Bea runs can show it.
struct CostumeGallery: View {
    private let rows: [Costume?] = [nil] + Costume.allCases

    var body: some View {
        ZStack {
            Cute.pageBackground.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Costumes")
                        .font(CuteFont.display(24, relativeTo: .title))
                        .foregroundStyle(Cute.ink)
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, costume in
                        row(costume)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
        .dynamicTypeSize(.large)
    }

    private func row(_ costume: Costume?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(costume.map { "The peach \($0.spoken)" } ?? "The plain peach, as it is today")
                .font(CuteFont.body(13, weight: "SemiBold", relativeTo: .caption))
                .foregroundStyle(Cute.inkFaint)
            HStack(alignment: .bottom, spacing: 18) {
                PeachMark(costume: costume).frame(width: 96, height: 96)
                CompletionOrnament(costume: costume)
                VStack(alignment: .leading, spacing: 10) {
                    chip(costume)
                    chip(costume).dynamicTypeSize(.accessibility5)
                    HStack(spacing: 6) {
                        ForEach([12, 15, 18, 22], id: \.self) { size in
                            PeachMark(showsFace: false, costume: costume)
                                .frame(width: CGFloat(size), height: CGFloat(size))
                        }
                    }
                }
            }
        }
    }

    /// The source word's chip, as the found list draws it: the mark and the
    /// word. A short word, so the largest text size still fits on one line.
    private func chip(_ costume: Costume?) -> some View {
        HStack(spacing: 4) {
            RarityMark(category: .source, costume: costume)
            Text("gene")
                .font(CuteFont.body(17, relativeTo: .body))
                .foregroundStyle(Cute.crownDeep)
        }
    }
}

#Preview("Costumes") {
    CostumeGallery()
}
#endif
