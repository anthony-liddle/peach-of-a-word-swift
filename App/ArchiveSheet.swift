import SwiftUI
import PeachEngine

/// The calendar of past boards.
///
/// **Intensity carries achievement, and that is the whole principle.** An empty
/// cell reads as nothing and a solid one reads as done, which is how every
/// calendar anyone has used already works. The first version inverted it: a
/// finished day was an outlined ring and an unplayed day was a filled white
/// square, so the achieved states were visually LIGHTER than the unachieved
/// ones, and seventy transferred days in a row read as one texture rather than
/// as seventy days of achievement.
///
/// The fills are a lightness ramp, measured rather than picked. Each fill is
/// composited over the sheet's paper, then reported in CIE L*, which is the
/// scale that matches how large a step looks, alongside the contrast ratio for
/// the number it carries:
///
///   still on the tree  #FFF4EE  L* 96.9  faint ink  5.52:1
///   started            #FFD9C8  L* 89.4  ink        6.27:1   step  7.5
///   finished           #ECB5C1  L* 78.9  ink        4.68:1   step 10.5
///   basket full        #C42E60  L* 45.0  white      5.38:1   step 33.9
///
/// Those are the colours the app actually renders, sampled from a
/// `simctl io screenshot` PNG rather than computed from the blend. The two
/// differ: the blend is a float and the frame buffer is eight bits a channel,
/// which moves finished by a tenth of a point of L*. Small, and the wrong
/// direction to guess in.
///
/// **L*, not relative luminance, and the difference is not pedantry.** An
/// earlier version of this comment gave the gaps as 0.17, 0.21 and 0.40 and
/// said that was what made the grid survive desaturation. Those were relative
/// luminance, which is linear light: exactly right for the contrast ratios in
/// the right-hand column and wrong for the question the sentence was answering,
/// because a step in linear light is not a step the eye sees as that size. A
/// real number measuring the wrong thing.
///
/// **Why finished sits where it does, so nobody moves it.** A fill has to be
/// L* 77.6 or lighter to carry `Cute.ink` at 4.5:1, and L* 49.9 or darker to
/// carry white. Nothing passes between those two, and that gap is exactly where
/// a mid pink lives. So there is no mid fill available at all: finished sits at
/// 78.9, the darkest pink ink can still carry, one point inside the ceiling.
/// The design this came from asked for "mid pink, white number", which has no
/// solution rather than a difficult one.
///
/// **The weakest greyscale pair is Started against Still on the tree**, 7.5
/// points of L* apart, 246 against 225 in eight-bit grey. Accepted deliberately: for the player this is built for,
/// who finishes nearly every day, Started is the rarest state on the calendar.
/// Hue moves as well, paper to peach to pink to deep pink, but it is
/// reinforcement rather than the signal.
///
/// **The heart is the shape half of the top state**, so a full basket does not
/// rest on fill alone. Not a peach: a bare peach means the source word on both
/// surfaces, and `DayOutcome` records no source-word bit, so a peach here would
/// claim a fact that is not stored. The heart already means "in the basket" in
/// the key, and a full basket is every basket word found, so it is the mark that
/// already means the thing being marked. It also survives 8pt, where `PeachMark`
/// drops its face because it turns to mud.
///
/// **One month at a time, decided 2026-09-10.** A grid rather than a list, and a
/// page rather than a scroll of every month: a month is at most 42 cells, so it
/// is built eagerly and costs the same on the day the archive holds three years
/// as on the day it holds seventy-nine.
struct ArchiveSheet: View {
    let days: [ArchiveDay]
    let canPlay: Bool
    let onPick: (Int) -> Void
    let onClose: () -> Void

    /// The months, grouped once.
    ///
    /// Stored rather than computed, because a computed property regroups every
    /// day in history on every body evaluation, including every page change.
    /// The sheet draws one month and should do work proportional to one month.
    let months: [[ArchiveDay]]

    /// Which month is on screen.
    ///
    /// **Held here, and set before the first layout, deliberately.** Four
    /// attempts at landing a continuous scroll on today failed because the
    /// position was the framework's to decide and the answer depended on when it
    /// decided it. A page index is ours, it is correct before anything is drawn,
    /// and there is nothing to resolve. `2026-09-10 What Eager Layout Really
    /// Costs.md` has what the alternatives cost.
    @State private var monthIndex: Int

