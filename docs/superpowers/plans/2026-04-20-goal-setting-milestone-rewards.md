# Goal Setting and Milestone Rewards Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Goal Setting and Milestone Rewards system where users create long-term goals (HealthKit-tracked or manual), watch cumulative progress, and earn tiered XP/Gold/stat rewards at 25%, 50%, 75%, and 100% milestones.

**Architecture:** Follows the existing MVVM pattern — new models in `Models.swift`, new state + business logic in `UserViewModel`, two new range-query methods in `HealthKitManager`, two new CloudKit sync methods in `CloudKitManager`, and three new SwiftUI views wired into a new Goals tab in `ContentView`.

**Tech Stack:** Swift, SwiftUI, HealthKit, CloudKit, UserDefaults, PhotosUI, Swift Testing

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `Life-XP-iOS/Life-XP-iOS/Models/Models.swift` | Modify | Add `GoalCategory`, `GoalTrackingType`, `Goal` |
| `Life-XP-iOS/Life-XP-iOS/ViewModels/UserViewModel.swift` | Modify | Goal CRUD, milestone logic, HealthKit refresh |
| `Life-XP-iOS/Life-XP-iOS/Managers/HealthKitManager.swift` | Modify | Cumulative date-range step/calorie queries |
| `Life-XP-iOS/Life-XP-iOS/Managers/CloudKitManager.swift` | Modify | `saveGoals` / `fetchGoals` |
| `Life-XP-iOS/Life-XP-iOS/Models/PreviewData.swift` | Modify | Sample `Goal` data for SwiftUI previews |
| `Life-XP-iOS/Life-XP-iOS/Views/GoalsView.swift` | Create | Goal list, `GoalRow`, milestone alert |
| `Life-XP-iOS/Life-XP-iOS/Views/AddGoalView.swift` | Create | New goal form sheet |
| `Life-XP-iOS/Life-XP-iOS/Views/GoalDetailView.swift` | Create | Goal detail, progress logging, photo picker |
| `Life-XP-iOS/Life-XP-iOS/ContentView.swift` | Modify | Add Goals tab; trigger HealthKit goal refresh |
| `Life-XP-iOS/Life-XP-iOSTests/LifeXPiOSTests.swift` | Modify | Tests for goal CRUD and milestone logic |

All `xcodebuild` commands run from `Life-XP-iOS/Life-XP-iOS/` (the directory containing `Life-XP-iOS.xcodeproj`).

---

## Task 1: Add Goal Data Models

**Files:**
- Modify: `Life-XP-iOS/Life-XP-iOS/Life-XP-iOS/Models/Models.swift`

- [ ] **Step 1: Add the three new types to the end of Models.swift**

Append after the closing brace of `HabitFrequency`:

```swift
enum GoalCategory: String, Codable, CaseIterable {
    case fitness
    case wellness
    case learning
    case financial
    case social

    var icon: String {
        switch self {
        case .fitness:   return "figure.run"
        case .wellness:  return "heart.fill"
        case .learning:  return "book.fill"
        case .financial: return "banknote.fill"
        case .social:    return "person.2.fill"
        }
    }

    var displayName: String { rawValue.capitalized }
}

enum GoalTrackingType: String, Codable, CaseIterable {
    case manual
    case steps
    case calories

    var displayName: String {
        switch self {
        case .manual:   return "Manual"
        case .steps:    return "Steps (HealthKit)"
        case .calories: return "Calories (HealthKit)"
        }
    }

    var unit: String {
        switch self {
        case .manual:   return ""
        case .steps:    return "steps"
        case .calories: return "kcal"
        }
    }
}

struct Goal: Identifiable, Codable {
    var id: UUID = UUID()
    var title: String
    var description: String
    var category: GoalCategory
    var trackingType: GoalTrackingType
    var targetValue: Double
    var currentProgress: Double = 0.0
    var startDate: Date = Date()
    var targetDate: Date?
    var notes: String?
    var photoData: Data?
    var isCompleted: Bool = false
    var awardedMilestones: Set<Int> = []

    var progressFraction: Double {
        guard targetValue > 0 else { return 0 }
        return min(currentProgress / targetValue, 1.0)
    }

    var progressPercent: Int {
        Int(progressFraction * 100)
    }
}
```

- [ ] **Step 2: Build to confirm models compile**

```bash
cd Life-XP-iOS/Life-XP-iOS && xcodebuild -project Life-XP-iOS.xcodeproj -scheme Life-XP-iOS -destination 'platform=iOS Simulator,name=iPhone 16e' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add Life-XP-iOS/Life-XP-iOS/Models/Models.swift
git commit -m "feat: add Goal, GoalCategory, GoalTrackingType models"
```

---

## Task 2: Write Failing Tests for UserViewModel Goal CRUD

**Files:**
- Modify: `Life-XP-iOS/Life-XP-iOSTests/LifeXPiOSTests.swift`

- [ ] **Step 1: Add `"LifeXPGoals"` cleanup to the existing `UserViewModelTests.init()`**

Find the existing `init()` in `UserViewModelTests` and add the goals key:

```swift
init() {
    UserDefaults.standard.removeObject(forKey: "LifeXPUser")
    UserDefaults.standard.removeObject(forKey: "LifeXPHabits")
    UserDefaults.standard.removeObject(forKey: "LifeXPGoals")
}
```

- [ ] **Step 2: Append a new `GoalCRUDTests` suite at the end of the test file**

