import Accelerate
import Foundation
import PeachEngine
import SoundscapePlayer
import Testing

/// The game's sounds never clip in Bea's mix, on the phone: the cue file the
/// app ships, played by `CuePlayer`, the player the app plays it with, in its
/// manual mode, as fast as anyone plays.
///
/// The phone starts a cue asked for now at its next render cycle, which can
/// fall on any frame, so a roll, two taps in one cycle, can land anywhere on
/// a find. Each sound is rendered alone through the player, and every pile-up
/// is summed from those renders, as the player's mixer sums its voices, at
/// every frame. The true peak, BS.1770-4's four-times interpolation, is
/// linear, so the sum of the interpolated renders is the interpolation of
/// the pile-up, exactly. The scenes and the worst pile-up are also played
/// through the player in one render each.
///
/// Held to -1 dBTP, the ceiling the mix was set to on the web, in
/// peach-of-a-word#188, where the same scenes are played through the game.
@MainActor
@Suite("the game's sounds never clip in Bea's mix")
struct NoClippingTests {
    static let rate = 48_000.0
    static let ceiling = -1.0

    /// A player with the app's cue file loaded, its clock at 0.
    static func player() async throws -> CuePlayer {
        let player = CuePlayer(output: .manual(.init(sampleRate: rate, channels: 1)))
        let text = try String(
            contentsOf: dataDirectory.appendingPathComponent("peach.cues.json"), encoding: .utf8)
        try await player.load(parsing: text)
        return player
    }

    /// Cues, each at its frame, through one player in one render: a new
    /// player, or `on` one already loaded, stopped first, which starts its
    /// clock at 0 again. Each cue is asked for when the render reaches its
    /// frame, as the game asks for a cue when its tap comes, never ahead:
    /// cues queued ahead would take each other's voices.
    static func played(
        _ hits: [(cue: String, frame: Int)], seconds: Double, on loaded: CuePlayer? = nil
    ) async throws -> [Float] {
        let player: CuePlayer
        if let loaded { player = loaded } else { player = try await Self.player() }
        player.stop()
        var out: [Float] = []
        func render(to frame: Int) throws {
            while out.count < frame {
                out += try player.renderOffline(min(4096, frame - out.count))[0]
            }
        }
        for hit in hits.sorted(by: { $0.frame < $1.frame }) {
            try render(to: hit.frame)
            try player.play(hit.cue, at: Double(hit.frame) / rate)
        }
        try render(to: Int(seconds * rate))
        return out
    }

    /// One cue alone, as the player renders it.
    static func alone(_ cue: String, on player: CuePlayer? = nil) async throws -> [Float] {
        try await played([(cue, 0)], seconds: 2, on: player)
    }

    // MARK: True peak

    /// BS.1770-4's true-peak interpolator, Annex 2: four phases of 12 taps,
    /// each a point a quarter of a sample further on.
    nonisolated static let phases: [[Float]] = [
        [0.001708984375, 0.010986328125, -0.0196533203125, 0.033203125, -0.0594482421875, 0.1373291015625,
         0.97216796875, -0.102294921875, 0.047607421875, -0.026611328125, 0.014892578125, -0.00830078125],
        [-0.0291748046875, 0.029296875, -0.0517578125, 0.089111328125, -0.16650390625, 0.465087890625,
         0.77978515625, -0.2003173828125, 0.1015625, -0.0582275390625, 0.0330810546875, -0.0189208984375],
        [-0.0189208984375, 0.0330810546875, -0.0582275390625, 0.1015625, -0.2003173828125, 0.77978515625,
         0.465087890625, -0.16650390625, 0.089111328125, -0.0517578125, 0.029296875, -0.0291748046875],
        [-0.00830078125, 0.014892578125, -0.026611328125, 0.047607421875, -0.102294921875, 0.97216796875,
         0.1373291015625, -0.0594482421875, 0.033203125, -0.0196533203125, 0.010986328125, 0.001708984375],
    ]

    /// A render four times over, as planes: the samples themselves, then each
    /// phase's interpolated points, each plane one value a sample. Its largest
    /// magnitude is the true peak, and two add plane by plane as their renders
    /// do. Worked out with vDSP, which is as exact as a loop and fast in a
    /// Debug build.
    struct Oversampled {
        var planes: [[Float]]
        var count: Int { planes[0].count }

