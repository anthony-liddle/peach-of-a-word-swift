import SwiftUI
import PeachEngine

struct ContentView: View {
    /// Fill the board on appear, for judging the visual work. Previews do not
    /// receive launch arguments, so the `-seedBoard` hook is unreachable from
    /// the canvas and this is how a preview gets a played board.
    private let debugSeed: String?

    /// `@State` owns the model for the lifetime of the view.
    ///
    /// The name is misleading coming from React: this is not `useState`. It is
    /// closer to a ref that SwiftUI keeps alive across re-renders, and with
    /// `@Observable` it is also how the view subscribes to changes. A `let`
    /// here would work for reading but the view would never update.
    @State private var model: GameModel

    /// At accessibility text sizes the fixed play surface cannot fit, so the
    /// whole screen falls back to scrolling. See `game`.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// `storage` is injectable so a preview does not scribble on the real
    /// UserDefaults every time the canvas re-renders.
    init(debugSeed: String? = nil,
         storage: GameStorage = GameStorage(store: UserDefaultsStore())) {
        self.debugSeed = debugSeed
        _model = State(initialValue: GameModel(storage: storage))
    }

    var body: some View {
        ZStack {
            Cute.pageBackground.ignoresSafeArea()

            switch model.phase {
            case .loading:
                // The kicker lives here now. It came off the play screen
                // because an app does not need to announce what it is every
                // session, but a splash is exactly where that line belongs, and
                // it is also where the dictionary load hides.
                VStack(spacing: 18) {
                    PeachMark().frame(width: 72, height: 72)
                    Text("A game about finding words in words")
                        .font(CuteFont.body(12, weight: "SemiBold", relativeTo: .caption))
                        .tracking(4.4)
                        .textCase(.uppercase)
                        .foregroundStyle(Cute.accentDeep)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    ProgressView().tint(Cute.accent)
                }
            case .failed(let message):
                ContentUnavailableView(
                    "Could not start",
                    systemImage: "exclamationmark.triangle",
                    description: Text(message)
                )
            case .ready:
                game
            }
        }
        // `.task` runs when the view appears and is cancelled automatically if
        // it disappears. It is the SwiftUI answer to useEffect with an empty
        // dependency array, minus the cleanup function.
        .sheet(item: $model.moment) { moment in
            Group {
                switch moment {
                case .sourceWord(let word, let points):
                    SourceRevealCard(
                        word: word,
                        points: points,
                        wordsGrown: model.puzzle?.commonWords.count ?? 0
                    ) { model.moment = nil }
                case .completion(let setTotal, let score):
                    CompletionCard(setTotal: setTotal, score: score) { model.moment = nil }
                }
            }
            // Medium rather than full, so the board stays visible behind it and
            // this reads as a moment rather than an interruption. Drag to
            // dismiss comes free, which is the reason for a sheet over an
            // overlay.
            // Large is offered as well as medium, so accessibility text sizes
            // have somewhere to go rather than being squeezed into a fixed
            // height.
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .task {
            await model.load()
            #if DEBUG
            if let debugSeed { model.seedBoard(debugSeed) }
            #endif
        }
    }

    /// **A screen, not a page.**
    ///
    /// The web version is a page: it may be arrived at from anywhere, so it can
    /// afford a masthead announcing what it is. An app is already open, already
    /// named on the home screen, already the thing that was tapped. So the
    /// kicker is gone, the wordmark is small, and the rack and controls fit in
    /// one view with the found list scrolling beneath.
    ///
    /// The layout is also bottom-weighted, which pages are not. The controls are
    /// pinned to the bottom in comfortable thumb reach, the reading material
    /// (the found list) takes the loose middle, and the things being acted on
    /// (well and rack) sit above it. That also gives the controls room to be
    /// bigger, which they needed: they are the most-used targets on the screen
    /// and were previously the smallest.
    ///
    /// At accessibility text sizes none of that fits, so the whole thing becomes
    /// one scroll view instead. Dynamic Type has been regressed here once
    /// already by assuming rather than checking, so both paths are verified.
    private var game: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                ScrollView {
                    VStack(spacing: 14) {
                        header
                        ComposingStick(word: model.composedWord)
                        TypeCase(model: model)
                        Controls(model: model)
                        MessageLine(feedback: model.feedback)
                        foundList
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                }
            } else {
                // Explicit spacing rather than one uniform VStack gap, because
                // the gaps are not all the same job: feedback belongs tight to
                // the well it reports on, and the rack wants less room beneath
                // it than the uniform 12pt was giving it.
                VStack(spacing: 0) {
                    header
                    ComposingStick(word: model.composedWord)
                        .padding(.top, 12)
                    // Feedback lives here, directly under the well it reports
                    // on, and it lives here permanently. It previously sat
                    // between the rack and the list, immediately above the
                    // summary line, where the two read as one slot alternating
                    // between a count and a message. They are different things:
                    // the summary describes the board, this describes the last
                    // submission. Both now have a fixed home and neither moves
                    // as words are found.
                    MessageLine(feedback: model.feedback)
                        .padding(.top, 6)
                    TypeCase(model: model)
                        .padding(.top, 8)

                    scrollingList
                        .padding(.top, 10)

                    Controls(model: model)
                        .padding(.top, 10)
                }
                .padding(.horizontal, 18)
                .padding(.top, 4)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            // Small. A browser tab needs a wordmark that size; an app does not.
            // "Peach" keeps the pink oblique, which is the identifying mark.
            (Text("Peach").font(CuteFont.displayOblique(22, relativeTo: .title3))
                .foregroundColor(Cute.accent)
             + Text(" of a Word").font(CuteFont.display(22, relativeTo: .title3))
                .foregroundColor(Cute.ink))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if let standing = model.standing {
                TierMeterView(standing: standing, streak: model.streak)
            }
        }
    }

