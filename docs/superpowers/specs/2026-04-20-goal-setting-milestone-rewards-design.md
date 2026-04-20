# Goal Setting and Milestone Rewards System — Design Spec
**Date:** 2026-04-20
**ClickUp Task:** 86b9gcpaq

---

## Overview

Implement a Goal Setting and Milestone Rewards system for Life XP iOS. Users can create long-term goals (health-tracked or manual), track progress, and earn tiered XP/Gold/stat rewards at 25%, 50%, 75%, and 100% completion milestones. Goals are synced across devices via CloudKit (metadata only; photos are local).

---

## Architecture

Follows the existing MVVM pattern:
- New models in `Models.swift`
- New published state and logic in `UserViewModel`
- New methods in `HealthKitManager` and `CloudKitManager`
- New views: `GoalsView`, `AddGoalView`, `GoalDetailView`
- `ContentView` gains a Goals tab

---

## Section 1: Data Models (`Models.swift`)

### `GoalCategory`
```swift
enum GoalCategory: String, Codable, CaseIterable {
    case fitness    // → Strength boost
    case wellness   // → Vitality boost
    case learning   // → Intelligence boost
    case financial  // → Intelligence + Charisma boost
    case social     // → Charisma boost
}
```

### `GoalTrackingType`
```swift
enum GoalTrackingType: String, Codable, CaseIterable {
    case manual    // user logs progress manually
    case steps     // HealthKit cumulative step count from startDate
    case calories  // HealthKit cumulative active energy from startDate
}
```

### `Goal`
```swift
struct Goal: Identifiable, Codable {
    var id: UUID = UUID()
    var title: String
    var description: String
    var category: GoalCategory
    var trackingType: GoalTrackingType
    var targetValue: Double           // e.g. 500000 steps, 225 lbs
    var currentProgress: Double = 0.0
    var startDate: Date = Date()
    var targetDate: Date?
    var notes: String?
    var photoData: Data?              // local only, excluded from CloudKit
    var isCompleted: Bool = false
    var awardedMilestones: Set<Int> = [] // tracks which of {25,50,75,100} have fired
}
```

`awardedMilestones` as `Set<Int>` prevents double-awarding: before granting a reward we check `!goal.awardedMilestones.contains(threshold)`.

---

## Section 2: HealthKit Changes (`HealthKitManager`)

Two new range-query methods using `HKStatisticsQuery` with `.cumulativeSum` over a caller-supplied date range:

```swift
func fetchCumulativeSteps(from startDate: Date, to endDate: Date, completion: @escaping (Double) -> Void)
func fetchCumulativeCalories(from startDate: Date, to endDate: Date, completion: @escaping (Double) -> Void)
```

These mirror the existing `fetchTodaySteps` / `fetchTodayActiveEnergy` pattern but accept a date range instead of assuming today's bounds. Called by `UserViewModel` during `syncHealthData` for any active HealthKit-tracked goals.

---

## Section 3: CloudKit Changes (`CloudKitManager`)

Two new methods following the same delete-all/save-all pattern as `saveHabits`/`fetchHabits`:

### `saveGoals(_ goals: [Goal], completion: @escaping (Error?) -> Void)`
Saves each `Goal` as a `CKRecord` with type `"Goal"`. Serialized fields:
- `id` (String), `title`, `description`, `category`, `trackingType`
- `targetValue`, `currentProgress`, `startDate`, `targetDate?`, `notes?`
- `isCompleted` (Int 0/1)
- `awardedMilestones` (JSON-encoded `[Int]`)

`photoData` is explicitly excluded.

### `fetchGoals(completion: @escaping (Result<[Goal], Error>) -> Void)`
Fetches all `"Goal"` records and reconstructs `[Goal]`. `awardedMilestones` is decoded from its JSON blob back into `Set<Int>`.

`UserViewModel` calls these in `fetchFromCloud()` and `uploadToCloud()` alongside existing habits sync.

---

## Section 4: UserViewModel Changes

### New published state
```swift
@Published var goals: [Goal] = []
@Published var showingMilestoneReward = false
@Published var lastMilestoneMessage = ""  // e.g. "Goal 50% complete! +50 XP, +25 Gold"
```

Milestone notifications reuse the same alert/overlay trigger pattern as `showingLevelUp` — a boolean flag set in `awardMilestone` drives a `.alert` in `GoalsView`.

### New public methods
| Method | Purpose |
|---|---|
| `addGoal(_:)` | Append, save locally, upload |
| `deleteGoal(at:)` | Remove, save, upload |
| `updateManualProgress(goalId:newValue:)` | Set currentProgress, trigger milestone check, save |
| `refreshHealthKitGoals()` | Called from syncHealthData; fires range queries for .steps/.calories goals |

### New private methods
| Method | Purpose |
|---|---|
| `checkMilestones(for:)` | Computes progress %, finds un-awarded thresholds crossed |
| `awardMilestone(_:threshold:)` | Grants XP + Gold + stat boost; at 100% appends Trophy Item |

### Milestone reward table
| Milestone | XP | Gold | Stat Boost |
|---|---|---|---|
| 25% | 25 | 10 | +1 |
| 50% | 50 | 25 | +2 |
| 75% | 100 | 50 | +3 |
| 100% | 200 | 100 | +5 + Trophy Item |

**Stat boost targeting** (from `GoalCategory`):
- `.fitness` → Strength
- `.wellness` → Vitality
- `.learning` → Intelligence
- `.financial` → Intelligence (+half boost) + Charisma (+half boost)
- `.social` → Charisma

**Trophy Item** (awarded at 100%):
```swift
Item(name: "\(goal.title) Trophy", description: "Completed: \(goal.title)", icon: "trophy.fill", price: 0, statBoost: nil)
```
Added directly to `user.inventory`.

### Local persistence
Goals saved/loaded via `UserDefaults` under key `"LifeXPGoals"` using `JSONEncoder`/`JSONDecoder`, matching the habits pattern.

---

## Section 5: Views

### `GoalsView.swift` (new)
- Root view for Goals tab
- List of `GoalRow` cards: title, category icon, progress bar, percentage label
- "+" toolbar button sheets into `AddGoalView`
- Tap a row navigates to `GoalDetailView`
- Empty state message when no goals exist
- Preview data provided in `PreviewData.swift`

### `AddGoalView.swift` (new)
- `NavigationView` with `Form`
- Fields: Title, Description, `GoalCategory` Picker, `GoalTrackingType` Picker
- Target value numeric input (`TextField` with `.numberPad`)
- Optional `DatePicker` for target date
- Notes text field
- Confirms via "Add Goal" toolbar button (disabled when title empty)

### `GoalDetailView.swift` (new)
- Full goal info header
- Circular progress ring with percentage
- Milestone markers at 25/50/75/100% (filled when awarded)
- **Manual goals:** "Log Progress" button opens a number-input sheet to call `updateManualProgress`
- **HealthKit goals:** "Refresh" button triggers `refreshHealthKitGoals()`
- Optional photo: `PhotosPicker` saves `photoData` to goal locally

### `ContentView.swift` (modified)
Adds Goals tab alongside existing tabs:
```swift
GoalsView(viewModel: viewModel)
    .tabItem { Label("Goals", systemImage: "target") }
```

---

## Out of Scope (Future Work)
- CloudKit photo sync via `CKAsset`
- Additional HealthKit goal types (weight, heart rate, sleep)
- Goal sharing or social features
- Push notifications for approaching target dates
