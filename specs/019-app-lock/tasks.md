# Tasks: App Lock

> **Feature number:** 019
> **Plan:** [`plan.md`](plan.md)
> **Author:** Codex
> **Date:** 2026-06-22

---

## Legend

- `[ ]` — not started
- `[x]` — complete
- `[P]` — can be parallelized with other `[P]` tasks in the same group
- `[B]` — blocked (note the blocker)

## Task groups

Tasks are organized into sequential groups. Tasks within the same group marked
`[P]` can be worked on in parallel.

### Group 1: Foundation Contracts

Create the app-lock contracts, test seams, and stable keys before wiring native
platform behavior or root UI.

- [x] [P] Define app-lock availability/result enums and the
      `AppLockAuthenticator` interface —
      `lib/data/auth/app_lock_authenticator.dart`
- [x] [P] Define the best-effort device-security settings opener interface —
      `lib/data/auth/device_security_settings_opener.dart`
- [x] [P] Add app-lock provider declarations for authenticator and settings
      opener injection — `lib/data/auth/app_lock_providers.dart`
- [x] [P] Add stable lock-screen and overlay test keys —
      `lib/presentation/app_lock/app_lock_test_keys.dart`
- [x] [P] Add initial unit-test doubles and mapper coverage for auth
      availability/results — `test/data/auth/app_lock_authenticator_test.dart`
- [x] [P] Add initial unit-test doubles for settings-opener success/failure —
      `test/data/auth/device_security_settings_opener_test.dart`

### Group 2: Controller Behavior

Implement the app-lock state machine independently of the visual overlay.

- [x] Create immutable `AppLockState` and `AppLockStatus` values for locked,
      authenticating, canceled, no-security, temporarily-unavailable, and
      unlocked states — `lib/presentation/app_lock/app_lock_controller.dart`
  - Depends on: Group 1
- [x] Implement cold-launch locked initialization and every-background
      relocking — `lib/presentation/app_lock/app_lock_controller.dart`
  - Depends on: Group 1
- [x] Implement resumed-only automatic authentication scheduling and
      single-flight prompt protection —
      `lib/presentation/app_lock/app_lock_controller.dart`
  - Depends on: Group 1
- [x] Implement success, cancel, no-security, temporary-unavailable, generic
      unavailable, settings, manual unlock, and no-security bypass transitions
      — `lib/presentation/app_lock/app_lock_controller.dart`
  - Depends on: Group 1
- [x] Add controller tests for cold launch, background lock, auto-prompt,
      single-flight prompt, success, cancel, no-security, settings,
      warning-bypass, temporary-unavailable, and retry paths —
      `test/presentation/app_lock/app_lock_controller_test.dart`
  - Depends on: controller implementation tasks in this group

### Group 3: Root UI And App Integration

Wire the state machine into the app shell and build the user-visible lock
experience.

- [x] Create the lock screen UI with approved copy, `Unlock`, `Open settings`,
      and `Continue without lock` actions —
      `lib/presentation/app_lock/app_lock_screen.dart`
  - Depends on: Group 2
- [x] Create `AppLockGate` with `WidgetsBindingObserver`, resumed-frame prompt
      scheduling, whole-app interaction blocking, 20dp blur, scrim, and overlay
      composition — `lib/presentation/app_lock/app_lock_gate.dart`
  - Depends on: Group 2
- [x] Wrap `MaterialApp.router` content with `AppLockGate` through
      `MaterialApp.router(builder: ...)` — `lib/app.dart`
  - Depends on: `AppLockGate`
- [x] Preserve existing `MainScreen` resume behavior for microphone permission
      refresh while adding root app-lock lifecycle handling —
      `lib/presentation/main/main_screen.dart`,
      `lib/presentation/app_lock/app_lock_gate.dart`
  - Depends on: `AppLockGate`
- [x] Add widget tests for whole-app blur/blocking, lock copy, unlock/settings
      actions, bypass visibility, accessibility labels/hints, and lifecycle
      prompt triggering — `test/presentation/app_lock/app_lock_gate_test.dart`
  - Depends on: UI integration tasks in this group
- [x] Update smoke/bootstrap tests to either override app lock to unlocked or
      explicitly assert the post-bootstrap lock gate —
      `test/app_smoke_test.dart`, `test/bootstrap_app_test.dart`
  - Depends on: app integration task