```swift
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
```

- [ ] **Step 3: Run tests to confirm they fail**

```bash
cd Life-XP-iOS/Life-XP-iOS && xcodebuild test -project Life-XP-iOS.xcodeproj -scheme Life-XP-iOS -destination 'platform=iOS Simulator,name=iPhone 16e' 2>&1 | grep -E "(error:|FAILED|addGoal|deleteGoal|updateManual)"
```

Expected: errors referencing `addGoal`, `deleteGoal`, `updateManualProgress` not found on `UserViewModel`, and `goals` property not found.

---

## Task 3: Implement UserViewModel Goal CRUD

**Files:**
- Modify: `Life-XP-iOS/Life-XP-iOS/Life-XP-iOS/ViewModels/UserViewModel.swift`

- [ ] **Step 1: Add goals published state after the `habits` published property (around line 12)**

```swift
@Published var goals: [Goal] = [] {
    didSet {
        saveGoals()
    }
}

@Published var showingMilestoneReward = false
@Published var lastMilestoneMessage = ""
```

- [ ] **Step 2: Add `loadGoals()` call in `init` (after `loadHabits()`)**

```swift
init(skipCloudSync: Bool = false) {
    loadUser()
    loadHabits()
    loadGoals()
    if !skipCloudSync {
        fetchFromCloud()
    }
}
```

- [ ] **Step 3: Add goals fetch to `fetchFromCloud()` — append inside the method after the existing `fetchHabits` call**

```swift
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
```

- [ ] **Step 4: Add goals upload to `uploadToCloud()` — append inside the method after the existing `saveHabits` call**

```swift
CloudKitManager.shared.saveGoals(goals) { error in
    if let error = error {
        print("CloudKit Goals Upload Error: \(error.localizedDescription)")
    }
}
```

- [ ] **Step 5: Add goal CRUD methods before the `addExperience` method**

```swift
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
    // Local only — not uploaded to CloudKit
}
```

- [ ] **Step 6: Add persistence methods after `loadHabits()`**

```swift
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
```

- [ ] **Step 7: Add a stub for `checkMilestones` (needed by `updateManualProgress`) — full implementation in Task 5**

```swift
private func checkMilestones(for goal: Goal) {
    // Milestone logic implemented in Task 5
}
```

- [ ] **Step 8: Run tests to confirm CRUD tests pass**

```bash
cd Life-XP-iOS/Life-XP-iOS && xcodebuild test -project Life-XP-iOS.xcodeproj -scheme Life-XP-iOS -destination 'platform=iOS Simulator,name=iPhone 16e' 2>&1 | grep -E "(Test Suite|passed|failed)"
```

Expected: all tests pass including the new `Goal CRUD` suite.

- [ ] **Step 9: Commit**

```bash
git add Life-XP-iOS/Life-XP-iOS/ViewModels/UserViewModel.swift
git commit -m "feat: add goal CRUD to UserViewModel with CloudKit and UserDefaults persistence"
```

---

## Task 4: Write Failing Tests for Milestone Logic

**Files:**
- Modify: `Life-XP-iOS/Life-XP-iOSTests/LifeXPiOSTests.swift`

- [ ] **Step 1: Append a new `MilestoneTests` suite at the end of the test file**

