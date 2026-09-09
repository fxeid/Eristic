//
//  XeidSymbol.swift
//  Eristic
//
//  Created by Fady A Eid on 9/3/26.
//

import SwiftUI
import PhosphorSwift

// MARK: - XeidGlyph
// The approved vocabulary. Every mark in the app comes from here; screens
// never reference Phosphor directly.
enum XeidGlyph {
    // The twelve fallacies, keyed by FallaciesList id order
    case strawMan, adHominem, falseDilemma, appealToIgnorance, slipperySlope, circularReasoning
    case hastyGeneralization, appealToAuthority, redHerring, equivocation, appealToEmotion, tuQuoque
    // Hub gates
    case library, flash, quiz, finder
    // UI
    case back, forward, close, check, speaker, edit, welcome, shuffle, hand
    
    var phosphor: Ph {
        switch self {
        case .strawMan: return .maskSad
        case .adHominem: return .userMinus
        case .falseDilemma: return .arrowsSplit
        case .appealToIgnorance: return .magnifyingGlass
        case .slipperySlope: return .trendDown
        case .circularReasoning: return .arrowsClockwise
        case .hastyGeneralization: return .users
        case .appealToAuthority: return .crownSimple
        case .redHerring: return .fish
        case .equivocation: return .arrowsLeftRight
        case .appealToEmotion: return .heartbeat
        case .tuQuoque: return .arrowUUpLeft
        case .library: return .books
        case .flash: return .cards
        case .quiz: return .timer
        case .finder: return .textAa
        case .back: return .arrowLeft
        case .forward: return .arrowRight
        case .close: return .x
        case .check: return .check
        case .speaker: return .user
        case .edit: return .pencilSimple
        case .welcome: return .brain
        case .shuffle: return .shuffle
        case .hand: return .hand
        }
    }
    
    // Glyph for a FallaciesList id (1...12)
    static func fallacy(id: Int) -> XeidGlyph {
        let all: [XeidGlyph] = [.strawMan, .adHominem, .falseDilemma, .appealToIgnorance, .slipperySlope, .circularReasoning,
                                .hastyGeneralization, .appealToAuthority, .redHerring, .equivocation, .appealToEmotion, .tuQuoque]
        return all.indices.contains(id - 1) ? all[id - 1] : .library
    }
}

// MARK: - XeidSymbol
// One glyph, one rule: a thin Phosphor glyph in brand blue over a 1pt
// magenta hairline. Geometry comes from the box size S: glyph = S x 0.756,
// hairline width = glyph x 0.5, gap = glyph x 0.2. Thin above 32pt, light
// at or below. Never hand-place icons in screens; use this view.
struct XeidSymbol: View {
    enum Tone { case brand, ink, muted, dark }
    
    let glyph: XeidGlyph
    var size: CGFloat = 44
    var leading = false
    var rule = true
    var tone: Tone = .brand
    
    private var glyphSize: CGFloat { (size * 0.756).rounded() }
    private var glyphColor: Color {
        switch tone {
        case .brand: return XeidColor.blue
        case .ink: return XeidColor.ink
        case .muted: return XeidColor.muted
        case .dark: return XeidColor.darkBlue
        }
    }
    private var ruleColor: Color {
        switch tone {
        case .muted: return XeidColor.muted
        case .dark: return XeidColor.darkMagenta
        default: return XeidColor.magenta
        }
    }
    
    var body: some View {
        let g = glyphSize
        VStack(alignment: leading ? .leading : .center, spacing: (g * 0.2).rounded()) {
            (g <= 32 ? glyph.phosphor.light : glyph.phosphor.thin)
                .frame(width: g, height: g)
                .foregroundColor(glyphColor)
            if rule {
                Rectangle()
                    .fill(ruleColor)
                    .frame(width: (g * 0.5).rounded(), height: 1)
                    .padding(.leading, leading ? (g * 0.25).rounded() : 0)
            }
        }
        .frame(width: size, height: size, alignment: leading ? .leading : .center)
        .accessibilityHidden(true)
    }
}

// Inline arrow or chevron inside text: same glyph, no hairline, text colour
struct XeidInlineGlyph: View {
    let glyph: XeidGlyph
    var size: CGFloat = 15
    var color: Color = XeidColor.ink
    var body: some View {
        glyph.phosphor.light.frame(width: size, height: size).foregroundColor(color).accessibilityHidden(true)
    }
}