    /// Which way the last step went, so the slide goes that way too.
    @State private var advancing = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(days: [ArchiveDay], canPlay: Bool,
         onPick: @escaping (Int) -> Void, onClose: @escaping () -> Void) {
        self.days = days
        self.canPlay = canPlay
        self.onPick = onPick
        self.onClose = onClose
        let grouped = Self.group(days)
        self.months = grouped
        _monthIndex = State(initialValue: Self.openingIndex(in: grouped))
    }

    /// The space between cells. **Fixed, not scaled, and that is deliberate.**
    ///
    /// A scaled gap does not make the grid more legible at large text sizes: the
    /// column count is fixed at seven, so every point the gap grows is a point
    /// taken off the cells. At AX5 on an iPhone SE 3 it took them to 36.5, under
    /// the 44pt tap target, which is the opposite of what scaling it was for.
    private let gap: CGFloat = 5

    private let gutter: CGFloat = 18

    #if DEBUG
    /// Extra header height, in points, from `-headerPad`. Zero in every run
    /// that does not ask for it, including every run on a device.
    private var headerPad: Double { UserDefaults.standard.double(forKey: "headerPad") }
    #endif

    var body: some View {
        GeometryReader { geo in
            let cell = cellSize(in: geo.size.width)
            VStack(spacing: 0) {
                header(cell: cell)
                #if DEBUG
                // `-headerPad 50.4` grows the header, and it is a permanent
                // fixture because it is the only reproducer issue #65 ever had.
                //
                // #65 bisected to the commit that renamed the empty state, which
                // took the key from two wrapped lines to four and cost the scroll
                // view 50.4pt off its top edge. Every other lever moved the whole
                // sheet; this one shrinks the scroll view's container while the
                // content stays the length it was, which is the shape of the bug.
                // Growing the header by the same amount reproduces the shortfall
                // on phones where nothing else did.
                //
                // It grows before the first layout rather than after it, so what
                // it reproduces is a header that is taller, not one that changes
                // height late. Those are different failures and only the first is
                // #65.
                Color.clear.frame(height: CGFloat(headerPad))
                #endif

                monthPage(cell: cell)

                Button(action: onClose) {
                    Text(Vocabulary.revealClose)
                        .font(CuteFont.display(16, relativeTo: .headline))
                        .frame(maxWidth: .infinity, minHeight: Cute.minTapTarget)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Cute.accentDeep)
                .padding(.horizontal, gutter)
                .padding(.bottom, 8)
            }
            #if DEBUG
            // The sheet reaching the screen, for `ArchiveTiming`. On the
            // container rather than inside it, so it fires once per presentation.
            .onAppear { ArchiveTiming.shared.appeared() }
            #endif
        }
        // Flat paper rather than the play screen's gradient. The sheet is a
        // different surface from the board and is allowed to say so. It began as
        // a requirement of the pinned month headings, which needed an opaque
        // band to sit on; those are gone with the scroll, and the flat paper is
        // kept because it was right on its own.
        .background(Cute.paper.ignoresSafeArea())
    }

    /// The cell size: the column, divided seven ways.
    ///
    /// **The width drives at every size, and it used to drive at almost none.**
    /// This read `min(idealCell, available / 7)` with `idealCell` a 30pt
    /// `@ScaledMetric`, added to stop the grid overflowing at accessibility
    /// sizes. It did stop that, and it also won everywhere else: below the
    /// accessibility range the width never binds, so every phone drew a 30pt
    /// cell. Measured on an iPhone SE 3, 30.00 by 30.00 at default against a
    /// 44pt tap target, in a grid 240pt wide inside a 339pt column. A cap
    /// written for one end of the range was being applied across all of it.
    ///
    /// Dividing the column is the rule the cap was standing in for, and it
    /// cannot overflow by construction. Measured after: 44.14 on an SE 3 at
    /// every text size, 46.29 on a 390pt phone.
    ///
    /// The floor stays for the pathological case of a container narrower than
    /// anything Apple ships.
    ///
    /// Accessibility sizes now get a cell of the same size as everywhere else
    /// with a number that does not scale past it, which is a capped grid by
    /// another name. That remains a decision rather than an omission: a real
    /// treatment is a second layout for a case nobody has reported.
    private func cellSize(in width: CGFloat) -> CGFloat {
        let available = width - gutter * 2 - gap * 6
        return max(18, available / 7)
    }

