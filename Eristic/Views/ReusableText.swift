//
//  ReusableText.swift
//  Eristic
//
//  Created by Fady A Eid on 11/20/23.
//

import Foundation
import SwiftUI

// ReusableText view for displaying text with optional system symbol
struct ReusableText: View {
    var systemSymbol: String?
    var text: String // Text content
    var font: Font // Font for the text
    var color: Color // Color for the text
    
    // Body of the view
    var body: some View {
        HStack {
            // Display system symbol if provided
            if let symbol = systemSymbol {
                Image(systemName: symbol)
                    .foregroundColor(color)
                    .font(font)
            }
            
            // Display main text
            Text("\(text)")
                .font(font)
                .foregroundColor(color)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Inter at any size
// For the handful of sizes the design system has no modifier for (the quiz
// question, option labels, the run-over score, finder sentences, profile
// stats). Tracking is in em as in the spec. lineHeight is the spec's CSS
// multiple; Inter's own line height is about 1.21 x size, so only the part
// above that is added as line spacing, which keeps the block the height the
// design draws.
extension View {
    func xeidText(_ size: CGFloat,
                  weight: XeidFont.Weight = .regular,
                  lineHeight: CGFloat = 1.21,
                  tracking: CGFloat = 0,
                  color: Color = XeidColor.ink,
                  relativeTo style: Font.TextStyle = .body) -> some View {
        font(XeidFont.inter(size, weight: weight, relativeTo: style))
            .tracking(tracking * size)
            .lineSpacing(max(0, (lineHeight - 1.21) * size))
            .foregroundColor(color)
    }
}
