//
//  XeidLaunch.swift
//  Eristic
//
//  Created by Fady A Eid on 9/8/26.
//

import SwiftUI

// MARK: - Brand launch primitives
// Ports of the two design-system components the launch screen is built from:
// the constellation NeuralBackground and the LogoIgnition X. Both are drawn
// from the same clock the screen runs on, so the sequence is one timeline
// rather than several animations that have to be kept in step.
//
// Source: XEID Launch Screen (standalone), components/brand/NeuralBackground.jsx
// and components/brand/LogoIgnition.jsx. Numbers here are the approved ones —
// changing any of them changes the brand, not just the look.

// MARK: - Easing
enum XeidEase {
    static func clamp(_ v: Double, _ a: Double = 0, _ b: Double = 1) -> Double {
        v < a ? a : (v > b ? b : v)
    }
    // Eased at both ends, so a fade never snaps on
    static func smooth(_ x: Double) -> Double { x * x * (3 - 2 * x) }
    static func outQuint(_ t: Double) -> Double { 1 - pow(1 - t, 5) }
    static func outQuart(_ t: Double) -> Double { 1 - pow(1 - t, 4) }
}

// MARK: - The neural palette
// The glowing on-black versions, distinct from the saturated brand gradient.
// Never use these on light surfaces.
private enum Neural {
    static let blue = (r: 98.0, g: 172.0, b: 255.0)
    static let magenta = (r: 255.0, g: 92.0, b: 190.0)

    static func color(_ c: (r: Double, g: Double, b: Double), _ alpha: Double) -> Color {
        Color(.sRGB, red: c.r / 255, green: c.g / 255, blue: c.b / 255, opacity: alpha)
    }
}

// MARK: - Deterministic RNG
// The design system's own mulberry32 seeded 77. The approved composition is
// this exact sequence of draws, so it is ported bit for bit: unsigned 32-bit
// wrapping throughout, which is what JavaScript's `>>> 0` and `Math.imul` do.
private struct Srnd {
    private var seed: UInt32

    init(_ s: UInt32 = 77) { seed = s }

    mutating func next() -> Double {
        seed = seed &+ 0x6D2B_79F5
        var q = (seed ^ (seed >> 15)) &* (1 | seed)
        q = (q &+ ((q ^ (q >> 7)) &* (61 | q))) ^ q
        return Double(q ^ (q >> 14)) / 4_294_967_296
    }
}

// MARK: - Field model
// A cluster: a hub that breathes around a fixed anchor, a few members orbiting
// it, and now and then a twig hanging off a member.
private struct NeuralMember {
    var ox: Double, oy: Double, r: Double
    var bw1: Double, bw2: Double, bp1: Double, bp2: Double
    var amp: Double, tw: Double, tp: Double
    var twig: (ox: Double, oy: Double, r: Double)?
}

private struct NeuralAnchor {
    var hx: Double, hy: Double
    var dw: Double, dp: Double, damp: Double, r: Double
    var col: (r: Double, g: Double, b: Double)
    var members: [NeuralMember]
    var tw: Double, tp: Double
}

private struct NeuralAxon {
    var a: Int, b: Int, off: Double
}

private struct NeuralFieldModel {
    var anchors: [NeuralAnchor] = []
    var axons: [NeuralAxon] = []
    var k: Double = 1

