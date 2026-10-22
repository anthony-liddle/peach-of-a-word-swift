import PeachEngine
import SwiftUI

/// Licences: a short list, and each entry a page of its own.
///
/// **A list since 22 October 2026.** It was one long page, every text in full
/// one under the other, about 31.5 KB, so the word lists and the typefaces sat
/// below Soundscape's seven notices. Now the first page is four rows that fit
/// one screen at L on an iPhone SE, each with a sentence on what it covers,
/// and each opens its texts in full: Soundscape, the word lists, the
/// definitions and word histories, and the typefaces. Soundscape's page leads
/// on to the notices of the code it adapts.
///
/// **The credits live here,** since the colophon kept only the dedication.
///
/// **The texts are read from the bundle,** so the screen shows the files that
/// ship rather than copies that could drift: Soundscape's two from `Data/`,
/// which `SoundscapeLicenceTests` pins; the word lists' and Wiktionary's terms
/// from `App/Licences/`, which `PlayerLicencesTests` holds to
/// `Data/ATTRIBUTION.md`; and the fonts' OFL texts. Which page shows which, and
/// how a text breaks into paragraphs, is `Licences` in the engine, where
/// `PlayerLicencesTests` holds every page to its files, word for word.
struct LicencesPage: View {
    var body: some View {
        ZStack {
            Cute.pageBackground.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(Vocabulary.licencesTitle)
                        .font(CuteFont.display(26, relativeTo: .title))
                        .foregroundStyle(Cute.ink)
                        .accessibilityAddTraits(.isHeader)
                    VStack(spacing: 0) {
                        ForEach(Array(Licences.list.enumerated()), id: \.element.id) { index, page in
                            if index > 0 { LicenceDivider() }
                            LicenceLink(page: page)
                        }
                    }
                    .licenceCard()
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(Cute.paper, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// One entry's page: its sentence, then its texts in full.
struct LicenceTextPage: View {
    let page: Licences.Page

    var body: some View {
        ZStack {
            Cute.pageBackground.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(LicenceCopy.title(page))
                        .font(CuteFont.display(24, relativeTo: .title2))
                        .foregroundStyle(Cute.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text(LicenceCopy.covers(page))
                        .font(CuteFont.body(15, relativeTo: .subheadline))
                        .foregroundStyle(Cute.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    ForEach(page.files, id: \.self) { path in
                        if let heading = LicenceCopy.heading(path) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(heading.title)
                                    .font(CuteFont.display(18, relativeTo: .headline))
                                    .foregroundStyle(Cute.ink)
                                    .accessibilityAddTraits(.isHeader)
                                Text(heading.note)
                                    .font(CuteFont.body(15, relativeTo: .subheadline))
                                    .foregroundStyle(Cute.ink)
                            }
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 8)
                        }
                        ForEach(Array(Licences.paragraphs(LicenceText.read(path)).enumerated()),
                                id: \.offset) { _, paragraph in
                            Text(paragraph)
                                .font(CuteFont.body(13, relativeTo: .footnote))
                                .foregroundStyle(Cute.inkSoft)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    // Soundscape's MIT licence first, then the way on to the
                    // notices of the code it adapts, which run to pages.
                    if page == Licences.soundscape {
                        LicenceLink(page: Licences.soundscapeNotices)
                            .licenceCard()
                            .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(Cute.paper, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// A row that opens an entry's page: its title, its sentence, and the way on.
private struct LicenceLink: View {
    let page: Licences.Page

    var body: some View {
        NavigationLink(value: page) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(LicenceCopy.title(page))
                        .font(CuteFont.body(16, weight: "SemiBold", relativeTo: .body))
                        .foregroundStyle(Cute.ink)
                    Text(LicenceCopy.covers(page))
                        .font(CuteFont.body(13, relativeTo: .footnote))
                        .foregroundStyle(Cute.inkFaint)
                }
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Cute.inkFaint)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
            .accessibilityElement(children: .combine)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("Licence-\(page.id)")
    }
}

private struct LicenceDivider: View {
    var body: some View {
        Rectangle().fill(Cute.rule).frame(height: 1).padding(.leading, 18)
    }
}

private extension View {
    /// The settings list's card, around the licences' rows.
    func licenceCard() -> some View {
        let shape = RoundedRectangle(cornerRadius: Cute.cardRadius, style: .continuous)
        return background(shape.fill(Cute.paperDeep))
            .overlay(shape.stroke(Cute.tileEdge, lineWidth: 1))
    }
}

/// Each page's words, from `Vocabulary`.
enum LicenceCopy {
    static func title(_ page: Licences.Page) -> String {
        switch page {
        case Licences.soundscape: Vocabulary.licenceSoundscapeTitle
        case Licences.soundscapeNotices: Vocabulary.licenceNoticesTitle
        case Licences.wordLists: Vocabulary.licenceWordListsTitle
        case Licences.wiktionary: Vocabulary.licenceWiktionaryTitle
        default: Vocabulary.licenceTypefacesTitle
        }
    }

    static func covers(_ page: Licences.Page) -> String {
        switch page {
        case Licences.soundscape: Vocabulary.licenceSoundscape
        case Licences.soundscapeNotices: Vocabulary.licenceChromium
        case Licences.wordLists: Vocabulary.licenceWordLists
        case Licences.wiktionary: Vocabulary.licenceWiktionary
        default: Vocabulary.licenceTypefaces
        }
    }

    /// A heading over one text, where a page shows more than one.
    static func heading(_ path: String) -> (title: String, note: String)? {
        switch path {
        case "App/Fonts/OFL-Fredoka.txt": (Vocabulary.licenceFredokaTitle, Vocabulary.licenceFredoka)
        case "App/Fonts/OFL-Nunito.txt": (Vocabulary.licenceNunitoTitle, Vocabulary.licenceNunito)
        default: nil
        }
    }
}

/// A licence text from the bundle, by its path in the repository: `Data/`'s
/// from the bundle's `Data` folder, the rest from its top level, where the
/// build copies `App/Licences/` and `App/Fonts/`.
enum LicenceText {
    static func read(_ path: String) -> String {
        let file = (path as NSString).lastPathComponent
        let name = (file as NSString).deletingPathExtension
        let directory = path.hasPrefix("Data/") ? "Data" : nil
        guard let url = Bundle.main.url(forResource: name, withExtension: "txt", subdirectory: directory),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return "" }
        return text
    }
}
