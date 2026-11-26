import PeachEngine
import SwiftUI

/// Peach rush: a run against the clock on today's board. The clock where the
/// board has its meter, then the board's own well, rack and controls, then the
/// run's finds. Its result replaces it when the run ends.
///
/// The design is `reports/2026-11-24 Timed Mode.md` in the vault, with
/// Antoine's answers in its update.
struct PeachRushScreen: View {
    let model: GameModel
    /// On to the basket: the board.
    let onBasket: () -> Void
    /// Done, Back, or the second scrub: the title. A run paused stays waiting.
    let onTitle: () -> Void

    @ScaledMetric(relativeTo: .body) private var minimumListHeight: CGFloat = 52
    @State private var askingToEnd = false

    var body: some View {
        if let run = model.run {
            if case .over(let early) = run.phase {
                PeachRushResult(model: model, run: run, endedEarly: early,
                                onBasket: onBasket, onTitle: onTitle)
                    // VoiceOver's scrub does what Done does: the result has
                    // no clock to pause (vault, `reports/2026-11-25
                    // Accessibility Labels.md`, finding 5).
                    .accessibilityAction(.escape) { onTitle() }
            } else {
                ViewThatFits(in: .vertical) {
                    fixed(run)
                    scrolling(run)
                }
                // VoiceOver's scrub (Antoine, 24 November): while the clock
                // runs, it pauses; paused or not started, it goes to the title.
                .accessibilityAction(.escape) {
                    if run.phase == .running { model.pauseRun(spoken: true) } else { onTitle() }
                }
                // End asks first: a day has one run.
                .alert(Vocabulary.runEndQuestion, isPresented: $askingToEnd) {
                    Button(Vocabulary.runEndConfirm, role: .destructive) { model.endRun(early: true) }
                    Button(Vocabulary.keepPlaying, role: .cancel) {}
                } message: {
                    Text(Vocabulary.runEndQuestionMessage)
                }
                #if DEBUG
                // `-timedRunAskEnd 1`: End's question, open, for a picture.
                .onAppear {
                    if UserDefaults.standard.bool(forKey: "timedRunAskEnd") { askingToEnd = true }
                }
                #endif
            }
        }
    }

    private var hidden: Bool { model.run?.phase != .running }

    /// The well says why the letters are hidden while they are.
    private func wellFeedback(_ run: RunState) -> GameModel.Feedback {
        switch run.phase {
        case .ready: .rejected(Vocabulary.runReady)
        case .paused: .rejected(Vocabulary.runPaused)
        default: model.feedback
        }
    }

    private func header(_ run: RunState) -> some View {
        PeachRushHeader(run: run) {
            if run.phase == .ready { onTitle() } else { askingToEnd = true }
        }
    }

    @ViewBuilder private func controls(_ run: RunState) -> some View {
        switch run.phase {
        case .ready:
            PeachRushButton(title: Vocabulary.runStart, identifier: "RunStart") { model.startRun() }
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        case .paused:
            PeachRushButton(title: Vocabulary.runResume, identifier: "RunResume") { model.startRun() }
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        default:
            Controls(model: model)
        }
    }

    private func fixed(_ run: RunState) -> some View {
        VStack(spacing: 0) {
            header(run)
                .fixedSize(horizontal: false, vertical: true)
            ComposingStick(word: model.composedWord, feedback: wellFeedback(run),
                           feedbackSeq: model.feedbackSeq, glint: model.glint)
                .padding(.top, 12)
            TypeCase(model: model, commitOnTouchDown: true, hidden: hidden)
                .accessibilityHidden(hidden)
                .padding(.top, 8)
            controls(run)
                .padding(.top, 8)
            ScrollView { PeachRushFinds(model: model, words: run.found) }
                .frame(minHeight: minimumListHeight, idealHeight: minimumListHeight,
                       maxHeight: .infinity)
                .padding(.top, 6)
        }
        .padding(.horizontal, 18)
        .padding(.top, 4)
    }

    /// Where the fixed layout can't fit: the clock pinned at the top and the
    /// controls at the bottom, so the time is never scrolled away.
    private func scrolling(_ run: RunState) -> some View {
        ScrollView {
            VStack(spacing: 14) {
                ComposingStick(word: model.composedWord, feedback: wellFeedback(run),
                               feedbackSeq: model.feedbackSeq, glint: model.glint,
                               slideCancelsTap: false)
                TypeCase(model: model, commitOnTouchDown: false, hidden: hidden)
                    .accessibilityHidden(hidden)
                PeachRushFinds(model: model, words: run.found)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            header(run)
                .padding(.horizontal, 18)
                .padding(.top, 4)
                .padding(.bottom, 8)
                .background(Cute.paper.ignoresSafeArea(edges: .top))
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            controls(run)
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(Cute.pageFoot.ignoresSafeArea(edges: .bottom))
        }
    }
}

/// The clock, the tally and the way out, where the board has its meter.
///
/// **Held at AX1, as the controls are.** The digits are already 40pt; at AX5
/// the row would take a third of an SE before the rack.
struct PeachRushHeader: View {
    let run: RunState
    let onLeave: () -> Void