    // One cluster grammar, laid out edge to edge. `clearRects` are fractions
    // of the frame that no neuron may enter — the lockup's keep-out.
    init(size: CGSize, clearRects: [CGRect]) {
        let W = Double(size.width), H = Double(size.height)
        guard W > 1, H > 1 else { return }

        var rnd = Srnd(77)

        // Match the website hero proportionally: neurons take the same
        // fraction of the frame, scaled by the limiting dimension.
        k = max(0.1, min(1.6, min(W / 1440, H / 810)))

        let ko = clearRects.map {
            (x0: $0.minX * W, y0: $0.minY * H, x1: $0.maxX * W, y1: $0.maxY * H)
        }
        func inRect(_ x: Double, _ y: Double,
                    _ r: (x0: Double, y0: Double, x1: Double, y1: Double),
                    _ pad: Double) -> Bool {
            x >= r.x0 - pad && x <= r.x1 + pad && y >= r.y0 - pad && y <= r.y1 + pad
        }
        func segHitsRect(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double,
                         _ r: (x0: Double, y0: Double, x1: Double, y1: Double),
                         _ pad: Double) -> Bool {
            for i in 0...10 {
                let u = Double(i) / 10
                if inRect(x1 + (x2 - x1) * u, y1 + (y2 - y1) * u, r, pad) { return true }
            }
            return false
        }

        // The approved default composition, filling the frame edge to edge
        let specs: [(bx: Double, fy: Double, col: (r: Double, g: Double, b: Double), n: Int, big: Bool)] = [
            (0.10, 0.22, Neural.blue,    3, true),
            (0.28, 0.66, Neural.magenta, 3, true),
            (0.42, 0.14, Neural.blue,    2, false),
            (0.18, 0.88, Neural.magenta, 2, false),
            (0.62, 0.28, Neural.magenta, 3, true),
            (0.78, 0.72, Neural.blue,    3, true),
            (0.92, 0.18, Neural.magenta, 2, false),
        ]

        let bandX0 = 28.0, bandX1 = W - 28
        let bw = bandX1 - bandX0

        // One scale sizes the dots, the member distances, the drift and the
        // twigs alike — a cluster is a reduction of a hero cluster, never a
        // blow-up with tiny dots.
        let reach = (88 + 35 + 30) * k
        let edge = reach + 12

        var idxMap = [Int](repeating: -1, count: specs.count)

        for (si, spec) in specs.enumerated() {
            if bw < 2 * reach + 10 || (!spec.big && bw < 2.6 * reach) { continue }

            let ax = min(bandX1 - edge, max(bandX0 + edge, bandX0 + spec.bx * bw))
            var ay = min(H - edge, max(edge, spec.fy * H))

            // A cluster never touches a text rect — nudge to clear, else drop it
            if !ko.isEmpty {
                let damp0 = 16 * k
                func collides(_ yy: Double) -> Bool {
                    ko.contains { inRect(ax, yy, $0, reach + damp0) }
                }
                if collides(ay) {
                    var placed = false
                    for df in [-0.18, 0.18, -0.34, 0.34, -0.5, 0.5] {
                        let cy = min(H - edge, max(edge, (spec.fy + df) * H))
                        if !collides(cy) { ay = cy; placed = true; break }
                    }
                    if !placed { continue }
                }
            }

            var members: [NeuralMember] = []
            for _ in 0..<spec.n {
                let ang = rnd.next() * .pi * 2
                let dist = (42 + rnd.next() * 46) * k
                var m = NeuralMember(
                    ox: cos(ang) * dist,
                    oy: sin(ang) * dist * 0.72,
                    r: max(0.8, (1.5 + rnd.next() * 1.1) * k),
                    bw1: 0.25 + rnd.next() * 0.3,
                    bw2: 0.2 + rnd.next() * 0.3,
                    bp1: rnd.next() * .pi * 2,
                    bp2: rnd.next() * .pi * 2,
                    amp: (2.5 + rnd.next() * 3.5) * k,
                    tw: 0.4 + rnd.next() * 0.5,
                    tp: rnd.next() * .pi * 2,
                    twig: nil)
                if rnd.next() > 0.8 {
                    m.twig = (ox: m.ox + (rnd.next() - 0.5) * 70 * k,
                              oy: m.oy + (rnd.next() - 0.5) * 50 * k,
                              r: max(0.7, (1 + rnd.next() * 0.7) * k))
                }
                members.append(m)
            }

            idxMap[si] = anchors.count
            anchors.append(NeuralAnchor(
                hx: ax, hy: ay,
                dw: 0.05 + rnd.next() * 0.05,
                dp: rnd.next() * .pi * 2,
                damp: (8 + rnd.next() * 8) * k,
                r: max(1.4, ((spec.big ? 3.6 : 2.8) + rnd.next() * 1.0) * k),
                col: spec.col,
                members: members,
                tw: 0.3 + rnd.next() * 0.3,
                tp: rnd.next() * .pi * 2))
        }

        // Axons never cross a keep-out, and never two long spans side by side
        let longL = 0.22 * max(W, H)
        let nearR = 0.18 * max(W, H)
        var kept: [(long: Bool, mx: Double, my: Double, ang: Double, ai: Int, bi: Int)] = []

        for (a, b) in [(3, 0), (0, 1), (1, 2), (4, 5), (5, 6)] {
            guard idxMap[a] >= 0, idxMap[b] >= 0 else { continue }
            let A = anchors[idxMap[a]], B = anchors[idxMap[b]]
            if ko.contains(where: { segHitsRect(A.hx, A.hy, B.hx, B.hy, $0, 20 * k) }) { continue }

            let L = hypot(B.hx - A.hx, B.hy - A.hy)
            let mx = (A.hx + B.hx) / 2, my = (A.hy + B.hy) / 2
            let ang = atan2(B.hy - A.hy, B.hx - A.hx)
            let isLong = L > longL

            if isLong && kept.contains(where: { kp in
                guard kp.long else { return false }
                if hypot(kp.mx - mx, kp.my - my) < nearR { return true }
                let shares = kp.ai == idxMap[a] || kp.ai == idxMap[b]
                          || kp.bi == idxMap[a] || kp.bi == idxMap[b]
                var d = abs(kp.ang - ang)
                d = min(d, .pi - d)
                return shares && d < 0.6
            }) { continue }

            axons.append(NeuralAxon(a: idxMap[a], b: idxMap[b], off: rnd.next()))
            kept.append((isLong, mx, my, ang, idxMap[a], idxMap[b]))
        }
    }
}

