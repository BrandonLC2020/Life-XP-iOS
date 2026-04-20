import Foundation
import Combine
import SwiftUI

class UserViewModel: ObservableObject {
    @Published var user: LifeXPUser = LifeXPUser() {
        didSet {
            saveUser()
        }
    }

    @Published var habits: [Habit] = [] {
        didSet {
            saveHabits()
        }
    }

    @Published var goals: [Goal] = [] {
        didSet {
            saveGoals()
        }
    }

    @Published var showingMilestoneReward = false
    @Published var lastMilestoneMessage = ""

    // Level Up State
    @Published var showingLevelUp = false
    @Published var lastLeveledUpTo = 0

    // Shop Items
    @Published var shopItems: [Item] = [
        Item(
            name: "Dumbbells",
            description: "+5 Strength",
            icon: "dumbbell.fill",
            price: 50,
            statBoost: .strength,
            boostAmount: 5
        ),
        Item(
            name: "Encyclopedia",
            description: "+5 Intelligence",
            icon: "book.fill",
            price: 75,
            statBoost: .intelligence,
            boostAmount: 5
        ),
        Item(
            name: "Herbal Tea",
            description: "+5 Vitality",
            icon: "cup.and.saucer.fill",
            price: 30,
            statBoost: .vitality,
            boostAmount: 5
        ),
        Item(
            name: "Stylish Fedora",
            description: "+5 Charisma",
            icon: "hat.widebrim.fill",
            price: 100,
            statBoost: .charisma,
            boostAmount: 5
        )
    ]

    // CloudKit sync state
    @Published var isSyncing = false
    @Published var lastCloudSync: Date?

    // Conversion Factors
    private let stepsToXP = 100 // 100 steps = 1 XP
    private let kcalToXP = 10   // 10 kcal = 1 XP
    private let waterToXP = 0.25 // 0.25L (1 cup) = 5 XP
    private let sleepToXP = 1.0  // 1 hour = 10 XP

    init(skipCloudSync: Bool = false) {
        loadUser()
        loadHabits()
        loadGoals()
        if !skipCloudSync {
            fetchFromCloud()
        }
    }