    private var foundList: some View {
        Group {
            if let puzzle = model.puzzle, let standing = model.standing {
                FoundListView(puzzle: puzzle, found: model.found,
                              standing: standing, boardDate: model.boardDate)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The scrolling list, with its boundaries faded.
    ///
    /// A plain ScrollView clips its content at a hard edge, so mid-scroll a
    /// group header was sliced through the middle of its text: top half gone,
    /// bottom half sitting against the background. That reads as broken rather
    /// than as scrolled.
    ///
    /// Two fixes were available: start the scroll region below the rack so
    /// nothing ever passes under it, or fade the content out as it reaches the
    /// boundary. **The fade wins**, because the region already starts below the
    /// rack: the slicing is the ScrollView's own edge, not the rack overlapping
    /// it, so moving things would not have helped. A fade is also the native
    /// treatment and it keeps the signal that there is more above, which a hard
    /// edge with nothing cut off would lose.
    ///
    /// The gradient is opaque through the middle and only eats the outer few
    /// points, so it never dims content that is fully in view.
    private var scrollingList: some View {
        ScrollView {
            // Padding inside the scrolled content, so at rest the fade eats
            // this rather than the first row. Without it the summary line sat
            // inside the gradient and rendered dimmed while fully in view.
            foundList.padding(.vertical, 16)
        }
        .scrollIndicators(.hidden)
        // Debug only: anchoring to the bottom shows the scrolled state, which
        // is the only state the clipping bug appears in and the only way to see
        // it without a gesture, since simctl cannot scroll.
        .modifier(DebugScrollAnchor())
        .frame(maxHeight: .infinity)
        .mask(alignment: .center) {
            LinearGradient(
                // The fade band is kept smaller than the 16pt content padding
                // above, so at rest it falls entirely inside the padding and
                // never dims a row that is fully in view. Mid-scroll it is what
                // content dissolves into instead of being sliced.
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.032),
                    .init(color: .black, location: 0.95),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

/// Anchors the found list to its bottom when `-scrollBottom 1` is passed, so
/// the scrolled state can be screenshotted. Debug builds only, and a no-op
/// everywhere else.
private struct DebugScrollAnchor: ViewModifier {
    func body(content: Content) -> some View {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "scrollBottom") {
            content.defaultScrollAnchor(.bottom)
        } else {
            content
        }
        #else
        content
        #endif
    }
}

// MARK: - Compose well

/// The stick: the letters placed so far, in order.
///
/// One fixed height for both the empty and filled states, so the rack never
/// shifts when the first letter lands. That is why the web pins it too.
private struct ComposingStick: View {
    let word: String
    @ScaledMetric(relativeTo: .title) private var height: CGFloat = 58

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Cute.cardRadius, style: .continuous)
    }

    var body: some View {
        ZStack {
            shape.fill(Cute.paperDeep)
            shape.stroke(Cute.tileEdge, lineWidth: 1)

            if word.isEmpty {
                Text("Pick letters to make a word")
                    .font(CuteFont.body(15, relativeTo: .subheadline))
                    .italic()
                    .tracking(0.6)
                    .foregroundStyle(Cute.inkFaint)
            } else {
                HStack(spacing: 4) {
                    ForEach(Array(word.enumerated()), id: \.offset) { _, letter in
                        Text(String(letter))
                            .font(CuteFont.display(28, relativeTo: .title))
                            .foregroundStyle(Cute.ink)
                    }
                }
                .padding(.horizontal, 10)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            }
        }
        .frame(height: height)
        .cuteSlab(shape, color: Cute.rule, y: 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(word.isEmpty
            ? "No letters picked yet"
            : "Picked so far: \(word.map(String.init).joined(separator: " "))")
    }
}

// MARK: - Rack

/// The rack. Each tile is a real button; a placed tile is disabled.
///
/// **Fixed columns, not adaptive.** The rack is always exactly eight tiles, and
/// `.adaptive` means "fit as many as fit", which is for collections of unknown
/// size. It negotiated, and it negotiated wrong: `@ScaledMetric` inflates the
/// minimum width, so on a 390pt phone at anything above the default text size a
/// fourth column stopped fitting and the rack split 3, 3, 2.
///
/// A fixed count makes that unrepresentable. Four columns at normal text sizes,
/// three at accessibility sizes, and 4x4 or 3+3+2 are the only two shapes this
/// can ever produce. The web does the same thing deliberately: four columns on
/// phone, eight on desktop, never negotiated.
///
/// Adaptive is still right for the found-word chips, where the count genuinely
/// varies.
private struct TypeCase: View {
    let model: GameModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Three columns at accessibility sizes is the reflow that was previously
    /// happening by accident of available width. Now it is an explicit response
    /// to Dynamic Type, which is what it always should have been.
    private var columnCount: Int { dynamicTypeSize.isAccessibilitySize ? 3 : 4 }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 9), count: columnCount)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(model.rackOrder, id: \.self) { id in
                if let tile = model.tiles.first(where: { $0.id == id }) {
                    TileButton(
                        letter: tile.letter,
                        placed: model.isPlaced(id),
                        action: { model.addTile(id) }
                    )
                }
            }
        }
        // Full width, matching the compose well above: that is the column the
        // eye reads down.
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Letter tiles")
    }
}