// MARK: - XeidNeuralField
// The constellation, drawn on a pure black field. `t` is the screen's clock in
// seconds; the field breathes off it rather than owning an animation of its own.
struct XeidNeuralField: View {
    var t: Double
    var clearRects: [CGRect] = []

    @State private var model = NeuralFieldModel(size: .zero, clearRects: [])
    @State private var builtFor: CGSize = .zero

    var body: some View {
        GeometryReader { proxy in
            Canvas { ctx, _ in draw(ctx) }
                .onAppear { rebuild(proxy.size) }
                .onChange(of: proxy.size) { rebuild($0) }
        }
        .accessibilityHidden(true)
    }

    private func rebuild(_ size: CGSize) {
        guard size != builtFor, size.width > 1, size.height > 1 else { return }
        builtFor = size
        model = NeuralFieldModel(size: size, clearRects: clearRects)
    }

    // MARK: Drawing
    private func draw(_ ctx: GraphicsContext) {
        let k = model.k

        // Halo, body, white core — the site's own bulb. Small frames get a
        // mild alpha boost so the glow survives at phone scale.
        func bulb(_ ctx: GraphicsContext, _ x: Double, _ y: Double, _ r: Double,
                  _ col: (r: Double, g: Double, b: Double), _ coreA: Double, _ tk: Double) {
            let lum = 1 + max(0, 1 - k) * 0.35
            let haloA = min(0.6, (0.28 + r * 0.08) * (0.8 + tk * 0.2) * lum)
            let hr = max(9, r * 4)

            ctx.fill(
                Path(ellipseIn: CGRect(x: x - hr, y: y - hr, width: hr * 2, height: hr * 2)),
                with: .radialGradient(
                    Gradient(stops: [
                        .init(color: Neural.color(col, haloA), location: 0),
                        .init(color: Neural.color(col, haloA * 0.32), location: 0.5),
                        .init(color: Neural.color(col, 0), location: 1),
                    ]),
                    center: CGPoint(x: x, y: y), startRadius: 0, endRadius: hr))

            ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                     with: .color(Neural.color(col, 0.82 + tk * 0.18)))

            let cr = r * 0.5
            ctx.fill(Path(ellipseIn: CGRect(x: x - cr, y: y - cr, width: cr * 2, height: cr * 2)),
                     with: .color(.white.opacity(coreA * (0.8 + tk * 0.2))))
        }

