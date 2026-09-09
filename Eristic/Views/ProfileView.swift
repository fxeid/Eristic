//
//  ProfileView.swift
//  Eristic
//
//  Created by Fady A Eid on 9/3/26.
//

import SwiftUI

// MARK: - ProfileView
// The You tab: the name on this phone, since when and the streak, the
// three counts, where the player stands per fallacy from the quiz record,
// and the XEID footer. EDIT opens the same rename screen as the hub.
struct ProfileView: View {
    // MARK: Properties
    @StateObject private var stateModel = StateModel()
    @ObservedObject private var progress = ProgressStore.shared
    @State private var isRenaming = false

    // MARK: Derived state
    private var name: String { stateModel.currentUserName }

    // "Since 20 Nov 2023 · 14-day streak"; the streak only once it is one
    private var sinceLine: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        var line = "Since \(formatter.string(from: progress.firstLaunch))"
        if progress.streakDays >= 2 {
            line += " \u{00B7} \(progress.streakDays)-day streak"
        }
        return line
    }

    // Every fallacy with at least one quiz answer, best first
    private var standings: [Standing] {
        let rows = progress.fallacyStats
            .filter { $0.value.total > 0 }
            .compactMap { id, stat -> Standing? in
                guard let fallacy = FallaciesList.fallacies.first(where: { $0.id == id }) else { return nil }
                return Standing(id: id, title: fallacy.title, accuracy: stat.accuracy)
            }
            .sorted {
                if $0.accuracy != $1.accuracy { return $0.accuracy > $1.accuracy }
                return $0.id < $1.id
            }
        // With three or more, the last one is the weakest
        guard rows.count >= 3, let last = rows.last else { return rows }
        return rows.dropLast() + [Standing(id: last.id, title: last.title, accuracy: last.accuracy, weakest: true)]
    }

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    // MARK: Body
    var body: some View {
        XeidScreen {
            XeidTopBar {
                XeidBarLabel(text: "On this phone only")
            } trailing: {
                Button {
                    isRenaming = true
                } label: {
                    XeidBarLabel(text: "Edit", action: true, wide: false)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(XeidCellButtonStyle())
                .accessibilityLabel("Edit name")
            }

            ScrollView {
                VStack(spacing: 0) {
                    nameBlock
                    statStrip
                    mastery
                }
            }

            footer
        }
        // The same full screen name entry as the hub
        .fullScreenCover(isPresented: $isRenaming) {
            WelcomeView(
                mode: .rename,
                currentName: stateModel.currentUserName,
                onSave: { newName in
                    stateModel.updateName(newName)
                    isRenaming = false
                },
                onCancel: { isRenaming = false }
            )
        }
    }

    // MARK: Name block
    private var nameBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(name.isEmpty ? "Set your name" : name)
                .xeidDisplay()
            Text(sinceLine)
                .font(XeidFont.secondary)
                .foregroundColor(XeidColor.secondary)
                .padding(.top, 13)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(EdgeInsets(top: 12, leading: 24, bottom: 28, trailing: 24))
    }

    // MARK: Stat strip
    // Three white cells between hairlines: best score, cards seen, texts scanned
    private var statStrip: some View {
        HStack(spacing: 0) {
            StatCell(value: "\(stateModel.currentUserHighScore)", label: "Best score", rightEdge: true)
            StatCell(value: "\(progress.cardsSeenTotal)", label: "Cards seen", rightEdge: true)
            StatCell(value: "\(progress.textsScanned)", label: "Texts scanned", rightEdge: false)
        }
        .fixedSize(horizontal: false, vertical: true)
        .background(XeidColor.cell)
        .overlay(alignment: .top) { XeidHairline() }
        .overlay(alignment: .bottom) { XeidHairline() }
    }

    // MARK: Where you stand
    private var mastery: some View {
        VStack(alignment: .leading, spacing: 18) {
            XeidEyebrow(text: "Where you stand", dot: XeidColor.blue)

            if standings.isEmpty {
                Text("Play a quiz to see where you stand.")
                    .xeidBody(XeidColor.secondary)
            } else {
                VStack(alignment: .leading, spacing: 27) {
                    ForEach(standings) { standing in
                        StandingRow(standing: standing)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(EdgeInsets(top: 24, leading: 24, bottom: 24, trailing: 24))
    }

    // MARK: Footer
    private var footer: some View {
        HStack(spacing: 12) {
            CraftedByXeid()
            Spacer(minLength: 0)
            Text("v\(version)")
                .xeidCaption()
        }
        .padding(EdgeInsets(top: 16, leading: 24, bottom: 16, trailing: 24))
        .overlay(alignment: .top) { XeidHairline() }
    }
}

// MARK: - Standing
// One fallacy's quiz accuracy on this phone
private struct Standing: Identifiable {
    let id: Int
    let title: String
    let accuracy: Double
    var weakest = false

    // "solid" from three right in four; "weakest" for the lowest of three or more
    var state: String {
        if weakest { return "weakest" }
        return accuracy >= 0.75 ? "solid" : "getting there"
    }
}

// MARK: - StatCell
// Value 31/300 over a 12/400 label, 20/18 padding, optional right hairline
private struct StatCell: View {
    let value: String
    let label: String
    let rightEdge: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(value)
                .xeidText(31, weight: .light, tracking: -0.03, relativeTo: .title)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .xeidEyebrow(XeidColor.secondary, wide: false)
                .lineSpacing(XeidFont.lineSpacing(XeidFont.eyebrowSize, lineHeight: 1.3))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(EdgeInsets(top: 20, leading: 18, bottom: 20, trailing: 18))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .overlay(alignment: .trailing) {
            if rightEdge {
                Rectangle().fill(XeidColor.hairline).frame(width: 1)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - StandingRow
// Name and state word over a 3pt bar; the weakest one reads in ink with a
// magenta bar
private struct StandingRow: View {
    let standing: Standing

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text(standing.title)
                    .font(XeidFont.body)
                    .foregroundColor(XeidColor.ink)
                Spacer(minLength: 0)
                Text(standing.state)
                    .font(XeidFont.body)
                    .foregroundColor(standing.weakest ? XeidColor.ink : XeidColor.secondary)
            }
            XeidProgressBar(fraction: standing.accuracy,
                            fill: standing.weakest ? XeidColor.magenta : XeidColor.blue)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(standing.title), \(standing.state), \(Int((standing.accuracy * 100).rounded())) percent")
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        ProfileView()
    }
}
