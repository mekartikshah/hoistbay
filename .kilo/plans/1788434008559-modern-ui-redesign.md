> **Status: 🟡 PARTIAL — checked 2026-10-07; working-tree changes not yet committed.**
> - Phase 1 ✅ design system in `lib/theme/` + `lib/components/`.
> - Phase 2 ✅ sidebar navigation (`lib/widgets/sidebar.dart`), Settings section (`lib/screens/settings_screen.dart`), tabs removed.
> - Phase 3 ✅ screens restyled with the new components.
> - Phase 4 🟡 hover / drag-drop feedback exist, but `lib/components/app_animations.dart` is unused (no page/dialog transitions yet) and no platform window config (`Info.plist`, `Runner.rc`) was changed.
> - Phase 5 ⏳ website (separate repo) not started.

# Modern UI Redesign Plan

## Overview
Redesign the S3 Scout app with macOS-inspired design principles: clean, minimal, subtle animations, rounded corners, soft shadows, native feel. Focus on usability over visual flair. After app UI is complete, redesign the website to match.

## Current Issues
1. **Menu confusion**: CloudFront Manager accessible as both tab AND menu item
2. **Buried features**: Default HTTP Headers hidden in menu popup
3. **Visual clutter**: Too many UI chrome elements (sidebar + tabs + breadcrumbs + action bar + object list + details pane)
4. **Inconsistent patterns**: Different selection mechanisms, styling, and layouts across screens
5. **Color scheme**: Orange doesn't feel macOS-like or professional
6. **Heavy dialogs**: Default Headers uses 800x600 dialog which feels outdated

## Design Direction
- **Color palette**: macOS-style neutrals (grays, subtle blues, white backgrounds)
- **Typography**: System fonts (SF Pro on macOS, Segoe UI on Windows, Roboto on Linux)
- **Spacing**: Generous whitespace, 8px grid system
- **Corners**: 8-12px border radius for cards, 6px for buttons
- **Shadows**: Subtle, layered shadows (elevation 1-3)
- **Animations**: 200-300ms ease-in-out transitions
- **Native feel**: Platform-specific window controls, menus, dialogs

## Implementation Phases

### Phase 1: Design System Foundation
**Goal**: Establish consistent design tokens and reusable components