        func line(_ ctx: GraphicsContext, _ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double,
                  _ col: (r: Double, g: Double, b: Double), _ alpha: Double, _ w: Double) {
            var p = Path()
            p.move(to: CGPoint(x: x1, y: y1))
            p.addLine(to: CGPoint(x: x2, y: y2))
            ctx.stroke(p, with: .color(Neural.color(col, alpha)), lineWidth: w)
        }

        // Hubs breathe around their anchor
        let pos: [(x: Double, y: Double)] = model.anchors.map {
            (x: $0.hx + sin(t * $0.dw + $0.dp) * $0.damp,
             y: $0.hy + cos(t * $0.dw * 0.8 + $0.dp) * $0.damp * 0.7)
        }

        // Axons, each with a slow travelling pulse
        for ax in model.axons {
            let A = pos[ax.a], B = pos[ax.b]
            let ca = model.anchors[ax.a].col, cb = model.anchors[ax.b].col
            let col = (r: (ca.r + cb.r) / 2, g: (ca.g + cb.g) / 2, b: (ca.b + cb.b) / 2)

            line(ctx, A.x, A.y, B.x, B.y, col, 0.2, max(0.5, 0.65 * k))

            let u = (t * 0.03 + ax.off).truncatingRemainder(dividingBy: 1)
            let sx = A.x + (B.x - A.x) * u, sy = A.y + (B.y - A.y) * u
            let pr = max(2.5, 6 * k)
            ctx.fill(
                Path(ellipseIn: CGRect(x: sx - pr, y: sy - pr, width: pr * 2, height: pr * 2)),
                with: .radialGradient(
                    Gradient(stops: [
                        .init(color: .white.opacity(0.75), location: 0),
                        .init(color: Neural.color(col, 0.35), location: 0.4),
                        .init(color: .black.opacity(0), location: 1),
                    ]),
                    center: CGPoint(x: sx, y: sy), startRadius: 0, endRadius: pr))
            let dr = max(0.6, 1.1 * k)
            ctx.fill(Path(ellipseIn: CGRect(x: sx - dr, y: sy - dr, width: dr * 2, height: dr * 2)),
                     with: .color(.white.opacity(0.85)))
        }

        // Clusters
        for (ai, a) in model.anchors.enumerated() {
            let AP = pos[ai]
            for m in a.members {
                let mx = AP.x + m.ox + sin(t * m.bw1 + m.bp1) * m.amp
                let my = AP.y + m.oy + cos(t * m.bw2 + m.bp2) * m.amp * 0.8

                line(ctx, AP.x, AP.y, mx, my, a.col, 0.3, max(0.5, 0.85 * k))

                if let twig = m.twig {
                    let tx = AP.x + twig.ox + sin(t * m.bw2 + m.bp2) * 2 * k
                    let ty = AP.y + twig.oy + cos(t * m.bw1 + m.bp1) * 2 * k
                    line(ctx, mx, my, tx, ty, a.col, 0.22, max(0.45, 0.65 * k))
                    bulb(ctx, tx, ty, twig.r, a.col, 0.7, 0.5)
                }

                bulb(ctx, mx, my, m.r, a.col, 0.85, (sin(t * m.tw + m.tp) + 1) / 2)
            }
            bulb(ctx, AP.x, AP.y, a.r, a.col, 1, (sin(t * a.tw + a.tp) + 1) / 2)
        }
    }
}

// MARK: - XeidLogoIgnition
// The approved way the X enters: a seed of light at the crossing, four rays
// out along the diagonals, then the glow settles into the neon X.
//
//   0.05–0.24  seed appears
//   0.20–0.74  rays expand (ease-out quint)
//   0.24–0.60  seed blinks out as the rays take over
//   0.62–1.00  glow blooms down to rest
struct XeidLogoIgnition: View {
    var size: CGFloat = 134
    var duration: Double = 1.2
    var time: Double

