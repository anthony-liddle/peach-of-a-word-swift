#if TAP_RECORDER
import SwiftUI
import UIKit

/// Input instrumentation, for diagnosing lost taps.
///
/// **Not a DEBUG feature.** It is behind its own compilation condition, set only
/// on the command line for a one-off diagnostic build, so it cannot reach a
/// shipping build even by accident. It is built into a **Release** binary
/// deliberately: a debug build has different timing (this repo has measured a
/// 25x penalty on some paths), and measuring a slower app than the one someone
/// actually plays would answer the wrong question.
///
/// **Three layers, because the gap between them is the diagnosis.**
///
///   1. `touchDown` / `touchUp`, from a passive recognizer on the window. Every
///      touch the system delivered, whether or not SwiftUI did anything with it.
///   2. `buttonDown` / `buttonUp`, from `configuration.isPressed` inside
///      `TilePressStyle`. What the Button's own recognizer saw.
///   3. `commit`, from `GameModel.addTile`. What actually reached the model.
///
/// One layer alone cannot tell a dropped touch from a reordered one. Touches
/// without button-downs mean SwiftUI never delivered the press, which is the
/// failure mode suspected for overlapping taps. Button-downs without commits
/// mean the gesture was cancelled after visibly depressing the tile. Commits in
/// a different order from button-downs mean touch-up ordering, since a Button
/// fires on release rather than on press.
@MainActor
final class TapRecorder {
    static let shared = TapRecorder()

    enum Kind: String {
        case touchDown, touchUp, buttonDown, buttonUp, commit, marker
        /// A tile pressed, recorded on touch DOWN by the tile's own gesture.
        case press
        /// A tap on a tile already on the stick. The count of these is the
        /// disabled-tile theory, confirmed or eliminated.
        case refused
    }

    private struct Event {
        let kind: Kind
        let tile: Int
        let letter: String
        /// Monotonic, from `CACurrentMediaTime`. Wall clock would be wrong here:
        /// it can step backwards, and the quantity of interest is an interval.
        let at: CFTimeInterval
        /// How many fingers the system currently has down. This is what makes
        /// overlap visible rather than inferred from timings.
        let activeTouches: Int
    }

    private var events: [Event] = []
    private var activeTouches = 0
    private let started = CACurrentMediaTime()

    /// Recording is an array append and nothing else. No string formatting, no
    /// file access, no allocation beyond the array's own growth. The instrument
    /// sits on the exact path whose latency is under suspicion, so it has to
    /// cost close to nothing or it becomes the bug.
    func record(_ kind: Kind, tile: Int = -1, letter: String = "") {
        switch kind {
        case .touchDown: activeTouches += 1
        case .touchUp: activeTouches = max(0, activeTouches - 1)
        default: break
        }
        events.append(Event(kind: kind, tile: tile, letter: letter,
                            at: CACurrentMediaTime(), activeTouches: activeTouches))
    }

    /// Written as CSV to the app's Documents directory, pulled off the device
    /// with `xcrun devicectl device copy from`.
    ///
    /// Flushed on backgrounding rather than per event: writing a file from the
    /// touch handler would add exactly the kind of main-thread latency being
    /// measured. Handing the phone over backgrounds the app, so the natural end
    /// of a session is also the flush.
    func flush() {
        guard !events.isEmpty else { return }
        var out = "seq,kind,tile,letter,ms,active_touches\n"
        for (i, e) in events.enumerated() {
            let ms = (e.at - started) * 1000
            out += "\(i),\(e.kind.rawValue),\(e.tile),\(e.letter),"
                + String(format: "%.2f", ms) + ",\(e.activeTouches)\n"
        }
        guard let docs = try? FileManager.default.url(
            for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        ) else { return }
        try? out.write(to: docs.appendingPathComponent("tap-log.csv"),
                       atomically: true, encoding: .utf8)
    }
}

/// Every touch the system delivered, including ones SwiftUI never acts on.
///
/// A gesture recognizer rather than an overlay view, because an overlay that
/// receives touches also has to decide whether to pass them on, and a probe that
/// changes routing is not a probe. This one never recognises and never consumes:
/// `cancelsTouchesInView` and the delays are off, and it reports simultaneous
/// recognition with everything, so the Buttons underneath behave exactly as they
/// do without it.
final class PassiveTouchProbe: UIGestureRecognizer, UIGestureRecognizerDelegate {
    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
        delegate = self
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        for _ in touches { MainActor.assumeIsolated { TapRecorder.shared.record(.touchDown) } }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        for _ in touches { MainActor.assumeIsolated { TapRecorder.shared.record(.touchUp) } }
        state = .failed
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        for _ in touches { MainActor.assumeIsolated { TapRecorder.shared.record(.touchUp) } }
        state = .failed
    }

    func gestureRecognizer(
        _ g: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool { true }
}

/// Attaches the probe to the window once the view is in a hierarchy.
struct TouchProbeInstaller: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let v = UIView(frame: .zero)
        v.isUserInteractionEnabled = false
        DispatchQueue.main.async {
            guard let window = v.window else { return }
            window.addGestureRecognizer(PassiveTouchProbe(target: nil, action: nil))
        }
        return v
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
#endif
