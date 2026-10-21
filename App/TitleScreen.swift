import PeachEngine
import SwiftUI

/// What the title screen can ask of the board.
struct TitleActions {
    /// Today's board, from Play or Continue.
    let play: () -> Void
    /// The calendar of past days.
    let pastDays: () -> Void
    /// A day from the week, by storage day index.
    let openDay: (Int) -> Void
    /// A past day, chosen for the player.
    let randomDay: () -> Void
    /// The settings sheet.
    let settings: () -> Void
}

/// The title screen: the peach and the name, then today and the last seven
/// days, then Play.
///
/// **It replaces the splash rather than sitting over it.** It draws at once,
/// because nothing above Play needs the word lists: the date, the streak, the
/// week and whether today has started all come from the store. Play waits for
/// the board, disabled and saying so in the splash's own words, and the line
/// under it is reserved, so nothing moves when the board arrives.
///
/// Built from the design pass's direction C (`reports/2026-10-21 A Title
/// Screen And Settings.md`), with A's "Pick the peaches" under the name.
struct TitleScreen: View {
    let model: GameModel
    let actions: TitleActions

    @State private var arrived = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var ready: Bool {
        if case .ready = model.phase { return true }
        return false
    }

    /// Today's board, once it is the board in play.
    private var standing: TierStanding? {
        guard ready, !model.isArchiveBoard else { return nil }
        return model.standing
    }

    private var started: Bool { model.todayStarted }

    private var complete: Bool { standing.map(isComplete) ?? false }

    private var buttonTitle: String {
        guard started else { return Vocabulary.titlePlay }
        return complete ? Vocabulary.titleBasketFull : Vocabulary.titleContinue
    }

    /// The calendar's own words for a day not started or started, and the rank
    /// with the basket once the board is known.
    private var stateLine: String {
        guard started else { return Vocabulary.markNoRecord }
        guard let standing else { return Vocabulary.markIncomplete }
        let rank = complete
            ? Vocabulary.crownName
            : Vocabulary.tierNames[min(standing.index, Vocabulary.tierNames.count - 1)]
        return Vocabulary.titleStanding(rank: rank, found: standing.setFound,
                                        total: standing.setTotal)
    }

    private var today: Date { GameModel.date(forStorageDay: GameModel.todayStorageIndex) }

    private var streak: Int { ready ? model.streak : model.storedStreak }

    var body: some View {
        ZStack {
            Cute.pageBackground.ignoresSafeArea()
            TitleFit {
                TitleTop(arrived: arrived)
            } lead: {
                VStack(alignment: .leading, spacing: 10) {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .firstTextBaseline) { heading(inRow: true) }
                        VStack(alignment: .leading, spacing: 4) { heading(inRow: false) }
                    }
                    WeekStrip(days: model.titleWeek(), ready: ready) { day in
                        if day.isToday { actions.play() } else { actions.openDay(day.day) }
                    }
                }
                .padding(.bottom, 16)
            } foot: {
                VStack(spacing: 6) {
                    TitlePlayButton(title: buttonTitle, stateLine: stateLine, started: started,
                                    ready: ready, action: actions.play)
                    TitleStateLine(text: stateLine, crowned: complete)
                }
            } extras: {
                VStack(spacing: 8) {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) { pills(fills: false) }
                        VStack(spacing: 8) { pills(fills: true) }
                    }
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 18) { links }
                        VStack(spacing: 0) { links }
                    }
                }
            }
        }
        // The peach settles in. Under Reduce Motion it is simply there.
        .onAppear {
            if reduceMotion { arrived = true } else { withAnimation(Feel.settle) { arrived = true } }
        }
        .accessibilityElement(children: .contain)
    }

    /// Today's date heads the week, with the streak beside it.
    @ViewBuilder private func heading(inRow: Bool) -> some View {
        Text(today.formatted(.dateTime.weekday(.wide).day().month(.wide)))
            .font(CuteFont.display(19, relativeTo: .title3))
            .foregroundStyle(Cute.ink)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("TitleDate")
        if inRow { Spacer(minLength: 8) }
        if streak > 0 { TitleStreak(streak: streak) }
    }

    @ViewBuilder private func pills(fills: Bool) -> some View {
        TitlePill(title: Vocabulary.archiveTitle, systemImage: "calendar",
                  identifier: "TitlePastDays", fills: fills, action: actions.pastDays)
        TitlePill(title: Vocabulary.titleRandomDay, systemImage: "dice",
                  identifier: "TitleRandomDay", disabled: !ready, fills: fills,
                  hint: Vocabulary.titleRandomDayHint, action: actions.randomDay)
    }

    /// The quiet ways out: underlined links, below the pills.
    @ViewBuilder private var links: some View {
        TitleLink(title: Vocabulary.settingsTitle, identifier: "TitleSettings",
                  action: actions.settings)
    }
}

