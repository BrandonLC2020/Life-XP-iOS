# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

All commands below are run from the primary working directory (`Life-XP-iOS/Life-XP-iOS/`).

**Build:**
```bash
xcodebuild -project Life-XP-iOS.xcodeproj -scheme Life-XP-iOS -destination 'platform=iOS Simulator,name=iPhone 16e' build
```

**Test (all):**
```bash
xcodebuild test -project Life-XP-iOS.xcodeproj -scheme Life-XP-iOS -destination 'platform=iOS Simulator,name=iPhone 16e'
```

**Lint:**
```bash
swiftlint lint --strict
```

SwiftLint runs automatically on staged Swift files at commit time. Violations block the commit. The pre-push hook runs the full test suite and blocks push on failure.

## Architecture

**MVVM** with a single central ViewModel. No external dependencies — only Apple frameworks (SwiftUI, HealthKit, CloudKit, Combine, UserDefaults).

**Data flow:**
- `Models.swift` — `LifeXPUser`, `Habit`, `Item` structs (all `Codable`)
- `UserViewModel.swift` — single `ObservableObject` holding all app state; handles XP calculations, leveling, habit completion, cloud sync coordination
- `Managers/` — `HealthKitManager` and `CloudKitManager` are singletons that encapsulate Apple framework integration; called from `UserViewModel`
- `Views/` — SwiftUI views observe `UserViewModel` via `@ObservedObject`; `ContentView` holds the root `@StateObject`

**Persistence:** UserDefaults for local data; CloudKit private database for cross-device sync. CloudKit merge logic uses highest level/XP wins.

**HealthKit → XP conversion ratios** (defined in `UserViewModel`):
- 100 steps → 1 XP
- 10 kcal → 1 XP
- 0.25L water → 5 XP (+1 Intelligence)
- 1 hour sleep → 10 XP (+1 Vitality)

## Conventions

- Use `@StateObject` in top-level views, `@ObservedObject` in subviews.
- Keep HealthKit/CloudKit integration logic inside the respective Manager classes.
- Provide mock data in `PreviewData.swift` for all new SwiftUI views.
- Prefer `async/await` for new async code; legacy Managers use `Combine` and completion handlers.
- Use SF Symbols and system colors throughout — no custom icon assets.