```swift
// MARK: - Milestone Reward Tests

@Suite("Milestone Rewards")
struct MilestoneTests {

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
        category: GoalCategory = .fitness,
        targetValue: Double = 100
    ) -> Goal {
        Goal(
            title: "Test Goal",
            description: "desc",
            category: category,
            trackingType: .manual,
            targetValue: targetValue
        )
    }

    // MARK: XP and Gold

    @Test @MainActor func milestone25_awardsCorrectXPAndGold() {
        let vm = makeVM()
        let goal = makeGoal(targetValue: 100)
        vm.addGoal(goal)
        let baseXP = vm.user.experience
        let baseGold = vm.user.gold
        vm.updateManualProgress(goalId: goal.id, newValue: 25)
        #expect(vm.user.experience == baseXP + 25)
        #expect(vm.user.gold == baseGold + 10)
    }

    @Test @MainActor func milestone50_awardsCorrectXPAndGold() {
        let vm = makeVM()
        let goal = makeGoal(targetValue: 100)
        vm.addGoal(goal)
        let baseXP = vm.user.experience
        let baseGold = vm.user.gold
        vm.updateManualProgress(goalId: goal.id, newValue: 50)
        // 25% and 50% both fire: 25+50=75 XP, 10+25=35 gold
        #expect(vm.user.experience == baseXP + 75)
        #expect(vm.user.gold == baseGold + 35)
    }

    @Test @MainActor func milestone100_awardsCorrectXPAndGold() {
        let vm = makeVM()
        let goal = makeGoal(targetValue: 100)
        vm.addGoal(goal)
        let baseXP = vm.user.experience
        let baseGold = vm.user.gold
        // Jump straight to 100 — all four milestones fire: 25+50+100+200=375 XP, 10+25+50+100=185 gold
        vm.updateManualProgress(goalId: goal.id, newValue: 100)
        #expect(vm.user.experience == baseXP + 375)
        #expect(vm.user.gold == baseGold + 185)
    }

    // MARK: Double-award prevention

    @Test @MainActor func milestone25_doesNotDoubleAward() {
        let vm = makeVM()
        let goal = makeGoal(targetValue: 100)
        vm.addGoal(goal)
        vm.updateManualProgress(goalId: goal.id, newValue: 25)
        let xpAfterFirst = vm.user.experience
        let goldAfterFirst = vm.user.gold
        // Update again at same threshold — should not re-award
        vm.updateManualProgress(goalId: goal.id, newValue: 30)
        #expect(vm.user.experience == xpAfterFirst)
        #expect(vm.user.gold == goldAfterFirst)
    }

    // MARK: Stat boosts

    @Test @MainActor func milestone_fitnessGoal_boostsStrength() {
        let vm = makeVM()
        let goal = makeGoal(category: .fitness, targetValue: 100)
        vm.addGoal(goal)
        let base = vm.user.strength
        vm.updateManualProgress(goalId: goal.id, newValue: 25)
        #expect(vm.user.strength == base + 1) // 25% boost = +1
    }

    @Test @MainActor func milestone_wellnessGoal_boostsVitality() {
        let vm = makeVM()
        let goal = makeGoal(category: .wellness, targetValue: 100)
        vm.addGoal(goal)
        let base = vm.user.vitality
        vm.updateManualProgress(goalId: goal.id, newValue: 25)
        #expect(vm.user.vitality == base + 1)
    }

    @Test @MainActor func milestone_learningGoal_boostsIntelligence() {
        let vm = makeVM()
        let goal = makeGoal(category: .learning, targetValue: 100)
        vm.addGoal(goal)
        let base = vm.user.intelligence
        vm.updateManualProgress(goalId: goal.id, newValue: 25)
        #expect(vm.user.intelligence == base + 1)
    }

    @Test @MainActor func milestone_socialGoal_boostsCharisma() {
        let vm = makeVM()
        let goal = makeGoal(category: .social, targetValue: 100)
        vm.addGoal(goal)
        let base = vm.user.charisma
        vm.updateManualProgress(goalId: goal.id, newValue: 25)
        #expect(vm.user.charisma == base + 1)
    }

    @Test @MainActor func milestone_financialGoal_boostsIntelligenceAndCharisma() {
        let vm = makeVM()
        let goal = makeGoal(category: .financial, targetValue: 100)
        vm.addGoal(goal)
        let baseInt = vm.user.intelligence
        let baseCha = vm.user.charisma
        // 50% milestone: boost = 2; financial splits → intelligence += 1, charisma += 1
        vm.updateManualProgress(goalId: goal.id, newValue: 50)
        // 25% boost=1: int += 1, cha += 0; 50% boost=2: int += 1, cha += 1 → total int+2, cha+1
        #expect(vm.user.intelligence == baseInt + 2)
        #expect(vm.user.charisma == baseCha + 1)
    }

    // MARK: Trophy at 100%

    @Test @MainActor func milestone100_addsTrophyToInventory() {
        let vm = makeVM()
        let goal = makeGoal(targetValue: 100)
        vm.addGoal(goal)
        vm.updateManualProgress(goalId: goal.id, newValue: 100)
        #expect(vm.user.inventory.contains(where: { $0.icon == "trophy.fill" }))
    }

    @Test @MainActor func milestone100_markGoalAsCompleted() {
        let vm = makeVM()
        let goal = makeGoal(targetValue: 100)
        vm.addGoal(goal)
        vm.updateManualProgress(goalId: goal.id, newValue: 100)
        #expect(vm.goals[0].isCompleted == true)
    }

    // MARK: Milestone notification state

    @Test @MainActor func milestone_setsShowingMilestoneReward() {
        let vm = makeVM()
        let goal = makeGoal(targetValue: 100)
        vm.addGoal(goal)
        vm.updateManualProgress(goalId: goal.id, newValue: 25)
        #expect(vm.showingMilestoneReward == true)
    }

    @Test @MainActor func milestone_setsLastMilestoneMessage() {
        let vm = makeVM()
        let goal = makeGoal(targetValue: 100)
        vm.addGoal(goal)
        vm.updateManualProgress(goalId: goal.id, newValue: 25)
        #expect(vm.lastMilestoneMessage.contains("25%"))
    }
}
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
cd Life-XP-iOS/Life-XP-iOS && xcodebuild test -project Life-XP-iOS.xcodeproj -scheme Life-XP-iOS -destination 'platform=iOS Simulator,name=iPhone 16e' 2>&1 | grep -E "(Milestone|failed|passed)" | head -20
```

Expected: `Milestone Rewards` suite shows multiple failures.

---

## Task 5: Implement UserViewModel Milestone Logic

**Files:**
- Modify: `Life-XP-iOS/Life-XP-iOS/Life-XP-iOS/ViewModels/UserViewModel.swift`

- [ ] **Step 1: Replace the stub `checkMilestones` with the full implementation**

Find and replace the stub from Task 3:

```swift
private func checkMilestones(for goal: Goal) {
    guard let index = goals.firstIndex(where: { $0.id == goal.id }) else { return }
    let percent = goal.progressPercent

    for threshold in [25, 50, 75, 100] {
        if percent >= threshold && !goals[index].awardedMilestones.contains(threshold) {
            goals[index].awardedMilestones.insert(threshold)
            if threshold == 100 {
                goals[index].isCompleted = true
            }
            awardMilestone(goals[index], threshold: threshold)
        }
    }
}
```

