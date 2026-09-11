#if DEBUG
import Foundation
import QuartzCore
import os

/// How long the archive takes to open, measured from inside the app.
///
/// **This exists because the only cost figure the archive has ever had came from
/// XCUITest.** That harness walks an accessibility tree the eager layout makes
/// forty times bigger, so its 16947ms was partly the harness measuring itself.
/// Nobody knew what a person opening the sheet waits for. These timings run on a
/// plain launch with no harness attached.
///
/// DEBUG only, and the whole file is inside the flag rather than each member, so
/// a Release build carries no timer, no display link and no log category.
///
/// Three instants, because which segment the cost sits in is itself the
/// question:
///
/// - `requested` is the moment something asks for the sheet, before SwiftUI has
///   built any of it.
/// - `appeared` is the sheet's body reaching the screen.
/// - `settled` is today's cell stopping. "Stopped" means its frame has not
///   changed for `quiet`, and the reported figure **excludes** that quiet
///   period: it ends at the last movement, not at the moment we noticed.
///
/// Today's own frame is the signal rather than the scroll view's geometry,
/// because "today's cell reaching its final position" is the question, and a
/// scroll that settles while the content is still growing is not the same event.
@MainActor
final class ArchiveTiming {
    static let shared = ArchiveTiming()

    private let log = Logger(subsystem: "com.anthonyliddle.peachofaword",
                             category: "timing")
    private let signposter = OSSignposter(subsystem: "com.anthonyliddle.peachofaword",
                                          category: "timing")

    /// How still today has to be before it counts as landed.
    private let quiet: CFTimeInterval = 0.4
    /// How long to wait for today to appear at all before giving up and saying so.
    private let patience: CFTimeInterval = 40

    private var requestedAt: CFTimeInterval?
    private var appearedAt: CFTimeInterval?
    private var lastMoveAt: CFTimeInterval?
    private var lastFrame: CGRect?
    private var moves = 0
    private var reported = false
    private var signpostID: OSSignpostID?
    private var interval: OSSignpostIntervalState?

    private var link: CADisplayLink?
    private var lastTick: CFTimeInterval?
    /// The longest gap between display callbacks inside the window.
    ///
    /// Deliberately not called a main thread stall. A missed frame and a blocked
    /// main thread coincide often but not always, and only one of them is what
    /// this can actually see.
    private var longestGap: CFTimeInterval = 0

    private func now() -> CFTimeInterval { CACurrentMediaTime() }

    /// Start watching for dropped frames before the thing that drops them.
    ///
    /// **Without this the stall measurement misses the stall.** The display link
    /// is started inside `requested`, and the sheet's construction blocks the
    /// main thread in the same runloop turn, so the link never gets a first
    /// callback to measure a gap from. It then wakes after the block with no
    /// previous timestamp and records nothing. Priming it seconds earlier means
    /// there is always a tick on both sides.
    func prime() {
        startLink()
        longestGap = 0
        lastTick = nil
    }

    func requested(label: String) {
        reset()
        requestedAt = now()
        let id = signposter.makeSignpostID()
        signpostID = id
        interval = signposter.beginInterval("archive open", id: id)
        log.notice("ARCHIVE-TIMING start \(label, privacy: .public)")
        // Only if nothing primed it, so a primed link keeps its running history.
        if link == nil { startLink(); longestGap = 0 }
        // Nothing may ever move, on a day where today is not drawn. Say that
        // rather than logging silence, which reads identically to a crash.
        let deadline = patience
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(deadline * 1_000_000_000))
            if !self.reported { self.finish(settled: false) }
        }
    }

    func appeared() {
        guard appearedAt == nil else { return }
        appearedAt = now()
    }

    func todayMoved(to frame: CGRect) {
        guard requestedAt != nil, !reported else { return }
        if let previous = lastFrame, previous == frame { return }
        lastFrame = frame
        lastMoveAt = now()
        moves += 1
        let mark = moves
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(self.quiet * 1_000_000_000))
            // Only the last movement gets to finish the measurement.
            if mark == self.moves, !self.reported { self.finish(settled: true) }
        }
    }

    private func finish(settled: Bool) {
        guard !reported, let requestedAt else { return }
        reported = true
        stopLink()
        if let interval, let signpostID {
            signposter.endInterval("archive open", interval)
            _ = signpostID
        }
        let appear = (appearedAt ?? requestedAt) - requestedAt
        let last = lastMoveAt ?? appearedAt ?? requestedAt
        let toSettle = last - (appearedAt ?? requestedAt)
        let total = last - requestedAt
        log.notice("""
            ARCHIVE-TIMING result settled=\(settled ? "yes" : "no", privacy: .public) \
            requestToAppear=\(Int(appear * 1000), privacy: .public)ms \
            appearToSettle=\(Int(toSettle * 1000), privacy: .public)ms \
            requestToSettle=\(Int(total * 1000), privacy: .public)ms \
            moves=\(self.moves, privacy: .public) \
            longestFrameGap=\(Int(self.longestGap * 1000), privacy: .public)ms
            """)
    }

    private func reset() {
        requestedAt = nil; appearedAt = nil; lastMoveAt = nil; lastFrame = nil
        moves = 0; reported = false
    }

    private func startLink() {
        stopLink()
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    private func stopLink() {
        link?.invalidate()
        link = nil
    }

    @objc private func tick(_ link: CADisplayLink) {
        let t = link.timestamp
        if let lastTick, t - lastTick > longestGap { longestGap = t - lastTick }
        lastTick = t
    }
}
#endif
