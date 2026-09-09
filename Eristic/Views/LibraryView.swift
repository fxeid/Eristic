//
//  LibraryView.swift
//  Eristic
//
//  Created by Fady A Eid on 9/3/26.
//

import SwiftUI

// MARK: - LibraryView
// The twelve, two to a row. Both a tab root (lockup in the top bar) and a
// screen pushed from the hub gate (back chevron). `isRoot` says which; when
// it is left at its default the view also checks whether it was pushed, so
// the root from RootView and the push from the hub both come out right.
struct LibraryView: View {
    // MARK: Properties
    var isRoot: Bool

    @Environment(\.isPresented) private var isPresented

    init(isRoot: Bool = false) {
        self.isRoot = isRoot
    }

    private var showsBack: Bool {
        !isRoot && isPresented
    }

    // Rows of two in FallaciesList order
    private var rows: [[Fallacy]] {
        let all = FallaciesList.fallacies
        return stride(from: 0, to: all.count, by: 2).map { start in
            Array(all[start..<min(start + 2, all.count)])
        }
    }

    // MARK: Body
    var body: some View {
        XeidScreen {
            XeidTopBar {
                if showsBack {
                    XeidBackButton()
                } else {
                    XeidLockup()
                }
            } trailing: {
                XeidBarLabel(text: "The twelve")
            }

            // Title block, 90pt, text at the top
            VStack(alignment: .leading, spacing: 0) {
                Text("Every informal fallacy")
                    .xeidTitle()
                Text("worth knowing.")
                    .font(XeidFont.inter(30, weight: .regular, relativeTo: .title))
                    .tracking(-0.035 * 30)
                    .foregroundColor(XeidColor.ink)
            }
            .accessibilityElement(children: .combine)
            .padding(.horizontal, 22)
            .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)

            // The grid scrolls; hairlines collapse: a top rule, right edges on
            // the left column, bottom edges on every row but the last
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    XeidHairline()

                    ForEach(rows.indices, id: \.self) { rowIndex in
                        let row = rows[rowIndex]
                        HStack(spacing: 0) {
                            ForEach(row) { fallacy in
                                cell(fallacy,
                                     rightEdge: fallacy.id == row.first?.id && row.count == 2,
                                     bottomEdge: rowIndex < rows.count - 1)
                            }
                            if row.count == 1 {
                                Color.clear.frame(maxWidth: .infinity)
                            }
                        }
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    // MARK: Cell
    // The detail page records the fallacy as last opened when it appears, so
    // the link carries no gesture of its own
    private func cell(_ fallacy: Fallacy, rightEdge: Bool, bottomEdge: Bool) -> some View {
        NavigationLink {
            FallacyDetailsView(exampleFallacy: fallacy)
        } label: {
            LibraryCell(fallacy: fallacy, rightEdge: rightEdge, bottomEdge: bottomEdge)
        }
        .buttonStyle(XeidCellButtonStyle())
    }
}

// MARK: - LibraryCell
// 138pt white cell, padding 16/16/14: XeidSymbol 54 at the top left, the
// name 19/300 pinned to the bottom. Press flips the background to surface.
private struct LibraryCell: View {
    let fallacy: Fallacy
    let rightEdge: Bool
    let bottomEdge: Bool

    @Environment(\.xeidPressed) private var pressed

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            XeidSymbol(glyph: .fallacy(id: fallacy.id), size: 54)

            Spacer(minLength: 0)

            Text(fallacy.title)
                .font(XeidFont.inter(19, relativeTo: .title3))
                .tracking(-0.01 * 19)
                .lineSpacing(19 * 0.04)
                .foregroundColor(XeidColor.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(EdgeInsets(top: 16, leading: 16, bottom: 14, trailing: 16))
        .frame(maxWidth: .infinity, minHeight: 138, maxHeight: .infinity, alignment: .topLeading)
        .background(pressed ? XeidColor.surface : XeidColor.cell)
        .overlay(alignment: .trailing) {
            if rightEdge {
                Rectangle().fill(XeidColor.hairline).frame(width: 1)
            }
        }
        .overlay(alignment: .bottom) {
            if bottomEdge {
                XeidHairline()
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Preview
#Preview("Root") {
    NavigationStack {
        LibraryView(isRoot: true)
    }
}

#Preview("Pushed") {
    NavigationStack {
        LibraryView()
    }
}
