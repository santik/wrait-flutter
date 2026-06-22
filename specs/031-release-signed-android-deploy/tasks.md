# Tasks: Release-Signed Android Deploy Flow

> **Feature number:** 031
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
`[P]` can be worked on in parallel after their group prerequisites are met.

### Group 1: Android Build Configuration

- [x] Update `android/app/build.gradle.kts` to load private values from
      `android/local.properties` using Gradle `Properties`.
- [x] Add a release signing config in `android/app/build.gradle.kts` that uses
      `KEYSTORE_PATH` and `KEY_ALIAS` from `android/local.properties` plus
      transient signing-password environment variables only when all required
      values are present.
- [x] Ensure release builds keep `applicationId = "com.wrait.flutter"` and use
      the real release signing config instead of debug signing.
- [x] Add `applicationIdSuffix = ".dev"` to the debug build type so debug APKs
      install as `com.wrait.flutter.dev`.
- [x] Add `applicationIdSuffix = ".dev"` to the profile build type so the final
      `deploy_debug.sh` profile install also targets `com.wrait.flutter.dev`.
- [x] Ensure release signing setup does not print signing passwords or private
      key material in normal Gradle configuration output.

### Group 2: Debug Deployment Identity Split

- [x] Update `deploy_debug.sh` package constants so the Flutter debug/profile
      app package is `com.wrait.flutter.dev`.
- [x] Update the debug integration-test companion package constant to match the
      package produced for `com.wrait.flutter.dev`.
- [x] Update package-derived activity component checks in `deploy_debug.sh` to
      launch and verify `com.wrait.flutter.dev/com.wrait.flutter.MainActivity`.
- [x] Update the debug lock-screen automation setting name to remain namespaced
      under the debug app identity.
- [x] Preserve the existing `deploy_debug.sh` flow: `PROXY_SECRET` validation,
      one physical phone, debug build, integration tests, profile build,
      install, launch verification, native app preservation, and cleanup
      restoration.
- [x] Verify `deploy_debug.sh` still contains no `adb uninstall`, `pm clear`, or
      package-data clearing behavior.

### Group 3: Release Deployment Script

- [x] Create `deploy_release.sh` with shared script helpers modeled on
      `deploy_debug.sh`: `fail`, `warn`, `require_command`, Java setup, one
      physical-phone discovery, package checks, force-stop, APK output
      preparation, built-APK verification, and launch verification.
- [x] Add concise release deployment usage and prerequisite guidance to
      `deploy_release.sh` comments and actionable failure messages, including
      source/target private config locations and physical-phone targeting.
- [x] Add release-script constants for `com.wrait.flutter`,
      `com.wrait.flutter.dev`, `com.wrait.app`, release APK output path, source
      private config path, and Flutter app-local config path.
- [x] Implement private config synchronization from
      `wrait-android/local.properties` to `android/local.properties` for the
      non-secret keys `KEYSTORE_PATH`, `KEY_ALIAS`, `BACKEND_URL`,
      `PROXY_SECRET`, and `RECORDING_HARD_CAP_MS`, while removing any stale
      persisted signing passwords from the target file.
- [x] Preserve existing unrelated `android/local.properties` keys such as
      `sdk.dir`, `flutter.sdk`, `flutter.buildMode`, `flutter.versionName`, and
      `flutter.versionCode`.
- [x] Validate missing source config, unreadable source config, missing target
      config directory, missing/blank signing keys, missing/blank runtime keys,
      and missing/unreadable keystore path before any build or install.
- [x] Normalize or resolve `KEYSTORE_PATH` so the Flutter Android Gradle build
      reads the intended keystore from `android/local.properties`.
- [x] Validate the resolved keystore and private-key access with `keytool`
      before any release build or install.
- [x] Write `android/local.properties` atomically so interrupted sync work does
      not leave a partially updated target file behind.
- [x] Build the release APK with `flutter build apk --release` and
      `--dart-define` values for `BACKEND_URL`, `PROXY_SECRET`, and
      `RECORDING_HARD_CAP_MS`, while passing signing passwords through
      environment variables instead of persisted file values.
- [x] Reject missing or empty release APK output before installation.
- [x] Detect whether `com.wrait.app` is installed before deployment and verify
      it remains installed afterward when it was present.