/// A link on the title: underlined text in a 44pt target.
struct TitleLink: View {
    let title: String
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(CuteFont.body(15, weight: "SemiBold", relativeTo: .subheadline))
                .foregroundStyle(Cute.accentDeep)
                .underline()
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: Cute.minTapTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}

// MARK: - The top

/// The peach, the name and "Pick the peaches": the title's top, and the whole
/// of what shows while the board loads on a launch that skips the title, so
/// the app has one loading look rather than two.
struct TitleTop: View {
    let arrived: Bool

    var body: some View {
        VStack(spacing: 12) {
            PeachMark()
                .frame(width: 96, height: 96)
                .scaleEffect(arrived ? 1 : 0.88)
                .opacity(arrived ? 1 : 0)
                .accessibilityHidden(true)
            TitleWordmark()
            Text(Vocabulary.mastheadSubline)
                .font(CuteFont.body(12, weight: "SemiBold", relativeTo: .caption))
                .tracking(4.4)
                .textCase(.uppercase)
                .foregroundStyle(Cute.accentDeep)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// The name, as the masthead set it, and with it the splash before the title.
///
/// "Peach" keeps the pink oblique, the half of the wordmark that is not just
/// words. `displayOblique` shears Fredoka by hand, because Fredoka has no
/// italic face and `.italic()` selects nothing; see `CuteFont`. The halves are
/// joined with `+`, one text run, so they wrap and scale as a unit rather than
/// as two views in a stack. It wraps rather than shrinking: the splash's
/// `minimumScaleFactor` is not carried over, since a name drawn smaller than
/// the size asked for passes a truncation check and fails a reader.
struct TitleWordmark: View {
    var body: some View {
        (Text("Peach").font(CuteFont.displayOblique(30, relativeTo: .largeTitle))
            .foregroundColor(Cute.accent)
         + Text(" of a Word").font(CuteFont.display(30, relativeTo: .largeTitle))
            .foregroundColor(Cute.ink))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }
}

/// What shows while the board loads on a launch that opens on the board: the
/// title's top, and the splash's spinner and line under it.
struct LoadingTop: View {
    var body: some View {
        VStack(spacing: 18) {
            TitleTop(arrived: true)
            ProgressView().tint(Cute.accent)
            Text(Vocabulary.loadingLine)
                .font(CuteFont.body(14, relativeTo: .subheadline))
                .foregroundStyle(Cute.inkFaint)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Play

/// Play, Continue or back to a full basket, or the load still running.
///
/// **Disabled until the board is ready, in the splash's own words.** The line
/// moves into the button, so the load keeps the voice it has always had, and
/// the button is where the eye already is when it ends.
struct TitlePlayButton: View {
    let title: String
    let stateLine: String
    let started: Bool
    let ready: Bool
    let action: () -> Void
    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 56

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if !ready { ProgressView().tint(Cute.accent) }
                Text(ready ? title : Vocabulary.loadingLine)
                    .font(CuteFont.body(17, weight: "SemiBold", relativeTo: .body))
                    .tracking(ready ? 2.4 : 0.3)
                    .textCase(ready ? .uppercase : nil)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(ready ? Cute.paper : Cute.inkFaint)
            .padding(.horizontal, 18)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .frame(minHeight: height)
            .background(Capsule().fill(ready ? Cute.accent : Cute.paperDeep))
            .overlay(Capsule().stroke(ready ? Cute.accent : Cute.rule, lineWidth: 1))
        }
        .buttonStyle(PillPressStyle())
        .disabled(!ready)
        // The button it will be, then why it waits, or what it opens onto: the
        // line under it is not a second stop.
        .accessibilityLabel(ready ? (started ? "\(title), \(stateLine)" : title)
                                  : "\(title), \(Vocabulary.loadingLine)")
        .accessibilityIdentifier("TitlePlay")
    }
}

/// The line under Play. One line reserved below the accessibility sizes and
/// two at them, so the rank arriving with the board never shoves the screen.
struct TitleStateLine: View {
    let text: String
    let crowned: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Text(text)
            .font(CuteFont.body(14, weight: "SemiBold", relativeTo: .subheadline))
            .foregroundStyle(crowned ? Cute.crownDeep : Cute.inkFaint)
            .multilineTextAlignment(.center)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1, reservesSpace: true)
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
    }
}

// MARK: - Pieces

/// A quiet pill, as the board's utility controls are drawn.
struct TitlePill: View {
    let title: String
    var systemImage: String? = nil
    let identifier: String
    var disabled: Bool = false
    /// Full width in a stack; hugging its label in a row, so a row is only
    /// chosen when every label fits on one line.
    var fills: Bool = true
    var hint: String? = nil
    let action: () -> Void
    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 46

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.footnote.weight(.semibold))
                        .accessibilityHidden(true)
                }
                Text(title)
                    .font(CuteFont.body(14, weight: "SemiBold", relativeTo: .subheadline))
                    .tracking(1.4)
                    .textCase(.uppercase)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(disabled ? Cute.inkFaint : Cute.inkSoft)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .frame(maxWidth: fills ? .infinity : nil)
            .frame(minHeight: height)
            .background(Capsule().fill(Cute.paperDeep))
            .overlay(Capsule().stroke(Cute.rule, lineWidth: 1))
        }
        .buttonStyle(PillPressStyle())
        .disabled(disabled)
        .accessibilityLabel(title)
        .accessibilityHint(hint ?? "")
        .accessibilityIdentifier(identifier)
    }
}

