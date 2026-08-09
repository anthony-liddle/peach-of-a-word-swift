import SwiftUI
import PeachEngine

/// The six named ranks, cute skin, from the web repo's `themeCopy.ts`.
/// The engine owns the ladder structure; these are a skin over the index.
private let cuteTierNames = [
    "First Sprout", "Little Bud", "Blossom", "Ripening", "Sweet", "Perfectly Peachy",
]

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
                ProgressView("Loading the dictionary")
                    .tint(Cute.accent)
                    .foregroundStyle(Cute.inkSoft)
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
        .task {
            await model.load()
            #if DEBUG
            if let debugSeed { model.seedBoard(debugSeed) }
            #endif
        }
    }

    /// The whole surface scrolls.
    ///
    /// At accessibility text sizes the rack alone is taller than the screen, so
    /// a fixed VStack pushed the masthead off the top. The web page scrolls;
    /// this should too. Note the found words are a plain LazyVStack rather than
    /// their own ScrollView, because nesting scroll views inside this one makes
    /// both behave badly.
    private var game: some View {
        ScrollView {
            VStack(spacing: 16) {
                Masthead(standing: model.standing)
                ComposingStick(word: model.composedWord)
                TypeCase(model: model)
                Controls(model: model)
                MessageLine(feedback: model.feedback)
                foundList
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
        }
    }

    private var foundList: some View {
        LazyVStack(alignment: .leading, spacing: 6) {
            ForEach(model.found, id: \.self) { word in
                Text(word)
                    .font(CuteFont.body(16))
                    .foregroundStyle(Cute.inkSoft)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel("Found words, \(model.found.count)")
    }
}

// MARK: - Masthead

/// Three lines, matching the web wordmark.
///
/// The italic pink "Peach" is the most identifying thing about it. Fredoka has
/// no true italic face; the browser fakes one and SwiftUI will not, so the slant
/// is applied by hand in `CuteFont.displayOblique`.
private struct Masthead: View {
    let standing: TierStanding?
    // Read so the body re-evaluates when Dynamic Type changes: the oblique
    // wordmark scales through UIFontMetrics at build time rather than through
    // `relativeTo:`, so it needs an explicit reason to recompute.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 4) {
            Text("A game about finding words in words")
                .font(CuteFont.body(11.5, weight: "SemiBold", relativeTo: .caption2))
                .tracking(4.8)          // 0.42em at 11.5pt
                .foregroundStyle(Cute.accentDeep)
                .textCase(.uppercase)
                .multilineTextAlignment(.center)

            (Text("Peach").font(CuteFont.displayOblique(34))
                .foregroundColor(Cute.accent)
             + Text(" of a Word").font(CuteFont.display(34, relativeTo: .largeTitle))
                .foregroundColor(Cute.ink))
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            // The subline, with a hairline rule either side.
            HStack(spacing: 8) {
                rule
                Text("Pick the peaches")
                    .font(CuteFont.body(11.5, relativeTo: .caption2))
                    .tracking(3.2)      // 0.28em at 11.5pt
                    .foregroundStyle(Cute.inkFaint)
                    .textCase(.uppercase)
                    .fixedSize(horizontal: false, vertical: true)
                rule
            }

            if let standing {
                // The web puts the rank and points in the glossary, which is out
                // of scope here, so they live under the masthead for now. The
                // rank NAME is kept rather than dropped: it is the part that
                // gets reacted to, where a bare point count is not.
                Text("\(cuteTierNames[min(standing.index, cuteTierNames.count - 1)]) · \(standing.score) points")
                    .font(CuteFont.body(13, relativeTo: .footnote))
                    .foregroundStyle(Cute.inkFaint)
                    .monospacedDigit()
                    .padding(.top, 2)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var rule: some View {
        Rectangle()
            .fill(Cute.rule)
            .frame(height: 1)
            .frame(maxWidth: 56)
    }
}

// MARK: - Compose well

/// The stick: the letters placed so far, in order.
///
/// One fixed height for both the empty and filled states, so the rack never
/// shifts when the first letter lands. That is why the web pins it too.
private struct ComposingStick: View {
    let word: String
    @ScaledMetric(relativeTo: .title) private var height: CGFloat = 64

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
                            .font(CuteFont.display(30, relativeTo: .title))
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
private struct TypeCase: View {
    let model: GameModel

    // Adaptive columns so the grid reflows when Dynamic Type grows the tiles,
    // rather than hardcoding four across. This is the CSS grid auto-fit
    // equivalent and it is the one place the layout had to think.
    @ScaledMetric(relativeTo: .largeTitle) private var tileMinWidth: CGFloat = 70

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: tileMinWidth), spacing: 10)],
            spacing: 12
        ) {
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
    @ScaledMetric(relativeTo: .largeTitle) private var glyphSize: CGFloat = 54

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
            .frame(minHeight: Cute.minTapTarget)
        }
        .buttonStyle(.plain)
        .disabled(placed)
        // A placed tile keeps its face and loses its slab, so it sits down into
        // the rack. 0.32 is the web's value: dimmed but still legible, which is
        // the difference between reading as unavailable and reading as absent.
        .cuteSlab(shape, color: placed ? .clear : Cute.surfaceShadow, y: 5)
        .opacity(placed ? 0.32 : 1)
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
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                PillButton("⌫", kind: .delete, disabled: empty,
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

    init(_ title: String, kind: Kind, disabled: Bool = false,
         label: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.kind = kind
        self.disabled = disabled
        self.label = label
        self.action = action
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
            Text(title)
                // 0.875rem uppercase with 0.14em tracking, as the web has it.
                // The delete glyph runs a little larger (1.05rem) so it does not
                // read as smaller than the words beside it.
                .font(kind == .delete
                      ? CuteFont.body(17, weight: "SemiBold", relativeTo: .body)
                      : CuteFont.body(14, weight: kind == .primary ? "SemiBold" : "Regular",
                                      relativeTo: .subheadline))
                .tracking(kind == .delete ? 0 : 1.96)   // 0.14em at 14pt
                .textCase(kind == .delete ? nil : .uppercase)
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity)
                .frame(minHeight: Cute.minTapTarget)
                .padding(.vertical, 2)
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
                Text("\(word), \(points) points" + (rung == .set ? "" : " (\(rung.rawValue))"))
                    .foregroundStyle(rung == .set ? Cute.accent : Cute.discovery)
            case .rejected(let message):
                Text(message).foregroundStyle(Cute.inkFaint)
            }
        }
        .font(CuteFont.body(15, relativeTo: .callout))
        .frame(maxWidth: .infinity, minHeight: 22)
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