- [ ] **Step 2: Add `awardMilestone`, `milestoneRewards`, and `applyStatBoost` private methods after `checkMilestones`**

```swift
private func awardMilestone(_ goal: Goal, threshold: Int) {
    let (xp, gold, statBoost) = milestoneRewards(for: threshold)
    addExperience(xp)
    user.gold += gold
    applyStatBoost(statBoost, for: goal.category)

    if threshold == 100 {
        let trophy = Item(
            name: "\(goal.title) Trophy",
            description: "Completed: \(goal.title)",
            icon: "trophy.fill",
            price: 0,
            statBoost: nil,
            boostAmount: 0
        )
        user.inventory.append(trophy)
    }

    lastMilestoneMessage = "\(goal.title) \(threshold)% complete! +\(xp) XP, +\(gold) Gold"
    showingMilestoneReward = true
}

private func milestoneRewards(for threshold: Int) -> (xp: Int, gold: Int, statBoost: Int) {
    switch threshold {
    case 25:  return (25, 10, 1)
    case 50:  return (50, 25, 2)
    case 75:  return (100, 50, 3)
    case 100: return (200, 100, 5)
    default:  return (0, 0, 0)
    }
}

private func applyStatBoost(_ amount: Int, for category: GoalCategory) {
    switch category {
    case .fitness:
        user.strength += amount
    case .wellness:
        user.vitality += amount
    case .learning:
        user.intelligence += amount
    case .financial:
        let upper = (amount + 1) / 2
        let lower = amount / 2
        user.intelligence += upper
        user.charisma += lower
    case .social:
        user.charisma += amount
    }
}
```

- [ ] **Step 3: Run tests to confirm all milestone tests pass**

```bash
cd Life-XP-iOS/Life-XP-iOS && xcodebuild test -project Life-XP-iOS.xcodeproj -scheme Life-XP-iOS -destination 'platform=iOS Simulator,name=iPhone 16e' 2>&1 | grep -E "(Test Suite|passed|failed)"
```

Expected: all suites pass.

- [ ] **Step 4: Commit**

```bash
git add Life-XP-iOS/Life-XP-iOS/ViewModels/UserViewModel.swift \
        Life-XP-iOS/Life-XP-iOSTests/LifeXPiOSTests.swift
git commit -m "feat: implement goal milestone reward logic with tests"
```

---

## Task 6: Add HealthKit Range Queries and UserViewModel Refresh

**Files:**
- Modify: `Life-XP-iOS/Life-XP-iOS/Life-XP-iOS/Managers/HealthKitManager.swift`
- Modify: `Life-XP-iOS/Life-XP-iOS/Life-XP-iOS/ViewModels/UserViewModel.swift`

- [ ] **Step 1: Add two cumulative query methods to `HealthKitManager` after `fetchTodaySleep`**

```swift
func fetchCumulativeSteps(from startDate: Date, to endDate: Date, completion: @escaping (Double) -> Void) {
    guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
        completion(0)
        return
    }
    let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
    let query = HKStatisticsQuery(
        quantityType: stepType,
        quantitySamplePredicate: predicate,
        options: .cumulativeSum
    ) { _, result, _ in
        let value = result?.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0
        DispatchQueue.main.async { completion(value) }
    }
    healthStore.execute(query)
}

func fetchCumulativeCalories(from startDate: Date, to endDate: Date, completion: @escaping (Double) -> Void) {
    guard let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
        completion(0)
        return
    }
    let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
    let query = HKStatisticsQuery(
        quantityType: energyType,
        quantitySamplePredicate: predicate,
        options: .cumulativeSum
    ) { _, result, _ in
        let value = result?.sumQuantity()?.doubleValue(for: HKUnit.kilocalorie()) ?? 0
        DispatchQueue.main.async { completion(value) }
    }
    healthStore.execute(query)
}
```

- [ ] **Step 2: Add `refreshHealthKitGoals` to `UserViewModel` after `deleteGoal`**

```swift
func refreshHealthKitGoals(using healthKitManager: HealthKitManager) {
    let activeGoals = goals.filter {
        !$0.isCompleted && ($0.trackingType == .steps || $0.trackingType == .calories)
    }
    for goal in activeGoals {
        guard let index = goals.firstIndex(where: { $0.id == goal.id }) else { continue }
        let start = goal.startDate
        let end = Date()
        switch goal.trackingType {
        case .steps:
            healthKitManager.fetchCumulativeSteps(from: start, to: end) { [weak self] total in
                guard let self else { return }
                self.goals[index].currentProgress = total
                self.checkMilestones(for: self.goals[index])
                self.uploadToCloud()
            }
        case .calories:
            healthKitManager.fetchCumulativeCalories(from: start, to: end) { [weak self] total in
                guard let self else { return }
                self.goals[index].currentProgress = total
                self.checkMilestones(for: self.goals[index])
                self.uploadToCloud()
            }
        case .manual:
            break
        }
    }
}
```

- [ ] **Step 3: Build to confirm no errors**

```bash
cd Life-XP-iOS/Life-XP-iOS && xcodebuild -project Life-XP-iOS.xcodeproj -scheme Life-XP-iOS -destination 'platform=iOS Simulator,name=iPhone 16e' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add Life-XP-iOS/Life-XP-iOS/Managers/HealthKitManager.swift \
        Life-XP-iOS/Life-XP-iOS/ViewModels/UserViewModel.swift
git commit -m "feat: add HealthKit cumulative range queries and goal refresh in UserViewModel"
```