    private var lastSeconds: Bool { run.phase == .running && run.remaining <= 10 }

    /// End, once the clock has started: it asks first.
    private var endButton: some View {
        Button(action: onLeave) {
            Text(Vocabulary.runEnd)
                .font(CuteFont.body(14, weight: "SemiBold", relativeTo: .subheadline))
                .tracking(1.4)
                .textCase(.uppercase)
                .foregroundStyle(Cute.inkSoft)
                .padding(.horizontal, 14)
                .frame(minHeight: Cute.minTapTarget)
                .background(Capsule().fill(Cute.paperDeep))
                .overlay(Capsule().stroke(Cute.rule, lineWidth: 1))
        }
        .buttonStyle(PillPressStyle())
        .accessibilityIdentifier("RunLeave")
    }

    /// Back to the title before Start, as the board's chevron is drawn and
    /// heard: "Back to the title screen", a button, first in its row.
    private var backChevron: some View {
        Button(action: onLeave) {
            Text(Image(systemName: "chevron.backward"))
                .font(.system(.headline).weight(.semibold))
                .foregroundStyle(Cute.accentDeep)
                .dynamicTypeSize(...DynamicTypeSize.large)
                .frame(width: 11, alignment: .leading)
                .frame(width: Cute.minTapTarget, height: Cute.minTapTarget, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Vocabulary.backToTitle)
        .accessibilityShowsLargeContentViewer {
            Label(Vocabulary.backToTitle, systemImage: "chevron.backward")
        }
        // First in the header, as the board's is first in the meter.
        .accessibilitySortPriority(1)
        .accessibilityIdentifier("RunBack")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 12) {
                Text(runClockText(run.remaining))
                    .font(CuteFont.display(40, relativeTo: .largeTitle))
                    .monospacedDigit()
                    .foregroundStyle(lastSeconds ? Cute.accentDeep : Cute.ink)
                    .accessibilityLabel(Vocabulary.runClockSpoken(runSpokenTime(run.remaining)))
                    .accessibilityAddTraits(.updatesFrequently)
                    .accessibilityIdentifier("RunClock")
                    // Before Start, the way back is the board's own chevron in
                    // the margin, "Back to the title screen" to VoiceOver: a
                    // bare "Back" is system language the game keeps out of
                    // its words (`OneDefinitionCardTests`).
                    .overlay(alignment: .leading) {
                        if run.phase == .ready { backChevron.offset(x: -15) }
                    }
                Spacer(minLength: 4)
                VStack(alignment: .trailing, spacing: 0) {
                    Text(counted(run.points, "point"))
                        .font(CuteFont.body(15, weight: "Bold", relativeTo: .subheadline))
                    Text(counted(run.found.count, "word"))
                        .font(CuteFont.body(13, weight: "SemiBold", relativeTo: .caption))
                        .foregroundStyle(Cute.inkFaint)
                }
                .foregroundStyle(Cute.ink)
                .monospacedDigit()
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("RunTally")
                // Held in its place before Start, unseen, so the tally doesn't
                // move when End arrives.
                endButton
                    .opacity(run.phase == .ready ? 0 : 1)
                    .disabled(run.phase == .ready)
                    .accessibilityHidden(run.phase == .ready)
            }
            // The time left as a bar that empties. Never animated: it steps
            // with the clock, so Reduce Motion has nothing to stop.
            Capsule()
                .fill(Cute.rule)
                .frame(height: 8)
                .overlay(alignment: .leading) {
                    GeometryReader { bar in
                        Capsule()
                            .fill(lastSeconds ? Cute.accentDeep : Cute.accent)
                            .frame(width: bar.size.width * max(0, min(1, run.remaining / run.length)))
                    }
                }
                .accessibilityHidden(true)
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        // Its own elements, so the way back can be sorted ahead of the clock,
        // as the board's meter sorts its chevron ahead of the rank's name.
        .accessibilityElement(children: .contain)
    }
}

/// Start, Resume and On to the basket: where the controls will be, so the
/// thumb is already there. The caller caps its text size, so its height,
/// read from the environment, is capped too.
struct PeachRushButton: View {
    let title: String
    let identifier: String
    let action: () -> Void
    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 56

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(CuteFont.body(17, weight: "SemiBold", relativeTo: .body))
                .tracking(2.4)
                .textCase(.uppercase)
                .foregroundStyle(Cute.paper)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .frame(minHeight: height)
                .background(Capsule().fill(Cute.button))
        }
        .buttonStyle(PillPressStyle())
        .accessibilityIdentifier(identifier)
    }
}

