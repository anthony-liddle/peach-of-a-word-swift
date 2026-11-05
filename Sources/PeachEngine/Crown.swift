import Foundation

/// The crown the completion card's peach wears, as the web holds it in
/// `CROWN` and `CROWN_ON_PEACH` (`src/ui/crown.ts`).
///
/// **Drawn the costumes' way.** The outline is SVG path data in the crown's
/// own 100 by 100 box, absolute M, L, C and Z, read by `costumeCommands` and
/// stretched to the crown's frame on the card. The illustrations' import
/// writes the `d` line from the crown edited in Inkscape, where it is
/// drawn in the peach's box as it looks on the card, and undoes that stretch.
///
/// **Pinned in both apps.** `CrownTests.crownSHA256` pins `canonicalCrown()`,
/// and the web's `crown.test.ts` pins the same text, so a crown changed in one
/// app and not the other fails the other's suite.
public enum CompletionCrown {
    /// The outline, in the crown's own 100 by 100 box.
    public static let d = "M0 100 L8 18 L30 62 L50 0 L70 62 L92 18 L100 100 Z"

    /// The cute theme's peach, as `Cute.crown` draws it. `CrownTests` holds
    /// the two together.
    public static let fill = "#FF9E58"

    /// Where the card puts it, in points: the peach framed at 112 with 16 of
    /// padding above it, and the crown framed at 46 by 26, centred at the top
    /// and offset 2 further up. So the crown stands 18 above the peach's box
    /// and comes 8 down into it, over the leaf.
    ///
    /// Whole numbers, so they print alike in both apps' canonical text.
    public static let peach = 112
    public static let paddingTop = 16
    public static let width = 46
    public static let height = 26
    public static let offsetY = -2
}

/// The crown as one canonical text, exactly as the web's `canonicalCrown()`
/// writes it: the outline and its colour, then the card's placement, fields
/// joined by `|`. The outline is carried as its own text, never printed from
/// parsed numbers.
public func canonicalCrown() -> String {
    let c = CompletionCrown.self
    return [
        "crown|\(c.d)|\(c.fill)",
        "placement|\(c.peach)|\(c.paddingTop)|\(c.width)|\(c.height)|\(c.offsetY)",
    ].joined(separator: "\n")
}