private struct TileButton: View {
    let letter: String
    let placed: Bool
    let action: () -> Void

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Cute.tileRadius, style: .continuous)
    }

    // The web sizes the glyph from the viewport (`clamp(1.75rem, 16vw, 5rem)`),
    // which lands near 56 percent of tile height at phone width. A GeometryReader
    // was tried for that and is wrong here: it consumes all offered space rather
    // than reporting an intrinsic size, so the font came out sized for a box the
    // tile never actually got and the glyph overflowed at large text sizes.
    // @ScaledMetric tracks Dynamic Type without depending on layout at all, and
    // minimumScaleFactor is the backstop for the extreme sizes.
    @ScaledMetric(relativeTo: .largeTitle) private var glyphSize: CGFloat = 46

    /// An upper bound only, and deliberately generous.
    ///
    /// **Width is the driver and height follows it**, via the 3:4 ratio, from
    /// whatever the fixed grid column gives. An earlier version inverted that:
    /// the height was a fixed constant and the width was derived, which meant
    /// each tile demanded a width the container could not supply four of. This
    /// cap only bites on unusually wide layouts, and it scales with Dynamic Type
    /// so it does not clamp the tiles exactly when they are meant to grow.
    @ScaledMetric(relativeTo: .largeTitle) private var maxTileHeight: CGFloat = 118

    var body: some View {
        Button(action: action) {
            ZStack {
                shape.fill(Cute.tileFace)
                shape.stroke(Cute.tileEdge, lineWidth: 1)
                Text(letter)
                    .font(CuteFont.display(glyphSize))
                    .foregroundStyle(placed ? Cute.inkFaint : Cute.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .padding(4)
            }
            // Taller than wide. This is most of why they read as tiles rather
            // than as buttons.
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .frame(maxHeight: maxTileHeight)
            .frame(minHeight: Cute.minTapTarget)
        }
        // The slab now lives in the press style, so it can shorten as the tile
        // descends onto it rather than staying put while the tile moves.
        .buttonStyle(TilePressStyle(slabColour: placed ? .clear : Cute.surfaceShadow,
                                    shape: shape))
        .disabled(placed)
        // A placed tile keeps its face and loses its slab, so it sits down into
        // the rack. 0.32 is the web's value: dimmed but still legible, which is
        // the difference between reading as unavailable and reading as absent.
        .opacity(placed ? 0.32 : 1)
        .motion(Feel.bounce, value: placed)
        .accessibilityLabel("Letter \(letter)\(placed ? ", already picked" : "")")
    }
}

