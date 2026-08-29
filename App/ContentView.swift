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
    /// **This floor used to decide that a 667pt phone scrolled at every text
    /// size. It no longer does, and the reasoning that accepted that outcome
    /// has been overtaken rather than overruled.**
    ///
    /// The argument was that the 40pt the SE got from the fixed layout "was
    /// never a list", so trading a real list for the touch-down commit on the
    /// one phone that could not show a list was the wrong way round. That was
    /// correct about 40pt. After the chrome reclaim (the wordmark and the
    /// message row, 61.67pt on a 390pt phone) the same phone measures
    /// **107.5pt of list at default size**, which is more than two and a half
    /// times what the argument was written about. The premise changed, so the
    /// conclusion changed with it, and the SE now takes the fixed layout at L,
    /// XL and XXL.
    ///
    /// **The cost is the other half of the old argument, and it is real.** That
    /// phone no longer has one layout at every size: it switches regimes
    /// between XXL and XXXL. "Same shape at every size" was a genuine property
    /// and it has been spent to buy a usable list and the touch-down commit at
    /// the three sizes most people actually use. Flagged here rather than
    /// smoothed over, because it was a deliberate decision once and is now a
    /// consequence of a different one.
    ///
    /// What has not changed is what the floor is for: it makes "fits" mean
    /// "fits with a list worth having" rather than "fits with the list crushed
    /// to nothing". On the SE at XXL that is doing visible work, holding the
    /// list at 63.5pt, which is the tightest cell in the whole matrix and sits
    /// essentially on the floor itself. That phone at that size is one small
    /// regression away from falling back, which is the floor working rather
    /// than a problem, but it is the cell to re-measure after any change to the
    /// furniture above it.
    ///
    /// **Re-measured when the controls moved up under the rack, and it held at
    /// 63.5pt.** That move reorders the furniture without changing how much of
    /// it there is, so this cell was expected to be untouched and is. Recorded
    /// because the instruction above is to re-measure rather than to reason,
    /// and a re-measurement that confirms the prediction is still the thing
    /// that was asked for.
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
                    wordmark
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
                case .sourceWord(let word):
                    let entry = model.sourceEntries[word]
                    SourceRevealCard(word: word, entry: entry) { model.moment = nil }
                        // Large only, and the board is covered whenever this is
                        // up. No crown carrying an entry has ever fitted the
                        // medium detent, and 615 of 626 carry one, so offering
                        // medium was offering a height that truncated almost
                        // every card. The way out is pinned inside the card
                        // rather than depending on this, which is what makes
                        // the long ones usable. See `SourceRevealCard`.
                        .presentationDetents([.large])
                case .completion(let setTotal, let score):
                    CompletionCard(setTotal: setTotal, score: score) { model.moment = nil }
                        .presentationDetents([.medium, .large])
                case .definition(let word, let category):
                    DefinitionCard(
                        word: word,
                        category: category,
                        definition: model.definitions[word]
                    ) { model.moment = nil }
                        .presentationDetents([.medium, .large])
                }
            }
            // Medium rather than full, so the board stays visible behind it and
            // this reads as a moment rather than an interruption. Drag to
            // dismiss comes free, which is the reason for a sheet over an
            // overlay.
            // Large is offered as well as medium, so accessibility text sizes
            // have somewhere to go rather than being squeezed into a fixed
            // height.
            //
            // Set per card rather than once for all three, because the source
            // reveal now decides its own from its content. The other two are
            // unchanged and carry the pair explicitly, so that this comment
            // still describes what they do.
            .presentationDragIndicator(.visible)
        }
        // The feedback line, spoken.
        //
        // The feedback is not in the accessibility tree: it renders inside
        // `ComposingStick`, which ignores its children, so before this there
        // was no way to hear a rejected guess at all. Posted here rather than
        // from the well because the well is instantiated twice, once per arm of
        // the `ViewThatFits`, and the root is instantiated once.
        //
        // Keyed on the counter rather than on `feedback` itself: the same word
        // rejected twice produces an equal value, which is not a change, and a
        // player who cannot see the line is exactly the player who has no way
        // to notice they submitted it again. See `GameModel.feedbackSeq`.
        .onChange(of: model.feedbackSeq) {
            guard let message = model.feedback.message else { return }
            AccessibilityNotification.Announcement(message).post()
        }
        // The one-time streak transfer from the web build. Disposable: when the
        // handoff is done, this modifier, `StreakTransfer`, `adoptStreak`, and
        // the CFBundleURLTypes entry in project.yml all go together.
        //
        // No confirmation UI on purpose. A transfer that lands shows the new
        // number on the meter, which is the whole of what she is here for, and
        // one that does not land leaves the number alone. Anything more would
        // be building a feature out of a migration.
        .onOpenURL { url in
            guard let transfer = StreakTransfer(url: url) else { return }
            model.adoptTransferredStreak(transfer)
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

    /// The name of the game, and the only place in the app it appears.
    ///
    /// **Transcribed from the masthead rather than approximated**, because the
    /// masthead is gone: it came off the play screen in the chrome reclaim, on
    /// the argument that an app is already open, already named on the home
    /// screen, already the thing that was tapped. That argument is about the
    /// play screen and it does not reach here. A splash is exactly where an app
    /// announces itself, once per session, and it was announcing everything
    /// except its name.
    ///
    /// "Peach" keeps the pink oblique, which is the identifying mark and the
    /// half of the wordmark that is not just words. `displayOblique` shears
    /// Fredoka by hand through CoreText because Fredoka has no italic face and
    /// `.italic()` therefore selects nothing; see `CuteFont`.
    ///
    /// The two halves are concatenated with `+` rather than set in an `HStack`.
    /// That is not a style preference: `Text + Text` is one text run, so it
    /// wraps, scales and truncates as a single unit, and the space before "of"
    /// belongs to the run rather than to a stack's spacing. An `HStack` would
    /// let the two halves scale independently.
    private var wordmark: some View {
        (Text("Peach").font(CuteFont.displayOblique(22, relativeTo: .title3))
            .foregroundColor(Cute.accent)
         + Text(" of a Word").font(CuteFont.display(22, relativeTo: .title3))
            .foregroundColor(Cute.ink))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            // The gutter the masthead used to inherit from its container.
            // Transcribing the view verbatim dropped it, because the play
            // screen padded the whole column by 18 and this splash pads
            // nothing: at AX5 the name rendered in full and touched both
            // bezels. Worth catching, since "exactly as the masthead had it"
            // turns out to include the box the masthead was in.
            .padding(.horizontal, 18)
    }

    /// **A screen, not a page.**
    ///
    /// The web version is a page: it may be arrived at from anywhere, so it can
    /// afford a masthead announcing what it is. An app is already open, already
    /// named on the home screen, already the thing that was tapped. So the
    /// kicker is gone, the wordmark is small, and the rack and controls fit in
    /// one view with the found list scrolling beneath.
    ///
    /// **The controls sit directly under the rack, and this reverses a decision
    /// made deliberately when the fixed layout was built.** They used to be
    /// pinned to the bottom edge in comfortable thumb reach, with the found
    /// list scrolling in the loose middle between them and the rack. The
    /// argument was that phones are bottom-weighted where pages are top-
    /// weighted, and it is a good argument.
    ///
    /// It lost to two testers who reported the same friction independently and
    /// unprompted. Words arrive in bursts, so backspace, pick word, shuffle and
    /// clear are used *between* taps on the rack rather than after a run of
    /// them, and a list scrolling between the two put the whole found list's
    /// height of finger travel inside a single word. A principle about where
    /// thumbs rest lost to two reports of what hands actually did.
    ///
    /// The controls keep the size that pinning them bought. They are the
    /// most-used targets on the screen and were once the smallest; being at the
    /// bottom was never what made them big.
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
            // Feedback lives INSIDE the well now, not in a row of its own
            // beneath it. See `ComposingStick`.
            ComposingStick(word: model.composedWord, feedback: model.feedback,
                               feedbackSeq: model.feedbackSeq)
                .padding(.top, 12)
            TypeCase(model: model, commitOnTouchDown: true)
                .padding(.top, 8)

            Controls(model: model)
                // 8 rather than 10. Taken off the gap above the block rather
                // than out of the buttons: the utility pair stands at 46pt
                // against a 44pt minimum target, so there are two points there
                // and they are not the two points to spend.
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
                ComposingStick(word: model.composedWord, feedback: model.feedback,
                               feedbackSeq: model.feedbackSeq)
                TypeCase(model: model, commitOnTouchDown: false)
                Controls(model: model)
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

    /// The tier meter, and nothing else.
    ///
    /// **The wordmark is gone from the play screen**, and the `VStack` that held
    /// it went with it rather than being left behind with one child. That second
    /// half is the load-bearing half: a `VStack(spacing: 8)` with a single child
    /// still allocates nothing visible but reads as a container that wants a
    /// sibling, and the 8pt only comes back because the stack itself is gone.
    /// Measured at 34.67pt returned on an iPhone 13 at default text size, 26.67
    /// of wordmark and 8 of spacing; leaving the stack in place would have
    /// quietly returned 26.67 and looked like the same change.
    ///
    /// The argument for cutting it was already written one level up, in `game`:
    /// an app is already open, already named on the home screen, already the
    /// thing that was tapped. The kicker went for that reason in an earlier
    /// pass and the wordmark stayed on the grounds that it was small. Small is
    /// not free on the one screen that has to hold everything at once, and this
    /// is the cheapest 35pt on it.
    ///
    /// The mark is not lost from the app. `PeachMark` and the subline are on
    /// the splash, which is where a name belongs: once per session, at the
    /// moment the app is announcing itself, rather than permanently above a
    /// board being played.
    private var header: some View {
        Group {
            if let standing = model.standing {
                TierMeterView(standing: standing, streak: model.streak)
            }
        }
    }

    private var foundList: some View {
        Group {
            if let puzzle = model.puzzle, let standing = model.standing {
                FoundListView(puzzle: puzzle, found: model.found,
                              standing: standing, boardDate: model.boardDate) { word in
                    model.revealFound(word)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The status row, outside the scroll region.
    ///
    /// **Rendered on an empty board too, showing zeros.** It used to be gated on
    /// `!model.found.isEmpty`, and a row that is absent is a row whose height
    /// arrives later: on a fresh day the first find inserted the row AND the
    /// 10pt padding above it, 52.67pt measured on an iPhone 17 at default size,
    /// which the found list absorbed by dropping its top from 512.00 to 564.67
    /// at the moment the first word landed. Same defect class as the message
    /// line and the tier caption, one level up: those two reserved a row that
    /// could grow, this one hid a row that could appear.
    ///
    /// Zeros rather than reserved blank space, because `FoundSummary` already
    /// makes that argument about itself: it prints a rung with nothing at it as
    /// "0 Uncommon" rather than hiding it, so the row cannot grow the first time
    /// a Rare turns up. Hiding the whole row undid that one level up. A tally
    /// reading zero is information; 42.67pt of nothing is not.
    private var pinnedSummary: some View {
        Group {
            if let puzzle = model.puzzle, let standing = model.standing {
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
    ///
    /// **This is now the bottom-most view, and that is worth a number rather
    /// than a shrug.** Moving the controls up under the rack does not change
    /// how much furniture there is, so the list was expected to measure exactly
    /// the same and on an iPhone SE it does: 107.5 / 84.5 / 63.5 at L, XL and
    /// XXL, unchanged to the hundredth of a point.
    ///
    /// On an iPhone 13 the frame gained **34.00pt at every size**, and the 34
    /// is not a coincidence: it is the bottom safe-area inset. A scroll view
    /// sitting at the bottom edge extends its frame through the home indicator,
    /// which is the native treatment and the reason a list runs to the edge of
    /// the screen rather than stopping short of it. The controls could never
    /// claim that region, because a button under the home indicator is a button
    /// competing with a system gesture.
    ///
    /// **That 34pt is not 34pt of words, and the frame measurement cannot tell
    /// you so.** Extending through the inset comes with a matching bottom
    /// content inset, so the visible content window is exactly what it was.
    /// Screenshotted before and after at the same seed on the same phone: both
    /// end on the same last row, `7 letters / destine entries / also found`.
    /// **Zero additional rows are readable at rest.** What actually changed is
    /// that the list bleeds to the screen edge instead of stopping above a row
    /// of buttons, which is a better treatment and is not a density win.
    ///
    /// Written down because "the list gets everything below the controls"
    /// sounds like it should be worth the controls' height; because a frame
    /// that measures 34pt taller looks like it settles the question and does
    /// not; and because the answer on any phone with a home button is zero
    /// either way. The layout is height-neutral by construction. This is the
    /// one edge effect on top of it, and it is cosmetic.
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

/// The stick: the letters placed so far, in order, **and the feedback line**.
///
/// One fixed height for every state, so the rack never shifts when the first
/// letter lands. That is why the web pins it too.
///
/// **The message used to have a row of its own directly beneath this one, and
/// that row is what paid for the found list.** It cost 21pt of reserved height
/// plus a 6pt gap, 27pt at default text size on an iPhone 13 and 31pt at XXL,
/// for a slot that is empty most of the time. The list is the only flexible
/// element on this screen, so every point that row held was a point the list
/// did not get.
///
/// **The reserved-height discipline is not merely carried across, it gets
/// stronger.** `MessageLine` reserved an exact 21pt so a two-line rejection
/// could not push the rack down mid-play; `MessageLineShove` exists because
/// that shove was real and was measured. Here the container is a fixed 58pt
/// well that was already fixed for its own reasons, so no string can change any
/// height at all. Reserving was a promise a frame had to keep. This is a
/// promise the layout cannot break.
///
/// **Three states, one slot, and the composed word wins.** Letters if there are
/// letters, otherwise the message, otherwise the placeholder. The well is the
/// composing surface and a slot holds one thing, so the question is only which
/// thing, and the answer is whatever the player is doing right now rather than
/// what they did last.
///
/// That is why `GameModel.addTile` clears the feedback when a tile lands. The
/// alternative was to leave the model's value set and merely hide it, which
/// looks equivalent and is not: deleting back to an empty well would bring a
/// stale rejection back, an answer to a question nobody had asked. Clearing on
/// the first letter is the same event the player already experiences as
/// starting over.
///
/// **The web keeps its message visible while composing, and that parity is
/// deliberately not carried.** It can afford to because its message has a row
/// of its own, and it can afford the row because the web is a page where
/// nothing is pinned and the found list has no ceiling to run out of. That row
/// is exactly what is being reclaimed here, so the reason the web's behaviour
/// works is the reason it does not port. Same discipline as `RungSheet`: the
/// reasoning carries over, the constraint does not.
///
/// **Two lines rather than one, which the old row could not afford.**
/// `MessageLine` was `lineLimit(1)` with a 0.6 floor and recorded two strings
/// that still truncate at AX5. A fixed 58pt box fits two 15pt lines with room
/// to spare, so those strings get a second line instead of an ellipsis, and it
/// costs nothing because the box cannot grow either way.
///
/// The announcement still comes from `ContentView.body`, not from here, for the
/// same reason it never came from `MessageLine`: this view is instantiated
/// twice, once per arm of the `ViewThatFits`, and the root exactly once.
private struct ComposingStick: View {
    let word: String
    var feedback: GameModel.Feedback = .none
    /// Bumped on every resolved guess, so a rejection can be told from the same
    /// rejection again.
    ///
    /// The tone alone is not enough: rejecting the same word twice produces an
    /// equal `feedback` value, which is not a change and so animates nothing.
    /// The web had exactly this bug and fixed it by making its tone attribute
    /// round-trip, so a rejection, a tile, then a second rejection replays the
    /// shake. This is the same fix in the shape this app already had lying
    /// around for the spoken announcement.
    var feedbackSeq: Int = 0
    @ScaledMetric(relativeTo: .title) private var height: CGFloat = 58

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shake: CGFloat = 0

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Cute.cardRadius, style: .continuous)
    }

    /// Inherited from `MessageLine` unchanged: a find is the accent, an
    /// off-page find the discovery purple, a rejection the faint ink that says
    /// "nothing happened" without shouting about it.
    private var tint: Color {
        switch feedback {
        case .none: Cute.inkFaint
        case .accepted(_, _, let rung): rung == .set ? Cute.accent : Cute.discovery
        case .sourceFound: Cute.accent
        case .rejected: Cute.inkFaint
        }
    }

    var body: some View {
        ZStack {
            shape.fill(Cute.paperDeep)
            shape.stroke(Cute.tileEdge, lineWidth: 1)

            if word.isEmpty, let message = feedback.message {
                Text(message)
                    .font(CuteFont.body(15, relativeTo: .callout))
                    .foregroundStyle(tint)
                    .multilineTextAlignment(.center)
                    // Two lines, and the same 0.6 floor the row used. Dropping
                    // the floor further would put a 24pt glyph in front of
                    // someone who asked for 43, which looks like it worked.
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    // The well is full content width, so this keeps nearly all
                    // of the width the row had: 330pt of 354 on a 390pt phone
                    // against the row's 354, bought back several times over by
                    // the second line.
                    .padding(.horizontal, 12)
            } else if word.isEmpty {
                // Obliqued, not `.italic()`. The web sets `.stick__empty` in
                // italic and this line claimed to match it for months while
                // rendering upright, because Nunito ships no italic face for
                // `.italic()` to select. See `CuteFont.bodyOblique`.
                Text(Vocabulary.inputPlaceholder)
                    .font(CuteFont.bodyOblique(15, relativeTo: .subheadline))
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
        // The rejection nudge, ported from the web, where Bea called it
        // delightful and asked for it here.
        //
        // **Web values rather than this app's existing ones, on purpose.** The
        // tiles already shake, at travel 4 over three cycles in 0.22s, which is
        // a fast buzz and reads as a refusal: that tile cannot be picked. The
        // web's `nudge` is one out-and-back of 5px over 0.32s, which reads as a
        // headshake: that word is not a word. They are different events and
        // they are allowed to feel different, so this matches the thing being
        // ported rather than the nearest thing already here.
        //
        // Keyed on the counter, not on the tone. The same rejection twice is an
        // equal value and animates nothing, which is the bug the web had and
        // fixed; see `feedbackSeq`.
        .modifier(ShakeEffect(travel: 5, cycles: 1, animatableData: shake))
        .onChange(of: feedbackSeq) {
            guard case .rejected = feedback, !reduceMotion else { return }
            shake = 0
            withAnimation(.easeOut(duration: 0.32)) { shake = 1 }
        }
        .cuteSlab(shape, color: Cute.rule, y: 6)
        // `children: .ignore`, so the message inside is not a second element to
        // swipe past. It is already spoken, as an announcement posted the
        // moment it lands, and this label deliberately does not repeat it:
        // hearing every rejection twice, once when it happens and again on the
        // next swipe, is what the old row's `accessibilityHidden(true)` was
        // avoiding. The label describes the composing state, which is what this
        // element is.
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
    /// each tile demanded a width the container could not supply four of, and
    /// the rack broke to 3+3+2. That inversion is the thing not to reintroduce.
    ///
    /// **Lowered from 118 to 104, which means it now bites at phone width.**
    /// The rack was the tallest furniture on a screen that has to hold
    /// everything at once, and this is where the vertical points are. On a 390pt
    /// phone the column gives 81.75pt of width, so the tiles were drawing 109pt
    /// tall; capped, they draw 104 and the rack gives back 10pt across its two
    /// rows.
    ///
    /// **92 was tried, measured, and reverted. Do not reach for it again
    /// without reading this.** It returned 24pt at default size, and the
    /// arithmetic is what makes it a trap: the cap constrains HEIGHT, and the
    /// column stays 81.75pt wide whatever the tile does. So a 92pt cap draws a
    /// 69 x 92 tile in an 81.75pt column and **the leftover 13pt per column
    /// becomes gap**. On the phone the rack stops reading as a grid of tiles
    /// and starts reading as tiles floating in space.
    ///
    /// This is the same mechanism the 118-to-104 move already flagged, where a
    /// 14pt trim cost about 4pt of width and was recorded as a visible change
    /// nobody asked for. At 24pt it is three times that, which is where it
    /// crosses from unnoticed to wrong.
    ///
    /// **The 44pt tap floor was never the constraint** and is not what stops
    /// this. A 69 x 92 tile is more than twice the minimum in both directions.
    /// The constraint is that these are the most identifying objects on the
    /// screen and the leftover width has nowhere to go.
    ///
    /// **This cap is also a DEFAULT-SIZE lever only, and it does not look like
    /// one.** Measured on a 390pt phone across the 104-to-92 experiment: **24pt
    /// returned at L, 11 at XXL, and 2 at XXXL.** The reason is `@ScaledMetric`
    /// on this line. Dynamic Type grows the cap along with everything else, so
    /// it climbs out of biting range while the tile's natural 3:4 height (fixed
    /// by the column width, which does not scale) stays put. By XXXL the cap is
    /// above the height the ratio asks for and clamps nothing at all: at 92,
    /// `RackShape` still printed a 107.67pt tile there.
    ///
    /// So anyone pricing a further trim should expect it to buy points at
    /// default size and almost nothing at the sizes where the screen is
    /// tightest, which is the opposite of the intuition, and to pay for them in
    /// column gap. Both halves point the same way: this is the weakest of the
    /// levers on this screen. If large text ever needs the room, it is not this
    /// number. It is either dropping `relativeTo:` so the cap stops scaling,
    /// which would pin tile size against Dynamic Type and is its own argument,
    /// or taking the points somewhere else entirely.
    ///
    /// **It is still a cap on HEIGHT, which is why it is the safe lever.** The
    /// tile shrinks inside a column it never asked to widen, so it cannot demand
    /// width the container has not got, and the column count is not negotiated
    /// at all: `columnCount` is 4, or 3 at accessibility sizes, and nothing
    /// about a tile's size can change that. The 3:4 ratio is untouched, which
    /// matters beyond the silhouette: `.sort` in the web's `index.css` is
    /// `aspect-ratio: 3 / 4` and that is a number the two versions share.
    ///
    /// Still scaled, so Dynamic Type still grows the tiles rather than pinning
    /// them at a constant the moment the text gets bigger.
    @ScaledMetric(relativeTo: .largeTitle) private var maxTileHeight: CGFloat = 104

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
        // 7 rather than 9, between the primary row and the utility row. The
        // same two points the block gave up above it, and the same reasoning:
        // the space between the rows is spare, the height of the rows is not.
        VStack(spacing: 7) {
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


