//
//  ProgressStore.swift
//  Eristic
//
//  Created by Fady A Eid on 9/3/26.
//

import Foundation
import Combine

// Per-fallacy quiz record: how many answers, how many right
struct FallacyStat: Codable {
    var correct: Int = 0
    var total: Int = 0

    var accuracy: Double {
        total == 0 ? 0 : Double(correct) / Double(total)
    }
}

// Everything the redesign shows that is not the name or the best score:
// the day streak, cards seen, texts scanned, the last fallacy opened and the
// per-fallacy quiz accuracy. Lives in UserDefaults as one JSON blob and is
// only ever touched on the main actor. Call `touchToday()` on launch; the
// record methods roll the day forward themselves when needed.
@MainActor
final class ProgressStore: ObservableObject {
    static let shared = ProgressStore()

    // MARK: Published state
    @Published private(set) var streakDays: Int
    private(set) var firstLaunch: Date
    @Published private(set) var cardsSeenTotal: Int
    @Published private(set) var cardsSeenToday: Int
    @Published private(set) var textsScanned: Int
    @Published private(set) var lastOpenedFallacyId: Int?
    @Published private(set) var fallacyStats: [Int: FallacyStat]

    // MARK: Storage
    private var lastActiveDay: Date?
    private let defaults: UserDefaults
    private let storageKey = "progressStore"
    private let calendar = Calendar.current

    // Decoded field by field so a missing key never wipes the whole record
    private struct Snapshot: Codable {
        var streakDays = 0
        var firstLaunch: Date?
        var lastActiveDay: Date?
        var cardsSeenTotal = 0
        var cardsSeenToday = 0
        var textsScanned = 0
        var lastOpenedFallacyId: Int?
        var fallacyStats: [String: FallacyStat] = [:]

        init() {}

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            streakDays = try container.decodeIfPresent(Int.self, forKey: .streakDays) ?? 0
            firstLaunch = try container.decodeIfPresent(Date.self, forKey: .firstLaunch)
            lastActiveDay = try container.decodeIfPresent(Date.self, forKey: .lastActiveDay)
            cardsSeenTotal = try container.decodeIfPresent(Int.self, forKey: .cardsSeenTotal) ?? 0
            cardsSeenToday = try container.decodeIfPresent(Int.self, forKey: .cardsSeenToday) ?? 0
            textsScanned = try container.decodeIfPresent(Int.self, forKey: .textsScanned) ?? 0
            lastOpenedFallacyId = try container.decodeIfPresent(Int.self, forKey: .lastOpenedFallacyId)
            fallacyStats = try container.decodeIfPresent([String: FallacyStat].self, forKey: .fallacyStats) ?? [:]
        }
    }

    // MARK: Init
    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        var snapshot = Snapshot()
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(Snapshot.self, from: data) {
            snapshot = decoded
        }

        streakDays = snapshot.streakDays
        cardsSeenTotal = snapshot.cardsSeenTotal
        cardsSeenToday = snapshot.cardsSeenToday
        textsScanned = snapshot.textsScanned
        lastOpenedFallacyId = snapshot.lastOpenedFallacyId
        lastActiveDay = snapshot.lastActiveDay
        fallacyStats = Dictionary(uniqueKeysWithValues: snapshot.fallacyStats.compactMap { key, value in
            Int(key).map { ($0, value) }
        })

        // Set once, the first time the store exists on this device
        if let first = snapshot.firstLaunch {
            firstLaunch = first
        } else {
            firstLaunch = Date()
            save()
        }
    }

    // MARK: Day keeping
    // Keeps a consecutive-day streak by calendar day: unchanged when today was
    // already counted, one more when yesterday was the last active day, back
    // to one when the gap is larger. A new day also resets today's card count.
    func touchToday() {
        let today = calendar.startOfDay(for: Date())

        if let last = lastActiveDay {
            let lastDay = calendar.startOfDay(for: last)
            if lastDay == today { return }

            let gap = calendar.dateComponents([.day], from: lastDay, to: today).day ?? Int.max
            streakDays = gap == 1 ? streakDays + 1 : 1
        } else {
            streakDays = 1
        }

        lastActiveDay = today
        cardsSeenToday = 0
        save()
    }

    // MARK: Recording
    func recordCardSeen() {
        touchToday()
        cardsSeenTotal += 1
        cardsSeenToday += 1
        save()
    }

    func recordTextScanned() {
        touchToday()
        textsScanned += 1
        save()
    }

    func recordFallacyOpened(id: Int) {
        touchToday()
        lastOpenedFallacyId = id
        save()
    }

    func recordQuizAnswer(fallacyId: Int, correct: Bool) {
        touchToday()
        var stat = fallacyStats[fallacyId] ?? FallacyStat()
        stat.total += 1
        if correct { stat.correct += 1 }
        fallacyStats[fallacyId] = stat
        save()
    }

    // MARK: Persistence
    private func save() {
        var snapshot = Snapshot()
        snapshot.streakDays = streakDays
        snapshot.firstLaunch = firstLaunch
        snapshot.lastActiveDay = lastActiveDay
        snapshot.cardsSeenTotal = cardsSeenTotal
        snapshot.cardsSeenToday = cardsSeenToday
        snapshot.textsScanned = textsScanned
        snapshot.lastOpenedFallacyId = lastOpenedFallacyId
        snapshot.fallacyStats = Dictionary(uniqueKeysWithValues: fallacyStats.map { (String($0.key), $0.value) })

        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
