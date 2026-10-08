> **Status: ✅ DONE — implemented 2026-10-07 in `lib/widgets/sidebar.dart`, not yet committed.**

# Sidebar Card Separation Plan

## Goal
Wrap the Settings and Logout section in a card-style container with rounded corners to create clear visual separation from the Buckets list, replacing the current thin Divider approach.

## Current State
- Settings and Logout are `AppListTile` widgets inside a `Padding` container at the bottom of the sidebar
- Separated from Buckets list only by a thin `Divider()` with minimal spacing
- No clear visual hierarchy between navigation content and account actions

## Design Decision
**Option 2: Card-style container** (user preference)
- Wrap Settings/Logout in a Container with rounded corners
- Add spacing above and below the card
- Use subtle background color and optional border/shadow for definition
- Remove or keep the existing Divider (card provides sufficient separation)

## Implementation

### File: `lib/widgets/sidebar.dart`

**Current structure (lines 85-118):**
```dart
const Divider(),
Padding(
  padding: const EdgeInsets.all(AppSpacing.sm),
  child: Column(
    children: [
      AppListTile(title: 'Settings', ...),
      const SizedBox(height: AppSpacing.xs),
      AppListTile(title: 'Logout', ...),
    ],
  ),
),
```

**New structure:**
```dart
const SizedBox(height: AppSpacing.md),
Container(
  margin: const EdgeInsets.symmetric(
    horizontal: AppSpacing.sm,
    vertical: AppSpacing.sm,
  ),
  padding: const EdgeInsets.all(AppSpacing.sm),
  decoration: BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: AppColors.borderLight),
    boxShadow: [
      BoxShadow(
        color: AppColors.shadowColor,
        blurRadius: 4,
        offset: const Offset(0, 1),
      ),
    ],
  ),
  child: Column(
    children: [
      AppListTile(title: 'Settings', ...),
      const SizedBox(height: AppSpacing.xs),
      AppListTile(title: 'Logout', ...),
    ],
  ),
),
```

**Key changes:**
1. Replace `Divider()` with `SizedBox(height: AppSpacing.md)` for spacing
2. Wrap the bottom actions Column in a Container with:
   - `margin`: horizontal and vertical spacing from sidebar edges
   - `padding`: internal spacing around the list tiles
   - `decoration`:
     - `color`: `AppColors.surface` (white) for contrast against sidebar background
     - `borderRadius`: 8px rounded corners
     - `border`: subtle light border (`AppColors.borderLight`)
     - `boxShadow`: very subtle shadow for depth (optional, can remove if too heavy)

## Validation
- Settings and Logout should appear in a distinct card
- Clear visual separation from Buckets list
- Consistent with macOS design language (rounded corners, subtle shadows)
- No functional changes to Settings/Logout behavior
- Responsive to sidebar width changes

## Rollback Path
If Option 2 doesn't work visually, revert to:
- Remove the Container wrapper
- Restore the `Divider()` approach
- Adjust spacing as needed
