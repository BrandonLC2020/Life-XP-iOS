import Foundation

extension LifeXPUser {
    static let preview = LifeXPUser(
        name: "Epic Adventurer",
        level: 5,
        experience: 250,
        strength: 15,
        intelligence: 12,
        vitality: 18,
        charisma: 10,
        lastSyncedSteps: 5000,
        lastSyncedCalories: 300.0,
        lastSyncedSleep: 7.5,
        lastSyncedWater: 1.5,
        lastSyncDate: Date()
    )
}

extension Habit {
    static let previewHabits = [
        Habit(title: "Hydrate", description: "Drink 2L of water", xpReward: 20, frequency: .daily),
        Habit(
            title: "Morning Sprint",
            description: "Fast jog for 15m",
            xpReward: 40,
            frequency: .daily,
            lastCompletedDate: Date()
        ),
        Habit(title: "Meditation", description: "10m mindfulness", xpReward: 15, frequency: .daily)
    ]
}

extension UserViewModel {
    static var preview: UserViewModel {
        let previewVM = UserViewModel()
        previewVM.user = .preview
        previewVM.habits = Habit.previewHabits
        return previewVM
    }
}
