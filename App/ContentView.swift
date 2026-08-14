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

    /// The smallest found list worth calling a list: a group heading and a row
    /// of chips. Scales with Dynamic Type, because a floor in fixed points
    /// would itself be crushed at large sizes.
    ///
    /// **This floor decides that a 667pt phone scrolls at every text size**,
    /// including the default, where it previously used the fixed layout. That
    /// was considered and kept, for two reasons.
    ///
    /// The 40pt it had there was never a list. It was a heading and a clipped
    /// word row, and trading a real list for a touch-down commit on the one
    /// phone that cannot display the list is the wrong way round. The
    /// complaint that started this work was about flow while composing, which
    /// a 40pt viewport does not help either.
    ///
    /// It also gives that phone **one layout instead of two**, so it never
    /// switches regimes as text size changes. That is the same "same shape at
    /// every size" property that made the fixed layout attractive in the first
    /// place, and a short phone is the one device that can actually have it.
    /// Two regimes with a boundary nobody could observe is what produced the
    /// untestable path this replaces.
    @ScaledMetric(relativeTo: .body) private var minimumListHeight: CGFloat = 52
    #if TAP_RECORDER
    @Environment(\.scenePhase) private var scenePhase
    #endif

    /// `storage` is injectable so a preview does not scribble on the real
    /// UserDefaults every time the canvas re-renders.
    init(debugSeed: String? = nil, storage: GameStorage = .appDefault) {
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
                    Text(Vocabulary.mastheadSubline)
                        .font(CuteFont.body(12, weight: "SemiBold", relativeTo: .caption))
                        .tracking(4.4)
                        .textCase(.uppercase)
                        .foregroundStyle(Cute.accentDeep)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    ProgressView().tint(Cute.accent)
                    // The loading line, which the app never had: a bare spinner
                    // where the web says what is happening. The subline in the
                    // continuous present, so the splash is the app doing the
                    // thing it is about to invite you to do.
                    Text(Vocabulary.loadingLine)
                        .font(CuteFont.body(14, relativeTo: .subheadline))
                        .foregroundStyle(Cute.inkFaint)
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
        // The feedback line, spoken.
        //
        // `MessageLine` is hidden from the accessibility tree, so before this
        // there was no way to hear a rejected guess at all. Posted here rather
        // than from the row because the row is instantiated twice, once per arm
        // of the `ViewThatFits`, and the root is instantiated once.
        //
        // Keyed on the counter rather than on `feedback` itself: the same word
        // rejected twice produces an equal value, which is not a change, and a
        // player who cannot see the line is exactly the player who has no way
        // to notice they submitted it again. See `GameModel.feedbackSeq`.
        .onChange(of: model.feedbackSeq) {
            guard let message = model.feedback.message else { return }
            AccessibilityNotification.Announcement(message).post()
        }
        #if TAP_RECORDER
        // The window-level probe, and the flush. Backgrounding is the natural
        // end of a session: handing the phone over writes the log.
        .background(TouchProbeInstaller().allowsHitTesting(false))
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { TapRecorder.shared.flush() }
        }
        #endif
        .task {
            #if TAP_RECORDER
            // A session marker written immediately, so the log exists before any
            // taps do. That is what makes "is the recorder actually live" a
            // question answerable by pulling a file rather than by grepping a
            // Release binary, which has produced a false negative in this repo
            // before.
            TapRecorder.shared.record(.marker)
            TapRecorder.shared.flush()
            #endif
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
        // Decided by available height, not by text size.
        //
        // It used to switch on `isAccessibilitySize`, which is a proxy for
        // "does this fit", and the proxy was measured wrong in both directions:
        // an SE and an iPhone 15 differ by 3pt across and 185pt down, and it is
        // the 185 that decides. At the largest text size the fixed furniture
        // needs roughly 1180pt against 852 on an iPhone 15 and 667 on an SE, so
        // it genuinely cannot fit at the top of the range on either. Below that
        // it often can, and every size that fits now keeps the fixed rack.
        //
        // `ViewThatFits` asks the question directly: take the fixed layout if
        // its ideal height fits, otherwise scroll everything. The minimum height
        // on the found list is what makes "fits" mean "fits with a list worth
        // having" rather than "fits with the list crushed to nothing", which is
        // the bug this replaces.
        ViewThatFits(in: .vertical) {
            fixedLayout
            scrollingFallback
        }
    }

    /// The rack and controls are fixed furniture; only the list scrolls.
    ///
    /// The touch-down commit is safe here because the rack is not inside a
    /// scroll view, so nothing has to guess whether a finger is tapping or
    /// panning. That is the whole reason this layout is preferred wherever it
    /// fits: it is the one that keeps input responsive.
    private var fixedLayout: some View {
        // Explicit spacing rather than one uniform VStack gap, because the gaps
        // are not all the same job: feedback belongs tight to the well it
        // reports on, and the rack wants less room beneath it than the uniform
        // 12pt was giving it.
        VStack(spacing: 0) {
            header
            ComposingStick(word: model.composedWord)
                .padding(.top, 12)
            // Feedback lives here, directly under the well it reports on, and
            // it lives here permanently. It previously sat between the rack and
            // the list, immediately above the summary line, where the two read
            // as one slot alternating between a count and a message.
            MessageLine(feedback: model.feedback)
                .padding(.top, 6)
            TypeCase(model: model, commitOnTouchDown: true)
                .padding(.top, 8)

            // Pinned, above the scroll rather than inside it.
            pinnedSummary
                .padding(.top, 10)

            scrollingList
                // The floor. Without it the list is the flexible element and
                // absorbs every shortfall, which is how it reached zero height
                // on an SE at xxxLarge while the layout still called itself a
                // fit. With it, a squeeze past this point falls to the
                // scrolling layout instead of silently deleting the list.
                // Ideal as well as minimum, and this is the load-bearing part.
                // A ScrollView proposes its whole content as its ideal height,
                // so the found list offered every word it had, the fixed layout
                // measured as enormous, and ViewThatFits rejected it at every
                // size including the default. Pinning the ideal to the floor
                // makes the question "does the furniture plus a usable list
                // fit", which is the question actually being asked.
                .frame(minHeight: minimumListHeight,
                       idealHeight: minimumListHeight,
                       maxHeight: .infinity)
                .padding(.top, 6)

            Controls(model: model)
                .padding(.top, 10)
        }
        .padding(.horizontal, 18)
        .padding(.top, 4)
    }

    /// Everything scrolls, for when the fixed layout genuinely cannot fit.
    ///
    /// The rack is inside the scroll view here, so the touch-down commit is off:
    /// `RackScrollTests` measured that forcing it on stops the view scrolling
    /// and inserts a letter. A player in this layout keeps the slower tiles, and
    /// that is now a known cost of a layout that only appears when nothing else
    /// will fit.
    private var scrollingFallback: some View {
        ScrollView {
            VStack(spacing: 14) {
                header
                ComposingStick(word: model.composedWord)
                TypeCase(model: model, commitOnTouchDown: false)
                Controls(model: model)
                MessageLine(feedback: model.feedback)
                pinnedSummary
                foundList
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
        }
        // So content past the fold can be screenshotted. Without it the whole
        // screen is one scroll view at these sizes, simctl cannot scroll, and
        // anything below the fold could only be reasoned about.
        .modifier(DebugScrollAnchor())
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

    /// The status row, outside the scroll region.
    private var pinnedSummary: some View {
        Group {
            if let puzzle = model.puzzle, let standing = model.standing, !model.found.isEmpty {
                FoundSummary(puzzle: puzzle, found: model.found,
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
                Text(Vocabulary.inputPlaceholder)
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
    /// Whether this rack sits in a fixed layout, and can therefore commit on
    /// touch down. See `effectiveCommitOnTouchDown`.
    let commitOnTouchDown: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Three columns at accessibility sizes is the reflow that was previously
    /// happening by accident of available width. Now it is an explicit response
    /// to Dynamic Type, which is what it always should have been.
    private var columnCount: Int { dynamicTypeSize.isAccessibilitySize ? 3 : 4 }

    /// Whether tiles commit on touch down.
    ///
    /// **Tied to the layout, not to the text size.** A zero-distance drag on a
    /// tile fires before the system can know whether the finger is tapping or
    /// starting a scroll, so it is only safe when the rack is not inside a
    /// scroll view. `RackScrollTests` measured what happens otherwise: the view
    /// stops scrolling entirely and a letter is inserted.
    ///
    /// It used to be keyed off `isAccessibilitySize`, which was a proxy for
    /// "is the rack in a scroll view". The proxy was wrong in both directions,
    /// so the caller now says which layout it is, and every player whose rack is
    /// fixed gets the responsiveness fix regardless of their text size.
    private var effectiveCommitOnTouchDown: Bool {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "forceTouchDown") { return true }
        #endif
        return commitOnTouchDown
    }

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
                        action: { model.addTile(id) },
                        // A refusal is animated from a token, so two refusals
                        // of the same tile are two shakes rather than one.
                        refusalToken: model.refusal?.tile == id
                            ? (model.refusal?.token ?? 0) : 0,
                        // Touch-down commit needs a gesture, and a gesture with
                        // no minimum distance would fight the scroll view that
                        // wraps the whole screen at accessibility sizes. That
                        // path is already flagged as untested, so it keeps the
                        // Button until it is looked at properly.
                        commitOnTouchDown: effectiveCommitOnTouchDown,
                        tileID: id
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
    var refusalToken: Int = 0
    var commitOnTouchDown: Bool = true
    /// Only read by the tap recorder, and only present in that build.
    var tileID: Int = -1

    /// Pressed state, owned here rather than by a `ButtonStyle`, because the
    /// commit now happens on touch down and the visual has to follow the same
    /// event. A `Button` fires on touch **up**, which measured at 58ms after
    /// the tile had already visibly depressed: the letter could not appear
    /// until the finger lifted. Nothing was ever dropped, but the gap between
    /// seeing the tile move and seeing the letter arrive is real.
    @State private var pressing = false
    @State private var shake: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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

    private var face: some View {
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

    /// Commit on touch down, animation following.
    ///
    /// A `DragGesture` with no minimum distance is the only way to see touch
    /// down in SwiftUI. The latch makes it fire once per touch rather than on
    /// every movement update. Hit testing is taken from `contentShape` on the
    /// unmoved geometry, so the target does not travel with the press
    /// animation.
    private var touchDownTile: some View {
        face
            .offset(y: pressing && !reduceMotion ? 3 : 0)
            .background(
                shape.fill(placed ? .clear : Cute.surfaceShadow)
                    .offset(y: pressing && !reduceMotion ? 1 : 5)
            )
            .animation(reduceMotion ? nil : Feel.bounce, value: pressing)
            .contentShape(shape)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !pressing else { return }
                        pressing = true
                        #if TAP_RECORDER
                        TapRecorder.shared.record(.press, tile: tileID, letter: letter)
                        #endif
                        action()
                    }
                    .onEnded { _ in pressing = false }
            )
            .accessibilityElement()
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(.default, action)
    }

    var body: some View {
        Group {
            if commitOnTouchDown {
                touchDownTile
            } else {
                Button(action: action) { face }
                    .buttonStyle(TilePressStyle(
                        slabColour: placed ? .clear : Cute.surfaceShadow, shape: shape))
            }
        }
        // The slab now lives in the press style, so it can shorten as the tile
        // descends onto it rather than staying put while the tile moves.
        // No longer `.disabled`. A used tile stays interactive so it can refuse
        // audibly rather than swallowing the tap, which is the whole point of
        // the change: silence was indistinguishable from a dropped tap.
        .modifier(ShakeEffect(animatableData: shake))
        .onChange(of: refusalToken) { _, token in
            guard token != 0, !reduceMotion else { return }
            shake = 0
            withAnimation(.easeOut(duration: 0.22)) { shake = 1 }
        }
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
                PillButton(Vocabulary.submitWord, kind: .primary,
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
/// find or a rejection.
///
/// **The height is reserved, which it previously only claimed to be.** The
/// frame said `minHeight: 20`, and a minimum is a floor, not a reservation: the
/// rejection for an unformable word wrapped to two lines and pushed the rack,
/// the summary and the list down, mid-play, at the exact moment a finger was
/// heading for a tile. Same defect the tier caption had, same fix, and the
/// second half of it matters as much as the first: reserving alone turns the
/// shove into a truncation, so the copy is cut to fit the reserved line too.
/// See `Vocabulary` and `GameModel.resolve` for what each string had to become.
///
/// **VoiceOver has never heard this line, and now it does.** The row is hidden
/// from the accessibility tree, which was defensible while it wrapped: the
/// sentence stayed whole on screen and the slot added nothing to swipe past.
/// Reserving the height changed that bargain. The visible line can now shrink
/// and, at the largest text sizes, truncate, so it is the only channel for the
/// information and it is a lossy one. The people most likely to be at those
/// sizes are the people most likely to be using VoiceOver, which is the wrong
/// way round. So the message is announced, from the same `Feedback.message` the
/// row renders, which is what makes the announcement carry the whole string no
/// matter what the row does to fit it.
///
/// The announcement is posted from `ContentView.body` rather than from here,
/// and that is load bearing: this view is instantiated twice, once in each arm
/// of the `ViewThatFits`, so announcing from inside it would be betting that
/// SwiftUI never runs `onChange` on the arm it measured and discarded. The root
/// exists exactly once, so there is no bet to lose.
private struct MessageLine: View {
    let feedback: GameModel.Feedback

    /// The reserved height for the message row. One line of Nunito at 15pt
    /// measures 21, and `@ScaledMetric` grows that with Dynamic Type, so the
    /// row still gets bigger as the text does. What it will not do is get
    /// bigger because of what the row happens to say.
    @ScaledMetric(relativeTo: .callout) private var messageHeight: CGFloat = 21

    private var tint: Color {
        switch feedback {
        case .none: Cute.inkFaint
        case .accepted(_, _, let rung): rung == .set ? Cute.accent : Cute.discovery
        case .sourceFound: Cute.accent
        case .rejected: Cute.inkFaint
        }
    }

    var body: some View {
        // A space rather than an empty string, so the row has a baseline to
        // sit on whatever else changes.
        Text(feedback.message ?? " ")
            .foregroundStyle(tint)
            .font(CuteFont.body(15, relativeTo: .callout))
            // 0.6 is the tier caption's allowance, and it buys a real amount
            // here. Measured in Nunito at 339pt of content, which is 375pt of
            // phone less the 18pt margins. That is the 13 mini, and it is the
            // binding case rather than the SE for a reason worth writing down:
            // the SE takes the scrolling fallback at every text size, so the
            // fixed layout never exists there, while the mini is narrow AND
            // tall enough to keep it. Widening this bound to a 402pt phone
            // would be measuring the wrong device.
            //
            // At AX5 the two shortened rejections need 0.78 and 0.81, and the
            // off-page find messages 0.65 and 0.72. Two strings still land
            // under 0.6 and will truncate: the source-word line (0.56), kept
            // deliberately because it is the game's one loaded sentence and a
            // sheet is opening behind it anyway, and an eight-letter uncommon
            // find (0.56), which is a format rather than a phrase. Dropping
            // the floor to fit them would put a 24pt glyph in front of someone
            // who asked for 43, which looks like it worked.
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            // Min and max both, which is how `frame` spells an exact height
            // while taking the full width. There is no `maxWidth:height:`.
            .frame(maxWidth: .infinity,
                   minHeight: messageHeight, maxHeight: messageHeight)
            // Still hidden as an element, and now that is a choice rather than
            // a gap: the announcement above is the channel, and leaving the row
            // in the tree as well would mean hearing every message twice, once
            // when it lands and again on the next swipe past it.
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


/// Where the app's progress lives.
///
/// One place, so the instrumented build cannot accidentally be pointed at the
/// real one. See `UserDefaultsStore.diagnostic` for why the diagnostic build
/// gets its own suite.
extension GameStorage {
    static var appDefault: GameStorage {
        #if TAP_RECORDER
        GameStorage(store: UserDefaultsStore.diagnostic)
        #else
        GameStorage(store: UserDefaultsStore())
        #endif
    }
}
