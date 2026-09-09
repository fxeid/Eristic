//
//  FallaciesView.swift
//  Eristic
//
//  Created by Fady A Eid on 11/20/23.
//

import SwiftUI

// MARK: - FallaciesView
// The hub: a greeting and headline, the four gates in a 2 x 2 grid and a
// resume strip filling whatever is left. The tab bar belongs to RootView;
// this screen only fills the space above it. Owns the StateModel that the
// quiz writes its score into, and the rename cover.
struct FallaciesView: View {
    // MARK: Properties
    @StateObject var stateModel = StateModel()
    @ObservedObject private var progress = ProgressStore.shared
    @State private var isRenaming = false

    private var fallacyCount: Int { FallaciesList.fallacies.count }

    // MARK: Copy
    // "Good morning / afternoon / evening, Name" by the hour of the day
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let part = hour < 12 ? "morning" : (hour < 17 ? "afternoon" : "evening")
        return "Good \(part), \(stateModel.currentUserName)"
    }

    // "14-day streak · best score 14"; a streak of one day is not a streak yet
    private var meta: String {
        let best = "best score \(stateModel.currentUserHighScore)"
        return progress.streakDays >= 2 ? "\(progress.streakDays)-day streak · \(best)" : best
    }

    // "07 / 61 today": cards seen today, capped at the deck size
    private var flashEyebrow: String {
        let deck = CardsStackView.deckSize
        return String(format: "%02d / %d today", min(progress.cardsSeenToday, deck), deck)
    }

    private var quizEyebrow: String {
        "Best \(stateModel.currentUserHighScore)"
    }

    // The last fallacy opened, or Straw Man when nothing has been opened yet
    private var resumeFallacy: Fallacy? {
        progress.lastOpenedFallacyId.flatMap { id in
            FallaciesList.fallacies.first { $0.id == id }
        }
    }

    private var resumeTitle: String {
        if let fallacy = resumeFallacy {
            return "\(fallacy.title) — fallacy \(String(format: "%02d", fallacy.id)) of \(fallacyCount)"
        }
        return "Straw Man — start here"
    }

    private var resumeTarget: Fallacy? {
        resumeFallacy ?? FallaciesList.fallacies.first
    }

    // MARK: Body
    var body: some View {
        XeidScreen {
            XeidTopBar {
                XeidLockup()
            } trailing: {
                XeidAvatar(name: stateModel.currentUserName)
            }

            // Fixed layout on the reference device; scrolls only when the
            // screen is shorter than the header, grid and strip together
            GeometryReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        header
                        gateGrid
                        resumeStrip
                    }
                    .frame(minHeight: proxy.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        // Tapping the greeting reopens the same full screen name entry
        .fullScreenCover(isPresented: $isRenaming) {
            WelcomeView(
                mode: .rename,
                currentName: stateModel.currentUserName,
                onSave: { name in
                    stateModel.updateName(name)
                    isRenaming = false
                },
                onCancel: { isRenaming = false }
            )
        }
    }

    // MARK: Header
    // 186pt block: greeting, headline, then the meta row pinned to the bottom
    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                isRenaming = true
            } label: {
                HubGreeting(name: stateModel.currentUserName, greeting: greeting)
            }
            .buttonStyle(XeidCellButtonStyle())
            .accessibilityHint("Sets the name shown with your best score")

            VStack(alignment: .leading, spacing: 0) {
                Text("Read it. Spot it.")
                    .xeidTitle()
                Text("Answer it.")
                    .font(XeidFont.inter(30, weight: .regular, relativeTo: .title))
                    .tracking(-0.035 * 30)
                    .foregroundColor(XeidColor.ink)
            }
            .padding(.top, 14)
            .accessibilityElement(children: .combine)

            Spacer(minLength: 0)

            HStack(spacing: 11) {
                HStack(spacing: 5) {
                    XeidDot(color: XeidColor.blue)
                    XeidDot(color: XeidColor.blue)
                    XeidDot(color: XeidColor.magenta)
                }
                .accessibilityHidden(true)
                Text(meta)
                    .xeidCaption()
            }
            .padding(.bottom, 22)
        }
        .padding(.top, 26)
        .padding(.horizontal, 22)
        .frame(maxWidth: .infinity, minHeight: 186, alignment: .topLeading)
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Gate grid
    // Two rows of two cells with collapsed hairlines: a top rule, right edges
    // on the left column, bottom edges on the first row. The resume strip's
    // top rule closes the grid.
    private var gateGrid: some View {
        VStack(spacing: 0) {
            XeidHairline()

            HStack(spacing: 0) {
                gate(.library, "Library", "Definition to counter.", "\(fallacyCount) fallacies",
                     rightEdge: true, bottomEdge: true) {
                    LibraryView()
                }
                gate(.flash, "Flash", "Sixty arguments. Sixty tells.", flashEyebrow,
                     rightEdge: false, bottomEdge: true) {
                    CardsStackView()
                }
            }
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 0) {
                gate(.quiz, "Quiz", "Sixty seconds. Three lives.", quizEyebrow,
                     rightEdge: true, bottomEdge: false) {
                    QuizView(gameManagerVM: GameManagerVM(stateModel: stateModel))
                }
                gate(.finder, "Finder", "Paste it. See it.", "On-device",
                     rightEdge: false, bottomEdge: false) {
                    FallacyFinderView()
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func gate<Destination: View>(_ glyph: XeidGlyph,
                                         _ title: String,
                                         _ line: String,
                                         _ eyebrow: String,
                                         rightEdge: Bool,
                                         bottomEdge: Bool,
                                         @ViewBuilder destination: @escaping () -> Destination) -> some View {
        NavigationLink {
            destination()
        } label: {
            XeidGateCell(glyph: glyph,
                         title: title,
                         line: line,
                         eyebrow: eyebrow,
                         rightEdge: rightEdge,
                         bottomEdge: bottomEdge)
        }
        .buttonStyle(XeidCellButtonStyle())
    }

    // MARK: Resume strip
    // Fills the rest of the screen above the tab bar; content centred
    private var resumeStrip: some View {
        VStack(spacing: 0) {
            XeidHairline()

            VStack(alignment: .leading, spacing: 13) {
                XeidEyebrow(text: "Pick up where you left off", color: XeidColor.secondary)

                if let target = resumeTarget {
                    NavigationLink {
                        FallacyDetailsView(exampleFallacy: target)
                    } label: {
                        HubResumeRow(title: resumeTitle)
                    }
                    .buttonStyle(XeidCellButtonStyle())
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - HubGreeting
// "Good evening, Fady" 14/300 0.04em secondary, or "Set your name" in blue
// with the edit glyph when there is no name. Presses shift to ink. The hit
// area is padded out to 44pt without moving the text.
private struct HubGreeting: View {
    let name: String
    let greeting: String

    @Environment(\.xeidPressed) private var pressed

    var body: some View {
        Group {
            if name.isEmpty {
                HStack(spacing: 8) {
                    Text("Set your name")
                        .font(XeidFont.caption)
                        .tracking(0.04 * 14)
                        .foregroundColor(pressed ? XeidColor.ink : XeidColor.blue)
                    XeidSymbol(glyph: .edit, size: 16, rule: false, tone: pressed ? .ink : .brand)
                }
            } else {
                Text(greeting)
                    .font(XeidFont.caption)
                    .tracking(0.04 * 14)
                    .foregroundColor(pressed ? XeidColor.ink : XeidColor.secondary)
            }
        }
        .lineLimit(1)
        .padding(.vertical, 15)
        .contentShape(Rectangle())
        .padding(.vertical, -15)
    }
}

// MARK: - HubResumeRow
// "Slippery Slope — fallacy 05 of 12" 17/1.4 with the forward glyph
private struct HubResumeRow: View {
    let title: String

    @Environment(\.xeidPressed) private var pressed

    private var color: Color {
        pressed ? XeidColor.secondary : XeidColor.ink
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Text(title)
                .font(XeidFont.body)
                .tracking(-0.01 * 17)
                .lineSpacing(17 * 0.19)
                .foregroundColor(color)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
            XeidInlineGlyph(glyph: .forward, size: 18, color: color)
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .contentShape(Rectangle())
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        FallaciesView()
    }
}
