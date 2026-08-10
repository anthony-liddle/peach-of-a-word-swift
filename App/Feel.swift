import SwiftUI
import UIKit
import CoreHaptics

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
    /// **A crescendo, not two taps.** The first version was a heavy impact
    /// followed by a medium one, and it read as exactly that: two discrete
    /// knocks rather than one event. This is a CoreHaptics pattern instead, a
    /// continuous rumble whose intensity curve climbs for about a third of a
    /// second and then resolves into a single sharp transient at the peak. One
    /// gesture that builds, which is what an escalation has to feel like when
    /// it is deliberately not being shown.
    ///
    /// The escalation is felt rather than seen on purpose. Confetti belongs to
    /// set completion, which is far rarer; the source word is usually cracked
    /// in the opening seconds, and spending the biggest visual gesture there
    /// would leave nothing for the actual peak.
    ///
    /// Falls back to the old two-beat pattern where CoreHaptics is unavailable,
    /// which is every simulator and any device without a Taptic Engine.
    ///
    /// `@MainActor` because the engine is: it is only ever called from the game
    /// model, which is main-actor isolated too.
    @MainActor
    static func sourceWord() {
        guard !HapticCrescendo.shared.play() else { return }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
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

/// The custom source-word pattern.
///
/// **On respecting the user's haptic setting.** Reduce Motion is not the
/// accommodation that governs this, and there is no public API to read the
/// Settings toggle for system haptics. There does not need to be: both
/// `UIFeedbackGenerator` and `CHHapticEngine` are silenced by the system when
/// it is off, so honouring it requires nothing here beyond not trying to work
/// around it.
@MainActor
final class HapticCrescendo {
    static let shared = HapticCrescendo()

    private var engine: CHHapticEngine?

    private init() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        engine = try? CHHapticEngine()
        // The engine is stopped by the system on interruption (a call, going to
        // background). Restarting on demand in `play` keeps this from being a
        // one-shot that quietly dies after the first phone call.
        engine?.resetHandler = { [weak self] in try? self?.engine?.start() }
        try? engine?.start()
    }

    /// Returns false if the pattern could not be played, so the caller can fall
    /// back to the simple generators.
    @discardableResult
    func play() -> Bool {
        guard let engine else { return false }
        do {
            try engine.start()
            try engine.makePlayer(with: try pattern()).start(atTime: CHHapticTimeImmediate)
            return true
        } catch {
            return false
        }
    }

    private func pattern() throws -> CHHapticPattern {
        let rise = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                .init(parameterID: .hapticIntensity, value: 0.25),
                .init(parameterID: .hapticSharpness, value: 0.35),
            ],
            relativeTime: 0,
            duration: 0.34
        )
        // The climb. Slow at first, steepening, so it builds rather than ramps
        // linearly.
        let curve = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: [
                .init(relativeTime: 0, value: 0.25),
                .init(relativeTime: 0.18, value: 0.45),
                .init(relativeTime: 0.30, value: 1.0),
            ],
            relativeTime: 0
        )
        // The resolution: one sharp hit at the top of the climb.
        let peak = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                .init(parameterID: .hapticIntensity, value: 1.0),
                .init(parameterID: .hapticSharpness, value: 0.7),
            ],
            relativeTime: 0.32
        )
        return try CHHapticPattern(events: [rise, peak], parameterCurves: [curve])
    }
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
