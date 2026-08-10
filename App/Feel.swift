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
    /// **The hierarchy, which is the whole point.** Four levels, each
    /// unmistakably larger than the one below:
    ///
    ///   tile tap  <  ordinary find  <  source word  <  completion
    ///
    /// The bottom two are generators, which is all they need. The top two are
    /// CoreHaptics patterns, because a discrete generator call cannot build and
    /// an escalation that does not build reads as just another tap.

    // Every function below is @MainActor, including the three that did not
    // need to be to compile here.
    //
    // UIKit's feedback generators are @MainActor in the iOS 18 SDK and
    // nonisolated from the iOS 26 SDK. Calling them from a nonisolated static
    // func therefore builds on Xcode 26 and fails on Xcode 16.4, which is how
    // this file quietly acquired a newest-toolchain requirement that the rest
    // of the app does not have. The deployment floor was moved down to iOS 17
    // deliberately; a source file that only compiles against the newest SDK
    // walks part of that back by accident.
    //
    // The annotation is also just true. These touch the haptics hardware from
    // UIKit and every caller is GameModel, which is already @MainActor, so
    // nothing changes at runtime and no call site needed touching.

    /// Picking up a tile. The lightest thing in the app, because it happens
    /// most: eight or more per word.
    @MainActor
    static func tilePress() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.58)
    }

    /// A word accepted. Clearly more than a tile, clearly less than the peach.
    @MainActor
    static func find() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// A word rejected. Deliberately softer than a find rather than harsher:
    /// a wrong guess in a word game is ordinary, not a failure worth punishing.
    /// `.warning` was tried and felt like being told off.
    @MainActor
    static func reject() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.5)
    }

    /// The source word. A crescendo that resolves into one sharp hit.
    @MainActor
    static func sourceWord() {
        guard !Haptics.shared.play(.sourceWord) else { return }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    /// Completion: every common word the rack can spell. The rarest thing in
    /// the game and now the largest thing it does.
    @MainActor
    static func completion() {
        guard !Haptics.shared.play(.completion) else { return }
        // The fallback has to be audibly bigger too, so it is three beats
        // rather than one.
        let heavy = UIImpactFeedbackGenerator(style: .heavy)
        heavy.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) { heavy.impactOccurred() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
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

/// The two custom patterns.
///
/// **On respecting the user's haptic setting.** Reduce Motion is not the
/// accommodation that governs this, and there is no public API to read the
/// Settings toggle for system haptics. There does not need to be: both
/// `UIFeedbackGenerator` and `CHHapticEngine` are silenced by the system when
/// it is off, so honouring it requires nothing here beyond not working around
/// it.
@MainActor
final class Haptics {
    static let shared = Haptics()

    enum Pattern { case sourceWord, completion }

    private var engine: CHHapticEngine?

    private init() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        engine = try? CHHapticEngine()
        // The system stops the engine on interruption (a call, backgrounding),
        // so without this it silently dies after the first phone call.
        engine?.resetHandler = { [weak self] in try? self?.engine?.start() }
        try? engine?.start()
    }

    /// False if the pattern could not play, so the caller falls back.
    @discardableResult
    func play(_ pattern: Pattern) -> Bool {
        guard let engine else { return false }
        do {
            try engine.start()
            let built = switch pattern {
            case .sourceWord: try sourceWordPattern()
            case .completion: try completionPattern()
            }
            try engine.makePlayer(with: built).start(atTime: CHHapticTimeImmediate)
            return true
        } catch {
            return false
        }
    }

    /// A rumble that climbs for half a second and lands on one sharp hit.
    ///
    /// **The bug worth recording**: the first version set the continuous event's
    /// base intensity to 0.25 and let the curve climb to 1.0. But
    /// `hapticIntensityControl` is a MULTIPLIER on the base, not an absolute,
    /// so the effective peak was 0.25 and the whole crescendo topped out barely
    /// above a letter tap. The base is now 1.0 and the curve does the shaping.
    private func sourceWordPattern() throws -> CHHapticPattern {
        let rise = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                .init(parameterID: .hapticIntensity, value: 1.0),
                .init(parameterID: .hapticSharpness, value: 0.3),
            ],
            relativeTime: 0,
            duration: 0.5
        )
        let climb = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: [
                .init(relativeTime: 0, value: 0.08),
                .init(relativeTime: 0.28, value: 0.35),
                .init(relativeTime: 0.46, value: 1.0),
            ],
            relativeTime: 0
        )
        let peak = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                .init(parameterID: .hapticIntensity, value: 1.0),
                .init(parameterID: .hapticSharpness, value: 0.85),
            ],
            relativeTime: 0.48
        )
        return try CHHapticPattern(events: [rise, peak], parameterCurves: [climb])
    }

    /// Twice as long, with a roll of hits at the top instead of one.
    ///
    /// It has to be unmistakably above the source word, and the source word is
    /// already a full-intensity crescendo, so the difference is made in
    /// duration and in event count rather than in raw strength: a longer build,
    /// then three accelerating hits and a final one that lands hardest.
    private func completionPattern() throws -> CHHapticPattern {
        let rise = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                .init(parameterID: .hapticIntensity, value: 1.0),
                .init(parameterID: .hapticSharpness, value: 0.25),
            ],
            relativeTime: 0,
            duration: 0.78
        )
        let climb = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: [
                .init(relativeTime: 0, value: 0.05),
                .init(relativeTime: 0.35, value: 0.25),
                .init(relativeTime: 0.62, value: 0.7),
                .init(relativeTime: 0.76, value: 1.0),
            ],
            relativeTime: 0
        )
        // Accelerating, so it reads as arrival rather than as a rhythm.
        let hits = [0.78, 0.90, 0.99].enumerated().map { index, time in
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    .init(parameterID: .hapticIntensity, value: Float(0.7 + 0.1 * Double(index))),
                    .init(parameterID: .hapticSharpness, value: 0.6),
                ],
                relativeTime: time
            )
        }
        let final = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                .init(parameterID: .hapticIntensity, value: 1.0),
                .init(parameterID: .hapticSharpness, value: 0.95),
            ],
            relativeTime: 1.08
        )
        return try CHHapticPattern(events: [rise] + hits + [final], parameterCurves: [climb])
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