- [x] Force-stop only `com.wrait.flutter` before release installation and
      launch verification.
- [x] Install the release APK with `adb -s <phone> install -r`.
- [x] Verify `com.wrait.flutter` is installed after release deployment.
- [x] Verify `com.wrait.flutter.dev` remains installed after release
      deployment when it was already present before the run.
- [x] Launch `com.wrait.flutter/com.wrait.flutter.MainActivity` with
      `adb shell am start -W` and fail clearly on launch timeout or unexpected
      activity output.
- [x] Ensure `deploy_release.sh` does not run integration tests, does not
      install `com.wrait.flutter.dev`, and does not enable debug lock-screen
      automation settings.
- [x] Ensure `deploy_release.sh` contains no `adb uninstall`, `pm clear`, or
      package-data clearing behavior.

### Group 4: Shell Test Coverage

- [x] Update `test/deploy_debug_script_test.sh` fakes and assertions for
      `com.wrait.flutter.dev`, its test package, launch component, foreground
      checks, permission grants, appops, force-stop, install verification, and
      automation setting name.
- [x] Keep existing debug script test scenarios passing for no phone,
      emulator-only, unauthorized/offline phone, missing/bad `PROXY_SECRET`,
      build failures, integration-test failure, wake failure, disconnect before
      install, launch timeout, native app preservation, cleanup restoration, and
      happy path.
- [x] Add `test/deploy_release_script_test.sh` with fake `adb` and `flutter`
      commands modeled on the debug script test harness.
- [x] Add release test coverage for missing source config, unreadable source
      config, missing/blank signing keys, missing/blank runtime keys, missing
      keystore file, no phone, emulator-only, unauthorized/offline phone, ADB
      failure, build without APK, zero-size APK, disconnect before install,
      launch timeout, native app removed after install, native app absent, and
      happy path.
- [x] Add release test coverage for invalid keystore password, invalid key
      password, and debug-package disappearance after install.
- [x] Add release test assertions that preflight failures do not invoke
      `flutter build`, `adb install`, or launch commands.
- [x] Add release test assertions that the script synchronizes only the required
      private keys into `android/local.properties` while preserving unrelated
      existing keys.
- [x] Add release test assertions that `flutter build apk --release` includes
      the expected runtime `--dart-define` values, requires transient signing
      password environment variables, and does not log signing passwords.
- [x] Add release safety assertions that `deploy_release.sh` never uninstalls
      packages and never clears package data.

### Group 5: Static and Automated Validation

- [x] Run `bash test/deploy_debug_script_test.sh`.
- [x] Run `bash test/deploy_release_script_test.sh`.
- [x] Run `/opt/homebrew/bin/flutter analyze`.
- [x] Run `/opt/homebrew/bin/flutter test --no-pub`.
- [x] Run a release APK build after private config synchronization:
      `/opt/homebrew/bin/flutter build apk --release`.
- [x] Record command results and any limitations in `implementation.md` and the
      validation evidence section below.

### Group 6: Physical Android Release Verification

- [x] Run `./deploy_release.sh` on the connected physical Android phone.
- [x] Verify `com.wrait.flutter` is installed with
      `adb -s <phone> shell pm path com.wrait.flutter`.
- [x] Verify `com.wrait.app` remains installed when it existed before release
      deployment with `adb -s <phone> shell pm path com.wrait.app`.
- [x] Verify release launch with
      `adb -s <phone> shell am start -W -n com.wrait.flutter/com.wrait.flutter.MainActivity`.
- [x] If practical, run `./deploy_debug.sh` after release deployment and verify
      it installs/launched `com.wrait.flutter.dev` without replacing
      `com.wrait.flutter`.
- [x] Record device serial redacted as needed, package checks, launch output
      summary, and any device limitations in `implementation.md` and validation
      evidence below.

### Group 7: Implementation Artifact

- [x] Create `specs/031-release-signed-android-deploy/implementation.md`.
- [x] Document the final package identities, signing config source and target,
      script behavior, validation commands, physical-device verification, and
      approved validation exceptions.
- [x] Document local release deployment usage and prerequisites in
      `implementation.md`, including `./deploy_release.sh`, private config
      source/target, and the physical-phone-only targeting rule.
- [x] Update this `tasks.md` checklist and validation evidence as tasks are
      completed.

