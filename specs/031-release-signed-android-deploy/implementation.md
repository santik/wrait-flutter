# Implementation: Release-Signed Android Deploy Flow

> **Feature number:** 031
> **Spec:** [`spec.md`](spec.md)
> **Plan:** [`plan.md`](plan.md)
> **Tasks:** [`tasks.md`](tasks.md)
> **Author:** Codex
> **Date:** 2026-06-22

## Summary

US-031 is implemented by splitting the Flutter Android install identities and
adding a dedicated release deployment path.

- `deploy_debug.sh` now targets `com.wrait.flutter.dev` for both its
  integration-test install path and its final profile install path, so debug
  deployment no longer touches the production-style update-validation install.
- `deploy_release.sh` now deploys the real release app as `com.wrait.flutter`,
  synchronizes private signing/runtime configuration from
  `wrait-android/local.properties` into the ignored Flutter app-local
  `android/local.properties`, validates that configuration before build/install,
  builds a release APK, preserves `com.wrait.app`, and verifies launch.
- Flutter Android release builds now consume release signing from
  `android/local.properties`, while debug and profile builds install as
  `com.wrait.flutter.dev`.

After external review, the release path was hardened further:

- signing passwords are no longer synchronized into `android/local.properties`
- release keystore and key access are preflight-validated with `keytool`
- release builds fail closed when required signing inputs are absent
- `android/local.properties` synchronization is atomic
- release deployment now verifies that a pre-existing
  `com.wrait.flutter.dev` install remains present
- the production Android manifest now owns `INTERNET` so release installs can
  perform backend registration and show quota correctly

## Implemented behavior

- Release builds keep `applicationId = "com.wrait.flutter"` and use the private
  release signing configuration when `KEYSTORE_PATH` and `KEY_ALIAS` are
  present in `android/local.properties` and the signing password environment
  variables are present for the active build.
- Debug and profile builds both use `applicationIdSuffix = ".dev"`, producing
  installs under `com.wrait.flutter.dev`.
- `deploy_debug.sh` preserves its existing flow and safety checks while using
  the `.dev` package, `.dev.test` companion package, and the updated
  lock-screen automation setting namespace.
- `deploy_release.sh`:
  - requires exactly one connected physical Android phone and ignores emulators
  - reads canonical private config from `wrait-android/local.properties`
  - normalizes `KEYSTORE_PATH` relative to that source file when necessary
  - synchronizes only non-secret release-signing and runtime keys into
    `android/local.properties` without touching unrelated keys there
  - removes any stale `KEYSTORE_PASSWORD` and `KEY_PASSWORD` entries from the
    target file instead of persisting them
  - validates signing keys, runtime values, keystore reachability, and private
    key access before any build or install
  - writes `android/local.properties` atomically
  - builds `app-release.apk` with `BACKEND_URL`, `PROXY_SECRET`, and
    `RECORDING_HARD_CAP_MS` `--dart-define` values plus transient signing
    password environment variables
  - installs and verifies `com.wrait.flutter`
  - leaves `com.wrait.app` installed when it was already present
  - verifies `com.wrait.flutter.dev` remains installed when it existed before
    release deployment
  - never uninstalls packages or clears package data

## File-change summary

### Production code and scripts

- `android/app/build.gradle.kts`
- `deploy_debug.sh`
- `deploy_release.sh`

### Tests

- `test/deploy_debug_script_test.sh`
- `test/deploy_release_script_test.sh`

### Story artifacts

- `specs/031-release-signed-android-deploy/spec.md`
- `specs/031-release-signed-android-deploy/plan.md`
- `specs/031-release-signed-android-deploy/tasks.md`
- `specs/031-release-signed-android-deploy/implementation.md`

## Notable implementation notes

- The Flutter app-local private config target is `android/local.properties`,
  which is already ignored by `android/.gitignore`. That lets the Flutter
  Android build consume non-secret release settings without introducing tracked
  secrets.
- The release script synchronizes only the managed non-secret release/runtime
  keys and
  preserves unrelated local keys such as `sdk.dir`, `flutter.sdk`,
  `flutter.buildMode`, `flutter.versionName`, and `flutter.versionCode`, while
  stripping stale password entries from older target files.
