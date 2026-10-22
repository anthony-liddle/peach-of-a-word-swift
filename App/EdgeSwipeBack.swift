import SwiftUI
import UIKit

/// The swipe back from the left edge of the screen, on the board: it goes where
/// the back chevron goes, to the title screen.
///
/// **The system's own edge recognizer, not a drag of SwiftUI's.** The title is
/// an overlay, not a navigation push, so there is no navigation controller's
/// swipe to inherit. `UIScreenEdgePanGestureRecognizer` is the recognizer that
/// swipe is built on: it only begins on a touch that starts at the left edge
/// and moves right, so a drag anywhere else on the board is not its business.
///
/// **On the window, while the board is in front.** A recognizer on a view sees
/// only touches that land in that view, and the edge belongs to whatever is
/// drawn there, the meter or a rack tile. So it is added to the window while
/// this view, the board's background, is on screen, and removed with it: the
/// board is not drawn while the title covers it.
///
/// **Never over a sheet.** While anything is presented, the calendar, a card or
/// Settings, the window's touches belong to it, and the calendar pages its
/// months with a swipe. So it takes no touch while the root has anything
/// presented.
///
/// **It leaves the rack alone.** It takes only touches that start within 24pt
/// of the left edge, so no other touch on the board ever reaches it, and it
/// holds back none of the ones it takes: a tile commits on touch down, and
/// that is the rack's whole responsiveness. The rack's first column starts
/// 18pt in on an iPhone SE and 26pt on an iPhone 18 Pro Max, and the system's
/// edge ends before it: a swipe begun on that tile, 2pt in, placed its letter
/// and did not go back, and one begun at the edge beside it went back and
/// placed nothing (`BackToTheTitle`). A first version delayed the touches it
/// considered, and the same tests passed without the delay, so it went.
struct EdgeSwipeBack: UIViewRepresentable {
    let action: () -> Void

    func makeUIView(context: Context) -> Anchor {
        let anchor = Anchor()
        anchor.isUserInteractionEnabled = false
        anchor.coordinator = context.coordinator
        return anchor
    }

    func updateUIView(_ anchor: Anchor, context: Context) {
        context.coordinator.action = action
    }

    static func dismantleUIView(_ anchor: Anchor, coordinator: Coordinator) {
        coordinator.detach()
    }

    func makeCoordinator() -> Coordinator { Coordinator(action: action) }

    /// A view that knows its window, so the recognizer can follow it there.
    final class Anchor: UIView {
        weak var coordinator: Coordinator?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            coordinator?.attach(to: window)
        }
    }

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var action: () -> Void
        private let swipe = UIScreenEdgePanGestureRecognizer()
        private weak var window: UIWindow?

        init(action: @escaping () -> Void) {
            self.action = action
            super.init()
            swipe.edges = .left
            swipe.delegate = self
            swipe.addTarget(self, action: #selector(swiped(_:)))
        }

        func attach(to window: UIWindow?) {
            guard window !== self.window else { return }
            detach()
            window?.addGestureRecognizer(swipe)
            self.window = window
        }

        func detach() {
            window?.removeGestureRecognizer(swipe)
            window = nil
        }

        @objc private func swiped(_ swipe: UIScreenEdgePanGestureRecognizer) {
            // On release, as a navigation swipe completes: far enough across,
            // or flicked.
            guard swipe.state == .ended, let view = swipe.view else { return }
            let across = swipe.translation(in: view).x
            let speed = swipe.velocity(in: view).x
            if across > 60 || speed > 400 { action() }
        }

        /// Only a touch that starts at the edge, and only with nothing
        /// presented. Every other touch on the board never reaches the
        /// recognizer, so nothing it does can hold back a tile's touch-down.
        func gestureRecognizer(_ recognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard let window, window.rootViewController?.presentedViewController == nil else { return false }
            return touch.location(in: window).x <= Self.edge
        }

        /// How far in from the left a swipe back may start.
        static let edge: CGFloat = 24
    }
}
