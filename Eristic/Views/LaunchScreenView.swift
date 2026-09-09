//
//  LaunchScreenView.swift
//  Eristic
//
//  Created by Fady A Eid on 9/8/26.
//

import SwiftUI

// MARK: - LaunchScreenView
// The XEID launch sequence, as drawn in the launch-screen spec: the design
// system's neural field comes up, the X ignites, then XEID and Exceed
// Intelligence fade up together. No movement in the type. Three seconds end to
// end, then it hands off to the app.
//
//   0 – 1.2s   X ignites
//   1.2 – 2.0s type fades up
//   3.0s       hand off
//
// iOS never animates a launch screen — the real one is the static black field
// set by UILaunchScreen, which this then continues from, so there is no cut
// between the two.
struct LaunchScreenView: View {
    // MARK: Properties
    var onFinish: () -> Void

    // Sizes are the spec's own, in the 390 x 844 frame it was drawn at
    private let handOff: Double = 3.0
    private let logoSize: CGFloat = 134
    // The lockup's keep-out: no neuron ever enters it
    private let clearRects = [CGRect(x: 0.20, y: 0.35, width: 0.60, height: 0.30)]

    @State private var start = Date.now
    @State private var handedOff = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: Body
    var body: some View {
        TimelineView(.animation(paused: handedOff)) { timeline in
            let t = timeline.date.timeIntervalSince(start)
            content(t: t)
                .onChange(of: t >= handOff) { done in
                    if done { finish() }
                }
        }
        .background(Color.black.ignoresSafeArea())
        .ignoresSafeArea()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("XEID. Exceed Intelligence.")
        // Reduced motion still gets the brand, just without the sequence
        .onAppear { if reduceMotion { finish(after: 1.2) } }
    }

    @ViewBuilder
    private func content(t: Double) -> some View {
        // The field comes up over a second and settles out of a slow push-in
        let fieldIn = XeidEase.smooth(XeidEase.clamp(t / 1.0))
        let fieldScale = 1.1 - 0.1 * XeidEase.smooth(XeidEase.clamp(t / 2.0))
        // Both lines together, once the ignition has finished
        let typeIn = XeidEase.smooth(XeidEase.clamp((t - 1.2) / 0.8))

        ZStack {
            Color.black

            XeidNeuralField(t: reduceMotion ? 0 : t, clearRects: clearRects)
                .opacity((reduceMotion ? 0.92 : fieldIn * 0.92))
                .scaleEffect(reduceMotion ? 1 : fieldScale)

            VStack(spacing: 0) {
                Text("Crafted by")
                    .font(XeidFont.interFixed(15, weight: .light))
                    .tracking(0.04 * 15)
                    .foregroundColor(.white.opacity(0.55))
                    .padding(.bottom, 4)

                XeidLogoIgnition(size: logoSize,
                                 duration: 1.2,
                                 time: reduceMotion ? 1.35 : min(t, 1.35))

                wordmark
                    .padding(.top, -11.5)

                Text("Exceed Intelligence")
                    .font(XeidFont.interFixed(19.8, weight: .light))
                    .tracking(0.01 * 19.8)
                    .foregroundColor(.white)
                    .padding(.top, 13.2)
            }
            .opacity(reduceMotion ? 1 : typeIn)
        }
    }

    // XEID with the registered mark set at the cap line, as the lockup draws it
    private var wordmark: some View {
        Text("XEID")
            .font(XeidFont.interFixed(44, weight: .light))
            .tracking(-0.03 * 44)
            .foregroundColor(XeidColor.muted)
            .overlay(alignment: .topTrailing) {
                Text("®")
                    .font(XeidFont.interFixed(0.38 * 44, weight: .light))
                    .foregroundColor(XeidColor.muted)
                    .alignmentGuide(.trailing) { d in d[.leading] - 0.12 * 44 }
            }
            .fixedSize()
    }

    // MARK: Actions
    private func finish(after delay: Double = 0) {
        guard !handedOff else { return }
        handedOff = true
        if delay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { onFinish() }
        } else {
            onFinish()
        }
    }
}

// MARK: - Preview
#Preview {
    LaunchScreenView(onFinish: {})
}
