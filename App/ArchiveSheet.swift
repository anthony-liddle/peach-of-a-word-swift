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
///   finished           #ECB5C1  L* 78.8  ink        4.67:1   step 10.6
///   basket full        #C42E60  L* 45.0  white      5.38:1   step 33.8
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
/// 78.8, the darkest pink ink can still carry, one point inside the ceiling.
/// The design this came from asked for "mid pink, white number", which has no
/// solution rather than a difficult one.
///
/// **The weakest greyscale pair is Started against Still on the tree**, 7.5
/// points of L* apart. Accepted deliberately: for the player this is built for,
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
/// A grid rather than a list, built that way from the start: seventy-nine days
/// exist today and the number goes up every morning.
struct ArchiveSheet: View {
    let days: [ArchiveDay]
    let canPlay: Bool
    let onPick: (Int) -> Void
    let onClose: () -> Void

    /// The space between cells. **Fixed, not scaled, and that is deliberate.**
    ///
    /// A scaled gap does not make the grid more legible at large text sizes: the
    /// column count is fixed at seven, so every point the gap grows is a point
    /// taken off the cells. At AX5 on an iPhone SE 3 it took them to 36.5, under
    /// the 44pt tap target, which is the opposite of what scaling it was for.
    private let gap: CGFloat = 5

    private let gutter: CGFloat = 18

    var body: some View {
        GeometryReader { geo in
            let cell = cellSize(in: geo.size.width)
            VStack(spacing: 0) {
                header(cell: cell)

                ScrollViewReader { scroller in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 18,
                                   pinnedViews: [.sectionHeaders]) {
                            ForEach(months, id: \.first!.day) { month in
                                Section {
                                    monthGrid(month, cell: cell)
                                } header: {
                                    monthHeading(month)
                                }
                            }
                        }
                        .padding(.horizontal, gutter)
                        .padding(.bottom, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    // Opens on today, not at the top and not at the bottom.
                    //
                    // The top is the least useful place to land and gets worse
                    // every morning, so this used to anchor to the bottom. Then
                    // the month started running past today so the seventh state
                    // had somewhere to appear, and the bottom became a screen of
                    // inert future days: at accessibility sizes, where only two
                    // rows fit, that was the whole view. Today is the answer to
                    // both, and it is also the way back from a past board.
                    // Two mechanisms, and both are needed.
                    //
                    // The anchor is the floor: it lands at the newest end
                    // without waiting for anything, which matters because the
                    // stack and the grids are both lazy and nothing offscreen
                    // exists yet. `scrollTo` alone landed at the very top, since
                    // `onAppear` runs before the cell it is asked to find has
                    // been built.
                    //
                    // The scroll then refines it onto today. The bottom is the
                    // end of the current month rather than today, which at
                    // default size still shows today and at accessibility sizes,
                    // where two rows fit, was a screenful of inert future days.
                    .accessibilityIdentifier("ArchiveScroll")
                    // The sheet opens already scrolled, and when it lands on a
                    // row boundary the pinned month heading covers the rows
                    // above it with nothing to say they are there. Under the
                    // showcase seed that is June and the first four days of
                    // July, and the sheet reads as a month starting on the 5th.
                    // A flash of the indicator is the smallest honest signal
                    // that the content runs past the top edge.
                    .scrollIndicatorsFlash(onAppear: true)
                    // Room for the today ring at the bottom edge.
                    //
                    // The sheet opens by putting today's bottom edge on the
                    // scroll view's, and the ring is drawn `ringOutset` beyond
                    // the cell through an overlay with negative padding, which
                    // does not change the cell's frame. So the ring's bottom
                    // stroke landed outside the visible region and was clipped,
                    // measured at exactly 3.00pt, on every open at every size.
                    //
                    // A content margin rather than padding on the stack:
                    // padding makes the content longer and leaves the anchor
                    // where it was, since `scrollTo` aligns a view's edge to the
                    // viewport's. A margin moves the viewport's edge, which is
                    // the thing that was in the wrong place.
                    .contentMargins(.bottom, ArchiveCellFace.ringOutset, for: .scrollContent)
                    .defaultScrollAnchor(.bottom)
                    .task {
                        guard let today = days.first(where: { $0.isToday })?.day else { return }
                        await Task.yield()
                        scroller.scrollTo(today, anchor: .bottom)
                    }
                }

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
        }
        // Flat paper rather than the play screen's gradient, and the reason is
        // the pinned headers: a month heading has to sit on an opaque band or
        // the cells scrolling under it show through, and a flat band cannot
        // match a gradient at every scroll position. The sheet is a different
        // surface from the board and is allowed to say so.
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

    private var months: [[ArchiveDay]] {
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

    /// Pinned, so the month is named even when its heading has scrolled past.
    ///
    /// The sheet opens at the newest end, which used to land mid-July with the
    /// July heading above the fold and "AUGUST 2026" the first words on screen,
    /// so the first block of cells belonged to nothing.
    private func monthHeading(_ month: [ArchiveDay]) -> some View {
        Text(monthName(month[0].date))
            .font(CuteFont.body(11, weight: "Bold", relativeTo: .caption))
            .tracking(1.4)
            .textCase(.uppercase)
            .foregroundStyle(Cute.inkFaint)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
            .background(Cute.paper)
    }

    private func monthGrid(_ month: [ArchiveDay], cell: CGFloat) -> some View {
        let columns = Array(repeating: GridItem(.fixed(cell), spacing: gap), count: 7)
        return LazyVGrid(columns: columns, alignment: .leading, spacing: gap) {
            ForEach(0..<leadingBlanks(before: month[0].date), id: \.self) { _ in
                Color.clear.frame(width: cell, height: cell)
            }
            ForEach(month, id: \.day) { day in
                ArchiveCell(day: day, size: cell, canPlay: canPlay) { onPick(day.day) }
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