---

## Task 7: Add CloudKit Goal Sync

**Files:**
- Modify: `Life-XP-iOS/Life-XP-iOS/Life-XP-iOS/Managers/CloudKitManager.swift`

- [ ] **Step 1: Add the `goalRecordType` constant after `habitRecordType` on line 12**

```swift
let goalRecordType = "Goal"
```

- [ ] **Step 2: Add `saveGoals` after `fetchHabits`**

```swift
func saveGoals(_ goals: [Goal], completion: @escaping (Error?) -> Void) {
    let query = CKQuery(recordType: goalRecordType, predicate: NSPredicate(value: true))

    privateDatabase.perform(query, inZoneWith: nil) { records, _ in
        let deleteIDs = records?.map { $0.recordID } ?? []
        let deleteOperation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: deleteIDs)

        deleteOperation.modifyRecordsCompletionBlock = { _, _, deleteError in
            if let deleteError = deleteError {
                completion(deleteError)
                return
            }

            let recordsToSave: [CKRecord] = goals.map { goal in
                let record = CKRecord(recordType: self.goalRecordType)
                record["goalId"] = goal.id.uuidString as CKRecordValue
                record["title"] = goal.title as CKRecordValue
                record["goalDescription"] = goal.description as CKRecordValue
                record["category"] = goal.category.rawValue as CKRecordValue
                record["trackingType"] = goal.trackingType.rawValue as CKRecordValue
                record["targetValue"] = goal.targetValue as CKRecordValue
                record["currentProgress"] = goal.currentProgress as CKRecordValue
                record["startDate"] = goal.startDate as CKRecordValue
                record["isCompleted"] = (goal.isCompleted ? 1 : 0) as CKRecordValue
                if let targetDate = goal.targetDate {
                    record["targetDate"] = targetDate as CKRecordValue
                }
                if let notes = goal.notes {
                    record["notes"] = notes as CKRecordValue
                }
                if let data = try? JSONEncoder().encode(Array(goal.awardedMilestones)),
                   let jsonString = String(data: data, encoding: .utf8) {
                    record["awardedMilestones"] = jsonString as CKRecordValue
                }
                return record
            }

            let saveOperation = CKModifyRecordsOperation(recordsToSave: recordsToSave, recordIDsToDelete: nil)
            saveOperation.modifyRecordsCompletionBlock = { _, _, saveError in
                completion(saveError)
            }
            self.privateDatabase.add(saveOperation)
        }
        self.privateDatabase.add(deleteOperation)
    }
}
```

- [ ] **Step 3: Add `fetchGoals` after `saveGoals`**

```swift
func fetchGoals(completion: @escaping (Result<[Goal], Error>) -> Void) {
    let query = CKQuery(recordType: goalRecordType, predicate: NSPredicate(value: true))

    privateDatabase.perform(query, inZoneWith: nil) { records, error in
        if let error = error {
            completion(.failure(error))
            return
        }

        let goals: [Goal] = records?.compactMap { record in
            guard
                let idString = record["goalId"] as? String,
                let id = UUID(uuidString: idString),
                let title = record["title"] as? String,
                let description = record["goalDescription"] as? String,
                let categoryString = record["category"] as? String,
                let category = GoalCategory(rawValue: categoryString),
                let trackingTypeString = record["trackingType"] as? String,
                let trackingType = GoalTrackingType(rawValue: trackingTypeString),
                let targetValue = record["targetValue"] as? Double,
                let currentProgress = record["currentProgress"] as? Double,
                let startDate = record["startDate"] as? Date
            else { return nil }

            var goal = Goal(
                title: title,
                description: description,
                category: category,
                trackingType: trackingType,
                targetValue: targetValue
            )
            goal.id = id
            goal.currentProgress = currentProgress
            goal.startDate = startDate
            goal.targetDate = record["targetDate"] as? Date
            goal.notes = record["notes"] as? String
            goal.isCompleted = (record["isCompleted"] as? Int ?? 0) == 1

            if let jsonString = record["awardedMilestones"] as? String,
               let data = jsonString.data(using: .utf8),
               let array = try? JSONDecoder().decode([Int].self, from: data) {
                goal.awardedMilestones = Set(array)
            }

            return goal
        } ?? []

        completion(.success(goals))
    }
}
```

- [ ] **Step 4: Build and test**

```bash
cd Life-XP-iOS/Life-XP-iOS && xcodebuild test -project Life-XP-iOS.xcodeproj -scheme Life-XP-iOS -destination 'platform=iOS Simulator,name=iPhone 16e' 2>&1 | grep -E "(Test Suite|passed|failed)"
```

Expected: all suites pass.

- [ ] **Step 5: Commit**

```bash
git add Life-XP-iOS/Life-XP-iOS/Managers/CloudKitManager.swift
git commit -m "feat: add CloudKit goal sync (saveGoals, fetchGoals)"
```

---

## Task 8: Add Goal Preview Data

**Files:**
- Modify: `Life-XP-iOS/Life-XP-iOS/Life-XP-iOS/Models/PreviewData.swift`

- [ ] **Step 1: Append goal preview data at the end of `PreviewData.swift`**