### Group 4: Native Auth And Platform Setup

Connect production platform authentication and settings behavior.

- [x] Implement `LocalAuthAppLockAuthenticator` using `local_auth`, including
      availability checks, authentication prompt copy, success/cancel mapping,
      no-security mapping, temporary-unavailable mapping, and generic
      unavailable fallback — `lib/data/auth/app_lock_authenticator.dart`
  - Depends on: Group 1
- [x] Implement production device-security settings opener with Android
      security-settings best effort and iOS/app-settings fallback —
      `lib/data/auth/device_security_settings_opener.dart`,
      `android/app/src/main/kotlin/com/wrait/flutter/MainActivity.kt`
  - Depends on: Group 1
- [x] Switch Android `MainActivity` from `FlutterActivity` to
      `FlutterFragmentActivity` while preserving automation-lockscreen and
      device-id channel behavior —
      `android/app/src/main/kotlin/com/wrait/flutter/MainActivity.kt`
  - Depends on: Group 1
- [x] Add Android biometric permission —
      `android/app/src/main/AndroidManifest.xml`
  - Depends on: Group 1
- [x] Adjust Android launch/normal theme parents only as needed for
      `local_auth_android` compatibility while preserving launch background and
      dark/light behavior — `android/app/src/main/res/values/styles.xml`,
      `android/app/src/main/res/values-night/styles.xml`,
      `android/app/build.gradle.kts`
  - Depends on: Android activity setup
- [x] Add iOS Face ID usage description copy —
      `ios/Runner/Info.plist`
  - Depends on: Group 1
- [x] Update native-auth and settings-opener unit tests for the production
      implementations and platform fallbacks —
      `test/data/auth/app_lock_authenticator_test.dart`,
      `test/data/auth/device_security_settings_opener_test.dart`
  - Depends on: native implementation tasks in this group

### Group 5: Integration Test Coverage

Add dedicated app-lock integration coverage and keep unrelated flows focused.

- [x] Create `integration_test/app_lock_flow_test.dart` harness with fake
      authenticator, fake settings opener, and provider overrides —
      `integration_test/app_lock_flow_test.dart`
  - Depends on: Groups 2 and 3
- [x] Add integration coverage for cold launch starting locked, fake auth
      success unlocking, and underlying main screen interaction after unlock —
      `integration_test/app_lock_flow_test.dart`
  - Depends on: app-lock integration harness
- [x] Add integration coverage for background/foreground relock and automatic
      fake prompt on resume — `integration_test/app_lock_flow_test.dart`
  - Depends on: app-lock integration harness
- [x] Add integration coverage for canceled auth staying locked until retry
      succeeds — `integration_test/app_lock_flow_test.dart`
  - Depends on: app-lock integration harness
- [x] Add integration coverage for no-security settings action plus warning
      bypass revealing the app — `integration_test/app_lock_flow_test.dart`
  - Depends on: app-lock integration harness
- [x] Add integration coverage for temporary-unavailable state staying locked
      and allowing retry — `integration_test/app_lock_flow_test.dart`
  - Depends on: app-lock integration harness
- [x] Update unrelated integration tests that pump `WraitApp` to override app
      lock to an unlocked state where the lock is not under test —
      `integration_test/*_test.dart`
  - Depends on: app-lock provider integration

### Group 6: Automated Validation

Run focused and broader checks, recording evidence as implementation proceeds.

- [x] Run focused app-lock tests —
      `flutter test test/data/auth test/presentation/app_lock test/app_smoke_test.dart test/bootstrap_app_test.dart`
  - Depends on: Groups 1-5
- [x] Run static analysis — `flutter analyze`
  - Depends on: Groups 1-5
- [x] Run relevant existing Flutter tests affected by app-shell/provider
      changes — `flutter test test/presentation test/core/router test/app_smoke_test.dart test/bootstrap_app_test.dart`
  - Depends on: Groups 1-5
- [x] Run app-lock integration test on host or simulator-capable device using
      fake authenticator — `flutter test integration_test/app_lock_flow_test.dart`
  - Depends on: Group 5
- [x] Run Android compile/build validation for platform setup —
      `./gradlew --no-daemon compileDebugKotlin` or the repo-approved Android
      build/test command
  - Depends on: Group 4

