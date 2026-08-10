import SwiftUI

/// The peach. The game's identifying mark, and the thing the name comes from.
///
/// **Ported from the web's artwork rather than redrawn.** The paths are
/// transcribed from `public/favicon-cute.svg`, which is generated from
/// `PEACH_MARK_PATHS` in `scripts/lib/icons.ts` and is the same shape used for
/// the favicon, the OG card and the home-screen icons. A second peach that
/// looked slightly different would be worse than the orange circle this
/// replaces.
///
/// **Ported as a path, not exported as an asset.** It is eight primitives in a
/// 100x100 box, so the transcription was cheap, and vector means it stays crisp
/// at both the 13pt chip mark and the 96pt celebration card without shipping
/// three raster sizes or adding an asset catalogue to a generated project. The
/// colours also stay legible as code rather than baked into a PNG.
struct PeachMark: View {
    /// Drawn in a 100x100 space and scaled to whatever frame it is given.
    private static let designSize: CGFloat = 100

    /// The face is charming at card size and turns to mud at mark size, so it
    /// is dropped below a threshold. The silhouette alone still reads as a
    /// peach, which is what a 13pt mark needs to do.
    var showsFace: Bool = true

    var body: some View {
        GeometryReader { geo in
            let scale = min(geo.size.width, geo.size.height) / Self.designSize
            ZStack {
                leaf.fill(Color(hex: 0x8FD3B6))
                body_.fill(Color(hex: 0xFFC27A))
                highlight.fill(Color(hex: 0xFFD79B).opacity(0.7))
                if showsFace { face }
            }
            .frame(width: Self.designSize, height: Self.designSize)
            .scaleEffect(scale, anchor: .topLeading)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    // MARK: The transcribed paths
    //
    // SVG path data is relative-cubic heavy and SwiftUI has no `S` (smooth)
    // command, so each smooth segment's first control point is written out as
    // the reflection of the previous one, which is what `S` means.

    /// `M50 12c4-8 14-9 18-4-2 6-9 9-14 8z`
    private var leaf: Path {
        Path { p in
            p.move(to: CGPoint(x: 50, y: 12))
            p.addCurve(to: CGPoint(x: 68, y: 8),
                       control1: CGPoint(x: 54, y: 4), control2: CGPoint(x: 64, y: 3))
            p.addCurve(to: CGPoint(x: 54, y: 16),
                       control1: CGPoint(x: 66, y: 14), control2: CGPoint(x: 59, y: 17))
            p.closeSubpath()
        }
    }

    /// `M50 16c20 0 34 16 34 36 0 22-16 38-34 38S16 74 16 52c0-20 14-36 34-36z`
    private var body_: Path {
        Path { p in
            p.move(to: CGPoint(x: 50, y: 16))
            p.addCurve(to: CGPoint(x: 84, y: 52),
                       control1: CGPoint(x: 70, y: 16), control2: CGPoint(x: 84, y: 32))
            p.addCurve(to: CGPoint(x: 50, y: 90),
                       control1: CGPoint(x: 84, y: 74), control2: CGPoint(x: 68, y: 90))
            // The S command: first control is (68,90) reflected about (50,90).
            p.addCurve(to: CGPoint(x: 16, y: 52),
                       control1: CGPoint(x: 32, y: 90), control2: CGPoint(x: 16, y: 74))
            p.addCurve(to: CGPoint(x: 50, y: 16),
                       control1: CGPoint(x: 16, y: 32), control2: CGPoint(x: 30, y: 16))
            p.closeSubpath()
        }
    }

    /// `M50 16c-9 0-17 4-23 11 7 4 15 5 23 5s16-1 23-5c-6-7-14-11-23-11z`
    private var highlight: Path {
        Path { p in
            p.move(to: CGPoint(x: 50, y: 16))
            p.addCurve(to: CGPoint(x: 27, y: 27),
                       control1: CGPoint(x: 41, y: 16), control2: CGPoint(x: 33, y: 20))
            p.addCurve(to: CGPoint(x: 50, y: 32),
                       control1: CGPoint(x: 34, y: 31), control2: CGPoint(x: 42, y: 32))
            // The s command: first control is (42,32) reflected about (50,32).
            p.addCurve(to: CGPoint(x: 73, y: 27),
                       control1: CGPoint(x: 58, y: 32), control2: CGPoint(x: 73, y: 31))
            p.addCurve(to: CGPoint(x: 50, y: 16),
                       control1: CGPoint(x: 67, y: 20), control2: CGPoint(x: 59, y: 16))
            p.closeSubpath()
        }
    }

    private var face: some View {
        ZStack {
            Circle().fill(Color(hex: 0x7A4A33))
                .frame(width: 6.8, height: 6.8).position(x: 40, y: 58)
            Circle().fill(Color(hex: 0x7A4A33))
                .frame(width: 6.8, height: 6.8).position(x: 60, y: 58)
            Circle().fill(Color(hex: 0xFF9DAE).opacity(0.7))
                .frame(width: 9, height: 9).position(x: 34, y: 66)
            Circle().fill(Color(hex: 0xFF9DAE).opacity(0.7))
                .frame(width: 9, height: 9).position(x: 66, y: 66)
            // `M45 67c3 3 7 3 10 0`
            Path { p in
                p.move(to: CGPoint(x: 45, y: 67))
                p.addCurve(to: CGPoint(x: 55, y: 67),
                           control1: CGPoint(x: 48, y: 70), control2: CGPoint(x: 52, y: 70))
            }
            .stroke(Color(hex: 0x7A4A33), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
        }
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
