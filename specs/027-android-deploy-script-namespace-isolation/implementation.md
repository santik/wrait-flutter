# Implementation: Android Deploy Script and App Namespace Isolation

> **Feature number:** 027
> **Spec:** [`spec.md`](spec.md)
> **Plan:** [`plan.md`](plan.md)
> **Tasks:** [`tasks.md`](tasks.md)
> **Author:** Codex
> **Date:** 2026-06-15

---

## Summary

US-027 is implemented except for physical Android phone verification, which is
blocked because the current ADB device list contains only an emulator.

Implemented behavior:

- Flutter Android namespace and application ID changed to `com.wrait.flutter`.
- `MainActivity` moved from package `com.wrait.app` to `com.wrait.flutter`.
- Existing `wrait/preferences` Android platform channel behavior preserved.
- Root `./deploy_debug.sh` added.
- The deploy script:
  - requires `adb` and `flutter`
  - configures Java consistently with the native Android reference scripts
  - finds exactly one connected non-emulator Android phone in `device` state
  - ignores emulator entries
  - fails before build/install when no usable phone is connected
  - fails before build/install when a phone is unauthorized or offline
  - builds the Flutter debug APK
  - runs `flutter test --no-pub -d <phone-serial> integration_test`
  - installs the debug APK only after real-device integration tests pass
  - verifies `com.wrait.flutter` exists after install
  - verifies `com.wrait.app` remains installed when it existed before
    deployment
  - does not uninstall any package
- Shell tests fail if `deploy_debug.sh` gains an `adb` or `flutter` uninstall
  command.
- `README.md` now documents the deploy command, real-device test behavior, and
  package coexistence with the native `com.wrait.app` app.
- Shell tests cover deploy-script orchestration with fake `adb` and `flutter`.

## Files changed

| File | Change |
| --- | --- |
| `android/app/build.gradle.kts` | Updated Android namespace and application ID to `com.wrait.flutter`. |
| `android/app/src/main/kotlin/com/wrait/app/MainActivity.kt` | Removed old package-path activity. |
| `android/app/src/main/kotlin/com/wrait/flutter/MainActivity.kt` | Added moved activity under `com.wrait.flutter`, preserving platform-channel behavior. |
| `deploy_debug.sh` | Added root debug deploy command. |
| `README.md` | Replaced Flutter starter text with project-specific development and deploy instructions. |
| `test/deploy_debug_script_test.sh` | Added shell tests for deploy-script no-phone, ADB failure, emulator-only, unavailable-phone, real-device-test failure, native-app coexistence, and one-phone success paths. |
| `specs/027-android-deploy-script-namespace-isolation/spec.md` | Updated through SDD clarify/approval and real-device test requirement. |
| `specs/027-android-deploy-script-namespace-isolation/plan.md` | Updated approved plan and validation strategy. |
| `specs/027-android-deploy-script-namespace-isolation/tasks.md` | Updated task status and validation evidence. |

## Validation evidence

```text
$ bash test/deploy_debug_script_test.sh
deploy_debug_script_test.sh: all tests passed

$ rg -n "com\.wrait\.app" android/app/build.gradle.kts android/app/src/main android/app/src/debug android/app/src/profile
No matches.

$ /opt/homebrew/bin/flutter analyze
No issues found! (ran in 3.0s)

$ /opt/homebrew/bin/flutter test
All tests passed! (192 tests)

$ /opt/homebrew/bin/flutter build apk --debug
Built build/app/outputs/flutter-apk/app-debug.apk

$ /Users/alexander/Library/Android/sdk/build-tools/36.1.0/aapt dump badging build/app/outputs/flutter-apk/app-debug.apk
package: name='com.wrait.flutter' versionCode='1' versionName='1.0.0' ...
```

## Android phone verification

Partially completed.

```text
$ adb devices
List of devices attached
4A181FDJH0030G	device
emulator-5554	device

$ ./deploy_debug.sh
Running Flutter integration tests on 4A181FDJH0030G...
...
Some tests failed.

Failing tests:
  integration_test/device_registration_launch_flow_test.dart:
    launch registration is non-blocking and updates session quota on success
  integration_test/device_registration_launch_flow_test.dart:
    transient launch registration failure is non-blocking and preserves quota

$ adb -s 4A181FDJH0030G shell pm path com.wrait.app
package:/data/app/.../com.wrait.app.../base.apk

$ adb -s 4A181FDJH0030G shell pm path com.wrait.flutter
not installed (command exited 1)
```

What this confirms:

- The deploy script detects and uses the connected physical Android phone.
- The deploy script runs `integration_test` before the final install step.
- The deploy script did not install `com.wrait.flutter` because the real-device
  test suite failed first.
- `com.wrait.app` remains installed after the aborted deploy attempt.

What remains incomplete:

- recording whether `com.wrait.app` was installed before deployment
- installing `com.wrait.flutter` after tests pass
- confirming `com.wrait.app` remains installed when present
- launching `com.wrait.flutter`

## Approved validation exceptions

- Android emulator verification is skipped because US-027 targets one
  connected Android phone and excludes emulator-specific behavior.
- iOS simulator verification is skipped because US-027 is Android-only and
  does not alter iOS behavior.

## Review notes

- `review.md` has not been provided yet.
- No review fixes have been applied.
- Final approval is blocked until physical Android phone verification is
  completed or the user explicitly changes the validation requirement.

## Long-lived documentation follow-up

Likely needed after final approval:

- Update `docs/agent-findings.md` entries that still describe the Flutter
  Android package/application ID as `com.wrait.app`.

Likely not needed:

- `docs/application-description.md`, because this feature is developer tooling
  rather than user-facing product behavior.
- `AGENTS.md`, unless the final verified deploy flow becomes a reusable rule
  for future agents.
