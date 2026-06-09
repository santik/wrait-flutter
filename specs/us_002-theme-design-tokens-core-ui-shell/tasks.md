# Tasks: Theme, Design Tokens & Core UI Shell

> **Feature number:** 003
> **Plan:** [`plan.md`](plan.md)
> **Author:** Codex
> **Date:** 2026-06-08

---

## Legend

- `[ ]` — not started
- `[x]` — complete
- `[P]` — can be parallelized with other `[P]` tasks in the same group
- `[B]` — blocked (note the blocker)

## Task groups

_Tasks are organized into sequential groups.
Tasks within the same group marked `[P]` can be worked on in parallel._

### Group 1: Build the reusable theme foundation

_Create the centralized presentation primitives that the shell will consume._

- [x] Create the shared design-token surface for spacing, animation timings, gesture thresholds, adaptive button sizing, and reserved status/quota heights — `lib/presentation/theme/design_tokens.dart`
- [x] [P] Translate the approved Wrait light and dark palettes into explicit Flutter color definitions — `lib/presentation/theme/wrait_colors.dart`
- [x] [P] Define the reusable typography roles needed by the shell with similar look and feel to the Android reference — `lib/presentation/theme/wrait_typography.dart`
- [x] Build the Wrait light/dark Material 3 theme configuration that uses the new colors and typography — `lib/presentation/theme/wrait_theme.dart`
  - Depends on: Group 1 token, color, and typography tasks
- [x] Implement the adaptive button-size helper as a pure width-to-size calculation using the approved ratio and clamp bounds — `lib/presentation/theme/adaptive_button_size.dart`
  - Depends on: Group 1 token task

### Group 2: Apply the theme at the app root

_Replace the provisional app styling with the approved shell theme behavior._

- [x] Update the app root to use the Wrait light and dark themes and follow system appearance automatically — `lib/app.dart`
  - Depends on: Group 1

### Group 3: Build the shared shell placeholder experience

_Create the placeholder UI that demonstrates the story’s user-facing shell contracts without introducing feature logic._

- [x] Create the shared shell placeholder screen that renders route-specific titles, optional entry ID content, reserved message areas, and an adaptive button-size preview — `lib/presentation/shell/shell_placeholder_screen.dart`
  - Depends on: Groups 1 and 2
- [x] Convert the existing home placeholder into a thin route-specific wrapper around the shared shell placeholder — `lib/presentation/home/home_placeholder_screen.dart`
  - Depends on: Group 3 shared shell task

### Group 4: Expand the routing surface

_Wire the approved destinations to the new placeholder shell._

- [x] Expand the router to support `/`, `/entries`, and `/entry/:id`, ensuring any non-empty entry ID can render the detail placeholder — `lib/core/router/app_router.dart`
  - Depends on: Group 3

### Group 5: Validate logic and user flows after implementation

_Add post-implementation automated coverage for the approved contracts and then run the validation commands._

- [x] Update the app smoke test to verify the default route renders the new themed shell correctly — `test/app_smoke_test.dart`
  - Depends on: Groups 2, 3, and 4
- [x] Add routing tests that cover direct accessibility for `/`, `/entries`, and `/entry/:id`, including the core placeholder user flow across the approved destinations — `test/core/router/app_router_test.dart`
  - Depends on: Groups 3 and 4
- [x] Add a widget test that verifies the placeholder shell keeps the reserved status/quota layout space even when those message areas are empty — `test/app_smoke_test.dart` or `test/core/router/app_router_test.dart`
  - Depends on: Groups 3 and 4
- [x] Add unit tests for adaptive button sizing across ratio, minimum clamp, and maximum clamp scenarios — `test/presentation/theme/adaptive_button_size_test.dart`
  - Depends on: Group 1 adaptive sizing task
- [x] Add theme tests that verify the reusable text roles and both light/dark theme surfaces are exposed as planned — `test/presentation/theme/wrait_theme_test.dart`
  - Depends on: Groups 1 and 2
- [x] Run `flutter analyze` and record zero-warning results as validation evidence
  - Depends on: Groups 1, 2, 3, 4, and 5 test-creation tasks
- [x] Run `flutter test` and record that the logic and user-flow tests pass after implementation
  - Depends on: Groups 1, 2, 3, 4, and 5 test-creation tasks
- [x] Perform manual Android and iOS light/dark verification plus direct-route checks for `/entries` and `/entry/<non-empty-id>` and record the results in this file
  - Depends on: Groups 1, 2, 3, and 4
- [x] Record validation evidence and any implementation notes directly in this file — `specs/003-theme-design-tokens-core-ui-shell/tasks.md`
  - Depends on: All groups

## Completion criteria

All tasks checked, `flutter analyze` warning-free, `flutter test` passing after
implementation, manual Android/iOS light-dark verification completed, and
validation evidence documented in this file.

## Validation evidence

_Record test results, screenshots, or command output here when complete._

```text
$ dart format lib test specs/003-theme-design-tokens-core-ui-shell
Formatted 16 files (6 changed) in 0.04 seconds.

$ flutter analyze
The following plugins do not support Swift Package Manager for ios:
  - sqflite_sqlcipher
No issues found! (ran in 7.2s)

$ flutter test
00:01 +13: All tests passed!

$ flutter run -d emulator-5554
Launched on Android emulator.
Manual verification captured:
- Light mode root shell screenshot: `/tmp/wrait-home-light-android.png`
- Dark mode root shell screenshot after relaunch under night mode: `/tmp/wrait-home-dark2-android.png`
- Verified title `Capture`, reserved status/quota sections, and adaptive button preview in both modes.

$ flutter run -d 0140EF83-0B3E-4517-B669-FDBE5E3B0BBA
Launched on iPhone 17 Pro simulator.
Manual verification captured:
- Light mode root shell screenshot: `/tmp/wrait-home-light-ios.png`
- Dark mode root shell screenshot after relaunch under dark appearance: `/tmp/wrait-home-dark3-ios.png`
- Verified title `Capture`, reserved status/quota sections, and adaptive button preview in both modes.

$ flutter run -d emulator-5554 --route=/entries
Manual direct-route verification captured:
- `/entries` screenshot: `/tmp/wrait-entries-android.png`
- UI dump confirms title `Entries`: `/tmp/wrait-entries-android.xml`

$ flutter run -d emulator-5554 --route=/entry/day-001
Manual direct-route verification captured:
- `/entry/day-001` screenshot: `/tmp/wrait-entry-android.png`
- UI dump confirms `Entry preview` and `Entry ID: day-001`: `/tmp/wrait-entry-android.xml`
```

## Notes

- The app router now honors Flutter's platform startup route when no explicit `initialLocation` is injected, which allows manual verification with `flutter run --route=...` while preserving the test override path.
- Android and iOS both followed system light/dark appearance once the app was launched or relaunched under the target mode.
- `sqflite_sqlcipher` still emits the existing Swift Package Manager support warning during Flutter commands, but it did not block implementation or validation.
- Several plugins still emit the existing Kotlin Gradle Plugin migration warning during Android builds (`package_info_plus`, `share_plus`, `speech_to_text`, `wakelock_plus`).