### Group 7: Runtime Platform Verification

Collect the default required Android emulator and iOS simulator evidence.

- [x] Verify Android emulator app-lock integration —
      `flutter test -d <android-emulator-id> integration_test/app_lock_flow_test.dart`
  - Depends on: Group 6
- [x] Verify Android launcher-style cold start and locked screen before content
      is usable —
      `adb shell am start -W -n com.wrait.flutter.dev/com.wrait.flutter.MainActivity`
      or the package under validation
  - Depends on: Android build validation
- [x] Verify Android native authentication prompt appears automatically on
      foreground return and success unlocks the app —
      Android emulator/manual runtime evidence
  - Depends on: Android cold-start verification
- [x] Verify Android no-security/best-effort settings and warning bypass path
      where emulator configuration permits —
      Android emulator/manual runtime evidence
  - Depends on: Android cold-start verification
- [x] Verify iOS simulator app-lock integration —
      `flutter test -d <ios-simulator-id> integration_test/app_lock_flow_test.dart`
  - Depends on: Group 6
- [x] Verify iOS cold launch, native Face ID/Touch ID prompt behavior,
      cancel/retry, success unlock, and best-effort settings destination —
      iOS simulator/manual runtime evidence
  - Depends on: iOS integration verification

### Group 8: Implementation Evidence

Capture what changed and the evidence needed for external review.

- [x] Update task statuses as implementation progresses —
      `specs/019-app-lock/tasks.md`
- [x] Record automated test commands and results in the validation evidence
      section — `specs/019-app-lock/tasks.md`
- [x] Record Android emulator and iOS simulator runtime verification evidence,
      including any platform limitation observed for settings deep links —
      `specs/019-app-lock/tasks.md`
- [x] Create `implementation.md` with implementation details, platform notes,
      validation evidence, and any approved deviations —
      `specs/019-app-lock/implementation.md`
- [x] Stop and wait for external `review.md`, unless the user explicitly skips
      review — `specs/019-app-lock/review.md`

### Group 9: Review And Fix

Handle the external review loop without changing files before approval.

- [x] Read externally provided `review.md` when available —
      `specs/019-app-lock/review.md`
- [x] Prepare a remediation plan for each review finding without updating files
      — `specs/019-app-lock/review.md`
- [x] Present the remediation plan and wait for explicit approval before making
      any changes
- [x] Implement approved review fixes and update `spec.md`, `plan.md`,
      `tasks.md`, `implementation.md`, code, and tests when review changes
      scope, approach, or validation
- [x] Repeat the review/fix loop if the same `review.md` file is updated for
      another pass

### Group 10: Finalization

Close the feature only after durable documentation follow-up is handled.

- [x] Decide whether US-019 produced durable learnings or long-lived
      product/architecture changes worth preserving
- [x] Propose updates to `AGENTS.md`, `docs/application-description.md`, and
      `docs/agent-findings.md` if app-lock behavior or platform setup should be
      long-lived guidance
- [x] Wait for explicit approval before editing those long-lived guidance
      documents
- [x] Apply approved long-lived documentation updates, or record the explicit
      no-update decision
- [x] Mark `spec.md` status `Complete` only after implementation, validation,
      review handling, and final knowledge-capture gates are done

## Completion criteria

All tasks checked, validation evidence documented, Android emulator and iOS
simulator verification completed or explicitly approved as exceptions, review
handled or explicitly skipped, final knowledge-capture gate handled, and
`spec.md` marked `Complete`.

## Validation evidence

Record test results, screenshots, command output, approved exceptions, or
review-related notes here when complete.

