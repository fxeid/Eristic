//
//  LocalAccount.swift
//  Eristic
//
//  Created by Fady A Eid on 11/25/23.
//

import Foundation

/// The one account on this device. There is no sign-in: it only remembers the
/// player's display name and their best quiz score.
final class LocalAccount {
    
    static let shared = LocalAccount()
    
    // MARK: - Properties
    private let userDefaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let accountKey = "localAccount"
    private let legacyUsersKey = "registeredUsers"   // storage used by the old log in screen
    private let namePromptedKey = "didAskForName"
    
    private var account: UserModel
    
    private init() {
        account = UserModel()
        loadAccount()
    }
    
    // MARK: - Display Name
    
    /// Optional — an empty name just means the greeting is shown without one.
    var displayName: String {
        get { account.displayName }
        set {
            account.displayName = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            saveAccount()
        }
    }
    
    /// True until the player has been asked for a name once, so the app asks on
    /// first launch and never nags after that.
    var shouldAskForName: Bool {
        account.displayName.isEmpty && !userDefaults.bool(forKey: namePromptedKey)
    }
    
    /// Call once the player has answered the name prompt, whether or not they gave one.
    func markAskedForName() {
        userDefaults.set(true, forKey: namePromptedKey)
    }
    
    // MARK: - High Score
    
    var highestScore: Int { account.highestScore }
    
    /// Stores `score` only when it beats the current best.
    /// - Returns: `true` when a new record was saved.
    @discardableResult
    func saveHighScore(_ score: Int) -> Bool {
        guard score > account.highestScore else { return false }
        
        account.highestScore = score
        saveAccount()
        return true
    }
    
    // MARK: - Private Helper Methods
    
    private func loadAccount() {
        guard let accountData = userDefaults.data(forKey: accountKey) else {
            // Nothing stored yet: bring over the name and best score from the old
            // username/password accounts, if this device has any.
            if let migratedAccount = migratedLegacyAccount() {
                account = migratedAccount
                saveAccount()
            }
            
            // Only once the migrated account is safely stored, and whether or not
            // the migration worked, since that data held plain text passwords.
            userDefaults.removeObject(forKey: legacyUsersKey)
            return
        }
        
        guard let storedAccount = try? JSONDecoder().decode(UserModel.self, from: accountData) else {
            // Unreadable, so play as a guest this launch rather than saving over
            // it. The stored bytes stay put in case a later version can read them.
            return
        }
        
        account = storedAccount
    }
    
    private func migratedLegacyAccount() -> UserModel? {
        // Mirrors only the fields worth keeping from the old UserModel. Both are
        // optional so one incomplete record cannot fail the whole array.
        struct LegacyUser: Decodable {
            let username: String?
            let highestScore: Int?
        }
        
        guard let legacyData = userDefaults.data(forKey: legacyUsersKey),
              let legacyUsers = try? JSONDecoder().decode([LegacyUser].self, from: legacyData),
              // The best player keeps the account, so the name and the score
              // belong to the same person.
              let bestUser = legacyUsers.max(by: { ($0.highestScore ?? 0) < ($1.highestScore ?? 0) }) else {
            return nil
        }
        
        return UserModel(displayName: bestUser.username ?? "",
                         highestScore: bestUser.highestScore ?? 0)
    }
    
    private func saveAccount() {
        do {
            let accountData = try encoder.encode(account)
            userDefaults.set(accountData, forKey: accountKey)
        } catch {
            // Log the error
            print("Error encoding local account: \(error.localizedDescription)")
            
            // Return without saving anything
            return
        }
    }
}
