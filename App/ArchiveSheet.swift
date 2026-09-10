import SwiftUI
import PeachEngine

/// The calendar of past boards.
///
/// **A grid rather than a list, built that way from the start.** Seventy-nine
/// days exist today and the number goes up by one every morning: a list is fine
/// at seventy-nine and unusable at four hundred, and the state model is the same
/// either way, so retrofitting would mean throwing the list away and keeping
/// nothing.
///
/// A sheet rather than a screen, because the play surface has no navigation
/// chrome at all and no room to grow any. The measurement is in
/// `docs/` and in the report: on an iPhone SE 3 at XXXL the fixed layout has
/// **16 points** of slack before it falls back to scrolling, and 44 is the
/// smallest real tap target. Nothing that could hold a toolbar fits, so the way
/// in rides an existing row instead and this arrives over the board.
struct ArchiveSheet: View {
    let days: [ArchiveDay]
    let canPlay: Bool
    let onPick: (Int) -> Void
    let onClose: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Cell size, scaled. A fixed 22pt cell is a 22pt cell at AX5 too, which is
    /// the shape of bug this project keeps finding in its own layout.
    @ScaledMetric(relativeTo: .body) private var cell: CGFloat = 22
    @ScaledMetric(relativeTo: .body) private var gap: CGFloat = 6

    var body: some View {
        VStack(spacing: 0) {
            // The sheet says what it is. A drag indicator and a wall of squares
            // is a puzzle rather than a screen, and this is the one place in the
            // app that has room for a heading: the play surface gave its
            // masthead up for 35 points of found list and this did not.
            Text(Vocabulary.archiveTitle)
                .font(CuteFont.display(22, relativeTo: .title3))
                .foregroundStyle(Cute.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.top, 20)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ForEach(months, id: \.first!.day) { month in
                        monthSection(month)
                    }
                    legend
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            // Opens at the newest end.
            //
            // The archive is append-only and grows by a day every morning, so
            // the top is the least useful place to land and gets worse forever:
            // at 626 days it is ninety rows above anything she played this week.
            // Anchoring to the bottom also puts today on screen, which is the
            // way back from a past board.
            .defaultScrollAnchor(.bottom)

            // Pinned, like the reveal card's way out. A sheet whose only exit
            // scrolls off the bottom is a sheet you have to hunt your way out
            // of, which `SourceRevealCard` already learned at length.
            Button(action: onClose) {
                Text(Vocabulary.revealClose)
                    .font(CuteFont.display(16, relativeTo: .headline))
                    .frame(maxWidth: .infinity, minHeight: Cute.minTapTarget)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Cute.accentDeep)
            .padding(.horizontal, 18)
            .padding(.bottom, 8)
        }
        .background(Cute.pageBackground.ignoresSafeArea())
    }

    // MARK: Months

    /// Days grouped by calendar month, oldest first.
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