```swift
extension Goal {
    static let previewGoals: [Goal] = [
        {
            var g = Goal(
                title: "Run a 5K",
                description: "Complete a 5km run without stopping",
                category: .fitness,
                trackingType: .steps,
                targetValue: 6000
            )
            g.currentProgress = 3000
            g.awardedMilestones = [25, 50]
            return g
        }(),
        {
            var g = Goal(
                title: "Save $5,000",
                description: "Build emergency fund",
                category: .financial,
                trackingType: .manual,
                targetValue: 5000
            )
            g.currentProgress = 1500
            return g
        }(),
        Goal(
            title: "Read 12 Books",
            description: "One book per month this year",
            category: .learning,
            trackingType: .manual,
            targetValue: 12
        )
    ]
}

extension UserViewModel {
    static var previewWithGoals: UserViewModel {
        let vm = UserViewModel(skipCloudSync: true)
        vm.user = .preview
        vm.habits = Habit.previewHabits
        vm.goals = Goal.previewGoals
        return vm
    }
}
```

- [ ] **Step 2: Build to verify**

```bash
cd Life-XP-iOS/Life-XP-iOS && xcodebuild -project Life-XP-iOS.xcodeproj -scheme Life-XP-iOS -destination 'platform=iOS Simulator,name=iPhone 16e' build 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add Life-XP-iOS/Life-XP-iOS/Models/PreviewData.swift
git commit -m "feat: add Goal preview data"
```

---

## Task 9: Create GoalsView

**Files:**
- Create: `Life-XP-iOS/Life-XP-iOS/Life-XP-iOS/Views/GoalsView.swift`

- [ ] **Step 1: Create the file with `GoalsView` and `GoalRow`**

```swift
import SwiftUI

struct GoalsView: View {
    @ObservedObject var viewModel: UserViewModel
    @ObservedObject var healthKitManager: HealthKitManager
    @State private var showingAddGoal = false

    var body: some View {
        NavigationView {
            Group {
                if viewModel.goals.isEmpty {
                    emptyState
                } else {
                    goalList
                }
            }
            .navigationTitle("Goals")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddGoal = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddGoal) {
                AddGoalView(viewModel: viewModel)
            }
            .alert("Milestone Reached!", isPresented: $viewModel.showingMilestoneReward) {
                Button("Awesome!") { viewModel.showingMilestoneReward = false }
            } message: {
                Text(viewModel.lastMilestoneMessage)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "target")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("No Goals Yet")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Set a long-term goal and earn rewards as you progress.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            Button("Add Your First Goal") {
                showingAddGoal = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var goalList: some View {
        List {
            ForEach(viewModel.goals) { goal in
                NavigationLink(
                    destination: GoalDetailView(
                        viewModel: viewModel,
                        goalId: goal.id,
                        healthKitManager: healthKitManager
                    )
                ) {
                    GoalRow(goal: goal)
                }
            }
            .onDelete { offsets in
                viewModel.deleteGoal(at: offsets)
            }
        }
    }
}

struct GoalRow: View {
    let goal: Goal

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: goal.category.icon)
                    .foregroundColor(.accentColor)
                Text(goal.title)
                    .font(.headline)
                Spacer()
                Text("\(goal.progressPercent)%")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(goal.isCompleted ? .green : .primary)
            }
            ProgressView(value: goal.progressFraction)
                .tint(goal.isCompleted ? .green : .blue)
            Text("\(goal.trackingType.displayName) · \(goal.category.displayName)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    GoalsView(viewModel: .previewWithGoals, healthKitManager: HealthKitManager())
}
```

- [ ] **Step 2: Build to verify**

```bash
cd Life-XP-iOS/Life-XP-iOS && xcodebuild -project Life-XP-iOS.xcodeproj -scheme Life-XP-iOS -destination 'platform=iOS Simulator,name=iPhone 16e' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add Life-XP-iOS/Life-XP-iOS/Views/GoalsView.swift
git commit -m "feat: add GoalsView and GoalRow"
```

---

## Task 10: Create AddGoalView

**Files:**
- Create: `Life-XP-iOS/Life-XP-iOS/Life-XP-iOS/Views/AddGoalView.swift`

- [ ] **Step 1: Create the file**

```swift
import SwiftUI

struct AddGoalView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: UserViewModel

    @State private var title = ""
    @State private var description = ""
    @State private var category: GoalCategory = .fitness
    @State private var trackingType: GoalTrackingType = .manual
    @State private var targetValueText = ""
    @State private var hasTargetDate = false
    @State private var targetDate = Date().addingTimeInterval(30 * 24 * 3600)
    @State private var notes = ""

    private var targetValue: Double { Double(targetValueText) ?? 0 }
    private var canSave: Bool { !title.isEmpty && targetValue > 0 }

    var body: some View {
        NavigationView {
            Form {
                Section("Goal Details") {
                    TextField("Title", text: $title)
                    TextField("Description", text: $description)
                }

                Section("Category & Tracking") {
                    Picker("Category", selection: $category) {
                        ForEach(GoalCategory.allCases, id: \.self) { cat in
                            Label(cat.displayName, systemImage: cat.icon).tag(cat)
                        }
                    }
                    Picker("Tracking", selection: $trackingType) {
                        ForEach(GoalTrackingType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                }

                Section("Target") {
                    HStack {
                        TextField("Target Value", text: $targetValueText)
                            .keyboardType(.decimalPad)
                        if !trackingType.unit.isEmpty {
                            Text(trackingType.unit)
                                .foregroundColor(.secondary)
                        }
                    }
                    Toggle("Set Target Date", isOn: $hasTargetDate)
                    if hasTargetDate {
                        DatePicker(
                            "Target Date",
                            selection: $targetDate,
                            in: Date()...,
                            displayedComponents: .date
                        )
                    }
                }

                Section("Notes (Optional)") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("New Goal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let goal = Goal(
                            title: title,
                            description: description,
                            category: category,
                            trackingType: trackingType,
                            targetValue: targetValue,
                            targetDate: hasTargetDate ? targetDate : nil,
                            notes: notes.isEmpty ? nil : notes
                        )
                        viewModel.addGoal(goal)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}

#Preview {
    AddGoalView(viewModel: .preview)
}
```