        init(_ x: [Float]) {
            // The render's trailing silence adds nothing to a peak
            let last = x.lastIndex { $0 != 0 } ?? 0
            let x = Array(x[...last])
            let taps = NoClippingTests.phases[0].count
            let length = x.count + taps
            planes = [x + [Float](repeating: 0, count: taps)]
            for phase in NoClippingTests.phases {
                var y = [Float](repeating: 0, count: length)
                y.withUnsafeMutableBufferPointer { out in
                    for (k, c) in phase.enumerated() {
                        var c = c
                        // y[n] += c * x[n - k], for every n the tap reaches
                        vDSP_vsma(x, 1, &c, out.baseAddress! + k, 1, out.baseAddress! + k, 1, vDSP_Length(x.count))
                    }
                }
                planes.append(y)
            }
        }

        /// Its loudest magnitude, with `other` added `offset` samples on.
        func loudest(plus other: Oversampled? = nil, at offset: Int = 0) -> Float {
            var most: Float = 0
            for (p, plane) in planes.enumerated() {
                var m: Float = 0
                vDSP_maxmgv(plane, 1, &m, vDSP_Length(plane.count))
                most = max(most, m)
                guard let other else { continue }
                let theirs = other.planes[p]
                // Where the two overlap; past this plane's end the other is alone
                let n = max(0, min(theirs.count, plane.count - offset))
                if n > 0 {
                    var sum = [Float](repeating: 0, count: n)
                    plane.withUnsafeBufferPointer { a in
                        vDSP_vadd(a.baseAddress! + offset, 1, theirs, 1, &sum, 1, vDSP_Length(n))
                    }
                    vDSP_maxmgv(sum, 1, &m, vDSP_Length(n))
                    most = max(most, m)
                }
                if n < theirs.count {
                    theirs.withUnsafeBufferPointer { b in
                        vDSP_maxmgv(b.baseAddress! + n, 1, &m, vDSP_Length(theirs.count - n))
                    }
                    most = max(most, m)
                }
            }
            return most
        }
    }

    static func dB(_ v: Float) -> Double { 20 * log10(Double(v)) }

    static func truePeak(_ x: [Float]) -> Double { dB(Oversampled(x).loudest()) }

    /// The loudest true peak of `a` with `b` added at each frame offset in
    /// `offsets`, from their oversampled renders.
    static func worst(_ a: Oversampled, plus b: Oversampled, at offsets: some Sequence<Int>) -> (dbtp: Double, at: Int) {
        var best: (Float, Int) = (0, 0)
        for offset in offsets {
            let most = a.loudest(plus: b, at: offset)
            if most > best.0 { best = (most, offset) }
        }
        return (dB(best.0), best.1)
    }

    // MARK: The scenes

    @Test("typing twenty letters a second, with two and three taps in one cycle")
    func typing() async throws {
        let every = Int(Self.rate / 20)
        var hits: [(cue: String, frame: Int)] = (0..<40).map { (cue: "tick", frame: $0 * every) }
        // A second tap in one cycle at the tenth letter, and two more at the twentieth
        hits += [(cue: "tick", frame: 10 * every), (cue: "tick", frame: 20 * every), (cue: "tick", frame: 20 * every)]
        let dbtp = Self.truePeak(try await Self.played(hits, seconds: 2.5))
        print("[no clipping] typing: \(dbtp) dBTP")
        #expect(dbtp < Self.ceiling, "typing reached \(dbtp) dBTP")
        // Three taps in one cycle add, to about -3.3: a lower peak means a tap
        // went missing, and this scene stopped being the one it says
        #expect(dbtp > -4.5, "typing only reached \(dbtp) dBTP: did the three taps sound together?")
    }

