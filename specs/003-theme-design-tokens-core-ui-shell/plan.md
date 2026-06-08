# Implementation Plan: Theme, Design Tokens & Core UI Shell

> **Feature number:** 003
> **Spec:** [`spec.md`](spec.md)
> **Author:** Codex
> **Date:** 2026-06-08

---

## Approach summary

Extend the existing Flutter foundation by replacing the seed-generated app theme with a Wrait-specific Material 3 theme that supports both light and dark color schemes through `ThemeMode.system`, centralizing the approved design tokens in a reusable presentation-layer module, and expanding the router from a single placeholder route to the three approved shell destinations. The placeholder experience will use one shared layout with route-specific titles and an entry-ID variant for `/entry/:id`, plus a small shell preview that exercises reserved status/quota space and adaptive primary-button sizing so those behaviors can be verified without introducing real feature logic. This satisfies the approved spec by delivering centralized reusable UI rules, cross-platform light/dark theming, route coverage for `/`, `/entries`, and `/entry/:id`, and automated evidence for routing and button-sizing behavior.

## Architecture decisions

| Decision | Choice | Rationale |
| --- | --- | --- |
| Theme ownership | Put reusable theme code under `lib/presentation/theme/` | Colors, typography, spacing, and sizing are presentation concerns. Keeping them in the presentation layer avoids turning UI tokens into generic core infrastructure while still making them available app-wide. |
| Dark mode behavior | Use `ThemeMode.system` with paired light and dark Material 3 `ThemeData` | The approved spec requires automatic device/system-following dark mode and explicitly excludes an in-app override. |
| Token structure | Model approved constants in small focused Dart types grouped by concern | Splitting spacing, animation, gesture, button, and reserved-layout values keeps the token surface readable and makes future stories less likely to redefine constants ad hoc. |
| Color strategy | Translate the Android reference palette into explicit light/dark color schemes rather than `ColorScheme.fromSeed` | The current seed-based theme cannot reliably match the approved Wrait look and feel across both modes. Direct palette mapping gives predictable results. |
| Typography strategy | Define the required Material text roles explicitly and keep the font family platform-default for now | The spec wants similar feel rather than exact parity. Explicit sizes and line heights give consistent roles without adding font assets in this story. |
| Adaptive button sizing | Implement a pure helper that computes button size from available width using ratio plus clamp rules | A pure function is easy to reuse and unit test, and it isolates the numeric acceptance criteria from widget layout code. |
| Placeholder shell design | Use one shared placeholder screen widget configured by title and optional entry ID | This matches the approved clarification that `/` and `/entries` may share a layout while still making each route distinct. |
| Route verification approach | Keep direct route accessibility as the routing contract and verify it with router/widget tests | The spec does not require in-app navigation controls yet, so tests can focus on route reachability and rendered titles instead of temporary buttons. |
| Reserved message areas | Render explicit status/quota slots in the placeholder shell using tokenized reserved heights | This makes the reserved-space behavior visible and testable now, and gives later stories a reusable shell pattern for transient messaging. |

## File changes

| File | Action | Description |
| --- | --- | --- |
| `lib/app.dart` | Modify | Replace the seed-based theme with explicit light/dark Wrait themes, set `themeMode` to system, and keep router wiring intact |
| `lib/core/router/app_router.dart` | Modify | Expand the router to support `/`, `/entries`, and `/entry/:id`, including passing entry IDs into the placeholder screen |
| `lib/presentation/home/home_placeholder_screen.dart` | Modify | Convert the current foundation placeholder into a thin route-specific wrapper around the shared shell placeholder layout |
| `lib/presentation/theme/design_tokens.dart` | Create | Centralize approved spacing, animation, gesture, button-sizing, and reserved-layout constants |
| `lib/presentation/theme/wrait_colors.dart` | Create | Define the explicit light/dark palette translated from the Android reference |
| `lib/presentation/theme/wrait_typography.dart` | Create | Define the required reusable Material text roles with Flutter text styles |
| `lib/presentation/theme/wrait_theme.dart` | Create | Build the light/dark `ThemeData` instances and any small theme extensions needed by the shell |
| `lib/presentation/theme/adaptive_button_size.dart` | Create | Pure helper for computing the adaptive primary-button size from available width |
| `lib/presentation/shell/shell_placeholder_screen.dart` | Create | Shared placeholder layout that renders route-specific titles, optional entry ID, reserved status/quota slots, and a simple button-size preview |
| `test/app_smoke_test.dart` | Modify | Update the existing app smoke test to validate the new shell content and default route rendering |
| `test/core/router/app_router_test.dart` | Create | Verify that the three approved routes are reachable and render the expected titles/ID content |
| `test/presentation/theme/adaptive_button_size_test.dart` | Create | Unit tests for ratio, minimum, and maximum button sizing behavior |
| `test/presentation/theme/wrait_theme_test.dart` | Create | Widget or unit-oriented checks that light/dark theme data expose the expected reusable text roles and switch with brightness |

## API contract details

No HTTP endpoints are implemented or changed in US-002.

The implementation-specific contract is internal to the client shell:

- Route paths:
  - `/` renders the home shell placeholder
  - `/entries` renders the entries shell placeholder
  - `/entry/:id` renders the entry placeholder for any non-empty `id`
- Theme behavior:
  - light and dark themes are both available
  - active theme follows the platform brightness automatically
  - no user-controlled override is exposed in this story
