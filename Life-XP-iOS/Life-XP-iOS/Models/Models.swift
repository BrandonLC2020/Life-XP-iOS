import Foundation

struct LifeXPUser: Codable {
    var name: String = "Adventurer"
    var level: Int = 1
    var experience: Int = 0
    var gold: Int = 100 // Starting gold

    // Stats
    var strength: Int = 10
    var intelligence: Int = 10
    var vitality: Int = 10
    var charisma: Int = 10

    var inventory: [Item] = []

    // Tracking sync to avoid double-counting
    var lastSyncedSteps: Int = 0
    var lastSyncedCalories: Double = 0.0
    var lastSyncedSleep: Double = 0.0
    var lastSyncedWater: Double = 0.0
    var lastSyncDate: Date?

    // Threshold calculation
    var xpToNextLevel: Int {
        return level * 100
    }

    var xpProgress: Double {
        return Double(experience) / Double(xpToNextLevel)
    }

    // Reset sync data if it's a new day
    mutating func checkNewDay() {
        guard let lastDate = lastSyncDate else {
            lastSyncDate = Date()
            return
        }

        if !Calendar.current.isDateInToday(lastDate) {
            lastSyncedSteps = 0
            lastSyncedCalories = 0.0
            lastSyncedSleep = 0.0
            lastSyncedWater = 0.0
            lastSyncDate = Date()
        }
    }
}

struct Item: Identifiable, Codable {
    var id = UUID()
    var name: String
    var description: String
    var icon: String
    var price: Int
    var statBoost: StatType?
    var boostAmount: Int = 0
}

enum StatType: String, Codable, CaseIterable {
    case strength, intelligence, vitality, charisma
}

struct Habit: Identifiable, Codable {
    var id = UUID()
    var title: String
    var description: String
    var xpReward: Int
    var frequency: HabitFrequency
    var lastCompletedDate: Date?
    var isCompletedToday: Bool {
        guard let lastCompletedDate = lastCompletedDate else { return false }
        return Calendar.current.isDateInToday(lastCompletedDate)
    }
}

enum HabitFrequency: String, Codable, CaseIterable {
    case daily, weekly, custom
}
