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
        NavigationStack {
            Group {
                switch model.phase {
                case .loading:
                    ProgressView("Loading the dictionary")
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
            .navigationTitle("Peach of a Word")
            .navigationBarTitleDisplayMode(.inline)
        }
        // `.task` runs when the view appears and is cancelled automatically if
        // it disappears. It is the SwiftUI answer to useEffect with an empty
        // dependency array, minus the cleanup function.
        .task { await model.load() }
    }

    private var game: some View {
        VStack(spacing: 16) {
            rack
            scoreLine
            entry
            feedbackLine
            foundList
        }
        .padding()
    }

    private var rack: some View {
        HStack(spacing: 6) {
            ForEach(Array(model.rackLetters.enumerated()), id: \.offset) { _, letter in
                Text(letter.uppercased())
                    .font(.title2.monospaced().bold())
                    .frame(width: 34, height: 44)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
            }
        }
        // Without this the rack reads as eight separate letters to VoiceOver.
        // One line, and it is the only accessibility work in the app.
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rack letters: \(model.rackLetters.joined(separator: ", "))")
    }

    private var scoreLine: some View {
        HStack {
            if let standing = model.standing {
                Text("\(standing.score) of \(standing.reachable) points")
                Spacer()
                Text("Rank \(standing.index) of \(tiers.count - 1)")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.subheadline)
        .monospacedDigit()
    }

    private var entry: some View {
        HStack {
            TextField("Enter a word", text: $model.guess)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onSubmit { model.submit() }
            Button("Submit") { model.submit() }
                .disabled(model.guess.isEmpty)
        }
    }

    private var feedbackLine: some View {
        Group {
            switch model.feedback {
            case .none:
                Text("Find words using these letters.")
                    .foregroundStyle(.secondary)
            case .accepted(let word, let points, let rung):
                Text("\(word): \(points) points" + (rung == .set ? "" : " (\(rung.rawValue))"))
            case .rejected(let message):
                Text(message).foregroundStyle(.secondary)
            }
        }
        .font(.callout)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var foundList: some View {
        List {
            Section("Found (\(model.found.count))") {
                ForEach(model.found, id: \.self) { word in
                    Text(word)
                }
            }
            Section("Debug") {
                Text("Dictionary load: \(model.loadMilliseconds, format: .number) ms")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.plain)
    }
}

#Preview {
    ContentView()
}