- [ ] **Step 2: Build to verify**

```bash
cd Life-XP-iOS/Life-XP-iOS && xcodebuild -project Life-XP-iOS.xcodeproj -scheme Life-XP-iOS -destination 'platform=iOS Simulator,name=iPhone 16e' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add Life-XP-iOS/Life-XP-iOS/Views/AddGoalView.swift
git commit -m "feat: add AddGoalView form"
```

---

## Task 11: Create GoalDetailView

**Files:**
- Create: `Life-XP-iOS/Life-XP-iOS/Life-XP-iOS/Views/GoalDetailView.swift`

- [ ] **Step 1: Create the file**

```swift
import SwiftUI
import PhotosUI

struct GoalDetailView: View {
    @ObservedObject var viewModel: UserViewModel
    let goalId: UUID
    @ObservedObject var healthKitManager: HealthKitManager

    @State private var showingProgressInput = false
    @State private var progressInputText = ""
    @State private var selectedPhoto: PhotosPickerItem?

    private var goal: Goal? {
        viewModel.goals.first(where: { $0.id == goalId })
    }

    var body: some View {
        Group {
            if let goal = goal {
                ScrollView {
                    VStack(spacing: 20) {
                        headerCard(goal)
                        progressCard(goal)
                        milestoneCard(goal)
                        actionsCard(goal)
                        if let notes = goal.notes, !notes.isEmpty {
                            notesCard(notes)
                        }
                        if let targetDate = goal.targetDate {
                            targetDateCard(targetDate)
                        }
                        photoCard(goal)
                    }
                    .padding()
                }
            } else {
                Text("Goal not found")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle(goal?.title ?? "Goal")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingProgressInput) {
            if let goal = goal {
                progressInputSheet(goal)
            }
        }
        .onChange(of: selectedPhoto) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    viewModel.updateGoalPhoto(goalId: goalId, photoData: data)
                }
            }
        }
    }

    private func headerCard(_ goal: Goal) -> some View {
        HStack(spacing: 12) {
            Image(systemName: goal.category.icon)
                .font(.system(size: 36))
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 4) {
                Text(goal.category.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(goal.description)
                    .font(.body)
                Text(goal.trackingType.displayName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if goal.isCompleted {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.green)
                    .font(.title2)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)).shadow(radius: 1))
    }

    private func progressCard(_ goal: Goal) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Progress")
                .font(.headline)
            ProgressView(value: goal.progressFraction)
                .tint(goal.isCompleted ? .green : .blue)
                .scaleEffect(x: 1, y: 2)
                .padding(.vertical, 4)
            HStack {
                let unit = goal.trackingType.unit
                let unitSuffix = unit.isEmpty ? "" : " \(unit)"
                Text(String(format: "%.0f\(unitSuffix)", goal.currentProgress))
                    .font(.title3)
                    .fontWeight(.bold)
                Spacer()
                Text(String(format: "%.0f\(unitSuffix)", goal.targetValue))
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            Text("\(goal.progressPercent)% complete")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)).shadow(radius: 1))
    }

    private func milestoneCard(_ goal: Goal) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Milestones")
                .font(.headline)
            HStack(spacing: 0) {
                ForEach([25, 50, 75, 100], id: \.self) { threshold in
                    VStack(spacing: 6) {
                        Image(systemName: goal.awardedMilestones.contains(threshold)
                              ? "star.fill" : "star")
                            .foregroundColor(goal.awardedMilestones.contains(threshold)
                                             ? .yellow : .secondary)
                        Text("\(threshold)%")
                            .font(.caption2)
                            .foregroundColor(goal.awardedMilestones.contains(threshold)
                                             ? .primary : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)).shadow(radius: 1))
    }

    private func actionsCard(_ goal: Goal) -> some View {
        VStack(spacing: 12) {
            if goal.trackingType == .manual && !goal.isCompleted {
                Button {
                    progressInputText = String(format: "%.0f", goal.currentProgress)
                    showingProgressInput = true
                } label: {
                    Label("Log Progress", systemImage: "pencil.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }

            if (goal.trackingType == .steps || goal.trackingType == .calories) && !goal.isCompleted {
                Button {
                    viewModel.refreshHealthKitGoals(using: healthKitManager)
                } label: {
                    Label("Refresh from HealthKit", systemImage: "arrow.triangle.2.circlepath")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)).shadow(radius: 1))
    }

    private func notesCard(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.headline)
            Text(notes)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)).shadow(radius: 1))
    }

    private func targetDateCard(_ date: Date) -> some View {
        HStack {
            Image(systemName: "calendar")
                .foregroundColor(.accentColor)
            Text("Target Date")
                .font(.subheadline)
            Spacer()
            Text(date, style: .date)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)).shadow(radius: 1))
    }

    private func photoCard(_ goal: Goal) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Photo")
                .font(.headline)
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                if let data = goal.photoData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                        .clipped()
                        .cornerRadius(8)
                } else {
                    Label("Add Photo", systemImage: "photo.badge.plus")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)).shadow(radius: 1))
    }

    private func progressInputSheet(_ goal: Goal) -> some View {
        NavigationView {
            Form {
                Section("Current Progress") {
                    HStack {
                        TextField("Value", text: $progressInputText)
                            .keyboardType(.decimalPad)
                        if !goal.trackingType.unit.isEmpty {
                            Text(goal.trackingType.unit)
                                .foregroundColor(.secondary)
                        }
                    }
                    Text("Target: \(String(format: "%.0f", goal.targetValue)) \(goal.trackingType.unit)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Log Progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingProgressInput = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let newValue = Double(progressInputText) {
                            viewModel.updateManualProgress(goalId: goalId, newValue: newValue)
                        }
                        showingProgressInput = false
                    }
                    .disabled(Double(progressInputText) == nil)
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        GoalDetailView(
            viewModel: .previewWithGoals,
            goalId: Goal.previewGoals[0].id,
            healthKitManager: HealthKitManager()
        )
    }
}
```

