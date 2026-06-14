# Implementation: Main Screen UI

> **Feature number:** 011
> **Spec:** [`spec.md`](spec.md)
> **Plan:** [`plan.md`](plan.md)
> **Tasks:** [`tasks.md`](tasks.md)
> **Author:** Codex
> **Date:** 2026-06-13

---

## Outcome

US-011 now replaces the root placeholder with the real recording-focused main
screen. The app launches into the approved vertical stack with the circular
`wrait` button, under-button status line, entry stats, visible quota line when
quota data exists, and saved-entry navigation. Listening now renders both the
animated pulse treatment and the maximum-length countdown ring, and controller
error state metadata lets the UI distinguish generic errors from true
`saved as draft` outcomes.

## Implemented behavior

- Routed `/` to the new `MainScreen`.
- Added pure presentation helpers for:
  - button/status-line copy and status-line tap actions
  - fixed `{count} entries - {days} days` stats formatting
- Added reusable main-screen widgets:
  - `ButtonArea`
  - `PulseRing`
  - `CountdownRing`
- Added UI-owned saved-state auto-clear handling using
  `RecordingFeedbackDelays.savedDisplayWindow`.
- Added listening-state countdown support by carrying
  `hardCapDeadlineElapsedRealtime` inside `RecordingListening`.
- Added draft-preservation UI support by carrying `preservedDraft` inside
  `RecordingErrorState`.
- Kept settings UI, settings panel, swipe gestures, and mode selection out of
  scope as approved.

## File changes

### Production

- `lib/core/router/app_router.dart`
  - routes `/` to `MainScreen`
- `lib/presentation/main/recording_state.dart`
  - adds listening deadline metadata
  - adds draft-preserved error metadata
- `lib/presentation/main/main_recording_controller.dart`
  - populates the new listening metadata
  - propagates preserved-draft metadata from audio-draft and cleanup-failure
    paths
- `lib/presentation/main/main_screen_status.dart`
  - maps controller state to button label, status copy, and status actions
- `lib/presentation/main/main_screen_stats.dart`
  - derives main-screen stats from stored entries using local calendar dates
- `lib/presentation/main/pulse_ring.dart`
  - renders the listening pulse
- `lib/presentation/main/countdown_ring.dart`
  - renders the listening countdown ring
- `lib/presentation/main/button_area.dart`
  - composes the circular button, pulse, countdown, disabled opacity, and shake
- `lib/presentation/main/main_screen.dart`
  - composes quota, button, status, and stats
  - loads first-recording preference
  - drives saved auto-clear and countdown refresh
  - wires saved/stat/status actions

### Tests

- `test/presentation/main/main_recording_controller_test.dart`
- `test/presentation/main/main_screen_status_test.dart`
- `test/presentation/main/main_screen_stats_test.dart`
- `test/presentation/main/button_area_test.dart`
- `test/presentation/main/main_screen_test.dart`
- `test/app_smoke_test.dart`
- `test/core/router/app_router_test.dart`
- `integration_test/main_recording_controller_flow_test.dart`
- `integration_test/main_screen_flow_test.dart`

## Decisions made during implementation

- Kept status-copy logic out of the widget tree so the approved copy is tested
  deterministically without widget setup noise.
- Kept stats derivation in a stream-backed helper/provider so draft inclusion and
  local-day counting stay explicit and reusable.
- Used a UI-owned periodic timer for the countdown display because the controller
  already exposes the deadline metadata and the screen only needs lightweight
  repaint cadence while listening.
- Adjusted widget and integration tests to avoid `pumpAndSettle()` while the
  countdown timer is active, since listening intentionally keeps scheduling
  frames.

## Review remediation

After the 2026-06-14 external review pass, the implementation was tightened in
four places without changing feature scope:

- The countdown refresh path moved from whole-screen `setState()` calls every
  100ms to a button-area-only `ValueNotifier<double?>` update on a relaxed
  refresh cadence.
- Saved auto-clear now uses a local generation token so older timers cannot
  clear a newer Saved presentation.
- `hasEverRecorded` loading now catches repository failures, logs them, and
  falls back to `false` instead of leaving the screen indeterminate.
- Button-area countdown sizing and shake parameters now live in design tokens
  instead of hardcoded literals.

The remediation pass also added edge-case coverage for stale Saved timers,
preference-loading failure, non-positive hard-cap configuration, listening
semantics, and disposing the screen while countdown updates are active.

## Validation

- `flutter analyze`
  - passed with `No issues found!`
- `flutter test`
  - passed with `All tests passed!`
- Screenshot-backed main-screen UI interaction flow
  - `integration_test/main_screen_flow_test.dart` now captures integration-test
    screenshot checkpoints for idle, listening, saved, entry-detail, stats,
    quota, and mic-blocked states
- Android emulator integration
  - command:
    `/opt/homebrew/bin/flutter test integration_test/main_screen_flow_test.dart -d emulator-5554`
  - result: passed
- Android provider-graph integration
  - command:
    `/opt/homebrew/bin/flutter test integration_test/main_recording_controller_flow_test.dart integration_test/main_screen_flow_test.dart -d emulator-5554`
  - result: passed
- iOS simulator integration
  - command:
    `/opt/homebrew/bin/flutter test integration_test/main_screen_flow_test.dart -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156`
  - result: passed
- iOS provider-graph integration
  - command:
    `/opt/homebrew/bin/flutter test integration_test/main_recording_controller_flow_test.dart integration_test/main_screen_flow_test.dart -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156`
  - result: passed
- Review remediation validation
  - `flutter analyze --no-pub`
    - passed with `No issues found!`
  - `flutter test --no-pub`
    - passed with `All tests passed!`
  - focused regression command:
    `/opt/homebrew/bin/flutter test --no-pub test/presentation/main/button_area_test.dart test/presentation/main/main_screen_test.dart test/presentation/main/main_recording_controller_test.dart`
    - passed
  - Android remediation integration:
    `/opt/homebrew/bin/flutter test --no-pub integration_test/main_screen_flow_test.dart -d emulator-5554`
    - passed
  - iOS remediation integration:
    `/opt/homebrew/bin/flutter test --no-pub integration_test/main_screen_flow_test.dart -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156`
    - passed

## Visual verification

- Android emulator launch
  - command: `/opt/homebrew/bin/flutter run -d emulator-5554`
  - screenshots:
    - `/private/tmp/wrait-main-root-android.png`
    - `/private/tmp/wrait-main-aftertap-android.png`
  - verified:
    - root screen is the real main UI
    - circular button sizing matches the intended layout
    - listening shows the `stop` label and visible countdown ring
- iOS simulator launch
  - command:
    `/opt/homebrew/bin/flutter run -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156`
  - screenshot:
    - `/private/tmp/wrait-main-root-ios.png`
  - verified:
    - root screen is the real main UI
    - circular button sizing matches the intended layout
    - listening-state interaction is additionally covered by the screenshot-backed
      `integration_test/main_screen_flow_test.dart` run on iOS

## Current status

Implementation and validation are complete for this review pass. The feature is
ready for an externally provided `review.md`.