/// A run's finds, newest first, with no length groups: the basket's counts
/// would say how many words the board holds.
struct PeachRushFinds: View {
    let model: GameModel
    let words: [String]
    /// What a word opens. Nil while the clock runs, so the words are words,
    /// not buttons; the result opens each one's card (Antoine, 25 November).
    var onSelect: ((FoundWord) -> Void)? = nil

    var body: some View {
        FlowLayout {
            ForEach(words, id: \.self) { word in
                if let puzzle = model.puzzle {
                    let rung = classifyWord(word, in: puzzle)
                    let found = FoundWord(
                        word: word,
                        category: word == puzzle.sourceWord ? .source : WordCategory(rung),
                        score: findScore(word, rung: rung))
                    WordChip(found: found, onSelect: onSelect.map { select in { select(found) } })
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("RunFinds")
    }
}

/// The end of a run: what it found, the peach of a word if it was found, and
/// the way to the basket.
struct PeachRushResult: View {
    let model: GameModel
    let run: RunState
    let endedEarly: Bool
    let onBasket: () -> Void
    let onTitle: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var record: RunRecord {
        RunRecord(day: run.day, words: run.found, points: run.points, peachFound: run.peachFound,
                  endedEarly: endedEarly, secondsLeft: Int(run.remaining.rounded(.up)),
                  length: run.length)
    }

    private var best: (word: String, points: Int)? {
        guard let puzzle = model.puzzle else { return nil }
        return bestRunWord(run.found) { findScore($0, rung: classifyWord($0, in: puzzle)) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                VStack(spacing: 6) {
                    Text(Vocabulary.runName)
                        .font(CuteFont.body(12, weight: "SemiBold", relativeTo: .caption))
                        .tracking(4.4)
                        .textCase(.uppercase)
                        .foregroundStyle(Cute.accentDeep)
                    Text(endedEarly ? Vocabulary.runEndedEarly(runClockText(run.remaining))
                                    : Vocabulary.runTimesUp)
                        .font(CuteFont.display(28, relativeTo: .title))
                        .foregroundStyle(Cute.ink)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("RunResultHeading")
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 28) { stats }
                    VStack(spacing: 10) { stats }
                }
                peach
                if let best {
                    Text(Vocabulary.runBestWord(best.word, points: best.points))
                        .font(CuteFont.body(16, weight: "SemiBold", relativeTo: .body))
                        .foregroundStyle(Cute.inkSoft)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                PeachRushFinds(model: model, words: run.found) { model.revealRunFind($0) }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: Cute.cardRadius).fill(Cute.paperDeep))
                    .overlay(RoundedRectangle(cornerRadius: Cute.cardRadius).stroke(Cute.rule, lineWidth: 1))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 8) {
                PeachRushButton(title: Vocabulary.runToBasket, identifier: "RunToBasket", action: onBasket)
                HStack(spacing: 8) {
                    ShareLink(item: buildRunShareText(name: Vocabulary.runName, record: record,
                                                      boardDate: model.boardDate)) {
                        pill(Vocabulary.runShare, systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(PillPressStyle())
                    .accessibilityIdentifier("RunShare")
                    Button(action: onTitle) { pill(Vocabulary.runDone, systemImage: nil) }
                        .buttonStyle(PillPressStyle())
                        .accessibilityIdentifier("RunDone")
                }
            }
            // As the board's controls: the words grow to AX1 and stop, so the
            // way out never covers the result.
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(Cute.pageFoot.ignoresSafeArea(edges: .bottom))
        }
    }

    @ViewBuilder private var stats: some View {
        stat(run.found.count, run.found.count == 1 ? "word" : "words")
        stat(run.points, run.points == 1 ? "point" : "points")
    }

    private func stat(_ n: Int, _ noun: String) -> some View {
        VStack(spacing: 0) {
            Text("\(n)")
                .font(CuteFont.display(44, relativeTo: .largeTitle))
                .monospacedDigit()
                .foregroundStyle(Cute.accent)
            Text(noun)
                .font(CuteFont.body(15, weight: "SemiBold", relativeTo: .subheadline))
                .foregroundStyle(Cute.inkSoft)
        }
        .accessibilityElement(children: .combine)
    }

    /// The word only when the run found it: a run never names a peach it
    /// missed, since the basket still has it to find.
    @ViewBuilder private var peach: some View {
        if run.peachFound, let word = model.puzzle?.sourceWord {
            Button { model.moment = .runPeach(word: word) } label: {
                let stack = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                    : AnyLayout(HStackLayout(spacing: 14))
                stack {
                    PeachMark(costume: model.costume)
                        .frame(width: 44, height: 44)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Vocabulary.runPeachFound)
                            .font(CuteFont.body(14, weight: "SemiBold", relativeTo: .subheadline))
                            .foregroundStyle(Cute.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(word)
                            .font(CuteFont.bodyOblique(22, weight: "SemiBold", relativeTo: .title2))
                            .foregroundStyle(Cute.crownDeep)
                    }
                    if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Cute.inkFaint)
                        .accessibilityHidden(true)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: Cute.cardRadius).fill(Cute.paperDeep))
                .overlay(RoundedRectangle(cornerRadius: Cute.cardRadius).stroke(Cute.crown, lineWidth: 1.5))
            }
            .buttonStyle(PillPressStyle())
            .accessibilityIdentifier("RunPeach")
        } else {
            Text(Vocabulary.runPeachHidden)
                .font(CuteFont.body(15, relativeTo: .subheadline))
                .foregroundStyle(Cute.inkFaint)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("RunPeachHidden")
        }
    }

    private func pill(_ title: String, systemImage: String?) -> some View {
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
        }
        .foregroundStyle(Cute.inkSoft)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 46)
        .background(Capsule().fill(Cute.paperDeep))
        .overlay(Capsule().stroke(Cute.rule, lineWidth: 1))
    }
}