### Group 8: Review and Fix

- [x] Stop and wait for external `review.md`, unless the user explicitly skips
      review.
- [x] Read `review.md` and prepare a remediation plan without changing files.
- [x] Present the remediation plan and wait for approval before making any
      changes.
- [x] Implement approved review fixes and update `spec.md`, `plan.md`,
      `tasks.md`, `implementation.md`, code, and tests when review changes
      scope, approach, or validation.
- [ ] Repeat the review/fix loop if the same `review.md` file is updated for
      another pass.

### Group 9: Finalization

- [ ] Decide whether this feature produced durable learnings or long-lived
      product/architecture changes worth preserving.
- [ ] If needed, propose updates to `AGENTS.md`.
- [ ] If needed, propose updates to `docs/application-description.md`.
- [ ] If needed, propose updates to `docs/agent-findings.md`.
- [ ] Wait for explicit approval before editing long-lived guidance documents.
- [ ] Record whether the knowledge-capture gate resulted in updates or an
      explicit no-update decision.
- [ ] Mark `spec.md` status as `Complete` only after implementation, review,
      validation, and final knowledge-capture gates are handled.

## Completion criteria

All implementation tasks checked, validation evidence documented, Android
physical-phone release deployment verified, approved validation exceptions
recorded, review handled or explicitly skipped, and final knowledge-capture gate
handled.

## Validation evidence

Record test results, screenshots, command output, approved exceptions, or
review-related notes here when complete.

```text
bash test/deploy_debug_script_test.sh
- Passed.

bash test/deploy_release_script_test.sh
- Passed.

/opt/homebrew/bin/flutter analyze
- Passed with no issues found.

/opt/homebrew/bin/flutter test --no-pub
- Passed. Full suite completed successfully.

/opt/homebrew/bin/flutter build apk --release
- Passed after synchronizing ignored android/local.properties from
  wrait-android/local.properties for validation.
- Required one escalated rerun because Flutter needed write access to its shared
  Homebrew cache outside the workspace sandbox.
- Produced build/app/outputs/flutter-apk/app-release.apk.

adb devices
- Reported physical phone 4A181FDJH0030G and emulator-5554.

./deploy_release.sh
- Initial run reached the install step on 4A181FDJH0030G and failed with
  `INSTALL_FAILED_UPDATE_INCOMPATIBLE`.
- Certificate comparison confirmed the built release APK matches the configured
  release keystore, while the previously installed `com.wrait.flutter` on the
  phone was signed with the default Android debug keystore.
- After explicit approval, `adb -s 4A181FDJH0030G uninstall com.wrait.flutter`
  succeeded and a rerun of `./deploy_release.sh` completed successfully.
- Release install and launch succeeded on-device.

adb -s 4A181FDJH0030G shell pm path com.wrait.flutter
- Passed after successful release deployment.

adb -s 4A181FDJH0030G shell pm path com.wrait.app
- Passed; native app remained installed.

adb -s 4A181FDJH0030G shell am start -W -n com.wrait.flutter/com.wrait.flutter.MainActivity
- Passed; launcher-style start reported Activity com.wrait.flutter/.MainActivity.

./deploy_debug.sh
- Passed on the same phone after release deployment.
- Integration tests completed successfully against `com.wrait.flutter.dev`.
- Final profile install and launch succeeded as
  `com.wrait.flutter.dev/com.wrait.flutter.MainActivity`.

adb -s 4A181FDJH0030G shell pm path com.wrait.flutter.dev
- Passed after debug coexistence validation.

Review-fix validation:
- `bash test/deploy_release_script_test.sh` -> passed after adding transient
  password handling, `keytool` preflight coverage, atomic sync coverage, and
  debug-package preservation checks.
- `bash test/deploy_debug_script_test.sh` -> passed to confirm the review fixes
  did not regress the debug deployment path.
- `./gradlew :app:help` (from `android/`) -> passed to confirm the updated
  Kotlin DSL config parses successfully.
- `./gradlew :app:assembleRelease` (from `android/` with no signing-password
  env vars) -> failed immediately with the expected fail-closed release-signing
  message requiring `WRAIT_RELEASE_KEYSTORE_PASSWORD` and
  `WRAIT_RELEASE_KEY_PASSWORD`.
```
