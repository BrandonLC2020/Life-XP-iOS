# Lock In Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement "Lock In Mode", an all-or-nothing daily habit challenge system with high stakes and high rewards.

**Architecture:** 
- **Model:** `LockInChallenge` struct with strike tracking and status.
- **State:** `LifeXPUser` stores one active challenge and a history of past ones.
- **Logic:** `UserViewModel` intercepts habit completions and evaluates daily status in `checkNewDay`.
- **UI:** New creation view, dashboard banner for active challenges, and a celebratory reward overlay.

**Tech Stack:** Swift, SwiftUI, Combine (existing project conventions).

---

### Task 1: Core Models & User State

**Files:**
- Modify: `Life-XP-iOS/Life-XP-iOS/Models/Models.swift`
- Test: `Life-XP-iOS/Life-XP-iOSTests/LockInTests.swift` (Create)

- [ ] **Step 1: Write the failing test for model persistence**
Create `Life-XP-iOS/Life-XP-iOSTests/LockInTests.swift`:
```swift
import Testing
import Foundation
@testable import Life_XP_iOS

@Suite("Lock In Models")
struct LockInModelTests {
    @Test func challengeModel_initializesCorrectly() {
        let id = UUID()
        let habitIDs = [UUID(), UUID()]
        let startDate = Date()
        let challenge = LockInChallenge(
            id: id,
            habitIDs: habitIDs,
            startDate: startDate,
            durationDays: 7
        )
        #expect(challenge.status == .active)
        #expect(challenge.strikesCount == 0)
        #expect(challenge.maxStrikes == 3)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**
Run: `xcodebuild test -project Life-XP-iOS/Life-XP-iOS.xcodeproj -scheme Life-XP-iOS -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing Life-XP-iOSTests/LockInModelTests`
Expected: FAIL (Type not found)

- [ ] **Step 3: Implement `LockInChallenge` and update `LifeXPUser`**
Modify `Life-XP-iOS/Life-XP-iOS/Models/Models.swift`:
```swift
enum ChallengeStatus: String, Codable {
    case active, failed, completed
}

struct LockInChallenge: Identifiable, Codable {
    var id = UUID()
    var habitIDs: [UUID]
    var startDate: Date
    var durationDays: Int
    var strikesCount: Int = 0
    var maxStrikes: Int = 3
    var status: ChallengeStatus = .active
    
    var endDate: Date {
        Calendar.current.date(byAdding: .day, value: durationDays, to: startDate) ?? startDate
    }
}

// Update LifeXPUser
struct LifeXPUser: Codable {
    // ... existing fields ...
    var activeLockIn: LockInChallenge?
    var pastLockIns: [LockInChallenge] = []
    // ... existing methods ...
}
```

- [ ] **Step 4: Run test to verify it passes**
Expected: PASS

- [ ] **Step 5: Commit**
```bash
git add Life-XP-iOS/Life-XP-iOS/Models/Models.swift
git commit -m "feat: add LockInChallenge data model and update LifeXPUser"
```

---

### Task 2: Daily Evaluation Logic & Strike System

**Files:**
- Modify: `Life-XP-iOS/Life-XP-iOS/ViewModels/UserViewModel.swift`
- Test: `Life-XP-iOS/Life-XP-iOSTests/LockInTests.swift`

- [ ] **Step 1: Write failing test for all-or-nothing XP**
Add to `LockInTests.swift`:
```swift
@Suite("Lock In Logic")
struct LockInLogicTests {
    @MainActor private func makeVM() -> UserViewModel {
        let vm = UserViewModel(skipCloudSync: true)
        vm.user = LifeXPUser()
        vm.habits = [
            Habit(title: "H1", description: "", xpReward: 100, frequency: .daily),
            Habit(title: "H2", description: "", xpReward: 100, frequency: .daily)
        ]
        return vm
    }