    // The logo's own geometry in its 1024 box: the two diagonals split into
    // four half-rays from the crossing point.
    private static let box: Double = 1024
    private static let cross = CGPoint(x: 510, y: 493)
    private static let rayLength: Double = 448
    private static let rays: [(gradient: Int, to: CGPoint)] = [
        (0, CGPoint(x: 194, y: 178)),
        (0, CGPoint(x: 826, y: 809)),
        (1, CGPoint(x: 195, y: 808)),
        (1, CGPoint(x: 825, y: 178)),
    ]
    // The X gradient, blue (encoder) through white to magenta (decoder)
    private static let stops = Gradient(stops: [
        .init(color: Color(hex: 0x3F77E7), location: 0),
        .init(color: Color(hex: 0x3F77E7), location: 0.40),
        .init(color: Color(hex: 0x6F9AEE), location: 0.46),
        .init(color: Color(hex: 0xE2EAFC), location: 0.49),
        .init(color: Color(hex: 0xFFFFFF), location: 0.50),
        .init(color: Color(hex: 0xFCE4F0), location: 0.51),
        .init(color: Color(hex: 0xF959A7), location: 0.54),
        .init(color: Color(hex: 0xF70077), location: 0.60),
        .init(color: Color(hex: 0xF70077), location: 1),
    ])
    private static let gradientEnds: [(CGPoint, CGPoint)] = [
        (CGPoint(x: 194, y: 178), CGPoint(x: 826, y: 809)),
        (CGPoint(x: 195, y: 808), CGPoint(x: 825, y: 178)),
    ]

    var body: some View {
        Canvas { ctx, canvasSize in
            let s = min(canvasSize.width, canvasSize.height) / Self.box
            let p = XeidEase.clamp(time / duration)

            let seedIn = XeidEase.outQuart(XeidEase.clamp((p - 0.05) / 0.19))
            let seedOut = XeidEase.clamp((p - 0.24) / 0.36)
            let seed = seedIn * (1 - seedOut)
            let grown = XeidEase.outQuint(XeidEase.clamp((p - 0.2) / 0.54))
            let glow = 1 + 0.5 * (1 - XeidEase.clamp((p - 0.62) / 0.38))

            ctx.blendMode = .screen

            // Each ray is three passes: a wide halo, a bloom, and the core
            // stroke. They grow out of the crossing point as `grown` runs.
            for ray in Self.rays {
                guard grown > 0.001 else { break }
                let from = CGPoint(x: Self.cross.x * s, y: Self.cross.y * s)
                let full = CGPoint(x: ray.to.x * s, y: ray.to.y * s)
                let to = CGPoint(x: from.x + (full.x - from.x) * grown,
                                 y: from.y + (full.y - from.y) * grown)

                var path = Path()
                path.move(to: from)
                path.addLine(to: to)

                let ends = Self.gradientEnds[ray.gradient]
                let shading = GraphicsContext.Shading.linearGradient(
                    Self.stops,
                    startPoint: CGPoint(x: ends.0.x * s, y: ends.0.y * s),
                    endPoint: CGPoint(x: ends.1.x * s, y: ends.1.y * s))

                for pass in [(width: 15.0, blur: 34.0, alpha: 0.6 * glow),
                             (width: 10.0, blur: 11.0, alpha: glow),
                             (width: 9.5, blur: 0.0, alpha: 1.0)] {
                    ctx.drawLayer { layer in
                        if pass.blur > 0 { layer.addFilter(.blur(radius: pass.blur * s)) }
                        layer.opacity = min(1, pass.alpha)
                        layer.stroke(path, with: shading,
                                     style: StrokeStyle(lineWidth: pass.width * s, lineCap: .round))
                    }
                }
            }

            // The seed of light at the crossing, collapsing as the rays take over
            if seed > 0.004 {
                let c = CGPoint(x: Self.cross.x * s, y: Self.cross.y * s)
                for ring in [(r: (10 + 150 * (1 - seed)) * s, blur: 34.0, alpha: 0.5 * seed),
                             (r: (6 + 26 * (1 - seed)) * s, blur: 11.0, alpha: 0.95 * seed)] {
                    ctx.drawLayer { layer in
                        layer.addFilter(.blur(radius: ring.blur * s))
                        layer.fill(
                            Path(ellipseIn: CGRect(x: c.x - ring.r, y: c.y - ring.r,
                                                   width: ring.r * 2, height: ring.r * 2)),
                            with: .color(.white.opacity(ring.alpha)))
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