    @Test("ten Shuffles twenty a second, two taps landing on each")
    func shuffles() async throws {
        let every = Int(Self.rate / 20)
        let hits: [(cue: String, frame: Int)] = (0..<10).flatMap { i -> [(cue: String, frame: Int)] in
            [(cue: "shuffle", frame: i * every), (cue: "tick", frame: i * every), (cue: "tick", frame: i * every)]
        }
        let dbtp = Self.truePeak(try await Self.played(hits, seconds: 1.5))
        print("[no clipping] ten Shuffles: \(dbtp) dBTP")
        #expect(dbtp < Self.ceiling, "ten Shuffles reached \(dbtp) dBTP")
        // A Shuffle and two taps add to about -3.8
        #expect(dbtp > -5, "ten Shuffles only reached \(dbtp) dBTP: did the taps sound with them?")
    }

    /// Every find cue the app plays, with a roll landing on any frame of its
    /// first 27 ms, through its attack and its loudest moment.
    @Test("a find of any length and rung, with two taps landing on any frame of its first 27 ms")
    func aFindOnARoll() async throws {
        let player = try await Self.player()
        let roll = Oversampled(try await Self.alone("tick", on: player).map { $0 * 2 })
        var finds: [String] = Cue.foundLengths.flatMap { length in
            ["set", "uncommon", "rare", "mythic-cute"].map { "found-\(length)-\($0)" }
        }
        finds += ["source", "edition", "invalid"]
        var loudest = (dbtp: -Double.infinity, cue: "", at: 0)
        for cue in finds {
            let find = Oversampled(try await Self.alone(cue, on: player))
            let w = Self.worst(find, plus: roll, at: 0...Int(0.027 * Self.rate))
            if w.dbtp > loudest.dbtp { loudest = (w.dbtp, cue, w.at) }
        }
        print("[no clipping] a find on a roll: \(loudest.cue), \(loudest.at) frames in, \(loudest.dbtp) dBTP")
        #expect(loudest.dbtp < Self.ceiling, "\(loudest.cue) with a roll \(loudest.at) frames in reached \(loudest.dbtp) dBTP")
    }

    /// The pile-up the mix was set by: the full basket, a mythic find of 8
    /// half a second into it, 24064 frames, and a roll 623 frames after that.
    /// Played through the player in one render.
    @Test("the full basket, a mythic find under its card and a roll on it: the stack the mix was set by")
    func theStackTheMixWasSetBy() async throws {
        let dbtp = Self.truePeak(try await Self.played(
            [("edition", 0), ("found-8-mythic-cute", 24064), ("tick", 24687), ("tick", 24687)],
            seconds: 2))
        print("[no clipping] the basket, a mythic find and a roll 623 frames after it: \(dbtp) dBTP")
        #expect(dbtp < Self.ceiling, "reached \(dbtp) dBTP")
        // Within 0.3 dB of the ceiling: a louder mix would pass it, and if this
        // ever reads far under, it is no longer the stack that sets the mix
        #expect(dbtp > Self.ceiling - 0.3, "only \(dbtp) dBTP: is this still the loudest stack?")
    }

    /// The same stack, summed from the renders alone, over every frame the
    /// roll could land on in the find's first 27 ms: the one played above is
    /// the loudest of them, to within 0.05 dB.
    @Test("that stack is the loudest of every frame the roll could land on")
    func theStackAtEveryFrame() async throws {
        let player = try await Self.player()
        let basket = try await Self.alone("edition", on: player)
        let find = try await Self.alone("found-8-mythic-cute", on: player)
        var both = basket + [Float](repeating: 0, count: 24064 + find.count)
        for i in find.indices { both[24064 + i] += find[i] }
        let under = Oversampled(both)
        let roll = Oversampled(try await Self.alone("tick", on: player).map { $0 * 2 })
        let every = Self.worst(under, plus: roll, at: 24064...(24064 + Int(0.027 * Self.rate)))
        let named = Self.worst(under, plus: roll, at: [24687])
        print("[no clipping] every frame: a roll at \(every.at), \(every.dbtp) dBTP; at 24687, \(named.dbtp)")
        #expect(every.dbtp < Self.ceiling, "a roll at frame \(every.at) reached \(every.dbtp) dBTP")
        #expect(every.dbtp - named.dbtp < 0.05,
                "a roll at frame \(every.at) reached \(every.dbtp) dBTP, louder than at 24687, \(named.dbtp)")
    }
}