/// The streak, as the meter's caption draws it.
struct TitleStreak: View {
    let streak: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
            Text(counted(streak, "day")).monospacedDigit()
        }
        .font(CuteFont.body(15, weight: "SemiBold", relativeTo: .subheadline))
        .foregroundStyle(Cute.crownDeep)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Streak, \(counted(streak, "day"))")
        .accessibilityIdentifier("TitleStreak")
    }
}

/// Fits the screen when it can, and scrolls with Play pinned when it cannot.
///
/// The board's own rule, `ContentView.game`: chosen by `ViewThatFits` on
/// height, and in the scrolling branch the most used target stays put. Text in
/// the fixed branch is held to its ideal height, so the choice is never made on
/// a layout that only holds by squeezing a label. `lead` sits just above Play
/// in the fixed branch and scrolls in the other, so only the button and its
/// line are ever pinned.
struct TitleFit<Content: View, Lead: View, Foot: View, Extras: View>: View {
    @ViewBuilder let content: Content
    @ViewBuilder let lead: Lead
    @ViewBuilder let foot: Foot
    @ViewBuilder let extras: Extras

    var body: some View {
        ViewThatFits(in: .vertical) {
            VStack(spacing: 0) {
                Spacer(minLength: 8)
                content
                Spacer(minLength: 16)
                lead
                foot
                extras.padding(.top, 14)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .frame(maxWidth: 520)

            ScrollView {
                VStack(spacing: 0) {
                    content
                    lead.padding(.top, 20)
                    extras.padding(.top, 20)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                foot
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Cute.pageFoot.ignoresSafeArea(edges: .bottom))
            }
        }
    }
}

// MARK: - The week

/// Seven days drawn by the calendar's own face, with their weekdays. A tap
/// opens that day's board, through `openArchiveDay`, the archive's one gate.
struct WeekStrip: View {
    let days: [ArchiveDay]
    let ready: Bool
    let onPick: (ArchiveDay) -> Void

    /// Sized from the window, as the calendar sizes its cells, and capped: the
    /// numbers inside are fixed to the cell, not to the text setting.
    private var cell: CGFloat {
        min(46, floor((ArchiveSheet.windowWidth - 48 - 6 * 6) / 7))
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(days, id: \.day) { day in
                VStack(spacing: 4) {
                    Text(day.date.formatted(.dateTime.weekday(.narrow)))
                        .font(.custom("Nunito-SemiBold", fixedSize: 12))
                        .foregroundStyle(Cute.inkFaint)
                        .accessibilityHidden(true)
                    Button { onPick(day) } label: {
                        ArchiveCellFace(
                            mark: day.mark,
                            day: Foundation.Calendar.current.component(.day, from: day.date),
                            size: cell
                        )
                        .overlay {
                            if day.isToday {
                                RoundedRectangle(cornerRadius: cell * 0.3 + ArchiveCellFace.ringOutset)
                                    .strokeBorder(Cute.ink, lineWidth: 1.5)
                                    .padding(-ArchiveCellFace.ringOutset)
                            }
                        }
                        .frame(minHeight: Cute.minTapTarget)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!ready)
                    .accessibilityLabel(label(day))
                    .accessibilityIdentifier(day.isToday ? "WeekToday" : "WeekDay")
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    /// The calendar's words: the date, the day's state, and "today".
    private func label(_ day: ArchiveDay) -> String {
        var parts = [day.date.formatted(.dateTime.weekday(.wide).day().month(.wide))]
        switch day.mark {
        case .notYet: parts.append(Vocabulary.markNotYet)
        case .noRecord: parts.append(Vocabulary.markNoRecord)
        case .incomplete: parts.append(Vocabulary.markIncomplete)
        case .cleared: parts.append(Vocabulary.markCleared)
        case .basket: parts.append(Vocabulary.markBasket)
        }
        if day.isToday { parts.append(Vocabulary.markToday) }
        return parts.joined(separator: ", ")
    }
}
