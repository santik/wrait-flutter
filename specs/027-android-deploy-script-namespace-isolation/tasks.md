# Tasks: Android Deploy Script and App Namespace Isolation

> **Feature number:** 027
> **Plan:** [`plan.md`](plan.md)
> **Author:** Codex
> **Date:** 2026-06-15

---

## Legend

- `[ ]` — not started
- `[x]` — complete
- `[P]` — can be parallelized with other `[P]` tasks in the same group
- `[B]` — blocked (note the blocker)

## Task groups

Tasks are organized into sequential groups. Tasks within the same group marked
`[P]` can be worked on in parallel.

### Group 1: Android Identity Foundation

Set up the new Android package/application identity while preserving existing
platform-channel behavior.

- [x] Update the Android namespace and application ID from `com.wrait.app` to
      `com.wrait.flutter` — `android/app/build.gradle.kts`
- [x] Move `MainActivity` from the old Kotlin package path to the new package
      path — `android/app/src/main/kotlin/com/wrait/flutter/MainActivity.kt`
- [x] Remove the old `MainActivity` source path after the package move —
      `android/app/src/main/kotlin/com/wrait/app/MainActivity.kt`
- [x] Verify the moved `MainActivity` still exposes the existing
      `wrait/preferences` platform channel behavior unchanged

### Group 2: Debug Deploy Command

Create the developer command for one connected Android phone.

- [x] Create the root debug deployment script — `deploy_debug.sh`
- [x] Add Java environment cleanup consistent with the reference Android
      scripts — `deploy_debug.sh`
- [x] Implement connected-phone detection from `adb devices` — `deploy_debug.sh`
- [x] Ignore emulator entries when detecting the connected Android phone —
      `deploy_debug.sh`
- [x] Make the script fail before build/install with a clear message when no
      usable Android phone is connected — `deploy_debug.sh`
- [x] Make the script fail before build/install with a clear message when a
      phone is unauthorized, offline, or otherwise unavailable —
      `deploy_debug.sh`
- [x] Build the Flutter debug APK from the repository root — `deploy_debug.sh`
- [x] Run `flutter test --no-pub -d <phone-serial> integration_test` on the
      detected Android phone before final install — `deploy_debug.sh`
- [x] Make the script fail before final install when real-device integration
      tests fail — `deploy_debug.sh`
- [x] Install `build/app/outputs/flutter-apk/app-debug.apk` to the detected
      phone without uninstalling any package — `deploy_debug.sh`
- [x] Verify `com.wrait.flutter` is installed after deployment and verify
      `com.wrait.app` remains installed when it was present before deployment —
      `deploy_debug.sh`
- [x] Add deploy-script regression coverage that fails if the script gains an
      uninstall command — `test/deploy_debug_script_test.sh`
- [x] Ensure the script does not implement release deployment, target
      selection, emulator-specific behavior, or automatic uninstall behavior

### Group 3: Documentation

Document the developer-facing command.

- [x] Replace the default README content with project-specific development
      commands — `README.md`
- [x] Document `./deploy_debug.sh`, Android phone prerequisites, real-device
      test execution, and no-phone failure behavior — `README.md`
- [x] Document that the Flutter Android app installs as `com.wrait.flutter`
      and is intended to coexist with the native `com.wrait.app` app —
      `README.md`

### Group 4: Automated Validation

Add and run focused checks for the Android identity and deploy script.

- [x] Add fake-command shell tests for no-phone, emulator-only,
      unavailable-phone, test-failure, native-app coexistence, and one-phone
      deploy behavior —
      `test/deploy_debug_script_test.sh`
- [x] Run the deploy script shell tests —
      `bash test/deploy_debug_script_test.sh`
- [x] Run a stale identity static check and confirm project-owned Android app
      identity files no longer use `com.wrait.app` for the Flutter app;
      deploy-script and README references to the native app are allowed only
      when clearly protecting or describing coexistence
- [x] Run Flutter static analysis — `/opt/homebrew/bin/flutter analyze`
- [x] Run existing Flutter tests — `/opt/homebrew/bin/flutter test`
- [x] Build the Android debug APK — `/opt/homebrew/bin/flutter build apk --debug`
- [x] Verify `./deploy_debug.sh` runs the Flutter integration test suite on the
      connected Android phone before final install
- [x] Record the approved Android emulator verification exception: US-027
      targets one connected Android phone and excludes emulator-specific
      behavior
- [x] Record the approved iOS simulator verification exception: US-027 is
      Android-only and does not alter iOS behavior

### Group 5: Android Phone Verification

Validate the feature on the in-scope physical Android phone.

- [x] Confirm exactly one Android phone is connected and authorized with
      `adb devices`
- [B] Record whether `com.wrait.app` is installed before deployment
- [x] Run `./deploy_debug.sh`
- [x] Confirm `./deploy_debug.sh` runs `integration_test` on the connected
      Android phone
- [B] Verify `com.wrait.flutter` is installed on the phone after tests pass
- [B] Verify `com.wrait.app` remains installed if it was present before
      deployment
- [B] Launch `com.wrait.flutter` on the phone and confirm the app opens

### Group 6: Implementation Record

Capture implementation details and evidence for review.

- [x] Create `implementation.md` with package identity changes, deploy command
      behavior, real-device test evidence, validation evidence, approved
      exceptions, and any known gaps —
      `specs/027-android-deploy-script-namespace-isolation/implementation.md`
- [x] Update this task list with completed statuses and validation evidence —
      `specs/027-android-deploy-script-namespace-isolation/tasks.md`

### Group 7: Review and Fix

Handle external review after implementation.

- [ ] Stop and wait for external `review.md`, unless the user explicitly skips
      review
- [ ] Read `review.md` and prepare a remediation plan without changing files
- [ ] Present the remediation plan and wait for approval before making any
      changes
- [ ] Implement approved review fixes and update `spec.md`, `plan.md`,
      `tasks.md`, `implementation.md`, code, and tests when review changes
      scope, approach, or validation
- [ ] Repeat the review/fix loop if the same `review.md` file is updated for
      another pass

### Group 8: Finalization

Handle durable documentation follow-up and closeout.

- [ ] Decide whether the feature produced durable learnings or long-lived
      product/architecture changes worth preserving
- [ ] Propose any needed updates to `AGENTS.md`,
      `docs/application-description.md`, and `docs/agent-findings.md`
- [ ] Wait for explicit approval before editing those long-lived guidance
      documents
- [ ] Record whether the knowledge-capture gate resulted in updates or an
      explicit no-update decision
- [ ] Update the spec status to `Complete` only after implementation,
      validation, review handling, and knowledge capture are complete —
      `specs/027-android-deploy-script-namespace-isolation/spec.md`

## Completion criteria

All tasks checked, validation evidence documented, approved validation
exceptions recorded, Android phone verification completed, review handled or
explicitly skipped, final knowledge-capture gate handled, and spec status
updated to `Complete`.

## Validation evidence

Record test results, command output, Android phone verification, approved
exceptions, or review-related notes here when complete.

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

Current state: the real Android phone path is confirmed, `integration_test`
runs before final install as designed, `com.wrait.app` is still installed, and
`com.wrait.flutter` was not installed because the deploy script stopped on
failing real-device tests before the final install step.
```

## Notes

- Approved validation exceptions from the plan: no Android emulator
  verification and no iOS simulator runtime verification.
- `./deploy_debug.sh` must run Flutter integration tests on the connected
  Android phone before final install.
- US-027 is debug Android deployment only.
- US-027 assumes one connected physical Android phone.
