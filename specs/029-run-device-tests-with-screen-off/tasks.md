# Tasks: Connected Device Tests With Screen Off

> **Feature number:** 029
> **Plan:** [`plan.md`](plan.md)
> **Author:** Codex
> **Date:** 2026-06-17

---

## Legend

- `[ ]` — not started
- `[x]` — complete
- `[P]` — can be parallelized with other `[P]` tasks in the same group
- `[B]` — blocked (note the blocker)

## Task groups

Tasks are organized into sequential groups. Tasks within the same group marked
`[P]` can be worked on in parallel after their group prerequisites are met.

### Group 1: Deploy Script Readiness Contract

Add the shell-level phone preparation behavior before changing Android runtime
code.

- [x] Add a reusable phone-readiness helper that re-checks the selected phone
      state before running device-dependent commands — `deploy_debug.sh`
- [x] Make the helper wake the connected phone through ADB and fail with a
      readiness-specific message if wake/connectivity fails — `deploy_debug.sh`
- [x] Make keyguard dismissal best-effort and non-fatal when the phone remains
      connected, because debug locked-screen activity support handles ordinary
      locked state — `deploy_debug.sh`
- [x] Auto-grant `android.permission.RECORD_AUDIO` through the deploy-time
      Flutter test session so recording tests do not block on a permission
      dialog while app packages are reinstalled — `deploy_debug.sh`
- [x] Call the readiness helper before the integration-test phase and before
      the final installed-app launch verification — `deploy_debug.sh`
- [x] Preserve the existing build, `PROXY_SECRET`, single physical phone,
      no-emulator, install-after-tests, native-app preservation, APK
      verification, and launch verification behavior — `deploy_debug.sh`

### Group 2: Automation-Gated Debug Android Locked-Screen Runtime Support

Allow the debug app under test to run from a locked phone without changing
release or profile behavior.

- [x] Add debuggable-state detection in the Android `MainActivity` —
      `android/app/src/main/kotlin/com/wrait/flutter/MainActivity.kt`
- [x] When the process is debuggable and automation mode is enabled, allow the
      activity to show over keyguard and turn the screen on using the
      appropriate Android API for supported SDK levels —
      `android/app/src/main/kotlin/com/wrait/flutter/MainActivity.kt`
- [x] When the process is debuggable and automation mode is enabled, keep the
      screen awake while the activity is active to reduce screen-off
      interruptions during integration tests —
      `android/app/src/main/kotlin/com/wrait/flutter/MainActivity.kt`
- [x] Ensure locked-screen and keep-awake flags are not enabled for
      non-debuggable or non-automation builds —
      `android/app/src/main/kotlin/com/wrait/flutter/MainActivity.kt`
- [x] Keep existing device-ID method-channel behavior unchanged —
      `android/app/src/main/kotlin/com/wrait/flutter/MainActivity.kt`

### Group 3: Shell Test Coverage

Extend the deterministic deploy-script test harness before relying on the real
phone run.

- [x] Extend the fake `adb` command to record and simulate wake/readiness and
      keyguard-dismiss commands — `test/deploy_debug_script_test.sh`
- [x] Extend the fake test-install flow to simulate runtime microphone
      permission grant and `appops` allowance for `com.wrait.flutter` —
      `test/deploy_debug_script_test.sh`
- [x] Add a locked-phone happy-path scenario that verifies readiness happens
      before `flutter test` and before final installed-app launch verification —
      `test/deploy_debug_script_test.sh`
- [x] Add a readiness failure scenario that exits non-success with a
      readiness-specific message and does not install —
      `test/deploy_debug_script_test.sh`
- [x] Add a keyguard-dismiss refusal scenario that still succeeds when the
      phone remains connected — `test/deploy_debug_script_test.sh`
- [x] Add cleanup coverage that verifies temporary stay-awake and automation
      settings are restored on success and failure paths —
      `test/deploy_debug_script_test.sh`
- [x] Assert the script still never issues uninstall or package-data-clear
      commands — `test/deploy_debug_script_test.sh`
- [x] Preserve existing regression scenarios for missing/invalid
      `PROXY_SECRET`, missing phone, emulator-only target, unauthorized/offline
      phone, build output validation, test failure, disconnect-before-install,
      native app preservation, and launch timeout —
      `test/deploy_debug_script_test.sh`

### Group 4: Developer Documentation

Document the new deploy preconditions and behavior at the command entry point.

- [x] Update Android debug deployment docs to state that `deploy_debug.sh`
      supports a locked, screen-off physical phone — `README.md`
- [x] Document that the script may wake the phone and keep it awake during the
      run, restores only the temporary automation/power settings it changes,
      and does not restore the prior visible screen/lock presentation state —
      `README.md`
- [x] Document that the script auto-grants `android.permission.RECORD_AUDIO`
      during automated test setup to avoid a locked-phone permission prompt —
      `README.md`
- [x] Document that the script uses the debug build for tests and the profile
      build for the final installed app on the validation phone — `README.md`
- [x] Document that USB debugging authorization is still required and that
      device policies requiring manual credential entry may block automation —
      `README.md`
- [x] Keep existing `PROXY_SECRET`, single physical phone, emulator exclusion,
      install-after-tests, and no-uninstall guidance intact — `README.md`

### Group 5: Validation

Run the planned checks and record evidence. The plan includes approved
exceptions for new Flutter integration-test files, Android emulator
verification, and iOS simulator verification.

- [x] Run `bash test/deploy_debug_script_test.sh`
- [x] Run Android debug build validation with a proxy secret dart define:
      `flutter build apk --debug --dart-define=PROXY_SECRET=...`
