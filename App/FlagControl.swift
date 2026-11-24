import PeachEngine
import SwiftUI

// MARK: - What a card needs to flag a word

private struct FlagStoreKey: EnvironmentKey {
    static var defaultValue: FlagStore? { nil }
}

private struct FlagDayKey: EnvironmentKey {
    static var defaultValue: String? { nil }
}

extension EnvironmentValues {
    /// The phone's flags. Nil in previews, which then show no flag.
    var flagStore: FlagStore? {
        get { self[FlagStoreKey.self] }
        set { self[FlagStoreKey.self] = newValue }
    }

    /// The board's calendar day, which a flag names. Nil with no board up.
    var flagDay: String? {
        get { self[FlagDayKey.self] }
        set { self[FlagDayKey.self] = newValue }
    }
}

extension View {
    /// The flags, and the day of the board in play, for the cards under this.
    func wordFlags(day: String?) -> some View {
        environment(\.flagStore, WordFlags.store).environment(\.flagDay, day)
    }
}

// MARK: - The flag

/// A pennant on a pole, the web's `FlagIcon`, from its 16-point drawing.
private struct FlagShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 16
        let x0 = rect.midX - 8 * s, y0 = rect.midY - 8 * s
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x0 + x * s, y: y0 + y * s) }
        var path = Path()
        path.move(to: p(3.5, 1.5))
        path.addLine(to: p(3.5, 14.5))
        path.move(to: p(3.5, 2.5))
        path.addLine(to: p(11.7, 2.5))
        path.addLine(to: p(9.8, 5.5))
        path.addLine(to: p(11.7, 8.5))
        path.addLine(to: p(3.5, 8.5))
        return path
    }
}

/// The flag's glyph. It grows with the text, as the words beside it do, and
/// stops at its 44-point target (Antoine's cap, 21 November).
struct FlagIcon: View {
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 17

    var body: some View {
        let side = min(size, 44)
        FlagShape()
            .stroke(style: StrokeStyle(lineWidth: side * 1.4 / 16, lineCap: .round, lineJoin: .round))
            .frame(width: side, height: side)
    }
}

/// The flag at the foot of a card's scrolling content, under the credit and
/// never in the pinned way out: the icon alone, a 44-point target, named "Flag
/// this word". It opens the picker as a sheet over the card. Once the word is
/// flagged, a line above it says what and whether it went, with a way to Your
/// flags, where a flag is taken back. The web's `FlagControl`.
///
/// With nothing left to flag, the icon goes and the line stays. With 50 flags
/// waiting, a line says so in the icon's place.
struct FlagControl: View {
    let word: String
    let card: FlagCard
    /// A found word's grade. The peach card has none.
    let grade: Rung?

    @Environment(\.flagStore) private var store
    @Environment(\.flagDay) private var day
    @State private var asking = false
    @State private var listing = false
    @AccessibilityFocusState private var focus: Target?

    private enum Target: Hashable { case flag, link }

    var body: some View {
        if let store, let day {
            content(store: store, day: day)
        }
    }