    func fetchFromCloud() {
        isSyncing = true

        CloudKitManager.shared.fetchUserStats { [weak self] result in
            DispatchQueue.main.async {
                self?.isSyncing = false
                switch result {
                case .success(let cloudUser):
                    // Simple merge: take the one with more total XP/level
                    if cloudUser.level > self?.user.level ?? 0 ||
                       (cloudUser.level == self?.user.level ?? 0 && cloudUser.experience > self?.user.experience ?? 0) {
                        self?.user = cloudUser
                        self?.lastCloudSync = Date()
                    }
                case .failure(let error):
                    print("CloudKit Fetch Error: \(error.localizedDescription)")
                }
            }
        }

        CloudKitManager.shared.fetchHabits { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let cloudHabits):
                    if !cloudHabits.isEmpty {
                        self?.habits = cloudHabits
                    }
                case .failure(let error):
                    print("CloudKit Habits Fetch Error: \(error.localizedDescription)")
                }
            }
        }

        CloudKitManager.shared.fetchGoals { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let cloudGoals):
                    if !cloudGoals.isEmpty {
                        self?.goals = cloudGoals
                    }
                case .failure(let error):
                    print("CloudKit Goals Fetch Error: \(error.localizedDescription)")
                }
            }
        }
    }

    func uploadToCloud() {
        isSyncing = true
        CloudKitManager.shared.saveUserStats(user) { [weak self] result in
            DispatchQueue.main.async {
                self?.isSyncing = false
                if case .success = result {
                    self?.lastCloudSync = Date()
                }
            }
        }

        CloudKitManager.shared.saveHabits(habits) { error in
            if let error = error {
                print("CloudKit Habits Upload Error: \(error.localizedDescription)")
            }
        }

        CloudKitManager.shared.saveGoals(goals) { error in
            if let error = error {
                print("CloudKit Goals Upload Error: \(error.localizedDescription)")
            }
        }
    }

    func syncHealthData(steps: Int, calories: Double, sleep: Double, water: Double) {
        user.checkNewDay()

        let newSteps = steps - user.lastSyncedSteps
        let newCalories = calories - user.lastSyncedCalories
        let newSleep = sleep - user.lastSyncedSleep
        let newWater = water - user.lastSyncedWater

        var totalXPGained = 0

        // Steps
        if newSteps >= stepsToXP {
            let experiencePoints = newSteps / stepsToXP
            totalXPGained += experiencePoints
            user.lastSyncedSteps += experiencePoints * stepsToXP
        }

        // Calories
        if newCalories >= Double(kcalToXP) {
            let experiencePoints = Int(newCalories / Double(kcalToXP))
            totalXPGained += experiencePoints
            user.lastSyncedCalories += Double(experiencePoints * kcalToXP)
        }

        // Water
        if newWater >= waterToXP {
            let experiencePoints = Int(newWater / waterToXP) * 5
            totalXPGained += experiencePoints
            user.lastSyncedWater += Double(Int(newWater / waterToXP)) * waterToXP
            user.intelligence += 1 // hydration helps the brain!
        }

        // Sleep
        if newSleep >= sleepToXP {
            let experiencePoints = Int(newSleep / sleepToXP) * 10
            totalXPGained += experiencePoints
            user.lastSyncedSleep += Double(Int(newSleep / sleepToXP)) * sleepToXP
            user.vitality += 1 // sleep restores vitality
        }

        if totalXPGained > 0 {
            addExperience(totalXPGained)

            // Random physical boost
            if Int.random(in: 1...5) == 1 {
                user.strength += 1
            }

            uploadToCloud() // Auto-sync to cloud when XP is gained
        }

        user.lastSyncDate = Date()
    }

    private func saveUser() {
        if let encoded = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(encoded, forKey: "LifeXPUser")
            // Don't auto-upload every single change to avoid CloudKit rate limits,
            // but syncHealthData and completeHabit will trigger it.
        }
    }

    private func loadUser() {
        if let data = UserDefaults.standard.data(forKey: "LifeXPUser"),
           let decoded = try? JSONDecoder().decode(LifeXPUser.self, from: data) {
            user = decoded
        }
    }

    private func saveHabits() {
        if let encoded = try? JSONEncoder().encode(habits) {
            UserDefaults.standard.set(encoded, forKey: "LifeXPHabits")
        }
    }

    private func saveGoals() {
        if let encoded = try? JSONEncoder().encode(goals) {
            UserDefaults.standard.set(encoded, forKey: "LifeXPGoals")
        }
    }

    private func loadGoals() {
        if let data = UserDefaults.standard.data(forKey: "LifeXPGoals"),
           let decoded = try? JSONDecoder().decode([Goal].self, from: data) {
            goals = decoded
        }
    }

    private func loadHabits() {
        if let data = UserDefaults.standard.data(forKey: "LifeXPHabits"),
           let decoded = try? JSONDecoder().decode([Habit].self, from: data) {
            habits = decoded
        } else {
            // Default habits if none exist
            habits = [
                Habit(title: "Drink Water", description: "Stay hydrated", xpReward: 10, frequency: .daily),
                Habit(title: "Morning Run", description: "30-minute jog", xpReward: 50, frequency: .daily),
                Habit(title: "Read for 30m", description: "Expand your mind", xpReward: 30, frequency: .daily)
            ]
        }
    }

    func addHabit(title: String, description: String, experiencePoints: Int) {
        let newHabit = Habit(
            title: title,
            description: description,
            xpReward: experiencePoints,
            frequency: .daily
        )
        habits.append(newHabit)
        saveHabits()
        uploadToCloud()
    }

    func deleteHabit(at offsets: IndexSet) {
        habits.remove(atOffsets: offsets)
        saveHabits()
        uploadToCloud()
    }

    func completeHabit(_ habit: Habit) {
        if let index = habits.firstIndex(where: { $0.id == habit.id }) {
            habits[index].lastCompletedDate = Date()
            addExperience(habit.xpReward)
            // Reward some gold too!
            user.gold += habit.xpReward / 2
            saveHabits()
            uploadToCloud()
        }
    }

    func buyItem(_ item: Item) {
        guard user.gold >= item.price else { return }

        user.gold -= item.price
        user.inventory.append(item)

        // Apply stat boost immediately
        if let boost = item.statBoost {
            switch boost {
            case .strength: user.strength += item.boostAmount
            case .intelligence: user.intelligence += item.boostAmount
            case .vitality: user.vitality += item.boostAmount
            case .charisma: user.charisma += item.boostAmount
            }
        }

        saveUser()
        uploadToCloud()
    }

    func addGoal(_ goal: Goal) {
        goals.append(goal)
        uploadToCloud()
    }

    func deleteGoal(at offsets: IndexSet) {
        goals.remove(atOffsets: offsets)
        uploadToCloud()
    }

    func updateManualProgress(goalId: UUID, newValue: Double) {
        guard let index = goals.firstIndex(where: { $0.id == goalId }) else { return }
        goals[index].currentProgress = newValue
        checkMilestones(for: goals[index])
        uploadToCloud()
    }

    func updateGoalPhoto(goalId: UUID, photoData: Data?) {
        guard let index = goals.firstIndex(where: { $0.id == goalId }) else { return }
        goals[index].photoData = photoData
    }

    private func checkMilestones(for goal: Goal) {
        // Full implementation added in Task 5
    }

    func addExperience(_ amount: Int) {
        user.experience += amount

        // Level up logic
        while user.experience >= user.xpToNextLevel {
            user.experience -= user.xpToNextLevel
            user.level += 1
            lastLeveledUpTo = user.level

            // Bonus stats on level up
            user.strength += 1
            user.intelligence += 1
            user.vitality += 1

            // Bonus gold for reaching new heights
            user.gold += user.level * 20

            // Trigger animation state
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.showingLevelUp = true
            }
        }
    }
}