- [ ] **Step 2: Build to verify**

```bash
cd Life-XP-iOS/Life-XP-iOS && xcodebuild -project Life-XP-iOS.xcodeproj -scheme Life-XP-iOS -destination 'platform=iOS Simulator,name=iPhone 16e' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add Life-XP-iOS/Life-XP-iOS/Views/GoalDetailView.swift
git commit -m "feat: add GoalDetailView with progress logging and photo picker"
```

---

## Task 12: Wire Goals Tab in ContentView

**Files:**
- Modify: `Life-XP-iOS/Life-XP-iOS/Life-XP-iOS/ContentView.swift`

- [ ] **Step 1: Add the Goals tab between Inventory and Settings in `ContentView.body`**

Find the existing `InventoryView` tab item block and add the Goals tab immediately after it:

```swift
GoalsView(viewModel: userViewModel, healthKitManager: healthKitManager)
    .tabItem {
        Label("Goals", systemImage: "target")
    }
```

The TabView should now contain, in order: Dashboard, Habits, Inventory, Goals, Settings.

- [ ] **Step 2: Add `refreshHealthKitGoals` call in the DashboardView sync button action**

In `DashboardView.swift`, find the existing refresh button action:

```swift
Button(action: {
    healthKitManager.fetchTodayHealthData()
    viewModel.syncHealthData(
        steps: healthKitManager.stepCount,
        calories: healthKitManager.activeEnergy,
        sleep: healthKitManager.sleepHours,
        water: healthKitManager.waterIntake
    )
}, label: {
```

Add the goals refresh call after `syncHealthData`:

```swift
Button(action: {
    healthKitManager.fetchTodayHealthData()
    viewModel.syncHealthData(
        steps: healthKitManager.stepCount,
        calories: healthKitManager.activeEnergy,
        sleep: healthKitManager.sleepHours,
        water: healthKitManager.waterIntake
    )
    viewModel.refreshHealthKitGoals(using: healthKitManager)
}, label: {
```

Also add the same call in the `.onAppear` block in `DashboardView`:

```swift
.onAppear {
    healthKitManager.fetchTodayHealthData()
    viewModel.syncHealthData(
        steps: healthKitManager.stepCount,
        calories: healthKitManager.activeEnergy,
        sleep: healthKitManager.sleepHours,
        water: healthKitManager.waterIntake
    )
    viewModel.refreshHealthKitGoals(using: healthKitManager)
}
```

- [ ] **Step 3: Build to verify**

```bash
cd Life-XP-iOS/Life-XP-iOS && xcodebuild -project Life-XP-iOS.xcodeproj -scheme Life-XP-iOS -destination 'platform=iOS Simulator,name=iPhone 16e' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add Life-XP-iOS/Life-XP-iOS/ContentView.swift \
        Life-XP-iOS/Life-XP-iOS/Views/DashboardView.swift
git commit -m "feat: add Goals tab to ContentView and HealthKit goal refresh in DashboardView"
```

---

## Task 13: Full Test Suite and Final Build Verification

- [ ] **Step 1: Run the complete test suite**

```bash
cd Life-XP-iOS/Life-XP-iOS && xcodebuild test -project Life-XP-iOS.xcodeproj -scheme Life-XP-iOS -destination 'platform=iOS Simulator,name=iPhone 16e' 2>&1 | grep -E "(Test Suite|passed|failed|error)"
```

Expected output includes:
```
Test Suite 'LifeXPUserTests' passed
Test Suite 'HabitTests' passed
Test Suite 'UserViewModelTests' passed
Test Suite 'Goal CRUD' passed
Test Suite 'Milestone Rewards' passed
** TEST SUCCEEDED **
```

- [ ] **Step 2: Run SwiftLint**

```bash
cd Life-XP-iOS/Life-XP-iOS && swiftlint lint --strict 2>&1 | tail -5
```

Expected: zero violations or only warnings (no errors).

- [ ] **Step 3: Final commit if linting required any fixes**

```bash
git add -A
git commit -m "fix: resolve SwiftLint violations in goal feature files"
```

Only run Step 3 if SwiftLint emitted errors that required code changes.
