import SwiftUI
import UIKit

/// Haptics and motion, decided together.
///
/// They are one beat felt two ways, so what a tap feels like is settled in one
/// place rather than twice. The gradient matters more than the specific
/// generators: an ordinary find should feel like less than the source word, and
/// a rejection should feel like neither.
enum Feel {
    /// Picking up a tile. The lightest thing in the app, because it happens
    /// most: eight or more per word.
    static func tilePress() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// A word accepted. A real event, distinctly more than a tile.
    static func find() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// A word rejected. Deliberately softer than a find rather than harsher:
    /// a wrong guess in a word game is ordinary, not a failure worth punishing.
    /// `.warning` was tried and felt like being told off.
    static func reject() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.55)
    }

    /// The source word. The biggest thing the app does.
    ///
    /// A `.success` notification would be the same signal an ordinary find
    /// gets, so this is a heavier double beat instead: the hierarchy is the
    /// point, and it has to be felt as more without a screenshot to explain it.
    static func sourceWord() {
        let heavy = UIImpactFeedbackGenerator(style: .heavy)
        heavy.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.9)
        }
    }

    /// The cute theme's signature easing.
    ///
    /// The web says `cubic-bezier(0.34, 1.56, 0.64, 1)`, an overshoot curve.
    /// A SwiftUI spring is the direct equivalent and is a better tool for it,
    /// so this ports the intent (a small, quick overshoot) rather than trying
    /// to reproduce the exact curve.
    static let bounce = Animation.spring(response: 0.28, dampingFraction: 0.55)

    /// For state that should settle rather than bounce, like the tier bar.
    static let settle = Animation.spring(response: 0.45, dampingFraction: 0.85)
}

/// Suppresses animation when Reduce Motion is on, while leaving haptics alone.
///
/// They are separate accommodations: someone who finds motion nauseating still
/// wants to feel the tap. This is the iOS equivalent of the
/// `prefers-reduced-motion` handling the web already does for the confetti and
/// the ornament entrance.
struct MotionAware: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation
    let value: AnyHashable

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : animation, value: value)
    }
}

extension View {
    func motion(_ animation: Animation = Feel.bounce, value: some Hashable) -> some View {
        modifier(MotionAware(animation: animation, value: AnyHashable(value)))
    }
}

/// The tile press: it sinks toward its slab rather than dimming or scaling.
///
/// The web does `translateY(3px)` while the hard shadow collapses from
/// `0 5px 0` to `0 1px 0`, so the tile physically travels down onto the shadow
/// it was floating above. That is what sells the tiles as keys rather than as
/// buttons, and it was missing entirely.
///
/// Implemented as a `ButtonStyle` so the pressed state comes from the button
/// itself and no gesture handling has to be written.
struct TilePressStyle: ButtonStyle {
    let slabColour: Color
    let shape: RoundedRectangle
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed && !reduceMotion
        configuration.label
            // The slab shortens as the tile descends onto it, so the two move
            // together and the tile looks like it is travelling rather than
            // just shifting.
            .background(shape.fill(slabColour).offset(y: pressed ? 1 : 5))
            .offset(y: pressed ? 3 : 0)
            .animation(reduceMotion ? nil : Feel.bounce, value: configuration.isPressed)
    }
}

/// The same press for the pill controls, which have no slab to sink onto and so
/// take a small scale instead.
struct PillPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .animation(reduceMotion ? nil : Feel.bounce, value: configuration.isPressed)
    }
}
