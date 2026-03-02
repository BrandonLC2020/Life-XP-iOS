---
name: swiftui-game-stylist
description: Expert in SwiftUI animations, custom UI components, and haptic feedback for gamified experiences in Life-XP-iOS. Use when creating level-up sequences, progress bars, or reward animations.
---

# SwiftUI Game Stylist

This skill provides procedural knowledge for creating high-polish, gamified UI in Life-XP-iOS.

## Core Design Principles

### 1. Visual Juice and Feedback
Every player action should have a satisfying visual and haptic response.
- **Level Up**: Scale effect with a burst animation (e.g., `ZStack` of circles).
- **Gold Gain**: `UIImpactFeedbackGenerator(style: .medium).impactOccurred()`.
- **Habit Check**: Spring animation (`.spring(response: 0.3, dampingFraction: 0.6)`).

### 2. RPG Themed Components
- **Progress Bars**: Use custom `LinearGradient` (e.g., Gold/Yellow for XP, Blue for Vitality).
- **Stat Cards**: Shadowed cards with secondary system backgrounds and SF Symbols.
- **Inventory Grid**: Square tiles with rounded corners (e.g., `cornerRadius(12)`).

## Workflows

### Creating a Reward Animation
When asked to add a "Gold Gain" animation:
1. Use `@State private var isAnimating = false`.
2. Wrap the gold icon in a `ScaleEffect` or `Offset` change.
3. Trigger the animation in `withAnimation` on tap or completion.
4. Call `HapticManager` for tactile feedback.

### Building a New Screen
1. Start with a `ScrollView` and `LazyVStack` for consistent layout.
2. Use standard `Section` wrappers for grouping stats/habits.
3. Apply `NavigationTitle` and appropriate `ToolbarItem` for actions.
4. Ensure `SwiftUI Previews` are updated in `PreviewData.swift`.
