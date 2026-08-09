import SwiftUI
import PeachEngine

struct ContentView: View {
    /// `@State` owns the model for the lifetime of the view.
    ///
    /// The name is misleading coming from React: this is not `useState`. It is
    /// closer to a ref that SwiftUI keeps alive across re-renders, and with
    /// `@Observable` it is also how the view subscribes to changes. A `let`
    /// here would work for reading but the view would never update.
    @State private var model = GameModel()

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
        .task { await model.load() }
    }

    private var game: some View {
        VStack(spacing: 18) {
            masthead
            ComposingStick(word: model.composedWord)
            TypeCase(model: model)
            Controls(model: model)
            feedbackLine
            foundList
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
    }

    private var masthead: some View {
        VStack(spacing: 2) {
            Text("Peach of a Word")
                .font(.system(.title, design: .rounded, weight: .semibold))
                .foregroundStyle(Cute.ink)
            if let standing = model.standing {
                Text("\(standing.score) of \(standing.reachable) points")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Cute.inkFaint)
                    .monospacedDigit()
            }
        }
    }

    private var feedbackLine: some View {
        Group {
            switch model.feedback {
            case .none:
                Text("Pick letters to make a word")
                    .foregroundStyle(Cute.inkFaint)
            case .accepted(let word, let points, let rung):
                Text("\(word), \(points) points" + (rung == .set ? "" : " (\(rung.rawValue))"))
                    .foregroundStyle(rung == .set ? Cute.accent : Cute.discovery)
            case .rejected(let message):
                Text(message).foregroundStyle(Cute.inkFaint)
            }
        }
        .font(.system(.callout, design: .rounded))
        .frame(maxWidth: .infinity, alignment: .center)
        // The visible line is decoration; the accessible announcement is the
        // live region below, so this is not read twice.
        .accessibilityHidden(true)
    }

    private var foundList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 6) {
                ForEach(model.found, id: \.self) { word in
                    Text(word)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(Cute.inkSoft)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityLabel("Found words, \(model.found.count)")
    }
}

/// The stick: the letters placed so far, in order.
///
/// Fixed height so the rack never shifts when the first letter lands, which is
/// the reason the web version pins it too.
private struct ComposingStick: View {
    let word: String
    @ScaledMetric(relativeTo: .title) private var height: CGFloat = 64

    var body: some View {
        RoundedRectangle(cornerRadius: Cute.cardRadius)
            .fill(Cute.paperDeep)
            .overlay(
                RoundedRectangle(cornerRadius: Cute.cardRadius)
                    .stroke(Cute.tileEdge, lineWidth: 1)
            )
            .frame(height: height)
            .cuteDropShadow(Cute.rule, y: 6)
            .overlay {
                if word.isEmpty {
                    Text("Pick letters to make a word")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Cute.inkFaint)
                } else {
                    HStack(spacing: 5) {
                        ForEach(Array(word.enumerated()), id: \.offset) { _, letter in
                            Text(String(letter))
                                .font(.system(.title, design: .rounded, weight: .semibold))
                                .foregroundStyle(Cute.ink)
                        }
                    }
                    .padding(.horizontal, 10)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(word.isEmpty
                ? "No letters picked yet"
                : "Picked so far: \(word.map(String.init).joined(separator: " "))")
    }
}

/// The rack. Each tile is a real button; a placed tile is disabled.
private struct TypeCase: View {
    let model: GameModel

    // Adaptive columns so the grid reflows when Dynamic Type grows the tiles,
    // rather than hardcoding four across. This is the CSS grid auto-fit
    // equivalent and it is the one place the layout had to think.
    @ScaledMetric(relativeTo: .largeTitle) private var tileMinWidth: CGFloat = 68

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: tileMinWidth), spacing: 10)],
            spacing: 10
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

    @ScaledMetric(relativeTo: .largeTitle) private var minHeight: CGFloat = 82

    var body: some View {
        Button(action: action) {
            Text(letter)
                .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                .foregroundStyle(placed ? Cute.paperEdge : Cute.ink)
                .frame(maxWidth: .infinity)
                .frame(minHeight: max(minHeight, Cute.minTapTarget))
                .background(
                    RoundedRectangle(cornerRadius: Cute.tileRadius)
                        .fill(placed ? Cute.paper : Cute.tileFace)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Cute.tileRadius)
                        .stroke(Cute.tileEdge, lineWidth: 1)
                )
                // A placed tile loses its shadow, so it visibly sits down into
                // the rack rather than standing proud of it.
                .cuteDropShadow(placed ? .clear : Cute.surfaceShadow)
        }
        .buttonStyle(.plain)
        .disabled(placed)
        .accessibilityLabel("Letter \(letter)\(placed ? ", already picked" : "")")
    }
}

/// Two clusters, ordered by how often each action is used.
///
/// The utility pair (Shuffle, Clear) is quiet and set apart; the primary pair
/// (Delete, then Submit) is prominent and sits in easy thumb reach. **Delete
/// comes before Submit.** That ordering is not aesthetic: it came from Bea
/// telling Antoine that delete is one of the most-used buttons and was in the
/// wrong place. Do not reorder it.
private struct Controls: View {
    let model: GameModel

    private var empty: Bool { model.composing.isEmpty }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                PillButton("Shuffle", kind: .utility) { model.shuffleRack() }
                PillButton("Clear", kind: .utility, disabled: empty) { model.clear() }
            }
            HStack(spacing: 10) {
                PillButton("⌫", kind: .delete, disabled: empty,
                           label: "Delete last letter") { model.removeLast() }
                    .frame(maxWidth: 110)
                PillButton("Pick word", kind: .primary,
                           disabled: model.composedWord.count < minWordLength) {
                    model.submit()
                }
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

    private var background: Color {
        switch kind {
        case .utility: Cute.paperDeep
        case .delete: Cute.paperDeep
        case .primary: Cute.accent
        }
    }

    private var foreground: Color {
        switch kind {
        case .utility: Cute.inkSoft
        case .delete: Cute.accentDeep
        case .primary: .white
        }
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(kind == .utility ? .subheadline : .body,
                              design: .rounded, weight: .semibold))
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity)
                .frame(minHeight: Cute.minTapTarget)
                .background(Capsule().fill(background))
                .overlay(Capsule().stroke(Cute.tileEdge, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.45 : 1)
        .accessibilityLabel(label ?? title)
    }
}

#Preview("Cute rack") {
    ContentView()
}
