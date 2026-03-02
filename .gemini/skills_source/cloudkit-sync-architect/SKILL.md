---
name: cloudkit-sync-architect
description: Expert in Apple's CloudKit framework for Life-XP-iOS. Use when managing data persistence, resolving sync conflicts, or implementing CKSubscription for multi-device support.
---

# CloudKit Sync Architect

This skill provides procedural knowledge for managing CloudKit synchronization in Life-XP-iOS.

## Core Framework Concepts

### 1. Record Types
- **LifeXPUser**: Stores XP, Level, Gold, and Stats.
- **Habit**: Stores Title, Frequency, and Completion History.
- **Item**: Stores Owned status and Boost values.

### 2. Implementation Patterns

#### Saving a Record
```swift
let record = CKRecord(recordType: "Habit")
record["title"] = habit.title
record["isCompleted"] = habit.isCompleted

CKContainer.default().privateCloudDatabase.save(record) { record, error in
    // Handle success or error...
}
```

### 3. Conflict Resolution
Always prefer the **Latest Change Wins** policy for simple RPG stats, but **Merge History** for habit completions to avoid data loss.
- Use `CKRecordValue` for basic fields.
- Use `CKAsset` for larger binary data (e.g., character portraits) if needed.

## Workflows

### Implementing Multi-device Sync
When asked to ensure habits sync across devices:
1. Register for `CKRecordZoneSubscription` in `CloudKitManager`.
2. Handle `CKQueryNotification` in `AppDelegate` or via `NotificationCenter`.
3. Re-fetch changed records and update the local `UserViewModel` state.
4. Trigger UI updates using `@Published` properties.

### Debugging Sync Failures
1. Check `CKError` codes (e.g., `.notAuthenticated`, `.networkFailure`).
2. Verify CloudKit Container ID in "Signing & Capabilities".
3. Validate Record Type schemas in the CloudKit Dashboard.
