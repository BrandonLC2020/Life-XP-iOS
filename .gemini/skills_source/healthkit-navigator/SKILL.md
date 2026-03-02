---
name: healthkit-navigator
description: Deep expertise in Apple's HealthKit framework for Life-XP-iOS. Use when implementing HKStatisticsQuery, managing HealthKit permissions, or mapping health data to RPG stats.
---

# HealthKit Navigator

This skill provides procedural knowledge for implementing HealthKit integrations in Life-XP-iOS.

## Core Framework Concepts

### 1. Data Mapping to RPG Stats
- **Steps**: Boosts **Strength** and provides **XP**. (Goal: 10,000 steps).
- **Active Calories**: Boosts **Strength** and **Vitality**. (Goal: 500 kcal).
- **Sleep Hours**: Boosts **Intelligence** and **Vitality**. (Goal: 7-8 hours).
- **Water Intake**: Boosts **Vitality**. (Goal: 2000 ml).

### 2. Implementation Patterns

#### HKStatisticsQuery
For fetching daily aggregates (e.g., total steps today):
```swift
let type = HKQuantityType.quantityType(forIdentifier: .stepCount)!
let now = Date()
let startOfDay = Calendar.current.startOfDay(for: now)
let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
    guard let sum = result?.sumQuantity() else { return }
    let steps = sum.doubleValue(for: HKUnit.count())
    // Process steps...
}
```

### 3. Permission Management
Always use `HKHealthStore().requestAuthorization(toShare:read:completion:)` before querying.
- Provide clear reason strings in `Info.plist`.
- Gracefully handle "denied" states by showing a fallback UI in `HealthKitManager`.

## Workflows

### Adding a New Metric
When asked to sync a new HealthKit metric:
1. Identify the `HKQuantityTypeIdentifier`.
2. Define the corresponding RPG stat it impacts.
3. Update `HealthKitManager` with a new `fetchX()` method.
4. Update `UserViewModel` to handle the incoming data and award XP.
5. Ensure `Info.plist` has the required usage description.