    // MARK: The top

    private func header(cell: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(Vocabulary.archiveTitle)
                .font(CuteFont.display(22, relativeTo: .title3))
                .foregroundStyle(Cute.ink)

            key(cell: cell)

            // Weekday columns, once, above the scroll rather than repeated in
            // every month: the columns never change, and a column header that
            // scrolls away is one you have to remember.
            HStack(spacing: gap) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(CuteFont.body(10, weight: "Bold", relativeTo: .caption2))
                        .foregroundStyle(Cute.inkFaint)
                        .frame(width: cell)
                }
            }
            .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, gutter)
        // The grabber sits above this. Without the top padding the title is
        // pressed against it.
        .padding(.top, 26)
        .padding(.bottom, 12)
    }

    /// The key, as a ramp rather than as a list of annotated examples.
    ///
    /// Four cells left to right with their labels underneath, above the grid
    /// rather than below it. What this replaces was a sentence under the
    /// calendar explaining nine cells, which is the tell that the cells were not
    /// carrying their own meaning: a scale reads at a glance, and a legend that
    /// arrives after the thing it explains has already failed.
    ///
    /// It draws the same faces the grid draws, so the two cannot drift into
    /// meaning different things.
    private func key(cell: CGFloat) -> some View {
        let size = min(cell, 26)
        return HStack(alignment: .top, spacing: 10) {
            keyItem(.noRecord, Vocabulary.markNoRecord, size)
            keyItem(.incomplete, Vocabulary.markIncomplete, size)
            keyItem(.cleared(onTheDay: true, web: false), Vocabulary.markCleared, size)
            keyItem(.basket(onTheDay: true), Vocabulary.markBasket, size)
        }
    }

    private func keyItem(_ mark: DayMark, _ label: String, _ size: CGFloat) -> some View {
        VStack(spacing: 5) {
            ArchiveCellFace(mark: mark, day: nil, size: size)
            Text(label)
                .font(CuteFont.body(10, relativeTo: .caption2))
                .foregroundStyle(Cute.inkFaint)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
    }

    /// Weekday initials in the reader's own order, since the week does not start
    /// on the same day everywhere.
    private var weekdaySymbols: [String] {
        let calendar = Foundation.Calendar.current
        let symbols = calendar.veryShortWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    // MARK: Months

    private static func group(_ days: [ArchiveDay]) -> [[ArchiveDay]] {
        let calendar = Foundation.Calendar.current
        var grouped: [[ArchiveDay]] = []
        for day in days {
            if let last = grouped.last?.last,
               calendar.isDate(last.date, equalTo: day.date, toGranularity: .month) {
                grouped[grouped.count - 1].append(day)
            } else {
                grouped.append([day])
            }
        }
        return grouped
    }

    /// The month the sheet opens on: the current one, which is the last, because
    /// the range now runs to the end of today's month.
    private static func openingIndex(in months: [[ArchiveDay]]) -> Int {
        guard !months.isEmpty else { return 0 }
        #if DEBUG
        // `-archiveMonth 2026-07` opens on that month instead.
        //
        // The same argument as `-openArchive`: simctl cannot tap, so a month
        // that can only be reached by a finger can only be reasoned about. This
        // replaces `-archiveTop`, which named an end of a scroll that no longer
        // exists.
        if let wanted = UserDefaults.standard.string(forKey: "archiveMonth"),
           let found = months.firstIndex(where: { monthKey($0) == wanted }) {
            return found
        }
        #endif
        return months.count - 1
    }

    /// A month's stable name, for `-archiveMonth` and for view identity.
    private static func monthKey(_ month: [ArchiveDay]) -> String {
        let parts = Foundation.Calendar.current
            .dateComponents([.year, .month], from: month[0].date)
        return String(format: "%04d-%02d", parts.year ?? 0, parts.month ?? 0)
    }

    /// The month on screen, and nothing else.
    ///
    /// **One month is at most 42 cells, so it is built eagerly and costs the
    /// same on every day the archive ever has.** The sheet used to scroll every
    /// month at once, which had to land on today: in a lazy stack that landing
    /// depended on timing and missed in two different ways on the two launch
    /// paths (#65, #67), and making the stack eager fixed the landing at a main
    /// thread stall that grew with every day of history, 599ms at 1080 days.
    /// `2026-09-10 What Eager Layout Really Costs.md` has the measurements.
    ///
    /// A page has no scroll position to resolve, so there is nothing to land on
    /// and nothing to get wrong.
    private func monthPage(cell: CGFloat) -> some View {
        let month = months[safeIndex]
        return VStack(alignment: .leading, spacing: 10) {
            monthBar(month)
            ScrollViewReader { scroller in
                ScrollView(.vertical) {
                    monthGrid(month, cell: cell)
                        .padding(.horizontal, gutter)
                        .padding(.bottom, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                // The grid alone scrolls, and the month's name does not go with
                // it. At AX5 on a 390pt phone the space under the fixed header
                // measured about 227pt against about 300pt for a six row month,
                // so at those sizes a month does not fit and this is the only
                // way to reach the rest of it. It is one eager month, where the
                // eager probe showed `scrollTo` landing exact.
                .accessibilityIdentifier("ArchiveScroll")
                // No scrolling at all when the month fits, which is every case
                // below the accessibility sizes.
                .scrollBounceBehavior(.basedOnSize)
                .task {
                    // The current month opens with today in view. Every other
                    // month opens at the top, which is its first week.
                    guard let today = month.first(where: { $0.isToday })?.day else { return }
                    await Task.yield()
                    scroller.scrollTo(today, anchor: .center)
                }
            }
            // **A fresh scroll for each month, and this is not cosmetic.** The
            // scroll view is reused across page changes and keeps its offset, so
            // paging back from a September scrolled to today would open August
            // at September's offset rather than at its first week. Invisible at
            // default size, where nothing scrolls at all.
            .id(Self.monthKey(month))
            .transition(slide)
        }
        .clipped()
        // Swipe is an enhancement on top of the buttons, doing the same thing.
        // Simultaneous rather than exclusive so it takes nothing from the day
        // cells underneath or from the grid's own vertical scrolling, and
        // horizontal dominance so a vertical drag at AX5 still scrolls.
        .simultaneousGesture(
            DragGesture(minimumDistance: 30)
                .onEnded { drag in
                    guard abs(drag.translation.width) > abs(drag.translation.height) else { return }
                    step(drag.translation.width > 0 ? -1 : 1)
                }
        )
    }

    /// The month's name is the page title, with the previous and next buttons
    /// either side of it. The buttons are the primary path and the accessible
    /// one; the swipe only repeats what they do.
    private func monthBar(_ month: [ArchiveDay]) -> some View {
        HStack(spacing: 0) {
            stepButton(-1)
            Text(monthName(month[0].date))
                .font(CuteFont.body(11, weight: "Bold", relativeTo: .caption))
                .tracking(1.4)
                .textCase(.uppercase)
                .foregroundStyle(Cute.inkFaint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("ArchiveMonthTitle")
            stepButton(1)
        }
        .padding(.horizontal, gutter - 10)
    }

    private func stepButton(_ delta: Int) -> some View {
        let target = safeIndex + delta
        let reachable = months.indices.contains(target)
        return Button { step(delta) } label: {
            Image(systemName: delta < 0 ? "chevron.left" : "chevron.right")
                .font(.system(size: 15, weight: .bold))
                .frame(width: Cute.minTapTarget, height: Cute.minTapTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(reachable ? Cute.accentDeep : Cute.inkFaint.opacity(0.30))
        .disabled(!reachable)
        .accessibilityIdentifier(delta < 0 ? "ArchivePreviousMonth" : "ArchiveNextMonth")
        .accessibilityLabel(stepLabel(delta, target: target, reachable: reachable))
    }

    /// "Previous month, August 2026", so the button names where it goes.
    private func stepLabel(_ delta: Int, target: Int, reachable: Bool) -> String {
        let which = delta < 0 ? Vocabulary.archivePreviousMonth : Vocabulary.archiveNextMonth
        guard reachable else {
            let none = delta < 0 ? Vocabulary.archiveNoEarlierMonth : Vocabulary.archiveNoLaterMonth
            return "\(which), \(none)"
        }
        return "\(which), \(monthName(months[target][0].date))"
    }

    private func step(_ delta: Int) {
        let target = safeIndex + delta
        guard months.indices.contains(target) else { return }
        advancing = delta > 0
        if reduceMotion {
            monthIndex = target
        } else {
            withAnimation(.easeInOut(duration: 0.22)) { monthIndex = target }
        }
    }

    /// The month slides the way it was asked to go. With Reduce Motion on it
    /// does not slide at all.
    private var slide: AnyTransition {
        guard !reduceMotion else { return .identity }
        return .asymmetric(
            insertion: .move(edge: advancing ? .trailing : .leading),
            removal: .move(edge: advancing ? .leading : .trailing)
        )
    }

    /// Clamped, because `days` can change under a sheet that is already open.
    private var safeIndex: Int {
        min(max(monthIndex, 0), max(months.count - 1, 0))
    }

    private func monthGrid(_ month: [ArchiveDay], cell: CGFloat) -> some View {
        // Eager rows of seven. No `Lazy` container anywhere in the sheet: a
        // month is at most 42 cells, and a lazy container's estimate of what it
        // has not built is the whole of issue #65.
        let blanks = leadingBlanks(before: month[0].date)
        let slots: [ArchiveDay?] = Array(repeating: nil, count: blanks) + month.map { $0 }
        let rows = stride(from: 0, to: slots.count, by: 7).map {
            Array(slots[$0..<min($0 + 7, slots.count)])
        }
        return VStack(alignment: .leading, spacing: gap) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: gap) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, slot in
                        if let day = slot {
                            ArchiveCell(day: day, size: cell, canPlay: canPlay) { onPick(day.day) }
                                // The ForEach id is the column, so the day id
                                // that `scrollTo` resolves has to be restated.
                                .id(day.day)
                        } else {
                            Color.clear.frame(width: cell, height: cell)
                        }
                    }
                }
            }
        }
    }

    private func monthName(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Foundation.Calendar.current
        formatter.setLocalizedDateFormatFromTemplate("MMMM y")
        return formatter.string(from: date)
    }

    private func leadingBlanks(before date: Date) -> Int {
        let calendar = Foundation.Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        return (weekday - calendar.firstWeekday + 7) % 7
    }
}

/// One day, ready to draw.
struct ArchiveDay: Equatable {
    let day: Int
    let date: Date
    let mark: DayMark
    let isToday: Bool
}

// MARK: - The cell

/// The drawing, with no behaviour, so the key and the grid share one face.
struct ArchiveCellFace: View {
    /// How far the today ring is drawn beyond the cell.
    ///
    /// Shared with the scroll view, which has to leave this much room at the
    /// bottom edge, and with the test that checks it does. Three copies of one
    /// number is how the ring got clipped in the first place.
    static let ringOutset: CGFloat = 3

    let mark: DayMark
    /// The day of the month, or nil in the key, where a number would be a date
    /// that does not exist.
    let day: Int?
    let size: CGFloat

    var body: some View {
        let radius = size * 0.3
        ZStack {
            RoundedRectangle(cornerRadius: radius)
                .fill(fill)
                .overlay {
                    if case .noRecord = mark {
                        RoundedRectangle(cornerRadius: radius)
                            .strokeBorder(Cute.rule, lineWidth: 1)
                    }
                }

            if let day {
                VStack(spacing: 0) {
                    Text("\(day)")
                        // **Fixed, not scaled, and this is the one place in the
                        // app where that is right.** The cell is capped so the
                        // grid fits the width, and a number that keeps growing
                        // after its box has stopped does not get bigger, it gets
                        // replaced by an ellipsis: at AX5 every date in the grid
                        // rendered as three dots. Once the container stops
                        // scaling, its contents have to stop with it.
                        .font(.custom("Nunito-SemiBold", fixedSize: numberPoints))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .foregroundStyle(numberColor)
                    if showsHeart {
                        Image(systemName: "heart.fill")
                            .font(.system(size: max(5, size * 0.19)))
                            .foregroundStyle(Cute.paperDeep)
                    }
                }
            } else if showsHeart {
                Image(systemName: "heart.fill")
                    .font(.system(size: max(6, size * 0.3)))
                    .foregroundStyle(Cute.paperDeep)
            }

            // **A day caught up after the day carries no mark, deliberately.**
            //
            // There was a corner dot here, and a dashed border before that. Both
            // are gone for the same reason: when she played is provenance, not
            // achievement. That is the argument that keeps any mark off
            // transferred days, and this is the same fact wearing a different
            // hat. The game was built by taking the clock out of it, so the grid
            // does not grade her on timeliness either.
            //
            // Nothing was lost from storage. The outcome still records `on`, and
            // the spoken label still says "caught up later", which is where that
            // fact belongs: available to anyone who asks a day about itself,
            // absent from a glance across seventy of them.
            //
            // If this looks like a missing feature, it is a removed one.
        }
        .frame(width: size, height: size)
    }

    private var numberPoints: CGFloat { max(8, size * 0.38) }

    private var fill: Color {
        switch mark {
        case .notYet, .noRecord: .clear
        case .incomplete: Cute.paperEdge
        case .cleared: Cute.accent.opacity(0.32)
        case .basket: Cute.accent
        }
    }

    private var numberColor: Color {
        switch mark {
        case .notYet: Cute.inkFaint.opacity(0.35)
        case .noRecord: Cute.inkFaint
        case .incomplete, .cleared: Cute.ink
        case .basket: Cute.paperDeep
        }
    }

    private var showsHeart: Bool {
        if case .basket = mark { return true }
        return false
    }

}

/// One cell, and whether it can be opened.
private struct ArchiveCell: View {
    let day: ArchiveDay
    let size: CGFloat
    let canPlay: Bool
    let action: () -> Void

    private var isPlayable: Bool {
        // The seventh state. `dailySourceWord` will compute any day including
        // next year, so a future cell is inert here as well as refused in the
        // model: two refusals, because handing out tomorrow's board is the one
        // mistake the archive cannot take back.
        day.mark != .notYet && canPlay
    }

    var body: some View {
        Button(action: action) {
            ArchiveCellFace(
                mark: day.mark,
                day: Foundation.Calendar.current.component(.day, from: day.date),
                size: size
            )
            .overlay {
                // Today, ringed outside its own fill, so the ring says "here"
                // without overwriting what the day achieved.
                if day.isToday {
                    RoundedRectangle(cornerRadius: size * 0.3 + ArchiveCellFace.ringOutset)
                        .strokeBorder(Cute.ink, lineWidth: 1.5)
                        .padding(-ArchiveCellFace.ringOutset)
                    #if DEBUG
                    // Today reporting its own position, for `ArchiveTiming`.
                    //
                    // An overlay of `Color.clear` inside the existing overlay, so
                    // it adds no layout height and cannot move the thing it is
                    // measuring. The frame is taken in global coordinates because
                    // the question is where today sits on the screen, not where
                    // it sits in the content.
                    GeometryReader { proxy in
                        Color.clear
                            .onAppear {
                                ArchiveTiming.shared.todayMoved(to: proxy.frame(in: .global))
                            }
                            .onChange(of: proxy.frame(in: .global)) { _, new in
                                ArchiveTiming.shared.todayMoved(to: new)
                            }
                    }
                    #endif
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isPlayable)
        // Identified, never matched on its date: the archive's dates move every
        // morning and `LayoutBudget` records what a date-dependent query costs.
        .accessibilityIdentifier(day.isToday ? "ArchiveTodayCell" : "ArchiveDayCell")
        .accessibilityLabel(label)
        .accessibilityAddTraits(isPlayable ? [.isButton] : [])
    }

    private var label: String {
        var parts = [dateText]
        switch day.mark {
        case .notYet: parts.append(Vocabulary.markNotYet)
        case .noRecord: parts.append(Vocabulary.markNoRecord)
        case .incomplete: parts.append(Vocabulary.markIncomplete)
        case .cleared(let onTheDay, let web):
            parts.append(Vocabulary.markCleared)
            if !onTheDay { parts.append(Vocabulary.markCaughtUpLater) }
            if web { parts.append(Vocabulary.markOnTheWeb) }
        case .basket(let onTheDay):
            parts.append(Vocabulary.markBasket)
            if !onTheDay { parts.append(Vocabulary.markCaughtUpLater) }
        }
        if day.isToday { parts.append(Vocabulary.markToday) }
        return parts.joined(separator: ", ")
    }

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.calendar = Foundation.Calendar.current
        formatter.setLocalizedDateFormatFromTemplate("MMMM d")
        return formatter.string(from: day.date)
    }
}
