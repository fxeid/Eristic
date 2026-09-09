//
//  EristicApp.swift
//  Eristic
//
//  Created by Fady A Eid on 11/6/23.
//

import SwiftUI

@main
struct EristicApp: App {
    init() {
        // Roll the day streak and today's card count forward on every launch
        ProgressStore.shared.touchToday()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