- Button sizing helper:
  - input: available container width in logical pixels
  - output: a clamped logical-pixel size using the approved ratio/min/max rules

## Data model changes

No persistent application data model changes are required.

This story does introduce new internal presentation contracts for reusable theme and layout behavior.

### Before

```dart
// No centralized Flutter presentation-token surface exists yet.
// The app uses a seed-based theme and a single hard-coded placeholder route.
```

### After

```dart
class AdaptiveButtonSize {
  static double forWidth(double widthDp) => ...;
}

abstract final class DesignTokens {
  static const fadeDurationMs = 300;
  static const pulseDurationMs = 1800;
  static const buttonAlphaDurationMs = 200;
  static const deleteFadeDurationMs = 200;

  // Additional spacing, gesture, reserved-height, and button clamp values...
}
```

### Migration

No migration is required because no persisted data or stored schema changes.

## Test strategy

Validation will focus on reusable UI contracts and the key user flows introduced by this shell story. Implementation should be completed first, and then automated tests should be run as post-implementation validation to prove the routing surface, system-following light/dark theme support, adaptive button-size math, and the core placeholder user flows across the approved destinations. Manual verification will confirm the shell looks coherent on Android and iOS in both appearance modes.

### Automated tests

| Test case | Type | File |
| --- | --- | --- |
| Root route renders the shared placeholder shell with the home title | Widget | `test/app_smoke_test.dart` |
| Entries route renders the shared placeholder shell with the entries title | Widget | `test/core/router/app_router_test.dart` |
| Entry-detail route renders successfully for a non-empty ID and displays that ID | Widget | `test/core/router/app_router_test.dart` |
| App shell user flow can move through the approved route set and render the expected placeholder states | Widget | `test/core/router/app_router_test.dart` |
| Placeholder shell preserves reserved status/quota space when messages are absent | Widget | `test/app_smoke_test.dart` or `test/core/router/app_router_test.dart` |
| Theme data exposes the intended reusable text roles in light mode | Unit or widget | `test/presentation/theme/wrait_theme_test.dart` |
| Theme data exposes the intended reusable text roles in dark mode | Unit or widget | `test/presentation/theme/wrait_theme_test.dart` |
| Adaptive button size uses the approved ratio for a typical handset width | Unit | `test/presentation/theme/adaptive_button_size_test.dart` |
| Adaptive button size clamps to the minimum for narrow widths | Unit | `test/presentation/theme/adaptive_button_size_test.dart` |
| Adaptive button size clamps to the maximum for wide widths | Unit | `test/presentation/theme/adaptive_button_size_test.dart` |
| `flutter analyze` completes with zero warnings after the theme and routing changes | Static analysis | N/A command evidence recorded in `tasks.md` |

### Manual verification

1. Complete the implementation tasks for theme, tokens, routing, and placeholder shell behavior.
2. Run `flutter analyze` and confirm there are no warnings.
3. Run `flutter test` and confirm the logic and user-flow tests pass.
4. Launch the app on Android with light system appearance and verify the root placeholder uses the intended light palette, typography hierarchy, reserved message space, and button-size preview.
5. Switch Android to dark system appearance and verify the shell follows automatically without an in-app toggle.
6. Launch the app on iOS with light system appearance and verify the same shell behavior and visual hierarchy.
7. Switch iOS to dark system appearance and verify the shell follows automatically without an in-app toggle.
8. Navigate directly to `/entries` and `/entry/<non-empty-id>` during local verification and confirm each route renders the expected title or entry ID.

## Integration notes

- The new theme layer will plug into the existing `MaterialApp.router` bootstrap in [lib/app.dart](/Users/alexander/projects/wrait/write-flutter/lib/app.dart) without changing runtime configuration flow.
- Routing continues to use GoRouter, but the configuration will expand beyond the current single route so later stories can attach real screens without restructuring the router again.
- The placeholder shell will likely replace the current configuration-oriented foundation placeholder, so config values used purely for bootstrap proofing will no longer drive the primary UI in this story.
- Android reference files remain the source for approved token values and visual direction, but the Flutter implementation will intentionally aim for similar feel rather than exact one-to-one typography parity.
- No backend, persistence, or permission integration points are added in this story.

## Rollout & migration

This is an additive refinement of the existing Flutter foundation.

- No feature flags are needed.
- No data migration is required.
- Backward compatibility risk is limited to replacing the existing placeholder shell and route structure, which is acceptable because no user-facing production flow depends on it yet.
- Future stories can build on the centralized token/theme layer instead of introducing parallel constants or alternate shell routes.

## Risks & mitigations

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| Flutter light/dark palette drifts noticeably from the Android reference | Medium | Medium | Translate the reference colors directly into explicit theme definitions and verify both modes manually on Android and iOS |
| Theme tests become brittle if they assert too many exact widget details | Medium | Medium | Focus tests on stable contracts such as route rendering, text-role availability, and button-size math rather than pixel-perfect snapshots |
| Adaptive button sizing is computed from the wrong width source | Medium | High | Isolate the sizing math in a pure helper and drive it from the layout width supplied by Flutter constraints during widget composition |
| Replacing the config-oriented placeholder removes useful bootstrap visibility | Low | Medium | Keep automated config tests in place and ensure the app smoke test still proves successful bootstrap through app rendering |
| Dark mode contrast or surface choices feel acceptable on one platform but weak on the other | Medium | Medium | Validate on both Android and iOS with manual checks in light and dark system modes before closing the story |

## Open items from spec

None.
