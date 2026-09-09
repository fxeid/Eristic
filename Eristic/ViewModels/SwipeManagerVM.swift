//
//  SwipeView.swift
//  Eristic
//
//  Created by Fady A Eid on 11/27/23.
//

import SwiftUI

// Enum to represent different swipe directions
enum SwipeDirection {
    case left, right, top, bottom
}

// MARK: - CardSwiperView
// The swipe engine for the flash deck. Only the top of the deck — `cards.first`
// — is on screen and takes the drag; what shows behind it belongs to the deck
// screen. A drag past the threshold flies the card off and reports the swipe;
// the deck that owns the array is the one that removes the card, and the card
// it removes is the one that was swiped.
public struct CardSwiperView<Content: View>: View {
    @Binding var cards: [Content] // Binding for the array of cards

    var onCardSwiped: ((SwipeDirection, Int) -> Void)? // Callback for card swiping
    var onCardDragged: ((SwipeDirection, Int, CGSize) -> Void)? // Callback for card dragging
    var initialOffsetY: CGFloat = 5 // Initial Y offset for cards
    var initialRotationAngle: Double = 0.5 // Initial rotation angle for cards

    // How far the card travels before the drag reads as a swipe
    private let swipeThreshold: CGFloat = 150
    // Up and down are damped, so the card leans into a sideways drag
    private let verticalDamping: CGFloat = 0.4
    // Far enough to clear the screen in any direction
    private let flyOffDistance: CGFloat = 900
    // The deck waits this long before taking the swiped card off the top, so
    // the card is gone by the time it stops moving. Keep the two in step.
    private let flyOffDuration: Double = 0.35

    // MARK: Top card state
    // What the card on top is doing, and where the deck stood when it was
    // measured. When the deck changes underneath us that card has left, so the
    // state no longer applies and the card that replaces it starts square.
    // This is what per-card @State plus `.id(UUID())` was reaching for; the
    // UUID gave every card a new identity on every render instead, which threw
    // the swipe away and put the card that had just left back on top.
    private struct TopCard {
        var offset: CGSize = .zero
        var depth: Int = -1     // cards.count when the offset was measured
        var changes: Int = -1   // deckChanges at that moment
        var hasFlownOff = false
    }

    @State private var top = TopCard()

    // How many times the deck has changed. `cards` is opaque — there is no
    // card identity to compare against — so the engine counts the changes it
    // sees instead.
    @State private var deckChanges = 0

    // The offset holds only while the deck is untouched. Depth catches a change
    // in the render pass it happens in, before the new card is ever drawn;
    // the count catches the change depth cannot see, since stepping back to the
    // previous card puts the depth back exactly where it was.
    private var isStale: Bool {
        top.depth != cards.count || top.changes != deckChanges
    }

    private var offset: CGSize { isStale ? .zero : top.offset }
    private var hasFlownOff: Bool { !isStale && top.hasFlownOff }

    // Initializer for the card swiper
    init(
        cards: Binding<[Content]>,
        onCardSwiped: ((SwipeDirection, Int) -> Void)? = nil,
        onCardDragged: ((SwipeDirection, Int, CGSize) -> Void)? = nil,
        initialOffsetY: CGFloat = 5,
        initialRotationAngle: Double = 0.5
    ) {
        self._cards = cards
        self.onCardSwiped = onCardSwiped
        self.onCardDragged = onCardDragged
        self.initialOffsetY = initialOffsetY
        self.initialRotationAngle = initialRotationAngle
    }

    // MARK: Body
    // Two cards deep. The next one sits square underneath so a swipe uncovers
    // the card behind rather than a hole, and once the deck moves on it is
    // already exactly where the card leaving it used to be — nothing to
    // redraw, nothing to fade in.
    public var body: some View {
        ZStack {
            if cards.count > 1 {
                cards[1]
                    .allowsHitTesting(false) // the card above owns the drag
            }

            if let topCard = cards.first {
                topCard
                    .contentShape(Rectangle())
                    .offset(x: offset.width, y: offset.height * verticalDamping)
                    .rotationEffect(.degrees(Double(offset.width / 40)))
                    .gesture(swipe)
            }
        }
        .onChange(of: cards.count) { deckChanges += 1 }
    }

    // MARK: Gesture
    private var swipe: some Gesture {
        DragGesture()
            .onChanged { gesture in
                // The card is already on its way out; let it go
                guard !hasFlownOff else { return }
                top = TopCard(offset: gesture.translation,
                              depth: cards.count,
                              changes: deckChanges)
                onCardDragged?(direction(for: gesture.translation) ?? .left, 0, gesture.translation)
            }
            .onEnded { _ in
                guard !hasFlownOff else { return }
                guard let swipeDirection = direction(for: offset) else {
                    withAnimation(.easeOut(duration: 0.2)) {
                        top = TopCard(depth: cards.count, changes: deckChanges)
                    }
                    return
                }
                withAnimation(.easeOut(duration: flyOffDuration)) {
                    top = TopCard(offset: flyOff(swipeDirection),
                                  depth: cards.count,
                                  changes: deckChanges,
                                  hasFlownOff: true)
                }
                onCardSwiped?(swipeDirection, 0)
            }
    }

    // The direction a drag reads as, or nil when it is short of the threshold.
    // Sideways wins over up and down, as it always has. There is no far edge:
    // a long, fast drag is a swipe, not a miss.
    private func direction(for translation: CGSize) -> SwipeDirection? {
        if translation.width <= -swipeThreshold { return .left }
        if translation.width >= swipeThreshold { return .right }
        if translation.height <= -swipeThreshold { return .top }
        if translation.height >= swipeThreshold { return .bottom }
        return nil
    }

    // Where the card lands once it is let go. Up and down are divided by the
    // damping so they clear the screen the way sideways does.
    private func flyOff(_ direction: SwipeDirection) -> CGSize {
        switch direction {
        case .left:   return CGSize(width: -flyOffDistance, height: 0)
        case .right:  return CGSize(width: flyOffDistance, height: 0)
        case .top:    return CGSize(width: 0, height: -flyOffDistance / verticalDamping)
        case .bottom: return CGSize(width: 0, height: flyOffDistance / verticalDamping)
        }
    }
}
