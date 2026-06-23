# Implementation: App Lock

> **Feature number:** 019
> **Spec:** [`spec.md`](spec.md)
> **Plan:** [`plan.md`](plan.md)
> **Tasks:** [`tasks.md`](tasks.md)
> **Author:** Codex
> **Date:** 2026-06-22

---

## Summary

US-019 now adds an app-wide privacy lock that starts locked on cold launch,
re-locks whenever Wrait leaves the foreground, auto-prompts only after the app
is resumed, and keeps the full app visually obscured until unlock succeeds or
the approved no-security bypass is used.

## What changed

### App-lock domain and platform services

- Added `lib/data/auth/app_lock_authenticator.dart`
  - defines app-lock availability and auth-result enums
  - wraps `local_auth` behind an injectable `AppLockAuthenticator`
  - adds an explicit native-auth timeout with best-effort cancellation for hung
    prompts
  - maps success, cancel, no-security, temporary-unavailable, device-level,
    and generic unavailable outcomes into app-facing results
  - logs non-success auth and availability outcomes through the existing
    warning logger
- Added `lib/data/auth/device_security_settings_opener.dart`
  - defines a best-effort settings opener abstraction
  - uses Android security settings via a method channel
  - falls back to app settings where direct security settings are not available
- Added `lib/data/auth/app_lock_providers.dart`
  - wires the production authenticator, settings opener, default enabled flag,
    and warning logger into Riverpod

### App-lock presentation and lifecycle

- Added `lib/presentation/app_lock/app_lock_controller.dart`
  - owns the ephemeral lock state
  - starts locked on cold launch
  - re-locks on every foreground exit
  - keeps auth prompting single-flight
  - keeps security-settings opening single-flight
  - handles unlock, retry, settings, and no-security bypass transitions
- Added `lib/presentation/app_lock/app_lock_screen.dart`
  - renders the approved copy and actions:
    - `wrait is locked`
    - `Unlock`
    - `Open settings`
    - `Continue without lock`
- Added `lib/presentation/app_lock/app_lock_gate.dart`
  - observes app lifecycle at the root
  - blurs and blocks the underlying app with a scrim and overlay
  - schedules authentication only after resume
  - ignores transient `AppLifecycleState.inactive` transitions so native
    biometric UI does not cancel and immediately restart authentication
- Added `lib/presentation/app_lock/app_lock_test_keys.dart`
  - stable keys for widget and integration coverage
- Updated `lib/app.dart`
  - wraps the router content with `AppLockGate` via `MaterialApp.router(builder: ...)`

### Android and iOS platform setup

- Updated `android/app/src/main/kotlin/com/wrait/flutter/MainActivity.kt`
  - switched from `FlutterActivity` to `FlutterFragmentActivity`
  - preserved existing automation lockscreen and device-id channel behavior
  - added the `wrait/app_lock` method channel for Android security settings
  - verifies the security-settings intent resolves before attempting to launch it
- Updated `android/app/src/main/AndroidManifest.xml`
  - added `android.permission.USE_BIOMETRIC`
- Updated Android theme parents in:
  - `android/app/src/main/res/values/styles.xml`
  - `android/app/src/main/res/values-night/styles.xml`
  - to AppCompat-compatible parents required by `local_auth_android`
- Updated `ios/Runner/Info.plist`
  - added `NSFaceIDUsageDescription`

### Test coverage and harness updates

- Added:
  - `test/data/auth/app_lock_authenticator_test.dart`
  - `test/data/auth/device_security_settings_opener_test.dart`
  - `test/presentation/app_lock/app_lock_controller_test.dart`
  - `test/presentation/app_lock/app_lock_gate_test.dart`
  - `integration_test/app_lock_flow_test.dart`
- Added a widget regression test proving that `inactive -> resumed` during an
  in-flight auth prompt does not cancel and restart the prompt loop
- Added an integration regression test proving the same lifecycle churn does
  not restart an in-flight fake auth prompt
- Updated unrelated widget and integration tests that pump `WraitApp` so they
  explicitly disable app lock when the lock is not the subject under test
- During physical-device validation, one unrelated flow
  (`integration_test/draft_retry_launch_flow_test.dart`) exposed missing
  app-lock overrides in several full-app integration harnesses. Those harnesses
  were updated before the final full `deploy_debug.sh` run.

## Behavior notes

- The lock is purely session-ephemeral. No journal data or preferences schema
  changed.
- Existing background work stays intact. The root lock gate obscures app
  content without canceling or mutating draft retry, cleanup, registration, or
  other existing flows.