- `deploy_release.sh` intentionally does not run `integration_test`, does not
  enable the debug automation setting, and does not install the debug identity.
- Because the Java/Kotlin namespace remains `com.wrait.flutter`, the debug
  deploy script now launches `com.wrait.flutter.dev/com.wrait.flutter.MainActivity`
  rather than assuming the package name and activity class name are identical.
- Release keystore preflight uses `keytool -list` to confirm keystore access and
  alias existence plus `keytool -certreq` to confirm private-key access with the
  configured key password before invoking Gradle.

## Deviations from the approved plan

None in scope. The implemented flow matches the approved plan.

The approved review remediation intentionally narrowed one implementation
detail: secret signing passwords no longer persist in
`android/local.properties`, even though earlier implementation drafts copied
them there.

## Validation

The following automated validation completed successfully:

- `bash test/deploy_debug_script_test.sh`
- `bash test/deploy_release_script_test.sh`
- `/opt/homebrew/bin/flutter analyze`
- `/opt/homebrew/bin/flutter test --no-pub`
- `/opt/homebrew/bin/flutter build apk --release`

Release build validation required synchronizing the ignored
`android/local.properties` from the private source config before invoking
`flutter build apk --release`.

One escalated command was required during validation: the release APK build had
to be rerun outside the sandbox because Flutter needed write access to its
shared Homebrew cache under `/opt/homebrew/share/flutter/bin/cache`.

Non-blocking build warning observed during release APK validation:

- Flutter reported several plugins still applying the Kotlin Gradle Plugin
  directly (`package_info_plus`, `share_plus`, `speech_to_text`,
  `wakelock_plus`). The release build still succeeded, but a future Flutter
  version may require plugin updates.

## Physical-device validation status

Physical Android validation completed on phone `4A181FDJH0030G`.

Release deployment validation:

- initial `./deploy_release.sh` reached the install step and failed with
  `INSTALL_FAILED_UPDATE_INCOMPATIBLE`
- certificate comparison confirmed:
  - the built release APK matches the configured release keystore from
    `wrait-android/local.properties`
  - the previously installed `com.wrait.flutter` matched the default Android
    debug keystore certificate instead
- after explicitly uninstalling the old debug-signed `com.wrait.flutter`,
  rerunning `./deploy_release.sh` completed successfully
- the rerun built the release APK, installed `com.wrait.flutter`, preserved
  `com.wrait.app`, and launched `com.wrait.flutter/.MainActivity`

Observed release-device checks:

- `adb -s 4A181FDJH0030G shell pm path com.wrait.flutter`
- `adb -s 4A181FDJH0030G shell pm path com.wrait.app`
- `adb -s 4A181FDJH0030G shell am start -W -n com.wrait.flutter/com.wrait.flutter.MainActivity`

Debug coexistence validation:

- `./deploy_debug.sh` completed successfully on the same phone after release
  deployment
- the integration-test phase ran successfully against `com.wrait.flutter.dev`
- the final profile install succeeded as `com.wrait.flutter.dev`
- launch verification succeeded for
  `com.wrait.flutter.dev/com.wrait.flutter.MainActivity`
- both package IDs remained installed side by side after the run:
  - `com.wrait.flutter`
  - `com.wrait.flutter.dev`

## Review-fix validation

After the approved remediation plan from
[`review.md`](review.md), the following regression checks passed:

- `bash test/deploy_release_script_test.sh`
  - verified transient signing-password handling
  - verified `keytool` keystore/key preflight failure cases
  - verified atomic config synchronization expectations
  - verified debug-package preservation after release deployment
- `bash test/deploy_debug_script_test.sh`
  - confirmed the release hardening changes did not regress the debug deploy
    flow
- `./gradlew :app:help` (from `android/`)
  - confirmed the updated Kotlin DSL configuration parses successfully
- `./gradlew :app:assembleRelease` (from `android/` with no signing-password
  env vars)
  - failed immediately with the intended fail-closed message requiring
    `WRAIT_RELEASE_KEYSTORE_PASSWORD` and `WRAIT_RELEASE_KEY_PASSWORD`