**Tasks**:
1. Create `lib/theme/` directory with:
   - `app_colors.dart`: Define neutral color palette
     - Primary: Blue accent (#007AFF - macOS blue)
     - Background: White (#FFFFFF), Light gray (#F5F5F7)
     - Surface: White (#FFFFFF), Card gray (#FAFAFA)
     - Text: Primary (#1D1D1F), Secondary (#86868B), Tertiary (#AEAEB2)
     - Borders: Light (#E5E5EA), Medium (#D1D1D6)
     - Success: Green (#34C759), Error: Red (#FF3B30), Warning: Orange (#FF9500)
   - `app_typography.dart`: Define text styles
     - Display: 28px bold
     - Title: 20px semibold
     - Headline: 17px semibold
     - Body: 15px regular
     - Caption: 13px regular
     - Small: 11px regular
   - `app_spacing.dart`: Define spacing scale (4, 8, 12, 16, 20, 24, 32, 40, 48)
   - `app_theme.dart`: Combine into ThemeData
     - Update `main.dart` to use new theme
     - Remove orange color scheme

2. Create `lib/components/` directory with reusable widgets:
   - `app_button.dart`: Primary, secondary, text, icon buttons with consistent styling
   - `app_card.dart`: Card component with subtle shadow and rounded corners
   - `app_input.dart`: Text field with consistent styling
   - `app_list_tile.dart`: List item with hover states
   - `app_dialog.dart`: Modern dialog with rounded corners
   - `app_progress.dart`: Progress indicators and loading states

**Files to create**:
- `lib/theme/app_colors.dart`
- `lib/theme/app_typography.dart`
- `lib/theme/app_spacing.dart`
- `lib/theme/app_theme.dart`
- `lib/components/app_button.dart`
- `lib/components/app_card.dart`
- `lib/components/app_input.dart`
- `lib/components/app_list_tile.dart`
- `lib/components/app_dialog.dart`
- `lib/components/app_progress.dart`

**Files to modify**:
- `lib/main.dart`: Update to use new theme

### Phase 2: Navigation Restructure
**Goal**: Simplify navigation, remove confusion, improve discoverability

**Tasks**:
1. **Remove tab-based navigation** between S3 and CloudFront
   - Both should be accessible from sidebar
   - Sidebar becomes the primary navigation

2. **Redesign sidebar** (`lib/widgets/bucket_list.dart` → `lib/widgets/sidebar.dart`):
   - Top section: Profile info with avatar/initials
   - Middle section: Navigation items
     - S3 Buckets (expandable to show bucket list)
     - CloudFront Distributions
   - Bottom section: Settings gear icon
   - Remove popup menu button

3. **Create Settings screen** (`lib/screens/settings_screen.dart`):
   - Move Default HTTP Headers here
   - Add profile management
   - Add about/version info
   - Accessible via sidebar gear icon

4. **Update browser_screen.dart**:
   - Remove TabBar and TabBarView
   - Replace with single content area that shows:
     - S3 browser (when bucket selected)
     - CloudFront manager (when CloudFront selected)
     - Settings (when settings selected)
   - Keep breadcrumb bar and action bar for S3 browser only

**Files to create**:
- `lib/widgets/sidebar.dart`
- `lib/screens/settings_screen.dart`

**Files to modify**:
- `lib/screens/browser_screen.dart`: Remove tabs, integrate sidebar
- `lib/widgets/bucket_list.dart`: Refactor into sidebar component
- `lib/providers/app_state.dart`: Add navigation state (selected section)

### Phase 3: Screen Redesigns
**Goal**: Apply new design system, reduce clutter, improve usability

**Tasks**:

1. **S3 Browser Screen**:
   - Simplify action bar: Move less-used actions to context menu
   - Primary actions: Upload, Download, Delete (visible)
   - Secondary actions: Copy, Move, Rename (in context menu or "More" button)
   - Improve object list styling with new components
   - Better empty states with illustrations
   - Smoother transitions between folders

2. **CloudFront Manager** (`lib/screens/cloudfront_manager_screen.dart`):
   - Redesign with new components
   - Replace DataTable with custom list cards
   - Improve distribution details panel
   - Add status badges with colors
   - Better loading and error states

3. **Settings Screen** (`lib/screens/settings_screen.dart`):
   - Clean settings layout with sections
   - Default HTTP Headers as a settings category
   - Redesign headers editor:
     - Replace 800x600 dialog with inline editor or smaller modal
     - Use cards instead of DataTable
     - Add/Edit/Delete with smooth animations
   - Profile management section
   - About section with version info

4. **Login/Profile Selection** (`lib/screens/login_screen.dart`, `lib/screens/profile_selection_screen.dart`):
   - Modern card-based design
   - Subtle animations on focus
   - Better visual hierarchy
   - Consistent with new design system

**Files to modify**:
- `lib/screens/browser_screen.dart`: Apply new design
- `lib/screens/cloudfront_manager_screen.dart`: Complete redesign
- `lib/screens/settings_screen.dart`: Create from scratch
- `lib/screens/login_screen.dart`: Redesign
- `lib/screens/profile_selection_screen.dart`: Redesign
- `lib/widgets/unified_action_bar.dart`: Simplify and modernize
- `lib/widgets/object_list.dart`: Use new components
- `lib/widgets/object_details_pane.dart`: Modernize
- `lib/widgets/breadcrumb_bar.dart`: Simplify

### Phase 4: Polish & Native Feel
**Goal**: Add subtle animations, ensure native feel on all platforms

**Tasks**:
1. **Add animations**:
   - Page transitions: 300ms fade + slide
   - List item hover: 200ms background color change
   - Button press: 150ms scale animation
   - Dialog open/close: 250ms fade + scale
   - Sidebar expand/collapse: 300ms height animation

2. **Platform-specific adjustments**:
   - macOS: Use system title bar, native menu bar
   - Windows: Adjust shadow intensity, button sizes
   - Linux: Ensure proper font rendering

3. **Micro-interactions**:
   - Drag-and-drop visual feedback
   - Selection animations
   - Loading state transitions
   - Error state shake animation

**Files to modify**:
- All screen files to add animations
- `lib/main.dart`: Configure platform-specific settings
- `macos/Runner/Info.plist`: Window configuration
- `windows/runner/Runner.rc`: Window configuration

### Phase 5: Website Redesign
**Goal**: Redesign website to match new app UI

**Tasks**:
1. **Update design language**:
   - Use same color palette as app
   - Match typography
   - Consistent spacing and layout

2. **Redesign sections** (`/Users/kartikshah/Documents/Kartik/Personal/s3-scout-website/`):
   - **Hero section**: 
     - Large app screenshot/mockup
     - Clear value proposition
     - Download buttons (Mac/Windows/Linux)
   - **Features section**:
     - 3-4 key features with icons
     - Clean grid layout
     - Subtle hover animations
   - **Screenshots section**:
     - Carousel or grid of app screenshots
     - Show different features
     - macOS-style window frames

3. **Update assets**:
   - Take new screenshots with redesigned app
   - Create feature icons/illustrations
   - Optimize images for web

**Files to modify**:
- `index.html`: Restructure content
- `style.css`: Complete redesign with new color palette
- `main.js`: Add smooth scroll, animations
- `assets/`: Update images and icons

## Success Criteria
- [ ] Consistent design language across all screens
- [ ] Reduced visual clutter (fewer UI chrome elements)
- [ ] Clear navigation hierarchy (no duplicate access paths)
- [ ] Native feel on macOS, Windows, Linux
- [ ] Smooth animations (200-300ms)
- [ ] Professional, modern appearance
- [ ] Website matches app design language
- [ ] All existing functionality preserved

## Risks & Mitigations
1. **Risk**: Breaking existing functionality during redesign
   - **Mitigation**: Test each screen after redesign, keep backup branch

2. **Risk**: Platform-specific issues (especially Linux)
   - **Mitigation**: Test on all three platforms, use Flutter's platform-aware widgets

3. **Risk**: Animation performance on lower-end machines
   - **Mitigation**: Keep animations subtle (200-300ms), use `AnimatedContainer` instead of complex animations

4. **Risk**: User confusion from major UI changes
   - **Mitigation**: Keep core workflows similar, add tooltips for new navigation

## Dependencies
- No new package dependencies required (use existing Flutter widgets)
- May need `flutter_animate` package for advanced animations (optional)

## Timeline
This is a large redesign that should be done incrementally:
1. Complete Phase 1 (Design System) before starting Phase 2
2. Complete Phase 2 (Navigation) before Phase 3 (Screens)
3. Phase 4 (Polish) can be done incrementally with Phase 3
4. Phase 5 (Website) should wait until app UI is stable

## Notes
- Keep the existing `AppState` architecture (it works well)
- Don't change core business logic, only UI/presentation
- Test drag-and-drop functionality after redesign
- Ensure accessibility (keyboard navigation, screen readers)
- Consider adding a "classic mode" toggle if users resist changes (optional)