    private func content(store: FlagStore, day: String) -> some View {
        let mine = store.list.filter { $0.word == word }
        let groups = flagGroups(card: card, grade: grade, flagged: Set(mine.map(\.reason)))
        let waiting = mine.contains { $0.state == .waiting }
        return VStack(spacing: 6) {
            if !mine.isEmpty {
                VStack(spacing: 0) {
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text(waiting ? "◷" : "✓").accessibilityHidden(true)
                        Text(FlagCopy.cardLine(mine.map(\.reason), waiting: waiting))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .font(CuteFont.body(12, relativeTo: .caption))
                    .foregroundStyle(Cute.inkFaint)
                    Button { listing = true } label: {
                        Text(FlagCopy.yourFlags)
                            .font(CuteFont.body(13, weight: "SemiBold", relativeTo: .footnote))
                            .foregroundStyle(Cute.accentDeep)
                            .underline()
                            .frame(minHeight: 44)
                            .padding(.horizontal, 6)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityFocused($focus, equals: .link)
                }
            }
            if !groups.isEmpty {
                if store.isFull {
                    Text(FlagCopy.full)
                        .font(CuteFont.body(12, relativeTo: .caption))
                        .foregroundStyle(Cute.inkFaint)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Button { asking = true } label: {
                        FlagIcon()
                            .foregroundStyle(Cute.inkFaint)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(FlagCopy.flagLabel)
                    .accessibilityHint(FlagCopy.flagHint)
                    .accessibilityIdentifier("CardFlag")
                    .accessibilityFocused($focus, equals: .flag)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
        .sheet(isPresented: $asking) {
            FlagPicker(word: word, card: card, grade: grade, groups: groups) { reason in
                asking = false
                Task { await made(reason, store: store, day: day) }
            } onCancel: {
                asking = false
                focus = .flag
            }
        }
        .sheet(isPresented: $listing, onDismiss: { focus = store.list.contains { $0.word == word } ? .link : .flag }) {
            YourFlagsSheet(store: store) { listing = false }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    /// Makes the flag, says so, and puts VoiceOver back on the flag, or on the
    /// way to Your flags once every reason is used.
    private func made(_ reason: FlagReason, store: FlagStore, day: String) async {
        _ = await store.flag(word: word, reason: reason, day: day)
        let flag = store.list.first { $0.word == word && $0.reason == reason }
        AccessibilityNotification.Announcement(FlagCopy.spoken(sent: flag?.state == .sent)).post()
        let left = flagGroups(card: card, grade: grade,
                              flagged: Set(store.list.filter { $0.word == word }.map(\.reason)))
        focus = left.isEmpty || store.isFull ? .link : .flag
    }
}

// MARK: - The picker

/// The picker, a sheet over the card: the title, the groups with their
/// choices, the short line and Cancel.
///
/// **It fits its content,** capped at full height, on every card (Antoine, 23
/// November): nothing may be cut off, and at the accessibility sizes it scrolls
/// at full height. Each choice wraps centred, in a box with rounded corners
/// rather than a pill, so a long one doesn't cut into its own ends.
struct FlagPicker: View {
    let word: String
    let card: FlagCard
    let grade: Rung?
    let groups: [FlagGroup]
    let onPick: (FlagReason) -> Void
    let onCancel: () -> Void

    @State private var contentHeight: CGFloat = 420

    var body: some View {
        ZStack {
            Cute.pageBackground.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 14) {
                    Text(FlagCopy.pickerTitle(word))
                        .font(CuteFont.body(19, weight: "Bold", relativeTo: .headline))
                        .foregroundStyle(Cute.ink)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("FlagPickerTitle")
                    ForEach(groups, id: \.kind) { group in
                        VStack(spacing: 8) {
                            Text(FlagCopy.heading(group.kind))
                                .font(CuteFont.body(12, weight: "Bold", relativeTo: .caption))
                                .tracking(0.6)
                                .textCase(.uppercase)
                                .foregroundStyle(Cute.inkFaint)
                                .accessibilityLabel(FlagCopy.heading(group.kind))
                                .accessibilityAddTraits(.isHeader)
                            ForEach(group.reasons, id: \.self) { reason in
                                choice(FlagCopy.choice(reason, card: card, grade: grade),
                                       ink: Cute.accentDeep, edge: Cute.accent) { onPick(reason) }
                            }
                        }
                    }
                    Text(FlagCopy.pickerNote)
                        .font(CuteFont.body(13, relativeTo: .footnote))
                        .foregroundStyle(Cute.inkFaint)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    choice(FlagCopy.cancel, ink: Cute.inkFaint, edge: Cute.rule, action: onCancel)
                }
                .padding(.horizontal, 24)
                .padding(.top, 30)
                .padding(.bottom, 16)
                .background {
                    GeometryReader { proxy in
                        Color.clear
                            .onAppear { contentHeight = proxy.size.height }
                            .onChange(of: proxy.size.height) { _, height in contentHeight = height }
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .accessibilityIdentifier("FlagPicker")
        }
        // Taller than the screen is held to full height by the sheet itself.
        .presentationDetents([.height(contentHeight)])
        .presentationDragIndicator(.visible)
    }

    private func choice(_ label: String, ink: Color, edge: Color,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(CuteFont.body(15, weight: "SemiBold", relativeTo: .subheadline))
                .foregroundStyle(ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(edge, lineWidth: 1))
                .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
