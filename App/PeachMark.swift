import PeachEngine
import SwiftUI

/// The peach. The game's identifying mark, and the thing the name comes from.
///
/// **Drawn from the shared table, not transcribed.** Its parts are the growing
/// peach's Perfectly Peachy stage, the table both apps pin by hash
/// (`GrowthStageTests.tableSHA256` here, `growthStages.test.ts` on the web),
/// drawn as a costume is. It used to be eight Swift paths and circles copied by
/// hand from the web's favicon. One handle of the highlight was copied wrong,
/// and the face, laid out as circles rather than drawn, rounded to the
/// screen's pixels. Drawing the table's paths ends both, and leaves iOS no copy
/// of the peach of its own to drift. `PeachMarkTests` holds it there.
///
/// **A path, not an asset.** Vector keeps it crisp at both the 13pt chip mark
/// and the 96pt celebration card without shipping three raster sizes, and the
/// colours stay legible as data rather than baked into a PNG.
struct PeachMark: View {
    /// Drawn in a 100x100 space and scaled to whatever frame it is given.
    private static let designSize: CGFloat = 100

    /// The peach's parts: the leaf, the body, the highlight, then the face,
    /// whose parts are drawn only where the peach shows its face.
    private static let parts = GrowthStage.perfectlyPeachy.parts

    /// The face is charming at card size and turns to mud at mark size, so it
    /// is dropped below a threshold. The silhouette alone still reads as a
    /// peach, which is what a 13pt mark needs to do.
    var showsFace: Bool = true

    /// What the peach is wearing, if anything. Drawn over the peach in the same
    /// 100x100 box, so a costume never changes its footprint. See `Costume`.
    var costume: Costume? = nil

    var body: some View {
        GeometryReader { geo in
            let scale = min(geo.size.width, geo.size.height) / Self.designSize
            ZStack {
                // A costume that draws its own face hides the peach's.
                PartsLayer(parts: Self.parts,
                           showsFace: showsFace && !(costume?.replacesFace ?? false))
                if let costume { PartsLayer(parts: costume.parts, showsFace: showsFace) }
            }
            .frame(width: Self.designSize, height: Self.designSize)
            .scaleEffect(scale, anchor: .topLeading)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

#Preview("Peach at three sizes") {
    HStack(spacing: 20) {
        PeachMark(showsFace: false).frame(width: 14, height: 14)
        PeachMark().frame(width: 40, height: 40)
        PeachMark().frame(width: 96, height: 96)
    }
    .padding()
    .background(Cute.paper)
}

/// The title's peach at one of its stages: a drawing from the growing peach's
/// table, in the peach's 100x100 box, drawn the way a costume is. Perfectly
/// Peachy is the peach itself, which `PeachMark` draws; see `GrowthStage`.
struct GrowthMark: View {
    let stage: GrowthStage
    var showsFace: Bool = true

    var body: some View {
        GeometryReader { geo in
            let scale = min(geo.size.width, geo.size.height) / 100
            PartsLayer(parts: stage.parts, showsFace: showsFace)
                .frame(width: 100, height: 100)
                .scaleEffect(scale, anchor: .topLeading)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// A costume's parts, or a growing peach's, drawn in the peach's 100x100 space
/// from path data: the costumes' is the web's own. Parsed once per part; a part
/// that fails to parse is skipped, which `CostumeTests` and `GrowthStageTests`
/// make impossible for the shipped tables.
private struct PartsLayer: View {
    let parts: [CostumePart]
    let showsFace: Bool

    var body: some View {
        ZStack {
            ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                if showsFace || !part.faceOnly, let path = Self.path(part.d) {
                    ZStack {
                        if let fill = part.fill { path.fill(Color(css: fill)) }
                        if let stroke = part.stroke {
                            path.stroke(Color(css: stroke), style: StrokeStyle(
                                lineWidth: part.strokeWidth ?? 1, lineCap: .round, lineJoin: .round
                            ))
                        }
                    }
                    .opacity(part.opacity ?? 1)
                }
            }
        }
    }

    static func path(_ d: String) -> Path? {
        guard let commands = try? costumeCommands(d) else { return nil }
        return Path { p in
            for command in commands {
                switch command {
                case let .move(x, y): p.move(to: CGPoint(x: x, y: y))
                case let .line(x, y): p.addLine(to: CGPoint(x: x, y: y))
                case let .curve(c1, c2, to):
                    p.addCurve(to: CGPoint(x: to.0, y: to.1),
                               control1: CGPoint(x: c1.0, y: c1.1),
                               control2: CGPoint(x: c2.0, y: c2.1))
                case .close: p.closeSubpath()
                }
            }
        }
    }
}

private extension Color {
    /// `#RRGGBB`, as the costume table writes colours to match the web's.
    init(css: String) {
        self.init(hex: UInt32(css.dropFirst(), radix: 16) ?? 0)
    }
}

// MARK: - The costume on screen

private struct PeachCostumeKey: EnvironmentKey {
    static let defaultValue: Costume? = nil
}

extension EnvironmentValues {
    /// What the peach wears on the board on screen, set once from the model at
    /// the root. Read where the costume belongs: the source word's mark, the
    /// reveal and completion cards, and the confetti. `PeachMark` itself does
    /// not read it, so the splash and the decorations stay plain.
    var peachCostume: Costume? {
        get { self[PeachCostumeKey.self] }
        set { self[PeachCostumeKey.self] = newValue }
    }
}

extension View {
    /// Tells VoiceOver what the peach is wearing, on its day. The peach is
    /// decorative on every other day, and stays hidden then.
    @ViewBuilder
    func sayingWhatThePeachWears(_ costume: Costume?) -> some View {
        if let costume {
            accessibilityElement(children: .ignore)
                .accessibilityLabel("The peach is \(costume.spoken).")
        } else {
            self
        }
    }

    /// Tells VoiceOver how far the title's peach has grown, in the same words
    /// a costume is said in: "The peach is in blossom."
    func sayingTheStage(_ stage: GrowthStage) -> some View {
        accessibilityElement(children: .ignore)
            .accessibilityLabel("The peach is \(stage.spoken).")
    }
}