- `MainScreen`'s own resume handling for microphone permission refresh was left
  alone; app-lock lifecycle handling is additive at the app root.

## Validation evidence

### Automated

- PASS `/opt/homebrew/bin/flutter test test/data/auth test/presentation/app_lock test/app_smoke_test.dart test/bootstrap_app_test.dart`
- PASS rerun after biometric prompt-loop fix:
  `/opt/homebrew/bin/flutter test test/data/auth test/presentation/app_lock test/app_smoke_test.dart test/bootstrap_app_test.dart`
- PASS rerun after approved review fixes:
  `/opt/homebrew/bin/flutter test test/data/auth test/presentation/app_lock test/app_smoke_test.dart test/bootstrap_app_test.dart`
- PASS `/opt/homebrew/bin/flutter test test/data/auth test/presentation/app_lock test/core/router/app_router_test.dart test/presentation/main/main_screen_test.dart test/presentation/entries/entry_list_screen_test.dart test/presentation/entries/entry_detail_screen_test.dart test/app_smoke_test.dart test/bootstrap_app_test.dart`
- PASS `/opt/homebrew/bin/flutter analyze`
- PASS `./gradlew --no-daemon compileDebugKotlin` from `android/`

### iOS simulator

- PASS `flutter test -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/app_lock_flow_test.dart`

Covered:
- cold launch unlock
- background/foreground relock
- inactive lifecycle churn during in-flight auth
- cancel and retry
- no-security settings + bypass
- temporary unavailable retry

### Android emulator

- PASS `flutter test -d emulator-5554 integration_test/app_lock_flow_test.dart`

Covered:
- cold launch unlock
- background/foreground relock
- inactive lifecycle churn during in-flight auth
- cancel and retry
- no-security settings + bypass
- temporary unavailable retry

### Connected Android phone

- PASS targeted regression check:
  - `flutter test --no-pub -d 4A181FDJH0030G integration_test/draft_retry_launch_flow_test.dart`
- PASS full `deploy_debug.sh` run on phone `4A181FDJH0030G`
  - full `integration_test/` suite passed
  - profile APK installed successfully
  - final cold launch verification succeeded
- PASS launcher-style cold start output:
  - `LaunchState: COLD`
  - `Activity: com.wrait.flutter.dev/com.wrait.flutter.MainActivity`
  - `TotalTime: 770`
- PASS post-review-fix real-device integration rerun:
  - `flutter test --no-pub -d 4A181FDJH0030G integration_test/app_lock_flow_test.dart`
  - covered the same six app-lock scenarios on the connected phone after the
    iOS simulator and Android emulator reruns
- PASS post-review-fix plain debug reinstall:
  - `adb -s 4A181FDJH0030G install -r build/app/outputs/flutter-apk/app-debug.apk`
- INFO post-review-fix cold launch of the reinstalled debug app:
  - `adb shell am start -W -n com.wrait.flutter.dev/com.wrait.flutter.MainActivity`
  - returned `Status: timeout` and `LaunchState: UNKNOWN (-1)`
  - still reported `Activity: com.wrait.flutter.dev/com.wrait.flutter.MainActivity`
  - follow-up `dumpsys activity` showed `ResumedActivity` for
    `com.wrait.flutter.dev/com.wrait.flutter.MainActivity`, so the app reached
    the foreground even though `-W` did not produce a normal launch duration
- Follow-up real-device issue reported after install:
  - symptom: biometric prompt repeatedly slid up/down and prevented interaction
  - root cause: the gate treated transient `inactive` lifecycle changes from
    native biometric UI as a true foreground exit
  - fix: relock now only occurs on `hidden`, `paused`, and `detached`
  - remediation hardening also added native-auth timeout recovery, broader
    exception mapping/logging, and single-flight settings opening

## Best-effort notes

- Direct native biometric dialogs were not separately automated end to end on
  emulator and iOS simulator beyond:
  - production platform wiring
  - dedicated fake-auth integration coverage on both platforms
  - successful real-device Android deploy/cold-launch validation
- Android validation produced non-blocking warnings from Flutter's Kotlin
  plugin deprecation checks and an intermittent `appops set RECORD_AUDIO`
  warning inside `deploy_debug.sh`; neither prevented the final green deploy.

## Deviations from plan

None to feature scope.

The only implementation-time adjustment was expanding app-lock-disabled
overrides in unrelated full-app integration harnesses after the first physical
phone deploy exposed that those tests were still booting behind the new lock
gate.
