# Tasks: Portrait-only App Orientation

> **Feature number:** 044
> **Plan:** [`plan.md`](plan.md)
> **Author:** Codex
> **Date:** 2026-09-02

---

## Legend

- `[ ]` — not started
- `[x]` — complete
- `[P]` — can be parallelized with other `[P]` tasks in the same group
- `[B]` — blocked (note the blocker)

## Task groups

_Tasks are organized into sequential groups.
Tasks within the same group marked `[P]` can be worked on in parallel._

### Group 1: Foundation

_Confirm the implementation boundaries and test contracts before editing
platform configuration._

- [x] Review the shared Android manifest, iOS orientation allowlists, and
      Flutter bootstrap to confirm the native-only approach and preserve the
      existing non-blocking startup behavior — `android/app/src/main/AndroidManifest.xml`, `ios/Runner/Info.plist`, `lib/main.dart`
- [x] Define source-contract assertions for Android sensor-based portrait
      orientation and iOS portrait-only allowlists — `test/platform/orientation_configuration_test.dart`

### Group 2: Core implementation

_Apply the native portrait policy and add automated coverage._

- [x] [P] Add `android:screenOrientation="sensorPortrait"` to `MainActivity`
      while retaining the existing configuration-change and startup settings
      — `android/app/src/main/AndroidManifest.xml`
  - Depends on: Group 1
- [x] [P] Remove the iPhone and iPad landscape orientation values while
      preserving the existing portrait values — `ios/Runner/Info.plist`
  - Depends on: Group 1
- [x] Add source-contract tests for the Android activity and both iOS
      orientation arrays — `test/platform/orientation_configuration_test.dart`
  - Depends on: Group 2 platform edits
- [x] Add an integration flow that launches Wrait with app lock disabled,
      asserts portrait presentation, simulates resume, navigates through all
      current routes, opens representative delete and feedback dialogs, and
      verifies the app remains usable and portrait — `integration_test/orientation_lock_flow_test.dart`
  - Depends on: Group 2 platform edits

### Group 3: Validation

_Run automated coverage, platform checks, and regression validation._

- [x] Run the focused source-contract test and the expanded
      `integration_test/orientation_lock_flow_test.dart` on the configured
      Android emulator and iOS simulator, plus the connected Android phone;
      record results below
- [x] Verify Android launcher-style cold start while the emulator is forced to
      both landscape rotations, verify portrait screenshots/window state after
      resume, and restore all rotation settings even on failure
- [x] Verify iOS cold launch, active rotation, and background/resume from both
      landscape directions using the Simulator rotation controls, or record
      the approved exception — macOS denied Simulator keyboard automation and
      `simctl` exposes no orientation command; portrait baseline, expanded
      integration flow, build, and built-plist checks passed, while physical
      rotation remains explicitly unverified under the approved exception
- [x] Run relevant app smoke, recording, privacy-lock, navigation, and
      import/export regression tests
- [x] Run static analysis and the required Android/iOS build checks; record
      commands and outcomes below
- [x] Confirm acceptance-criterion evidence and record the approved iOS
      physical-rotation validation exception — the active iOS rotation portion
      remains explicitly unverified, while the remaining evidence is recorded
      below

### Group 4: Review and fix

_Handle external review after implementation._

- [x] Create `implementation.md` with implementation notes and validation evidence
- [x] Stop and wait for external `review.md`, unless the user explicitly skips review
- [x] Read `review.md` and prepare a remediation plan without changing files
- [x] Present the remediation plan and wait for approval before making any changes
- [x] Implement approved review fixes and update `spec.md`, `plan.md`, `tasks.md`, `implementation.md`, code, and tests when review changes scope, approach, or validation
- [x] Repeat the review/fix loop if the same `review.md` file is updated for another pass — no second review pass was requested

### Group 5: Finalization

_Handle durable documentation follow-up and closeout._

- [x] Decide whether the feature produced durable learnings or long-lived product/architecture changes worth preserving — no durable update needed
- [x] If needed, propose updates to `AGENTS.md`, `docs/application-description.md`, and `docs/agent-findings.md` — no updates proposed
- [x] Wait for explicit approval before editing those long-lived guidance documents — approval received
- [x] Record whether the knowledge-capture gate resulted in updates or an explicit no-update decision — explicit no-update decision recorded

## Completion criteria

All tasks checked, validation evidence documented, review handled or explicitly
skipped, and the final knowledge-capture gate handled.

## Validation evidence

Record test results, screenshots, command output, approved exceptions, or
review-related notes here when complete.

```text
$ flutter test test/platform/orientation_configuration_test.dart
2 tests passed.

$ flutter analyze
No issues found.

$ flutter test --no-pub
443 tests passed.

$ flutter test --no-pub -d emulator-5554 integration_test/orientation_lock_flow_test.dart
1 test passed (expanded route/dialog flow).

$ flutter test --no-pub -d 4A181FDJH0030G integration_test/orientation_lock_flow_test.dart
1 test passed (expanded route/dialog flow).

$ flutter test --no-pub -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/orientation_lock_flow_test.dart
1 test passed (expanded route/dialog flow).

$ flutter build apk --debug --no-pub
Built build/app/outputs/flutter-apk/app-debug.apk.

$ flutter build ios --simulator --no-pub
Built build/ios/iphonesimulator/Runner.app.

Android forced landscape runtime evidence:
- emulator landscape-left and landscape-right: focused Wrait activity reported
  port / ROTATION_0 with a 1080x2400 window after cold launch and resume.
- connected phone landscape-left: focused Wrait activity reported port /
  ROTATION_0 with a 1080x2400 window; app interaction integration test passed.
- original emulator settings (accelerometer_rotation=1, user_rotation=0) and
  phone settings (accelerometer_rotation=0, user_rotation=0) restored.

iOS simulator evidence:
- validation-mode portrait screenshot captured at
  /private/tmp/wrait_orientation_ios_validation_portrait.png.
- built Runner.app plist contains portrait and portraitUpsideDown only.
- physical landscape rotation remains blocked by macOS Simulator automation
  permissions; no unverified result is claimed.

Review remediation evidence:
- Pre-existing unrelated worktree changes were left untouched per user
  direction and remain eligible for the same changeset.
- The integration flow now covers main, entries, entry detail, the delete
  confirmation dialog, and the feedback preparation dialog.
- The iOS physical-rotation validation exception was explicitly approved and
  is documented in `plan.md` and `implementation.md`.
```

## Notes

Record observations, decisions, and any deviations from the approved plan
during implementation.
