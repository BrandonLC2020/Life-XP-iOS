---
name: rpg-mechanics-balancer
description: Expert in RPG progression systems, XP curves, and reward balancing for Life-XP-iOS. Use when designing habit rewards, leveling formulas, or item stat boosts.
---

# RPG Mechanics Balancer

This skill provides procedural knowledge for balancing the Life-XP-iOS gamification systems.

## Core Progression Concepts

### 1. XP Curve Calculation
Life-XP uses a standard exponential XP curve.
- **Formula**: `XP_for_Level_N = base_xp * (level ^ exponent)`
- **Standard Defaults**: `base_xp = 100`, `exponent = 1.5`
- **Goal**: Each level should take roughly 15-20% longer than the previous.

### 2. Reward Scaling
Habits and HealthKit activities provide XP and Gold.
- **Daily Habit**: ~50 XP, ~10 Gold.
- **Health Goal (e.g., 10k steps)**: ~100 XP, ~20 Gold.
- **Difficulty Multiplier**: Easy (1.0x), Medium (1.5x), Hard (2.0x).

### 3. Stat Boosts (Strength, Intelligence, Vitality, Charisma)
Items in the shop provide static or percentage boosts.
- **Early Game Items**: +2-5 to a stat.
- **Late Game Items**: +15-25 to a stat or 5-10% multiplier.

## Workflows

### Balancing a New Item
When asked to create a new shop item:
1. Determine the target level range for the item.
2. Calculate the average player gold income at that level.
3. Set the price to ~3-5 days of consistent activity.
4. Set stat boosts relative to the player's average base stats at that level.

### Adjusting Difficulty
If a user reports leveling is too fast/slow:
1. Analyze the current `UserViewModel` XP logic.
2. Propose a change to the `exponent` or `base_xp`.
3. Simulate the impact across levels 1-50 before applying.