/// The run's way in on the title, under Play: its name, and beside it the
/// clock's length, the time left of a run waiting, or the day's points once
/// played. One line at the pills' height where it fits, so the SE's title
/// keeps its fixed layout at L; two where it doesn't.
struct TitleRunButton: View {
    let offer: RunOffer
    let ready: Bool
    let action: () -> Void
    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 46
    /// Observed, so "1:30" turns to "3:00" as Longer clock is switched on.
    @AppStorage(LongerClockSetting.key) private var longerClockOn = false

    private var length: Double { GameModel.runLength(longerClock: longerClockOn) }

    /// Beside the name, on one line.
    private var detail: String {
        switch offer {
        case .none, .fresh: runClockText(length)
        case .paused(let remaining): Vocabulary.runLeft(runClockText(remaining))
        case .played(let record): counted(record.points, "point")
        }
    }

    /// Under the name, on two lines.
    private var line: String {
        switch offer {
        case .none, .fresh: Vocabulary.runOnTheClock(runClockText(length))
        case .paused(let remaining): Vocabulary.runPausedLeft(runClockText(remaining))
        case .played(let record): Vocabulary.runTally(words: record.words.count, points: record.points)
        }
    }

    /// What VoiceOver hears after the name.
    private var spoken: String {
        switch offer {
        case .paused(let remaining): Vocabulary.runPausedSpoken(runSpokenTime(remaining))
        default: line
        }
    }

    private var name: some View {
        HStack(spacing: 8) {
            Image(systemName: "timer")
                .font(.body.weight(.semibold))
                .accessibilityHidden(true)
            Text(Vocabulary.runName)
                .font(CuteFont.body(16, weight: "SemiBold", relativeTo: .body))
                .tracking(2.2)
                .textCase(.uppercase)
        }
        .foregroundStyle(ready ? Cute.button : Cute.inkFaint)
    }

    private func small(_ text: String) -> some View {
        Text(text)
            .font(CuteFont.body(14, weight: "SemiBold", relativeTo: .subheadline))
            .foregroundStyle(Cute.inkFaint)
            .monospacedDigit()
    }

    var body: some View {
        Button(action: action) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    name
                    small(detail)
                }
                .lineLimit(1)
                VStack(spacing: 1) {
                    name
                    small(line)
                }
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .frame(minHeight: height)
            .background(Capsule().fill(Cute.paperDeep))
            .overlay(Capsule().stroke(ready ? Cute.button : Cute.rule, lineWidth: 1.5))
        }
        .buttonStyle(PillPressStyle())
        .disabled(!ready)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("\(Vocabulary.runName), \(spoken)")
        .accessibilityIdentifier("TitleRun")
    }
}
