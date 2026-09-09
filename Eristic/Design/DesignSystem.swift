//
//  DesignSystem.swift
//  Eristic
//
//  Created by Fady A Eid on 9/3/26.
//

import SwiftUI

// MARK: - Colours
// XEID tokens from the redesign handoff. Full-strength hex only: no tints,
// no opacity, no gradients except the flash-card seam.
enum XeidColor {
    static let surface = Color(hex: 0xF5F5F5)   // screen background
    static let cell = Color(hex: 0xFFFFFF)      // cards and cells
    static let hairline = Color(hex: 0xE0E0E0)  // 1pt borders
    static let ink = Color(hex: 0x1A1A1A)       // primary text, black pill
    static let secondary = Color(hex: 0x525252) // secondary text
    static let muted = Color(hex: 0x8E8E8E)     // placeholders, inactive
    static let blue = Color(hex: 0x3F77E7)      // the argument, structure, progress
    static let magenta = Color(hex: 0xF70077)   // the fallacy, the tell, wrong answers
    static let darkBlue = Color(hex: 0x5B9FFF)  // on true black only
    static let darkMagenta = Color(hex: 0xFF4AB7)
    
    // The only gradient in the app: the flash-card seam, blue holds to 46%,
    // white core at 50%, magenta from 54%, left to right
    static let seam = LinearGradient(
        stops: [
            .init(color: blue, location: 0),
            .init(color: blue, location: 0.46),
            .init(color: cell, location: 0.50),
            .init(color: magenta, location: 0.54),
            .init(color: magenta, location: 1),
        ],
        startPoint: .leading, endPoint: .trailing)
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}

// MARK: - Type
// Inter only, weights 300 and 400. Sizes scale with Dynamic Type relative to
// their Apple text style, and sit on Apple's own scale: 34 large title,
// 30/27 titles, 19 title 3, 17 body, 16 callout, 15 subheadline, 13 footnote,
// 12 caption. Nothing is smaller than 12, so nothing lands under the 11pt
// floor the HIG sets even at the smallest Dynamic Type setting.
//
// Weight is 400 by default. The HIG says to avoid light weights, "which can
// be difficult to see, especially when text is small", so 300 is kept for
// display type only — 27pt and up, where it is a deliberate look and reading
// is not at stake. Anything at reading size is 400.
enum XeidFont {
    enum Weight { case light, regular }
    
    static func inter(_ size: CGFloat, weight: Weight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        Font.custom(weight == .light ? "Inter-Light" : "Inter-Regular", size: size, relativeTo: style)
    }

    // Inter that does NOT take Dynamic Type. Only for the brand lockup, whose
    // parts are drawn to a fixed ratio to each other and to the logo box — it
    // is a mark, not reading text, and it carries its own accessibility label.
    static func interFixed(_ size: CGFloat, weight: Weight = .regular) -> Font {
        Font.custom(weight == .light ? "Inter-Light" : "Inter-Regular", fixedSize: size)
    }
    
    static let display = inter(34, weight: .light, relativeTo: .largeTitle)  // screen titles, tracking -0.035em
    static let title = inter(30, weight: .light, relativeTo: .title)          // hub headline
    static let title2 = inter(27, weight: .light, relativeTo: .title2)
    static let cardTitle = inter(19, weight: .regular, relativeTo: .title3)
    static let body = inter(17)
    static let bodySmall = inter(16)
    static let secondary = inter(15, relativeTo: .subheadline)
    static let caption = inter(14, relativeTo: .footnote)
    static let footnote = inter(13, relativeTo: .footnote)
    static let eyebrow = inter(12, weight: .regular, relativeTo: .caption)
    static let button = inter(16, weight: .regular)

    // The spec's line heights are CSS multiples of the size. Inter's own line
    // height is about 1.21 x size, so only the part above that is added as
    // line spacing; a multiple at or below 1.21 adds nothing.
    static func lineSpacing(_ size: CGFloat, lineHeight: CGFloat) -> CGFloat {
        max(0, (lineHeight - 1.21) * size)
    }
}