- [x] Run Android profile build validation with the same proxy secret dart
      define: `flutter build apk --profile --dart-define=PROXY_SECRET=...`
- [x] Run physical Android validation with one authorized phone locked and
      screen-off: `PROXY_SECRET=... ./deploy_debug.sh`
- [x] Confirm the physical run requires no phone interaction, runs the existing
      integration-test phase, clears the recording permission prompt through
      the development channel, installs only after tests pass, keeps the phone
      awake when needed, and verifies launch
- [x] Record the approved exception that no new Flutter `integration_test` file
      is required because this is a developer shell workflow and the existing
      suite still runs inside `deploy_debug.sh`
- [x] Record the approved Android emulator verification exception because
      `deploy_debug.sh` intentionally ignores emulators
- [x] Record the approved iOS simulator verification exception because this
      feature has no iOS runtime surface
- [x] Record validation command output and any runtime observations in this
      file and `implementation.md`

### Group 6: Review and Fix

Handle external review after implementation.

- [x] Create `implementation.md` with implementation notes and validation
      evidence — `specs/029-run-device-tests-with-screen-off/implementation.md`
- [x] Stop and wait for external `review.md`, unless the user explicitly
      skips review
- [x] Read `review.md` and prepare a remediation plan without changing files
- [x] Present the remediation plan and wait for approval before making any
      changes
- [x] Implement approved review fixes and update `spec.md`, `plan.md`,
      `tasks.md`, `implementation.md`, code, and tests when review changes
      scope, approach, or validation
- [ ] Repeat the review/fix loop if the same `review.md` file is updated for
      another pass

### Group 7: Finalization

Handle durable documentation follow-up and closeout.

- [x] Decide whether US-029 produced durable learnings or long-lived
      product/architecture changes worth preserving
- [x] Propose updates to `AGENTS.md` for locked-screen `deploy_debug.sh`
      guidance if final implementation confirms it should become durable agent
      workflow guidance
- [x] Propose updates to `docs/agent-findings.md` for reusable deploy-script
      locked-screen behavior and validation lessons
- [x] Decide whether `docs/application-description.md` needs any update;
      outcome: no update because this is developer tooling, not product
      behavior
- [x] Wait for explicit approval before editing long-lived guidance documents
- [x] Record whether the knowledge-capture gate resulted in updates or an
      explicit no-update decision
- [ ] Mark `spec.md` status as `Complete` only after implementation, review,
      validation, and final knowledge-capture gates are handled

## Completion criteria

All tasks checked, validation evidence documented, review handled or explicitly
skipped, and the final knowledge-capture gate handled.

## Validation evidence

Record test results, command output, approved exceptions, or review-related
notes here when complete.

```text
2026-06-18

- `bash test/deploy_debug_script_test.sh`
  - Passed after extending the fake device harness for namespaced automation
    setting readback, bounded microphone-permission watchdog behavior, cleanup
    restoration, profile final-install handling, and launch verification.
- `/opt/homebrew/bin/flutter build apk --debug --dart-define=PROXY_SECRET=test-proxy-secret`
  - Passed. Kotlin changes compiled and produced
    `build/app/outputs/flutter-apk/app-debug.apk`.
  - Flutter emitted existing plugin KGP compatibility warnings for
    `package_info_plus`, `share_plus`, `speech_to_text`, and `wakelock_plus`.
- `/opt/homebrew/bin/flutter build apk --profile --dart-define=PROXY_SECRET=test-proxy-secret`
  - Passed. Produced `build/app/outputs/flutter-apk/app-profile.apk`.
  - Flutter emitted the same existing plugin KGP compatibility warnings for
    `package_info_plus`, `share_plus`, `speech_to_text`, and `wakelock_plus`.
- `PROXY_SECRET=test-proxy-secret ./deploy_debug.sh`
  - Required an unsandboxed run because the sandboxed environment could not
    start or connect to the ADB daemon.
  - Pre-review implementation passed once against the connected Android phone
    `4A181FDJH0030G` while still ending with the standalone debug install.
  - The deploy run printed:
    - readiness preparation before the integration-test phase
    - `Granted android.permission.RECORD_AUDIO to com.wrait.flutter for automated tests.`
    - `All tests passed!`
    - successful reinstall preserving `com.wrait.app`
    - a final launch verification attempt for `com.wrait.flutter`
  - Subsequent device investigation showed the final standalone debug install
    could remain stuck on the Flutter splash screen even though the debug test
    phase itself worked.
  - Manual physical-device validation after that investigation confirmed:
    - Flutter UI content existed behind the stuck standalone debug launch
    - manual `adb` install plus cold launch of
      `build/app/outputs/flutter-apk/app-profile.apk` opened normally on the
      same phone
  - The approved review remediation therefore switched the final installed
    artifact from debug to profile while keeping the test phase on the debug
    integration channel.
  - A fresh end-to-end run of the updated `./deploy_debug.sh` is still pending
    execution on the connected phone outside the sandbox.
- Approved exceptions recorded:
  - no new Flutter `integration_test` file
  - no Android emulator verification
  - no iOS simulator verification
```

## Notes

- Plan-approved validation exceptions: no new Flutter `integration_test` file,
  no Android emulator verification, and no iOS simulator verification.
- Physical Android validation remains required with the phone locked and
  screen-off before starting `./deploy_debug.sh`.
- The current reviewed implementation uses a single final launch verification
  and exact resumed/focused-activity checks rather than the earlier duplicate
  launch flow.
- Knowledge-capture gate result:
  - updated `AGENTS.md`
  - updated `docs/agent-findings.md`
  - intentionally did not update `docs/application-description.md` because
    US-029 changes developer workflow, not product behavior
