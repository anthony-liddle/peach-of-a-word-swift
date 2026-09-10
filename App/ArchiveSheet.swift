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
/// The fills are a luminance ramp, measured rather than picked. Each fill is
/// composited over the sheet's paper and checked against the number it carries:
///
///   no record   #FFF4EE  lum 0.921   faint ink  5.52:1
///   played      #FFD9C8  lum 0.751   ink        6.27:1
///   finished    #ECB5C1  lum 0.546   ink        4.67:1
///   basket      #C42E60  lum 0.145   white      5.38:1
///
/// Every step clears 4.5:1 for its own number, and the luminance falls
/// monotonically with gaps of 0.17, 0.21 and 0.40, which is what makes the grid
/// survive being desaturated. Hue moves as well, peach to pink to deep pink, but
/// it is reinforcement rather than the signal.
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

    /// The cell the layout would like. What it gets is this or whatever fits,
    /// whichever is smaller: see `cellSize`.
    @ScaledMetric(relativeTo: .body) private var idealCell: CGFloat = 30
    @ScaledMetric(relativeTo: .body) private var gap: CGFloat = 5

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

    /// The cell size, capped to what the width can actually hold.
    ///
    /// A `@ScaledMetric` alone overflows: seven cells of 30pt grow past 90pt
    /// each at AX5, which needs roughly 628 points on a 375 point screen, and
    /// the sheet slides sideways taking its title and its way out with it. That
    /// was measured, not predicted. Capping is the same lesson `ContentView`
    /// records about `.adaptive`, which negotiated and negotiated wrong: decide
    /// on the constraint that actually binds.
    ///
    /// The numbers stop growing with the text at the top of the range, which is
    /// a real cost and a smaller one than a sheet nobody can read or leave.
    /// Accessibility sizes probably want a different shape entirely rather than
    /// a squeezed grid, and that is its own question rather than this one.
    private func cellSize(in width: CGFloat) -> CGFloat {
        let available = width - gutter * 2 - gap * 6
        return max(18, min(idealCell, available / 7))
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

            // Caught up after the day, demoted to a corner.
            //
            // It was a dashed border, which competed with the fill for the
            // achievement read and is most of the reason the grid needed a
            // legend at all. It is secondary information and now looks like it.
            if caughtUpLater {
                Circle()
                    .fill(numberColor.opacity(0.85))
                    .frame(width: max(3, size * 0.14), height: max(3, size * 0.14))
                    .padding(max(2, size * 0.1))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
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

    private var caughtUpLater: Bool {
        switch mark {
        case .cleared(let onTheDay, _), .basket(let onTheDay): !onTheDay
        default: false
        }
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
                    RoundedRectangle(cornerRadius: size * 0.3 + 3)
                        .strokeBorder(Cute.ink, lineWidth: 1.5)
                        .padding(-3)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isPlayable)
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
