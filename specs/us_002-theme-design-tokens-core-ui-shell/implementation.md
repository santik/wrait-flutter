# Implementation Notes: Theme, Design Tokens & Core UI Shell

## Summary

US-002 replaces the seed-based Flutter foundation theme with an explicit Wrait light/dark Material 3 theme, centralizes the story's design tokens, and expands the placeholder app shell to cover `/`, `/entries`, and `/entry/:id`.

## Key implementation points

- Added centralized presentation tokens in [lib/presentation/theme/design_tokens.dart](/Users/alexander/projects/wrait/write-flutter/lib/presentation/theme/design_tokens.dart) for spacing, timings, gesture thresholds, button sizing, and reserved layout heights.
- Added explicit Wrait palette and typography definitions in [wrait_colors.dart](/Users/alexander/projects/wrait/write-flutter/lib/presentation/theme/wrait_colors.dart), [wrait_typography.dart](/Users/alexander/projects/wrait/write-flutter/lib/presentation/theme/wrait_typography.dart), and [wrait_theme.dart](/Users/alexander/projects/wrait/write-flutter/lib/presentation/theme/wrait_theme.dart).
- Added the pure adaptive sizing helper in [adaptive_button_size.dart](/Users/alexander/projects/wrait/write-flutter/lib/presentation/theme/adaptive_button_size.dart).
- Replaced the old config-oriented placeholder with a shared shell placeholder in [shell_placeholder_screen.dart](/Users/alexander/projects/wrait/write-flutter/lib/presentation/shell/shell_placeholder_screen.dart) and a thin home wrapper in [home_placeholder_screen.dart](/Users/alexander/projects/wrait/write-flutter/lib/presentation/home/home_placeholder_screen.dart).
- Expanded GoRouter in [lib/core/router/app_router.dart](/Users/alexander/projects/wrait/write-flutter/lib/core/router/app_router.dart) to support `/`, `/entries`, and `/entry/:id`, and to honor Flutter's platform startup route for manual direct-route launches.

## Validation

- `flutter analyze` passed with no issues.
- `flutter test` passed with 13 tests covering:
  - root-shell rendering
  - reserved status/quota layout preservation
  - direct route rendering for `/entries` and `/entry/:id`
  - route flow transitions
  - adaptive button sizing math
  - light/dark theme contracts
- Manual screenshots were captured for:
  - Android root shell in light and dark mode
  - iOS root shell in light and dark mode
  - Android `/entries`
  - Android `/entry/day-001`

## Follow-up context

- Existing toolchain warnings for `sqflite_sqlcipher` Swift Package Manager support and several Android Kotlin Gradle Plugin migrations remain unchanged from the project foundation story.
