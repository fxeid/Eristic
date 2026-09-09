//
//  StateModel.swift
//  Eristic
//
//  Created by Fady A Eid on 11/23/23.
//

import Foundation
import Observation

// A class representing the state model of the application
final class StateModel: ObservableObject {
    // Current player's name, empty until they set one
    @Published private(set) var currentUserName: String
    
    // Published property for the current user's high score
    @Published private(set) var currentUserHighScore: Int
    
    // Initialize the state model
    init() {
        // Read the name and best score from the local account on this device
        currentUserName = LocalAccount.shared.displayName
        currentUserHighScore = LocalAccount.shared.highestScore
    }
    
    // Store a new name on the local account. An empty name is allowed: it puts
    // the player back to being greeted without one.
    func updateName(_ name: String) {
        LocalAccount.shared.displayName = name
        currentUserName = LocalAccount.shared.displayName
    }
    
    // Store a score on the local account, keeping the published copy in step.
    // Both halves live here so no caller can update one and forget the other.
    func recordScore(_ score: Int) {
        guard LocalAccount.shared.saveHighScore(score) else { return }
        
        currentUserHighScore = LocalAccount.shared.highestScore
    }
}