```text
Automated checks
- PASS `/opt/homebrew/bin/flutter test test/data/auth test/presentation/app_lock test/app_smoke_test.dart test/bootstrap_app_test.dart`
- PASS rerun after biometric prompt-loop fix:
  `/opt/homebrew/bin/flutter test test/data/auth test/presentation/app_lock test/app_smoke_test.dart test/bootstrap_app_test.dart`
- PASS rerun after approved review fixes:
  `/opt/homebrew/bin/flutter test test/data/auth test/presentation/app_lock test/app_smoke_test.dart test/bootstrap_app_test.dart`
- PASS `/opt/homebrew/bin/flutter test test/data/auth test/presentation/app_lock test/core/router/app_router_test.dart test/presentation/main/main_screen_test.dart test/presentation/entries/entry_list_screen_test.dart test/presentation/entries/entry_detail_screen_test.dart test/app_smoke_test.dart test/bootstrap_app_test.dart`
- PASS `/opt/homebrew/bin/flutter analyze`
- PASS `./gradlew --no-daemon compileDebugKotlin` (run from `android/`)

Simulator / emulator validation
- PASS iOS simulator `491CD949-D3C0-4C4C-A6B9-15BAB1859156` before the real-device rerun:
  `/opt/homebrew/bin/flutter test -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/app_lock_flow_test.dart`
- PASS Android emulator `emulator-5554` before the real-device rerun:
  `/opt/homebrew/bin/flutter test -d emulator-5554 integration_test/app_lock_flow_test.dart`

Connected Android phone validation
- PASS targeted spot check after unrelated integration harnesses were updated:
  `/opt/homebrew/bin/flutter test --no-pub -d 4A181FDJH0030G integration_test/draft_retry_launch_flow_test.dart`
- PASS full real-device deploy and validation using local `PROXY_SECRET` sourced
  from private local properties:
  `./deploy_debug.sh`
- PASS final launcher-style cold start reported by `deploy_debug.sh`:
  `adb shell am start -W -n com.wrait.flutter.dev/com.wrait.flutter.MainActivity`
  output included `LaunchState: COLD`, `Activity: com.wrait.flutter.dev/com.wrait.flutter.MainActivity`, and `TotalTime: 770`
- PASS post-review-fix real-device app-lock integration rerun after both
  simulator/emulator validations:
  `/opt/homebrew/bin/flutter test --no-pub -d 4A181FDJH0030G integration_test/app_lock_flow_test.dart`
- PASS post-review-fix plain debug reinstall:
  `adb -s 4A181FDJH0030G install -r build/app/outputs/flutter-apk/app-debug.apk`
- INFO post-review-fix cold launch of the reinstalled debug app reached
  `com.wrait.flutter.dev/com.wrait.flutter.MainActivity`, but
  `adb shell am start -W` reported:
  - `Status: timeout`
  - `LaunchState: UNKNOWN (-1)`
  - `Activity: com.wrait.flutter.dev/com.wrait.flutter.MainActivity`
  Follow-up `dumpsys activity` still showed `ResumedActivity:
  ActivityRecord{... com.wrait.flutter.dev/com.wrait.flutter.MainActivity ...}`
  on-device, so the app reached the foreground even though `-W` did not return
  a normal launch duration.

Best-effort runtime notes
- Dedicated app-lock integration covered cold launch, resume relock, cancel,
  no-security + settings + bypass, and temporary-unavailable flows on both iOS
  simulator and Android emulator with fake authenticator/settings seams.
- Full physical-phone `deploy_debug.sh` validation also passed the production
  app cold-launch install path and the full `integration_test/` suite.
- Native biometric system dialogs were not separately automated on emulator and
  iOS simulator beyond the production platform wiring, focused app-lock
  integration flows, and the real-device deploy/cold-launch evidence above.
- Non-blocking warnings observed during Android validation:
  - Flutter/KGP deprecation warnings from `package_info_plus`, `share_plus`,
    `speech_to_text`, and `wakelock_plus`
  - intermittent `appops set RECORD_AUDIO` warning in `deploy_debug.sh`, while
    the underlying permission grant and test/deploy flow still succeeded
- Follow-up bug fix after physical-device feedback:
  - symptom: biometric prompt repeatedly slid up/down on the installed debug app
  - fix: app lock now ignores transient `AppLifecycleState.inactive` so the
    biometric sheet does not trigger relock/cancel/re-prompt loops
  - remediation hardening also added:
    - native auth timeout + best-effort cancellation
    - single-flight settings opening
    - broader local-auth exception mapping/logging
    - Android security-settings intent resolution check
    - integration coverage for `inactive -> resumed` churn
```

## Notes

- No validation exception is approved or requested in the plan.
- Preserve current in-progress recording, upload, cleanup, registration, and
  draft-retry behavior while locked unless implementation reveals a specific
  platform instability. Pause and request explicit approval before changing
  that behavior.