// MARK: - Controls

/// Two rows, ordered by how often each action is used.
///
/// The **primary pair (Delete, then Pick word) sits on top**, closest to the
/// rack and the well where the action already is, and the utility pair
/// (Shuffle, Clear) sits quietly beneath. The eye scans top to bottom and lands
/// on the most-used actions first.
///
/// Delete comes before Submit. That ordering is not aesthetic: it came from Bea
/// telling Antoine that delete is one of the most-used buttons and was in the
/// wrong place. Do not reorder it.
private struct Controls: View {
    let model: GameModel

    private var empty: Bool { model.composing.isEmpty }

    var body: some View {
        VStack(spacing: 9) {
            HStack(spacing: 10) {
                PillButton(kind: .delete, disabled: empty,
                           label: "Delete last letter") { model.removeLast() }
                    // The web gives Submit `flex: 2` against Delete's `flex: 1`.
                    // Capping Delete is the simple approximation of that ratio
                    // and holds at phone widths, which is all this targets.
                    .frame(maxWidth: 116)
                PillButton("Pick word", kind: .primary,
                           disabled: model.composedWord.count < minWordLength) {
                    model.submit()
                }
            }
            HStack(spacing: 10) {
                PillButton("Shuffle", kind: .utility) { model.shuffleRack() }
                PillButton("Clear", kind: .utility, disabled: empty) { model.clear() }
            }
        }
    }
}

private struct PillButton: View {
    enum Kind { case utility, delete, primary }

    let title: String
    let kind: Kind
    var disabled: Bool = false
    var label: String? = nil
    let action: () -> Void

    init(_ title: String = "", kind: Kind, disabled: Bool = false,
         label: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.kind = kind
        self.disabled = disabled
        self.label = label
        self.action = action
    }

