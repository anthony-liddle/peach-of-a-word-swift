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
/// Two instants:
///
/// - `requested` is the moment something asks for the sheet, before SwiftUI has
///   built any of it.
/// - `appeared` is the sheet's body reaching the screen.
///
/// **There used to be a third, and it has been removed rather than repaired.**
/// `settled` claimed to be today's cell coming to rest, reported from a hook
/// watching that cell's frame. On an eager layout the hook sees the first
/// position and nothing after it: a probe that delayed the opening scroll by
/// 2.5s moved today's ring 40.3pt after it appeared and the run still logged
/// `moves=1` and `appearToSettle=0ms`. A probe that reads the same whether it
/// is working or not is worse than no probe, because its zero reads as an
/// answer. `requestToAppear` was never affected and is what is left.
///
/// Whether today moves after the first paint is now answered by recording the
/// open and stepping through the frames, which needs no instrument in the app.
/// See `2026-09-11 The Month Page Layout.md`.
@MainActor
final class ArchiveTiming {
    static let shared = ArchiveTiming()

    private let log = Logger(subsystem: "com.anthonyliddle.peachofaword",
                             category: "timing")
    private let signposter = OSSignposter(subsystem: "com.anthonyliddle.peachofaword",
                                          category: "timing")

    /// How long to keep watching for dropped frames after the sheet appears.
    ///
    /// The appearance is the measurement, but the frames dropped drawing it
    /// land just after it, so the report waits this long before closing.
    private let watch: CFTimeInterval = 0.4
    /// How long to wait for the sheet to appear at all before saying it did not.
    private let patience: CFTimeInterval = 40

    private var requestedAt: CFTimeInterval?
    private var appearedAt: CFTimeInterval?
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
        // A primed link keeps its last tick, so there is something to measure
        // the first gap from, but the tally starts here.
        //
        // **Both halves matter and each was wrong on its own.** Starting the
        // link here left it with no previous tick when the sheet blocked the
        // main thread in the same turn, and it recorded nothing in four runs out
        // of five. Priming it and keeping the tally recorded the simulator not
        // drawing while the app sat idle, which showed up as a 150ms gap inside
        // a 120ms window: a number larger than the thing it was inside.
        if link == nil { startLink() }
        longestGap = 0
        // Seed the previous tick with this instant rather than the last real
        // callback. The simulator stops serving the display link while the app
        // sits idle, so the last callback can be long past, and the first tick
        // after the request would otherwise report that idle stretch as a gap.
        // That put a 150ms floor under every reading, larger than the whole
        // window it was supposed to sit inside.
        lastTick = now()
        // The sheet may never appear, on a day where there is nothing to show.
        // Say that rather than logging silence, which reads like a crash.
        let deadline = patience
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(deadline * 1_000_000_000))
            if !self.reported { self.finish(appeared: false) }
        }
    }

    func appeared() {
        guard appearedAt == nil else { return }
        appearedAt = now()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(self.watch * 1_000_000_000))
            if !self.reported { self.finish(appeared: true) }
        }
    }

    private func finish(appeared: Bool) {
        guard !reported, let requestedAt else { return }
        reported = true
        stopLink()
        if let interval, let signpostID {
            signposter.endInterval("archive open", interval)
            _ = signpostID
        }
        let appear = (appearedAt ?? requestedAt) - requestedAt
        log.notice("""
            ARCHIVE-TIMING result appeared=\(appeared ? "yes" : "no", privacy: .public) \
            requestToAppear=\(Int(appear * 1000), privacy: .public)ms \
            longestFrameGap=\(Int(self.longestGap * 1000), privacy: .public)ms
            """)
    }

    private func reset() {
        requestedAt = nil; appearedAt = nil; reported = false
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
