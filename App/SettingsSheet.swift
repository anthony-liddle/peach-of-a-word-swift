import PeachEngine
import SwiftUI

/// Settings, a sheet from the title screen: the sound switch, How the words
/// work, Licences, and the privacy policy.
///
/// **A short list,** as the design pass mocked and Antoine chose: the switch on
/// top, and three rows that open what they name.
///
/// **The colophon's links live here now.** On 22 October 2026 the foot of the
/// found list kept only the dedication: How the words work and the privacy
/// policy are this list's rows, and the credits are on Licences.
struct SettingsSheet: View {
    /// The switch, turned: the game stops or starts the player.
    let onSound: (Bool) -> Void
    let onClose: () -> Void

    /// On by default; a mute is remembered (D5). `@AppStorage`'s default
    /// covers a phone that has never written the key. See `SoundSetting`.
    @AppStorage(SoundSetting.key) private var soundOn = true
    @State private var explaining = false

    /// The pages pushed onto the list: Licences, then an entry's page, and from
    /// Soundscape's the notices. `-openLicences 1` starts on Licences, and
    /// `-openLicence <id>` goes on to that entry's page (`Licences.Page.id`).
    @State private var path: NavigationPath = {
        var path = NavigationPath()
        #if DEBUG
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: "openLicences") { path.append("licences") }
        if let id = defaults.string(forKey: "openLicence"),
           let page = Licences.all.first(where: { $0.id == id }) {
            if page == Licences.soundscapeNotices { path.append(Licences.soundscape) }
            path.append(page)
        }
        #endif
        return path
    }()

    private var card: RoundedRectangle {
        RoundedRectangle(cornerRadius: Cute.cardRadius, style: .continuous)
    }

    var body: some View {
        NavigationStack(path: $path) {
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
            .navigationDestination(for: Licences.Page.self) { LicenceTextPage(page: $0) }
        }
        .tint(Cute.accentDeep)
        .onChange(of: soundOn) { onSound(soundOn) }
        .sheet(isPresented: $explaining) {
            HowItWorks { explaining = false }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        #if DEBUG
        // Once Settings is up, `-openExplainer 1` opens How the words work and
        // `-openPrivacy 1` the policy, for tests and pictures: simctl cannot
        // tap. The explainer's hook was the colophon's, and moved with the way
        // in; both need `-openSettings 1`.
        .task {
            let defaults = UserDefaults.standard
            guard defaults.bool(forKey: "openExplainer") || defaults.bool(forKey: "openPrivacy") else { return }
            try? await Task.sleep(for: .seconds(1))
            if defaults.bool(forKey: "openExplainer") { explaining = true }
            if defaults.bool(forKey: "openPrivacy") { SafariPage.open(SafariPage.privacyPolicy) }
        }
        #endif
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
            // In a Safari view, not a handoff to Safari: the policy is a page
            // of the game's own site, read and closed without leaving the game.
            // See `SafariPage`. The arrow still says it is a page of the web.
            Button { SafariPage.open(SafariPage.privacyPolicy) } label: {
                SettingsRow(title: Vocabulary.privacyLinkSpoken, note: Vocabulary.privacyNote,
                            trailing: "arrow.up.right")
            }
            .buttonStyle(.plain)
            .accessibilityHint(Vocabulary.privacyHint)
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
    var identifier: String = "SheetClose"
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
        // Spoken as written, not as the capitals drawn.
        .accessibilityLabel(title)
        .accessibilityIdentifier(identifier)
    }
}