// MARK: - Text styles
// Tracking values are in em in the handoff; SwiftUI takes points, so they
// are multiplied by the size they apply to. Line heights go through
// XeidFont.lineSpacing so the blocks come out the height the design draws.
extension View {
    func xeidDisplay(_ color: Color = XeidColor.ink) -> some View {
        font(XeidFont.display).tracking(-0.035 * 34).lineSpacing(XeidFont.lineSpacing(34, lineHeight: 1.05)).foregroundColor(color)
    }
    func xeidTitle(_ color: Color = XeidColor.ink) -> some View {
        font(XeidFont.title).tracking(-0.035 * 30).foregroundColor(color)
    }
    func xeidTitle2(_ color: Color = XeidColor.ink) -> some View {
        font(XeidFont.title2).tracking(-0.035 * 27).foregroundColor(color)
    }
    func xeidCardTitle(_ color: Color = XeidColor.ink) -> some View {
        font(XeidFont.cardTitle).tracking(-0.015 * 19).foregroundColor(color)
    }
    func xeidBody(_ color: Color = XeidColor.ink) -> some View {
        font(XeidFont.body).tracking(-0.01 * 17).lineSpacing(XeidFont.lineSpacing(17, lineHeight: 1.45)).foregroundColor(color)
    }
    func xeidBodySmall(_ color: Color = XeidColor.ink) -> some View {
        font(XeidFont.bodySmall).tracking(-0.02 * 16).foregroundColor(color)
    }
    func xeidSecondary(_ color: Color = XeidColor.secondary) -> some View {
        font(XeidFont.secondary).lineSpacing(XeidFont.lineSpacing(15, lineHeight: 1.35)).foregroundColor(color)
    }
    func xeidCaption(_ color: Color = XeidColor.secondary) -> some View {
        font(XeidFont.caption).foregroundColor(color)
    }
    func xeidFootnote(_ color: Color = XeidColor.secondary) -> some View {
        font(XeidFont.footnote).lineSpacing(XeidFont.lineSpacing(13, lineHeight: 1.4)).foregroundColor(color)
    }
    // Section labels: 12/400 uppercase, 0.18em; nav and meta use 0.14em
    func xeidEyebrow(_ color: Color = XeidColor.secondary, wide: Bool = true) -> some View {
        font(XeidFont.eyebrow).tracking((wide ? 0.18 : 0.14) * 12).textCase(.uppercase).foregroundColor(color)
    }
}

// MARK: - Surfaces and controls
struct HairlineBorder: ViewModifier {
    func body(content: Content) -> some View {
        content.overlay(Rectangle().stroke(XeidColor.hairline, lineWidth: 1))
    }
}

extension View {
    // White cell with a 1pt hairline and no radius
    func xeidCell() -> some View {
        background(XeidColor.cell).modifier(HairlineBorder())
    }
}

// The primary pill: black, white 16/400 text, 50pt tall. Press shifts the
// colour to blue; disabled drops to 0.4 opacity.
struct XeidPillButtonStyle: ButtonStyle {
    var filled = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(XeidFont.button)
            .foregroundColor(filled ? .white : XeidColor.secondary)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(filled ? (configuration.isPressed ? XeidColor.blue : XeidColor.ink) : Color.clear)
            .clipShape(Capsule())
            .contentShape(Capsule())
    }
}

// A 5pt status dot used in eyebrows, meta rows and quiz lives
struct XeidDot: View {
    var color: Color = XeidColor.blue
    var size: CGFloat = 5
    var body: some View { Circle().fill(color).frame(width: size, height: size) }
}

// The 1pt XEID hairline as a standalone divider
struct XeidHairline: View {
    var body: some View { Rectangle().fill(XeidColor.hairline).frame(height: 1) }
}

// The neon-X logo from the asset catalog, sized by height
struct XeidNeonX: View {
    var height: CGFloat = 22
    var body: some View {
        Image("XeidNeonX").resizable().scaledToFit().frame(height: height)
    }
}

// The mandatory footer, as drawn: white pill with a hairline, neon-X 15pt
// and "Crafted by XEID Intelligence" 14/300 0.04em secondary, padding 8/14/8/10
struct CraftedByXeid: View {
    var body: some View {
        HStack(spacing: 8) {
            XeidNeonX(height: 15)
            Text("Crafted by XEID Intelligence")
                .font(XeidFont.caption)
                .tracking(0.04 * 14)
                .foregroundColor(XeidColor.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8) // 14pt floors at 11.2, the HIG minimum
        }
        .padding(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 14))
        .background(XeidColor.cell)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(XeidColor.hairline, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Motion
// Fades and 24pt rises, about 0.7s ease-out. No bounce anywhere; presses
// shift colour only.
enum XeidMotion {
    static let duration: Double = 0.7
    static let rise: CGFloat = 24
    
    static var standard: Animation { .easeOut(duration: duration) }
    
    // Incoming content fades in while rising 24pt; outgoing content fades out
    static var riseIn: AnyTransition {
        .asymmetric(insertion: .opacity.combined(with: .offset(y: rise)), removal: .opacity)
    }
}