    /// The delete control carries an icon rather than a glyph in a text font.
    /// It is the only icon-only control on the screen and was the least legible
    /// thing on it: a backspace character set in a body face renders far smaller
    /// than the words beside it. The web makes `.btn--delete` a size larger than
    /// its siblings for exactly this reason; an SF Symbol is sized as an icon,
    /// which is the same intent expressed the native way.
    @ScaledMetric(relativeTo: .title3) private var deleteGlyph: CGFloat = 26

    /// The most-used controls on the screen, so they are the biggest. The
    /// primary pair runs taller than the utility pair beneath it.
    @ScaledMetric(relativeTo: .body) private var primaryHeight: CGFloat = 56
    @ScaledMetric(relativeTo: .body) private var utilityHeight: CGFloat = 46

    private var height: CGFloat {
        kind == .utility ? utilityHeight : primaryHeight
    }

    // Disabled controls are muted by colour rather than a dim veil, so the label
    // stays perceivable. The primary's disabled state is a white pill with a
    // rule border, NOT a pale fill, which reads as not-yet-active rather than
    // broken.
    private var fill: Color {
        if disabled { return Cute.paperDeep }
        return kind == .primary ? Cute.accent : Cute.paperDeep
    }

    private var border: Color {
        if disabled { return Cute.rule }
        switch kind {
        case .primary: return Cute.accent
        case .utility: return Cute.rule
        case .delete: return Cute.ink
        }
    }

    private var foreground: Color {
        if disabled { return Cute.inkFaint }
        switch kind {
        case .primary: return Cute.paper
        case .utility: return Cute.inkSoft
        case .delete: return Cute.ink
        }
    }

    var body: some View {
        Button(action: action) {
            Group {
                if kind == .delete {
                    Image(systemName: "delete.left")
                        .font(.system(size: deleteGlyph, weight: .medium))
                } else {
                    // 0.875rem uppercase with 0.14em tracking, as the web has it.
                    Text(title)
                        .font(CuteFont.body(15,
                                            weight: kind == .primary ? "SemiBold" : "Regular",
                                            relativeTo: .subheadline))
                        .tracking(2.1)
                        .textCase(.uppercase)
                }
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(minHeight: height)
            .background(Capsule().fill(fill))
            .overlay(Capsule().stroke(border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .accessibilityLabel(label ?? title)
    }
}

// MARK: - Message line

/// The feedback slot. Blank when there is nothing to say.
///
/// It previously echoed the compose well's placeholder, so "Pick letters to make
/// a word" appeared twice on screen. On the web this line only ever carries a
/// find or a rejection. The height is reserved either way so feedback never
/// shifts the layout.
private struct MessageLine: View {
    let feedback: GameModel.Feedback

    var body: some View {
        Group {
            switch feedback {
            case .none:
                Text(" ")
            case .accepted(let word, let points, let rung):
                Text("\(word), \(counted(points, "point"))" + (rung == .set ? "" : " (\(rung.rawValue))"))
                    .foregroundStyle(rung == .set ? Cute.accent : Cute.discovery)
            case .sourceFound:
                Text("You found the Peach of a Word!")
                    .foregroundStyle(Cute.accent)
            case .rejected(let message):
                Text(message).foregroundStyle(Cute.inkFaint)
            }
        }
        .font(CuteFont.body(15, relativeTo: .callout))
        .frame(maxWidth: .infinity, minHeight: 20)
        .accessibilityHidden(true)
    }
}

#Preview("Empty board") {
    ContentView(storage: GameStorage(store: InMemoryStore()))
}

#Preview("Played board, near completion") {
    // The state the tier meter and the found list are most worth judging
    // against. In-memory storage so the canvas never touches real saved
    // progress.
    ContentView(debugSeed: "almost", storage: GameStorage(store: InMemoryStore()))
}

#Preview("Played board, mid game") {
    ContentView(debugSeed: "24", storage: GameStorage(store: InMemoryStore()))
}
