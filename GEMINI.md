# Life-XP iOS Project Context

## Project Overview
Life-XP is a gamified life-tracking iOS application built with SwiftUI. It transforms real-world health data and habit completion into a role-playing game (RPG) experience where users gain experience points (XP), level up, and earn gold to purchase virtual items.

### Core Features
- **Health Integration:** Syncs with HealthKit to convert steps, active calories, sleep, and water intake into XP and stat boosts.
- **Habit Tracking:** Users can create and complete daily habits to earn rewards.
- **RPG Mechanics:** Character leveling system with core stats: Strength, Intelligence, Vitality, and Charisma.
- **Inventory & Shop:** A virtual shop where users can spend earned gold on items that provide stat boosts.
- **Cloud Sync:** Uses CloudKit to persist user progress and habits across devices.

### Tech Stack
- **Language:** Swift 5.10+
- **Framework:** SwiftUI
- **Data Persistence:** UserDefaults (Local) & CloudKit (Remote)
- **Health Data:** HealthKit
- **Reactive Programming:** Combine

## Project Structure
- `Life-XP-iOS/`: Main application source code.
    - `Managers/`: Singletons for system integrations (`HealthKitManager`, `CloudKitManager`).
    - `Models/`: Data structures (`LifeXPUser`, `Habit`, `Item`).
    - `ViewModels/`: Business logic and state management (`UserViewModel`).
    - `Views/`: SwiftUI view components.
- `Life-XP-iOSTests/`: Unit tests for models and view models.
- `Life-XP-iOSUITests/`: UI tests for critical user flows.

## Building and Running
As a standard Xcode project, the primary way to build and run is using Xcode.

### Prerequisites
- macOS with Xcode 15+ installed.
- A physical iOS device or Simulator.
- HealthKit and CloudKit capabilities must be enabled in the "Signing & Capabilities" tab for full functionality.

### Command Line
You can build and test the project using `xcodebuild`:

- **Build:**
  ```bash
  xcodebuild -project Life-XP-iOS/Life-XP-iOS.xcodeproj -scheme Life-XP-iOS -destination 'platform=iOS Simulator,name=iPhone 15' build
  ```

- **Test:**
  ```bash
  xcodebuild test -project Life-XP-iOS/Life-XP-iOS.xcodeproj -scheme Life-XP-iOS -destination 'platform=iOS Simulator,name=iPhone 15'
  ```

## Development Conventions
- **Architecture:** Follows the MVVM (Model-View-ViewModel) pattern.
- **State Management:** Use `@StateObject` in top-level views and `@ObservedObject` for subviews. Centralize state in `UserViewModel`.
- **Managers:** Keep integration logic (HealthKit/CloudKit) within their respective Manager classes.
- **Styling:** Use standard SwiftUI modifiers and prioritize system colors/icons (`SF Symbols`) for a native feel.
- **Async/Await:** Prefer modern Swift concurrency (`async/await`) where applicable, though some legacy `Combine` and completion handlers are present in the managers.
- **Previews:** Always provide `PreviewData.swift` or mock data for SwiftUI Previews to ensure UI components can be developed in isolation.
