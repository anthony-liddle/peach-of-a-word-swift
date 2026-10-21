import SwiftUI

/// Settings, a sheet from the title screen: the sound switch, How the words
/// work, Licences, and the privacy policy.
///
/// **A short list,** as the design pass mocked and Antoine chose: the switch on
/// top, and three rows that open what they name. The colophon stays at the foot
/// of the found list, so the credits are not repeated here.
struct SettingsSheet: View {
    /// The switch, turned: the game stops or starts the player.
    let onSound: (Bool) -> Void
    let onClose: () -> Void

    /// On by default; a mute is remembered (D5). `@AppStorage`'s default
    /// covers a phone that has never written the key. See `SoundSetting`.
    @AppStorage(SoundSetting.key) private var soundOn = true
    @State private var explaining = false

    private var card: RoundedRectangle {
        RoundedRectangle(cornerRadius: Cute.cardRadius, style: .continuous)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Cute.pageBackground.ignoresSafeArea()
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            Text(Vocabulary.settingsTitle)
                                .font(CuteFont.display(28, relativeTo: .largeTitle))
                                .foregroundStyle(Cute.ink)
                                .accessibilityAddTraits(.isHeader)
                            soundCard
                            rows
                        }
                        .padding(.horizontal, 22)
                        .padding(.vertical, 24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    SheetCloseButton(action: onClose)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: String.self) { _ in LicencesPage() }
        }
        .tint(Cute.accentDeep)
        .onChange(of: soundOn) { onSound(soundOn) }
        .sheet(isPresented: $explaining) {
            HowItWorks { explaining = false }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    /// The switch, with what it governs under it. VoiceOver hears a switch
    /// named "Sound", and the line as its hint rather than as a second stop.
    private var soundCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: $soundOn) {
                Text(Vocabulary.soundSwitch)
                    .font(CuteFont.body(17, weight: "SemiBold", relativeTo: .body))
                    .foregroundStyle(Cute.ink)
            }
            .tint(Cute.accent)
            .accessibilityHint(Vocabulary.soundNote)
            .accessibilityIdentifier("SettingsSound")
            Text(Vocabulary.soundNote)
                .font(CuteFont.body(14, relativeTo: .subheadline))
                .foregroundStyle(Cute.inkFaint)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)
        }
        .padding(18)
        .background(card.fill(Cute.paperDeep))
        .overlay(card.stroke(Cute.tileEdge, lineWidth: 1))
    }

    private var rows: some View {
        VStack(spacing: 0) {
            Button { explaining = true } label: {
                SettingsRow(title: Vocabulary.explainerTitle, note: nil, trailing: "chevron.right")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("SettingsHowWords")
            divider
            NavigationLink(value: "licences") {
                SettingsRow(title: Vocabulary.licencesTitle, note: Vocabulary.licencesNote,
                            trailing: "chevron.right")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("SettingsLicences")
            divider
            // A `Link`, so the page opens in the browser and the app itself
            // loads nothing, as the colophon's link does.
            Link(destination: Colophon.privacyPolicy) {
                SettingsRow(title: Vocabulary.privacyLinkSpoken, note: Vocabulary.privacyLink,
                            trailing: "arrow.up.right")
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens in Safari")
            .accessibilityIdentifier("SettingsPrivacy")
        }
        .background(card.fill(Cute.paperDeep))
        .overlay(card.stroke(Cute.tileEdge, lineWidth: 1))
    }

    private var divider: some View {
        Rectangle().fill(Cute.rule).frame(height: 1).padding(.leading, 18)
    }
}

/// One row of the settings list: a title, an optional line, and where it goes.
private struct SettingsRow: View {
    let title: String
    let note: String?
    let trailing: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(CuteFont.body(16, weight: "SemiBold", relativeTo: .body))
                    .foregroundStyle(Cute.ink)
                if let note {
                    Text(note)
                        .font(CuteFont.body(13, relativeTo: .footnote))
                        .foregroundStyle(Cute.inkFaint)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Image(systemName: trailing)
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
}

/// The pinned way out, as the explainer's: below the fold is no place for it.
struct SheetCloseButton: View {
    var title: String = Vocabulary.close
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(CuteFont.body(15, weight: "SemiBold", relativeTo: .subheadline))
                .tracking(2.1)
                .textCase(.uppercase)
                .foregroundStyle(Cute.paper)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 52)
                .padding(.vertical, 6)
                .background(Capsule().fill(Cute.accent))
        }
        .buttonStyle(PillPressStyle())
        .padding(.horizontal, 22)
        .padding(.top, 12)
        .padding(.bottom, 20)
        .background(Cute.pageBackground)
        .accessibilityIdentifier("SheetClose")
    }
}

// MARK: - Licences

/// Every licence the app carries, each under a sentence saying what it covers.
///
/// **Read from the bundle,** so the screen shows the files that ship, byte for
/// byte, rather than a copy that could drift from them: Soundscape's two from
/// `Data/`, which `SoundscapeLicenceTests` pins, the fonts' OFL texts, and the
/// word lists' and Wiktionary's terms from `App/Licences/`, which
/// `PlayerLicencesTests` holds to `Data/ATTRIBUTION.md`.
struct LicencesPage: View {
    struct Notice: Identifiable {
        let id: String
        let title: String
        let covers: String
        let text: String
    }

    static let files: [(id: String, title: String, covers: String, name: String, directory: String?)] = [
        ("soundscape", "Soundscape", Vocabulary.licenceSoundscape, "Soundscape-LICENSE", "Data"),
        ("chromium", "Soundscape's notices", Vocabulary.licenceChromium,
         "Soundscape-LICENSE-CHROMIUM", "Data"),
        ("words", "The word lists", Vocabulary.licenceWordLists, "WordLists", nil),
        ("wiktionary", "Wiktionary", Vocabulary.licenceWiktionary, "Wiktionary", nil),
        ("fredoka", "Fredoka", Vocabulary.licenceFredoka, "OFL-Fredoka", nil),
        ("nunito", "Nunito", Vocabulary.licenceNunito, "OFL-Nunito", nil),
    ]

    private let notices: [Notice] = Self.files.compactMap { file in
        guard let url = Bundle.main.url(forResource: file.name, withExtension: "txt",
                                        subdirectory: file.directory),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return Notice(id: file.id, title: file.title, covers: file.covers, text: text)
    }

    var body: some View {
        ZStack {
            Cute.pageBackground.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(Vocabulary.licencesTitle)
                        .font(CuteFont.display(26, relativeTo: .title))
                        .foregroundStyle(Cute.ink)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(notices) { notice in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(notice.title)
                                .font(CuteFont.display(18, relativeTo: .headline))
                                .foregroundStyle(Cute.ink)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityAddTraits(.isHeader)
                            Text(notice.covers)
                                .font(CuteFont.body(15, relativeTo: .subheadline))
                                .foregroundStyle(Cute.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            ForEach(Array(Self.paragraphs(notice.text).enumerated()),
                                    id: \.offset) { _, paragraph in
                                Text(paragraph)
                                    .font(CuteFont.body(13, relativeTo: .footnote))
                                    .foregroundStyle(Cute.inkSoft)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .accessibilityIdentifier("Licence-\(notice.id)")
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

    /// The texts are wrapped at about 72 columns, for a terminal. A paragraph
    /// whose lines are all flush left is running prose and is joined, so it
    /// wraps to the phone; one with indented or listed lines, such as the
    /// notices' file paths, keeps its breaks.
    static func paragraphs(_ text: String) -> [String] {
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
