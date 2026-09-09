//
//  UserModel.swift
//  Eristic
//
//  Created by Fady A Eid on 11/20/23.
//

import Foundation

// Local account model — no credentials, just who is playing and their best score
struct UserModel: Codable {
    // Properties
    var displayName: String = ""
    var highestScore: Int = 0
}

// Decoded field by field, because Swift's synthesized decoder ignores the
// defaults above and throws on a missing key. Adding a property later would
// otherwise make every stored account unreadable.
extension UserModel {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? ""
        highestScore = try container.decodeIfPresent(Int.self, forKey: .highestScore) ?? 0
    }
}