    private func monthSection(_ month: [ArchiveDay]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(monthName(month[0].date))
                .font(CuteFont.body(12, weight: "Bold", relativeTo: .caption))
                .tracking(1.6)
                .textCase(.uppercase)
                .foregroundStyle(Cute.inkFaint)

            // A plain grid of fixed-width columns rather than LazyVGrid's
            // adaptive sizing: the cells must line up into weekday columns, and
            // an adaptive grid reflows them into whatever fits.
            let columns = Array(
                repeating: GridItem(.fixed(cell), spacing: gap), count: 7
            )
            LazyVGrid(columns: columns, alignment: .leading, spacing: gap) {
                ForEach(0..<leadingBlanks(before: month[0].date), id: \.self) { _ in
                    Color.clear.frame(width: cell, height: cell)
                }
                ForEach(month, id: \.day) { day in
                    ArchiveCell(day: day, size: cell, canPlay: canPlay) {
                        onPick(day.day)
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

    /// How many empty cells a month starts with, so every column is one weekday.
    ///
    /// Read off `Calendar.current.firstWeekday`, which is not Monday everywhere
    /// and is not something to hard-code from where this was written.
    private func leadingBlanks(before date: Date) -> Int {
        let calendar = Foundation.Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        return (weekday - calendar.firstWeekday + 7) % 7
    }

    private var legend: some View {
        Text(Vocabulary.archiveLegend)
            .font(CuteFont.body(12, relativeTo: .caption))
            .foregroundStyle(Cute.inkFaint)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 4)
    }
}

/// One day, ready to draw.
struct ArchiveDay: Equatable {
    let day: Int
    let date: Date
    let mark: DayMark
    let isToday: Bool
}

/// One cell.
///
/// **Shape carries the state; colour only reinforces it.** A ring is a finished
/// day, a filled square is a full basket, a dashed edge is a day caught up
/// afterwards. Six states told apart by hue alone would not survive the
/// accessibility bar the rest of this app clears, and two of the palette's marks
/// sit close enough in normal vision to be hard to separate at this size.
private struct ArchiveCell: View {
    let day: ArchiveDay
    let size: CGFloat
    let canPlay: Bool
    let action: () -> Void

    private var isPlayable: Bool {
        // The seventh state. `dailySourceWord` will compute any day including
        // next year, so a future cell must be inert here as well as refused in
        // the model: two refusals, because handing out tomorrow's board is the
        // one mistake the archive cannot take back.
        day.mark != .notYet && canPlay
    }

    var body: some View {
        Button(action: action) {
            shape
                .frame(width: size, height: size)
                // Today, ringed.
                //
                // It reached the spoken label and never the drawing, which a
                // screenshot found and no test would have: every assertion about
                // this grid passed while the one cell a player needs to find
                // looked like all the others. It is also the way back from a past
                // board, so being able to pick it out is the difference between
                // a calendar and a maze.
                .overlay {
                    if day.isToday {
                        RoundedRectangle(cornerRadius: size * 0.28 + 3)
                            .strokeBorder(Cute.ink, lineWidth: 1.5)
                            .padding(-3)
                    }
                }
                // The cell is the drawing; the target is the whole 44pt.
                // Overlapping targets on a 6pt gap are the price of a grid this
                // dense, and SwiftUI resolves to the nearest.
                .contentShape(Rectangle())
                .frame(minWidth: Cute.minTapTarget * 0.6,
                       minHeight: Cute.minTapTarget * 0.6)
        }
        .buttonStyle(.plain)
        .disabled(!isPlayable)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isPlayable ? [.isButton] : [])
    }

    @ViewBuilder
    private var shape: some View {
        let radius = size * 0.28
        switch day.mark {
        case .notYet:
            RoundedRectangle(cornerRadius: radius)
                .strokeBorder(Cute.paperEdge, style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
        case .noRecord:
            RoundedRectangle(cornerRadius: radius)
                .fill(Cute.paperDeep)
                .overlay(RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(Cute.rule, lineWidth: 1))
        case .incomplete:
            RoundedRectangle(cornerRadius: radius)
                .fill(Cute.paperDeep)
                .overlay(Circle().fill(Cute.inkFaint).frame(width: size * 0.26))
                .overlay(RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(Cute.rule, lineWidth: 1))
        case .cleared(let onTheDay, let web):
            RoundedRectangle(cornerRadius: radius)
                .fill(Cute.paperDeep)
                .overlay(RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(Cute.accent, style: border(onTheDay: onTheDay, width: 3)))
                .overlay(alignment: .bottom) {
                    // The web annotation, and it never appears on a basket: the
                    // web did not record basket completion, so that is not its
                    // claim to make.
                    if web {
                        Capsule().fill(Cute.discovery)
                            .frame(width: size * 0.38, height: 2)
                            .offset(y: 2)
                    }
                }
        case .basket(let onTheDay):
            RoundedRectangle(cornerRadius: radius)
                .fill(Cute.accent)
                .overlay(RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(Cute.paper, style: border(onTheDay: onTheDay, width: 2))
                    .opacity(onTheDay ? 0 : 1))
        }
    }

    /// Dashed when the day was caught up after the fact.
    private func border(onTheDay: Bool, width: CGFloat) -> StrokeStyle {
        onTheDay ? StrokeStyle(lineWidth: width)
                 : StrokeStyle(lineWidth: width, dash: [3, 2])
    }

    /// Everything the cell says, spoken.
    ///
    /// The date first, because a grid read cell by cell is otherwise a list of
    /// states with nothing to attach them to.
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