    @Test @MainActor func completeHabit_doesNotAwardXP_ifInActiveLockIn() {
        let vm = makeVM()
        let habit = vm.habits[0]
        vm.user.activeLockIn = LockInChallenge(habitIDs: [habit.id], startDate: Date(), durationDays: 7)
        
        vm.completeHabit(habit)
        
        #expect(vm.user.experience == 0) // Should be deferred
    }
}
```

- [ ] **Step 2: Run test to verify it fails**
Expected: FAIL (Awards 100 XP immediately)

- [ ] **Step 3: Update `completeHabit` to intercept locked-in habits**
Modify `Life-XP-iOS/Life-XP-iOS/ViewModels/UserViewModel.swift`:
```swift
func completeHabit(_ habit: Habit) {
    guard let index = habits.firstIndex(where: { $0.id == habit.id }) else { return }
    // ... existing streak logic ...
    
    let isLockedIn = user.activeLockIn?.habitIDs.contains(habit.id) ?? false
    
    if !isLockedIn {
        addExperience(habit.xpReward)
        user.gold += habit.xpReward / 2 + user.charisma / 10
        // ... existing stat boost logic ...
    }
    
    saveHabits()
    uploadToCloud()
}
```

- [ ] **Step 4: Implement Daily Evaluation in `UserViewModel`**
Add `evaluateLockIn()` and call it in `checkNewDay` (which we'll need to move to `UserViewModel` or wrap).
Actually, `LifeXPUser.checkNewDay` is mutating, but `UserViewModel` handles the actual game logic.
Let's add a wrapper in `UserViewModel`.

Modify `Life-XP-iOS/Life-XP-iOS/ViewModels/UserViewModel.swift`:
```swift
func evaluateLockIn() {
    guard var lockIn = user.activeLockIn else { return }
    
    let calendar = Calendar.current
    let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
    
    // Check if all habits were completed yesterday
    let lockedHabits = habits.filter { lockIn.habitIDs.contains($0.id) }
    let allCompleted = lockedHabits.allSatisfy { habit in
        guard let lastDate = habit.lastCompletedDate else { return false }
        return calendar.isDate(lastDate, inSameDayAs: yesterday)
    }
    
    if allCompleted {
        let totalXP = lockedHabits.reduce(0) { $0 + $1.xpReward }
        addExperience(totalXP)
        user.gold += totalXP / 2
    } else {
        lockIn.strikesCount += 1
        if lockIn.strikesCount >= lockIn.maxStrikes {
            lockIn.status = .failed
            user.pastLockIns.append(lockIn)
            user.activeLockIn = nil
            return
        }
    }
    
    user.activeLockIn = lockIn
}
```
Update `init` to call this when a new day is detected.

- [ ] **Step 5: Run tests and verify success**
Expected: PASS

- [ ] **Step 6: Commit**
```bash
git add Life-XP-iOS/Life-XP-iOS/ViewModels/UserViewModel.swift
git commit -m "logic: implement all-or-nothing XP and strike system for Lock In Mode"
```

---

### Task 3: Completion & Rewards

**Files:**
- Modify: `Life-XP-iOS/Life-XP-iOS/ViewModels/UserViewModel.swift`
- Test: `Life-XP-iOS/Life-XP-iOSTests/LockInTests.swift`

- [ ] **Step 1: Write failing test for challenge completion**
Add to `LockInTests.swift`:
```swift
@Test @MainActor func evaluateLockIn_completesChallenge_ifEndDateReached() {
    let vm = makeVM()
    let startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
    vm.user.activeLockIn = LockInChallenge(habitIDs: [], startDate: startDate, durationDays: 7)
    
    vm.evaluateLockIn()
    
    #expect(vm.user.activeLockIn == nil)
    #expect(vm.user.pastLockIns.last?.status == .completed)
}
```

- [ ] **Step 2: Run test to verify it fails**
Expected: FAIL (Stays active)

- [ ] **Step 3: Implement Completion Reward Logic**
Modify `evaluateLockIn` in `UserViewModel.swift`:
```swift
if Date() >= lockIn.endDate {
    lockIn.status = .completed
    
    // Rewards
    addExperience(1000) // Massive lump sum
    user.gold += 500
    
    let trophy = Item(
        name: "\(lockIn.durationDays)-Day Lock In Trophy",
        description: "Survived the challenge!",
        icon: "lock.shield.fill",
        price: 0,
        statBoost: .vitality,
        boostAmount: 10
    )
    user.inventory.append(trophy)
    
    user.pastLockIns.append(lockIn)
    user.activeLockIn = nil
    
    showingLockInReward = true // Need to add this @Published property
    return
}
```

- [ ] **Step 4: Run tests and verify success**
Expected: PASS

- [ ] **Step 5: Commit**
```bash
git commit -m "feat: add Lock In challenge completion and massive rewards"
```

---

### Task 4: UI/UX - Creation & Active Challenge

**Files:**
- Create: `Life-XP-iOS/Life-XP-iOS/Views/CreateLockInView.swift`
- Modify: `Life-XP-iOS/Life-XP-iOS/Views/DashboardView.swift`
- Modify: `Life-XP-iOS/Life-XP-iOS/Views/HabitListView.swift`

- [ ] **Step 1: Create `CreateLockInView.swift`**
Implement a multi-select list of habits and duration picker.
```swift
struct CreateLockInView: View {
    @ObservedObject var viewModel: UserViewModel
    @State private var selectedHabitIDs = Set<UUID>()
    @State private var duration = 7
    // ...
}
```

- [ ] **Step 2: Add Active Challenge Banner to `DashboardView.swift`**
Add a card at the top of the dashboard showing progress and strikes.

- [ ] **Step 3: Run app and verify UI**
Manually verify creation flow and banner visibility.

- [ ] **Step 4: Commit**
```bash
git add .
git commit -m "ui: add Lock In creation view and active challenge dashboard banner"
```

---

### Task 5: UI/UX - Reward Overlay

**Files:**
- Create: `Life-XP-iOS/Life-XP-iOS/Views/LockInRewardOverlay.swift`
- Modify: `Life-XP-iOS/Life-XP-iOS/Views/ContentView.swift`

- [ ] **Step 1: Create `LockInRewardOverlay.swift`**
Use `ZStack` and scale animations to show the trophy, gold, and XP rewards.

- [ ] **Step 2: Add Overlay to `ContentView.swift`**
```swift
if viewModel.showingLockInReward {
    LockInRewardOverlay(viewModel: viewModel)
}
```

- [ ] **Step 3: Run app and verify reward presentation**
Mock a completed challenge and verify the overlay triggers.

- [ ] **Step 4: Commit**
```bash
git commit -m "ui: add celebratory reward overlay for Lock In completion"
```

---
