import Testing
import Foundation
@testable import Life_XP_iOS

// MARK: - Goal CRUD Tests

@Suite("Goal CRUD")
struct GoalCRUDTests {

    init() {
        UserDefaults.standard.removeObject(forKey: "LifeXPUser")
        UserDefaults.standard.removeObject(forKey: "LifeXPHabits")
        UserDefaults.standard.removeObject(forKey: "LifeXPGoals")
    }

    @MainActor private func makeVM() -> UserViewModel {
        let vm = UserViewModel(skipCloudSync: true)
        vm.user = LifeXPUser()
        vm.habits = []
        vm.goals = []
        return vm
    }

    private func makeGoal(
        title: String = "Run a Marathon",
        category: GoalCategory = .fitness,
        trackingType: GoalTrackingType = .manual,
        targetValue: Double = 100
    ) -> Goal {
        Goal(
            title: title,
            description: "Test goal",
            category: category,
            trackingType: trackingType,
            targetValue: targetValue
        )
    }

    @Test @MainActor func addGoal_appendsGoalToList() {
        let vm = makeVM()
        let goal = makeGoal()
        vm.addGoal(goal)
        #expect(vm.goals.count == 1)
        #expect(vm.goals[0].title == "Run a Marathon")
    }

    @Test @MainActor func addGoal_multipleGoalsAccumulate() {
        let vm = makeVM()
        vm.addGoal(makeGoal(title: "Goal A"))
        vm.addGoal(makeGoal(title: "Goal B"))
        #expect(vm.goals.count == 2)
    }

    @Test @MainActor func deleteGoal_removesCorrectGoal() {
        let vm = makeVM()
        vm.addGoal(makeGoal(title: "Alpha"))
        vm.addGoal(makeGoal(title: "Beta"))
        vm.deleteGoal(at: IndexSet(integer: 0))
        #expect(vm.goals.count == 1)
        #expect(vm.goals[0].title == "Beta")
    }

    @Test @MainActor func updateManualProgress_setsCurrentProgress() {
        let vm = makeVM()
        let goal = makeGoal(targetValue: 100)
        vm.addGoal(goal)
        vm.updateManualProgress(goalId: goal.id, newValue: 50)
        #expect(vm.goals[0].currentProgress == 50)
    }

    @Test @MainActor func updateManualProgress_doesNothingForUnknownId() {
        let vm = makeVM()
        vm.addGoal(makeGoal(targetValue: 100))
        let unknownId = UUID()
        vm.updateManualProgress(goalId: unknownId, newValue: 50)
        #expect(vm.goals[0].currentProgress == 0)
    }
}
