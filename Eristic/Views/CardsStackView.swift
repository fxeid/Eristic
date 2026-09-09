//
// CardsStackView.swift
// Eristic
//
//  Created by Fady A Eid on 11/27/23.
//

import SwiftUI

// MARK: - CardsStackView
// The flash deck: one card at a time on the swipe engine, a counter in the
// top bar, shuffle on the right, previous and next in the footer. The whole
// deck is shuffled on entry; `fallacyIds` narrows it to a few fallacies for
// drilling. Every card that leaves the top of the deck counts as seen.
struct CardsStackView: View {
    // MARK: Properties
    private let fallacyIds: Set<Int>?

    // Cards in the whole deck, for the "07 / 61 today" eyebrows on the hub
    // and the practice tab
    static var deckSize: Int { deck.count }

    @State private var cards: [CardView] = []       // still to see, top first
    @State private var history: [FlashCard] = []    // already seen, most recent last
    @State private var hasLoaded = false

    init(fallacyIds: Set<Int>? = nil) {
        self.fallacyIds = fallacyIds
    }

    // "07 / 60": the position of the card on top, two digits
    private var counter: String {
        let total = cards.count + history.count
        let position = min(history.count + 1, total)
        return String(format: "%02d / %02d", position, total)
    }

    // MARK: Body
    var body: some View {
        XeidScreen {
            XeidTopBar {
                XeidBackButton()
            } center: {
                XeidBarLabel(text: counter, wide: false)
            } trailing: {
                Button(action: loadCards) {
                    XeidBarLabel(text: "Shuffle", action: true, wide: false)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(XeidCellButtonStyle())
            }

            cardArea
                .padding(.top, 16)
                .padding(.horizontal, 22)

            footer
        }
        .onAppear {
            guard !hasLoaded else { return }
            hasLoaded = true
            loadCards()
        }
    }

    // MARK: Card area
    // The card fills the area minus the 14pt the two ghost outlines peek out
    // below it. The engine is centred on the card so its drag maths hold.
    private var cardArea: some View {
        GeometryReader { proxy in
            let cardSize = CGSize(width: max(proxy.size.width, 0),
                                  height: max(proxy.size.height - 14, 0))
            ZStack(alignment: .top) {
                ghost(inset: 12, drop: 14, size: cardSize)
                ghost(inset: 6, drop: 7, size: cardSize)

                // Lies at the bottom of the deck the whole time, so the last
                // card slides off it the way every other card slides off the
                // one behind it
                DeckEmptyState(size: cardSize)
                    .accessibilityHidden(!cards.isEmpty)

                if !cards.isEmpty {
                    CardSwiperView(cards: $cards, onCardSwiped: { _, _ in
                        advance(afterSwipe: true)
                    })
                    .environment(\.flashCardSize, cardSize)
                    .frame(width: cardSize.width, height: cardSize.height)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private func ghost(inset: CGFloat, drop: CGFloat, size: CGSize) -> some View {
        RoundedRectangle(cornerRadius: 16)
            .strokeBorder(XeidColor.hairline, lineWidth: 1)
            .frame(width: max(size.width - inset * 2, 0), height: size.height)
            .offset(y: drop)
            .accessibilityHidden(true)
    }

    // MARK: Footer
    // 82pt: previous | next, with a 1 x 12 hairline between
    private var footer: some View {
        HStack(spacing: 18) {
            Button(action: goBack) {
                DeckFooterLabel(text: "previous", glyph: .back, glyphFirst: true)
            }
            .buttonStyle(XeidCellButtonStyle())
            .disabled(history.isEmpty)

            Rectangle()
                .fill(XeidColor.hairline)
                .frame(width: 1, height: 12)

            Button {
                advance(afterSwipe: false)
            } label: {
                DeckFooterLabel(text: "next", glyph: .forward, glyphFirst: false)
            }
            .buttonStyle(XeidCellButtonStyle())
            .disabled(cards.isEmpty)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 82)
    }

    // MARK: Actions
    // A fresh shuffle of the deck, or of the chosen fallacies
    private func loadCards() {
        var deck = CardsStackView.deck
        if let fallacyIds {
            deck = deck.filter { fallacyIds.contains($0.fallacyId) }
        }
        deck.shuffle()
        history = []
        cards = deck.map { CardView(card: $0) }
    }

    // Moves the top card into history and counts it as seen. After a swipe
    // the engine is still flying the card off, so the deck waits for that to
    // finish; from the footer the card fades and the next one takes its place.
    private func advance(afterSwipe: Bool) {
        guard !cards.isEmpty else { return }
        if afterSwipe {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 350_000_000)
                popTopCard()
            }
        } else {
            withAnimation(XeidMotion.standard) {
                popTopCard()
            }
        }
    }

    private func popTopCard() {
        guard !cards.isEmpty else { return }
        let card = cards.removeFirst()
        history.append(card.card)
        ProgressStore.shared.recordCardSeen()
    }

    // Brings the last seen card back to the top
    private func goBack() {
        guard let card = history.popLast() else { return }
        withAnimation(XeidMotion.standard) {
            cards.insert(CardView(card: card), at: 0)
        }
    }
}

// MARK: - DeckFooterLabel
// "previous" / "next" 14/300 secondary with a 15pt inline arrow; press
// shifts to ink, disabled drops to 0.4
private struct DeckFooterLabel: View {
    let text: String
    let glyph: XeidGlyph
    let glyphFirst: Bool

    @Environment(\.xeidPressed) private var pressed
    @Environment(\.isEnabled) private var isEnabled

    private var color: Color {
        pressed ? XeidColor.ink : XeidColor.secondary
    }

    var body: some View {
        HStack(spacing: 6) {
            if glyphFirst {
                XeidInlineGlyph(glyph: glyph, size: 15, color: color)
            }
            Text(text)
                .font(XeidFont.caption)
                .foregroundColor(color)
            if !glyphFirst {
                XeidInlineGlyph(glyph: glyph, size: 15, color: color)
            }
        }
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
        .opacity(isEnabled ? 1 : 0.4)
    }
}

// MARK: - DeckEmptyState
// Shown in the card's place once every card has been seen
private struct DeckEmptyState: View {
    let size: CGSize

    var body: some View {
        VStack(spacing: 14) {
            XeidEyebrow(text: "That's the deck", dot: XeidColor.magenta)
            Text("Every card has been seen. Shuffle to go again.")
                .xeidSecondary()
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(width: size.width, height: size.height)
        .background(XeidColor.cell)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(XeidColor.hairline, lineWidth: 1))
    }
}

// MARK: - The deck
// Every card in the app, in FallaciesList order. Ids are positions in this
// list; fallacyId is the FallaciesList id of the fallacy the response commits.
extension CardsStackView {
    private static let deck: [FlashCard] = {
        let rows: [(Int, String, String)] = [
            // Straw Man
            (1, "We should invest more in improving public schools.", "So, you're saying we should completely abandon private schools?"),
            (1, "We need to address climate change by reducing carbon emissions.", "You want to shut down all industries and throw people out of jobs!"),
            (1, "Regulate firearms for public safety.", "You're a socialist, want government control."),
            (1, "Reconsider military budget, focus on diplomacy.", "You suggest leaving country defenseless."),
            (1, "Stricter food safety regulations to prevent health issues.", "You want to ban fast food, enforce government-approved meals?"),

            // Ad Hominem
            (2, "Abolish prisons; crime linked to social factors.", "You're a bleeding-heart liberal, indifferent to crime victims."),
            (2, "Ban assault weapons; they're the main cause of violence.", "You're an ignorant anti-gunner, lacks knowledge about guns."),
            (2, "Legalize all drugs; the war on drugs failed, leading to mass incarceration, violence, and corruption.", "You're just a drug addict justifying your drug use."),
            (2, "Open borders to immigrants; everyone deserves a better life.", "You're a naive globalist ignoring national sovereignty."),

            // False Dilemma
            (3, "Love America despite social and political issues.", "Love it as is or leave."),
            (3, "Consider myself a centrist who votes based on policies.", "Either conservative or liberal!"),
            (3, "Any weekend plans?", "Nothing good on TV, so I'll just get drunk."),
            (3, "What motivates supporting this candidate?", "If he doesn't win, our economy will be devastated."),
            (3, "In advertisement", "Use our beauty products or never look youthful."),
            (3, "Sustainable development balances economic growth and environmental responsibility.", "Prioritize economic growth or focus solely on environmental conservation."),
            (3, "Promote informed vaccine choices, addressing concerns and ensuring transparency.", "Either pro-vaccination without question or against all vaccines."),

            // Appeal to Ignorance
            (4, "Your perspectives on extraterrestrial life?", "No evidence proving aliens don't exist, so they must."),
            (4, "Skeptical about psychics; predictions never proven accurate.", "No one proved psychic powers aren't real, so they must be."),
            (4, "Scientists discussing time travel possibilities.", "Can't prove time travel is impossible, so it must be achievable."),
            (4, "Saw a guy on TV claiming he saw Bigfoot.", "Can't disprove Bigfoot's existence, so it's reasonable to believe."),
            (4, "How do you view allegations against this politician?", "Since corruption charges aren't proven, the politician must be completely honest."),

            // Slippery Slope
            (5, "Allow students to use calculators for problem-solving.", "Soon they won't know basic math without them."),
            (5, "Researchers suggest occasional remote work may increase productivity.", "Soon, productivity will plummet, and the company will fail."),
            (5, "One person was a little late to the meeting; no big deal.", "Soon everyone will be late, and meetings won't start on time."),
            (5, "Implement a flexible dress code for employee comfort.", "This will lead to chaos, and people will wear anything."),
            (5, "Providing free samples encourages people to buy our product.", "Giving free samples leads to everyone expecting free products, bankrupting businesses."),

            // Circular Reasoning
            (6, "How do you know global warming is a significant problem?", "Scientists agree, and it's significant because they agree."),
            (6, "How do you know this book is a masterpiece?", "Considered a classic because it's a masterpiece, and it's a masterpiece because it's considered a classic."),
            (6, "How can you trust this news source?", "Reported by reputable sources, and they're reliable because they report accurately."),
            (6, "Why do you think this software is user-friendly?", "User-friendly because the manual says so, and the manual is trustworthy as it's by the developer."),
            (6, "Why do you think this diet plan is effective?", "Effective because testimonials say so, and testimonials are trustworthy as they follow the diet plan."),

            // Hasty Generalization
            (7, "Do you think all politicians are corrupt?", "Yes, definitely. Heard about a few scandals, so all politicians must be corrupt."),
            (7, "What do you think about online classes?", "Joined one online class, and it was boring. Online classes are a waste of time."),
            (7, "Did you attend the language learning meetup?", "Went once, couldn't understand anything. Language meetups are a waste of time."),
            (7, "What's your opinion on the new movie?", "Watched five minutes, seemed boring. The movie is probably not worth watching."),
            (7, "Did you visit the new restaurant downtown?", "Yeah, went last week, service was terrible. That restaurant is awful."),

            // Appeal to Authority
            (8, "Why trust this diet plan?", "Celebrity nutritionist backs it, so it must work."),
            (8, "Why support this political figure?", "Famous actor endorsed them, making it a good choice."),
            (8, "Is this technology worth investing in?", "Tech guru on social media recommended it, making it a smart investment."),
            (8, "Is this product effective?", "Top athlete endorses it, ensuring enhanced performance."),
            (8, "Is this financial advice reliable?", "Billionaire entrepreneur recommended it, so it's likely sound."),

            // Red Herring
            (9, "Did you forget to do the dishes?", "Don't appreciate how hard I work. Had a long day."),
            (9, "Have you been drinking alcohol at the party?", "Spent the whole day organizing. Can't you see my effort?"),
            (9, "Did you finish your project?", "Computer crashed. Dealing with technical issues is frustrating."),
            (9, "Why didn't you submit the report on time?", "Doctor's appointment, kids from school. Work isn't my only priority."),
            (9, "Did you cheat on the test?", "Struggling with the subject. Accusing me won't help."),

            // Equivocation
            (10, "Did you attend the full meeting?", "Yes, I attended. Joined for the first few minutes, then left early."),
            (10, "Did you finish the report on time?", "Yes, it's finished. Introduction and conclusion are done, but the body needs more work."),
            (10, "Did you read the entire article?", "Yes, I read it. Abstract and conclusion. That's the essence, right?"),
            (10, "Did you return the borrowed book?", "Yes, I returned it. Returned it to the shelf, not to the owner."),
            (10, "Did you resolve the software issue?", "Yes, it's resolved. Restarted the computer, but the issue might happen again."),

            // Appeal to Emotion
            (11, "Why support this environmental policy?", "Think about the suffering animals. We must do it for them."),
            (11, "Argument for stricter gun control?", "Consider the emotional toll of gun violence on families. Stricter control saves lives and prevents suffering."),
            (11, "Address mental health in workplace policies?", "Imagine the relief employees would feel if we prioritize mental health. Essential for their overall well-being."),
            (11, "Why donate to this specific charity?", "Imagine the children's faces lighting up when they receive our help."),
            (11, "Why invest in renewable energy?", "Think about a cleaner planet for future generations. Investing in renewables is crucial for their well-being."),

            // Tu Quoque
            (12, "You shouldn't have skipped class. It's important to attend lectures.", "Well, you've skipped class before too, so why are you telling me now?"),
            (12, "Don't drink and drive. It's dangerous.", "I've seen you drive after having a few drinks. Why the hypocrisy?"),
            (12, "Respect other people's privacy.", "I've seen you go through someone's phone. Why are you being a hypocrite?"),
            (12, "Peer review ensures quality.", "You published without rigorous review. Why advocate for it now?"),
            (12, "Scientific integrity is paramount in our field.", "I've heard rumors about your involvement in unethical practices. Why should I take your moral stand seriously?"),
        ]
        return rows.enumerated().map { offset, row in
            FlashCard(id: offset + 1, fallacyId: row.0, argument: row.1, response: row.2)
        }
    }()
}

// MARK: - Preview
#Preview {
    NavigationStack {
        CardsStackView()
    }
}
