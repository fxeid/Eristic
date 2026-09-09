//
//  RootView.swift
//  Eristic
//
//  Created by Fady A Eid on 9/3/26.
//

import SwiftUI

// MARK: - RootView
// The four-tab root. One NavigationStack holds whichever root screen the tab
// bar selects; the tab bar is a bottom safe-area inset of that root content,
// so it is part of the root screen and not of anything pushed on top of it.
// Pushed screens therefore fill the whole height and show their own back
// chevron, and the bar slides away with the root during the push, the way a
// UIKit tab bar does. Tabs only change while a root is showing, so a single
// stack behaves exactly like one stack per tab.
struct RootView: View {
    // MARK: Properties
    @State private var selection: RootTab

    init(initialTab: RootTab = .hub) {
        _selection = State(initialValue: initialTab)
    }

    // MARK: Body
    var body: some View {
        NavigationStack {
            ZStack {
                Group {
                    switch selection {
                    case .hub:
                        FallaciesView()
                    case .library:
                        LibraryView()
                    case .practice:
                        PracticeView()
                    case .you:
                        ProfileView()
                    }
                }
                .id(selection)
                .transition(XeidMotion.riseIn)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                XeidTabBar(selection: $selection)
            }
            .background(XeidColor.surface.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
        .tint(XeidColor.ink)
    }
}

// MARK: - Preview
#Preview {
    RootView()
}
