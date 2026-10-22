import Foundation

/// The Licences screen's pages: which texts each one shows, and how a text is
/// broken into paragraphs for a phone.
///
/// **In the engine, not the app,** so `PlayerLicencesTests` can hold each page
/// to its files: that every file is there, that no file is left off a page, and
/// that the paragraphs a page shows put back together are its file, word for
/// word. The titles and the sentence over each page are the app's copy, in
/// `Vocabulary`.
///
/// **Every text stays in the app, in full.** The six BSD-style notices in
/// Soundscape's ask that a binary reproduce them "in the documentation and/or
/// other materials provided with the distribution", and Soundscape's README
/// says an app that ships it carries them. A link out to a web page would be
/// the weaker way to do that, so the texts are in the bundle and on screen,
/// one page down from the list.
public enum Licences {
    /// One page of the screen, and its texts, by their path in the repository:
    /// `Data/` for the files the data directory carries, `App/` for the rest.
    public struct Page: Hashable, Sendable, Identifiable {
        public let id: String
        public let files: [String]
    }

    /// Soundscape's MIT licence. Its page leads on to `soundscapeNotices`.
    public static let soundscape = Page(id: "soundscape", files: ["Data/Soundscape-LICENSE.txt"])

    /// The seven notices of the code Soundscape adapts: Chromium's own, four of
    /// Google's, Intel's, and Sun's for fdlibm.
    public static let soundscapeNotices = Page(id: "soundscape-notices",
                                               files: ["Data/Soundscape-LICENSE-CHROMIUM.txt"])

    /// ENABLE's and SCOWL's terms, SCOWL's notice word for word.
    public static let wordLists = Page(id: "word-lists", files: ["App/Licences/WordLists.txt"])

    /// Wiktionary's licence, CC BY-SA 4.0, for the definitions and etymologies.
    public static let wiktionary = Page(id: "wiktionary", files: ["App/Licences/Wiktionary.txt"])

    /// The two typefaces' SIL Open Font License texts, Fredoka's then Nunito's.
    public static let typefaces = Page(id: "typefaces",
                                       files: ["App/Fonts/OFL-Fredoka.txt", "App/Fonts/OFL-Nunito.txt"])

    /// The list, in its order. The notices are reached from Soundscape's page.
    public static let list = [soundscape, wordLists, wiktionary, typefaces]

    /// Every page, the notices included.
    public static let all = list + [soundscapeNotices]

    /// A text broken into the paragraphs a page shows.
    ///
    /// The texts are wrapped at about 72 columns, for a terminal. A paragraph
    /// whose lines are all flush left is running prose and is joined, so it
    /// wraps to the phone; one with indented or listed lines, such as the
    /// notices' file paths, keeps its breaks.
    public static func paragraphs(_ text: String) -> [String] {
        text.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .newlines) }
            .filter { !$0.isEmpty }
            .map { paragraph in
                let lines = paragraph.components(separatedBy: "\n")
                let prose = lines.dropFirst().allSatisfy { line in
                    !(line.first?.isWhitespace ?? true)
                        && !line.hasPrefix("- ") && !line.hasPrefix("* ")
                }
                return prose ? lines.joined(separator: " ") : paragraph
            }
    }
}
