# Implementation Plan: Release-Signed Android Deploy Flow

> **Feature number:** 031
> **Spec:** [`spec.md`](spec.md)
> **Status:** Approved
> **Author:** Codex
> **Date:** 2026-06-22

## Summary

Add a separate release deployment path for the Flutter Android app while keeping
the existing debug deployment behavior as stable as possible. The release path
will build and install `com.wrait.flutter` with the real release signing
identity. The debug path will continue to run its current build/test/profile
deployment flow, but it will target `com.wrait.flutter.dev` so debug automation
does not overwrite release/update-validation app state.

Release-signing values will remain private. The implementation will copy the
needed non-secret signing/runtime keys from `wrait-android/local.properties`
into the Flutter app's ignored `android/local.properties` file, preserving
existing Flutter SDK metadata in that file. Secret signing passwords will stay
transient: `deploy_release.sh` will validate them with `keytool` and pass them
to Gradle through environment variables for the active release build only.

## Scope

### In scope

- [ ] Add `deploy_release.sh` for physical-phone-only release-signed Android
      deployment of `com.wrait.flutter`.
- [ ] Configure Flutter Android release builds to use release signing from
      private `android/local.properties` values.
- [ ] Synchronize required non-secret release-signing and runtime configuration
      keys from `wrait-android/local.properties` into `android/local.properties`
      without committing or logging secret values.
- [ ] Move the debug/profile Flutter Android build identity used by
      `deploy_debug.sh` to `com.wrait.flutter.dev`.
- [ ] Keep `deploy_debug.sh` behavior unchanged except for package identity,
      component, and automation-setting names required by the debug identity.
- [ ] Add shell-level tests for release deployment preflight, build/install
      behavior, package isolation, and no-uninstall/no-clear safety checks.
- [ ] Update existing debug deployment shell tests for the new debug identity.

### Out of scope

- [ ] iOS deployment changes.
- [ ] Play Store, app bundle publishing, or store upload automation.
- [ ] Migration or data sharing between `com.wrait.flutter` and
      `com.wrait.flutter.dev`.
- [ ] Changing backend APIs, diary data models, local database schema, or
      ordinary app UX.
- [ ] Running integration tests from `deploy_release.sh`.

## Architecture / approach

### Android package identities

The main Flutter Android package remains `com.wrait.flutter`. The debug build
type will use `applicationIdSuffix = ".dev"`, producing
`com.wrait.flutter.dev` for debug installs. The profile build used by
`deploy_debug.sh` also needs to target `com.wrait.flutter.dev`; because the
profile build type is distinct from debug in Flutter, the plan is to apply the
same suffix to profile builds as well.

Release builds will not use a suffix and will install as `com.wrait.flutter`.
This preserves update compatibility for the release/update-validation app.

### Signing configuration

The existing private source of truth is `wrait-android/local.properties`.
The Flutter app's private build configuration location is
`android/local.properties`, which is already git-ignored and already used by
Flutter for local SDK/build metadata.

Implementation will copy or synchronize these keys from the source private file
to `android/local.properties`:

- `KEYSTORE_PATH`
- `KEY_ALIAS`
- `BACKEND_URL`
- `PROXY_SECRET`
- `RECORDING_HARD_CAP_MS`

`KEYSTORE_PATH` will be validated after synchronization. If the path is
relative, validation should resolve it relative to
`wrait-android/local.properties`, which remains the canonical source file. If
necessary, the synchronized value can be normalized to an absolute path inside
the private `android/local.properties` file so the Flutter Android Gradle build
uses the intended keystore.

`KEYSTORE_PASSWORD` and `KEY_PASSWORD` will remain transient values loaded from
the source private config, validated with `keytool`, and passed to the release
Gradle build through environment variables rather than persisted into
`android/local.properties`.

The Gradle build will create a `release` signing config only when all required
signing keys are available and valid, and it will fail closed for release tasks
when signing inputs are incomplete. `deploy_release.sh` will perform its own
preflight before building so missing or invalid signing inputs fail before
installation with actionable errors.

### Deployment scripts

`deploy_debug.sh` will retain its current flow:

1. Validate `PROXY_SECRET`.
2. Require exactly one connected physical Android phone and ignore emulators.
3. Build a debug APK.
4. Prepare the phone for automation.
5. Run `flutter test --no-pub -d <phone> integration_test`.
6. Build a profile APK as the final install artifact.
7. Install, verify, and launch the Flutter app.
8. Restore stay-awake and lock-screen automation settings.

The minimal intended changes are package constants and package-derived activity
references so that the flow operates on `com.wrait.flutter.dev` and its test
package, not `com.wrait.flutter`.

`deploy_release.sh` will be a new focused release flow with concise operator
usage and prerequisite guidance in its comments and failure messages:

1. Configure Java consistently with `deploy_debug.sh`.
2. Require `adb` and `flutter`.
3. Require exactly one connected physical Android phone and ignore emulators.
4. Synchronize required private settings from `wrait-android/local.properties`
   into `android/local.properties`.
5. Validate release-signing inputs and runtime configuration before building,
   including `keytool` verification of the configured keystore and key access.
6. Build a release APK with `flutter build apk --release` and the resolved
   runtime `--dart-define` values plus transient signing-password environment
   variables.
7. Reject missing or empty release APK output.
8. Detect whether the older native app `com.wrait.app` is installed and never
   uninstall or clear it.
9. Force-stop only `com.wrait.flutter`.
10. Install the release APK with `adb install -r`.
11. Verify `com.wrait.flutter` is installed and `com.wrait.app` remains present
    if it was present before deployment.
12. Verify `com.wrait.flutter.dev` remains present if it was installed before
    deployment.
13. Launch `com.wrait.flutter/com.wrait.flutter.MainActivity` with
    `adb shell am start -W` and verify launch output.

The release script will not enable debug lock-screen automation settings, will
not run integration tests, and will not install the debug/profile app identity.

## Detailed design

### Component / module changes

- **`android/app/build.gradle.kts`** - load private values from
  `android/local.properties`, add release signing config, set debug/profile
  app ID suffixes, and keep release as `com.wrait.flutter`.
- **`deploy_debug.sh`** - change package constants and derived component names
  to `com.wrait.flutter.dev`; keep the current build/test/profile/install flow
  and safety checks.
- **`deploy_release.sh`** - new release deployment script with private config
  synchronization, signing preflight, release build, physical-phone install,
  package verification, native-app preservation, launch verification, and
  concise local-use documentation.
- **`test/deploy_debug_script_test.sh`** - update expected debug package,
  activity, test package, and automation setting names while preserving behavior
  expectations.
- **`test/deploy_release_script_test.sh`** - new shell test harness modeled on
  the debug script tests for success and failure paths.
- **`specs/031-release-signed-android-deploy/tasks.md`** - replace the template
  with ordered implementation tasks after plan approval.
- **`specs/031-release-signed-android-deploy/implementation.md`** - create
  during implementation with validation evidence and notes.

### Data flow

1. Operator runs `./deploy_release.sh`.
2. Script reads source private values from `wrait-android/local.properties`.
3. Script updates `android/local.properties` atomically with only the required
   non-secret keys while preserving existing Flutter-local metadata such as SDK
   paths and build mode.
4. Script validates signing/runtime inputs without printing secret values,
   including `keytool` checks for keystore access and key access.
5. Flutter release build reads `android/local.properties` for non-secret
   release settings, reads signing passwords from environment variables, and
   receives runtime values through `--dart-define`.
6. Script installs the release APK as `com.wrait.flutter`.
7. Script verifies the release package and launch, while leaving `com.wrait.app`
   and any pre-existing `com.wrait.flutter.dev` install untouched.

Debug deployment follows the existing path but operates on
`com.wrait.flutter.dev`, so `flutter test` and final profile install no longer
touch `com.wrait.flutter`.

### Contracts and interfaces

No backend HTTP, app data, or public product API contracts change.

Operational interfaces:

- `./deploy_debug.sh` remains the debug deploy entrypoint.
- `./deploy_release.sh` becomes the release-signed deploy entrypoint.
- Private `wrait-android/local.properties` remains the source configuration for
  signing/runtime values.
- Private `android/local.properties` becomes the Flutter app-local consumed
  configuration for signing/runtime values.

## Alternatives considered

- **Keep debug and release on `com.wrait.flutter`:** rejected because debug
  integration-test installs can overwrite or reset release/update-validation
  state.
- **Require the operator to manually copy signing keys into the Flutter app:**
  rejected because the story asks for a repeatable flow without manual signing
  steps and with clearer setup failures.
- **Read signing values directly from `wrait-android/local.properties` in the
  Flutter Gradle build:** rejected because the Flutter Android project should
  use its own app-local private config location, and direct cross-project reads
  make the build less self-contained.
- **Run integration tests from `deploy_release.sh`:** rejected by the clarified
  scope. Release deploy should build and install the release-signed artifact
  only.
- **Support Android emulators in `deploy_release.sh`:** rejected by the
  clarified scope. Release deploy should use the same physical-phone targeting
  model as debug deploy.

## Test strategy

### Unit / integration coverage

| Area | Test type | Notes |
| --- | --- | --- |
| Debug deploy identity split | Shell script test | Update `test/deploy_debug_script_test.sh` to assert debug/profile install, permission grants, appops, launch, and force-stop use `com.wrait.flutter.dev`. |
| Debug deploy behavior preservation | Shell script test | Existing success/failure scenarios remain covered: missing phone, bad `PROXY_SECRET`, unavailable phone, build failures, integration-test failure, launch timeout, native app preservation, cleanup restore. |
| Release deploy preflight | Shell script test | New tests for missing source config, missing/blank signing keys, missing keystore, missing/blank runtime values, emulator-only/no-phone handling, and no build/install before preflight passes. |
| Release deploy secret handling and keystore validation | Shell script test | Verify signing passwords are not synchronized into `android/local.properties`, fake release builds require transient environment variables, and invalid keystore/key passwords fail during preflight. |
| Release deploy happy path | Shell script test | Fake `adb`/`flutter`/`keytool` flow verifies config synchronization, `flutter build apk --release`, `adb install -r`, package verification, launch of `com.wrait.flutter`, debug-package preservation, and native app preservation. |
| Release deploy safety | Shell script test | Assert release script does not use `adb uninstall`, `pm clear`, or package-data clearing commands. |
| Release deploy documentation | Script review and implementation notes | Verify the release script and implementation artifact document local prerequisites, private config source/target, command usage, and validation expectations. |
| Android Gradle signing config | Build validation | Run a release APK build after private config synchronization to prove the Gradle release signing config is consumable. |

### Runtime verification

#### Android

1. Run shell tests:
   `bash test/deploy_debug_script_test.sh`
2. Run release deploy shell tests:
   `bash test/deploy_release_script_test.sh`
3. Run static analysis:
   `/opt/homebrew/bin/flutter analyze`
4. Run relevant unit/widget tests:
   `/opt/homebrew/bin/flutter test --no-pub`
5. On the physical Android phone used for deployment validation, run:
   `./deploy_release.sh`
6. Verify the installed package:
   `adb -s <phone> shell pm path com.wrait.flutter`
7. Verify the debug package was not required or touched by release deploy:
   `adb -s <phone> shell pm path com.wrait.flutter.dev` when present before the
   run, or record that it was absent before deployment.
8. Verify the older native app remains installed when present:
   `adb -s <phone> shell pm path com.wrait.app`
9. Launch the release app:
   `adb -s <phone> shell am start -W -n com.wrait.flutter/com.wrait.flutter.MainActivity`
10. Optionally run `./deploy_debug.sh` after release deployment and verify it
    installs/launched `com.wrait.flutter.dev` without replacing
    `com.wrait.flutter`.

#### iOS

No iOS runtime verification is planned because this story does not change iOS
source, build configuration, signing, packaging, or deployment behavior. This
is an explicit validation exception request for user approval with this plan.

### Requested validation exceptions

- **No release-flow `integration_test` coverage:** The in-scope release user
  flow is an operator shell deployment path, not an in-app user flow, and the
  user clarified that release deployment should be release-only. Shell tests
  plus physical-phone release deployment will cover the behavior instead.
- **No Android emulator runtime verification:** The release deployment flow is
  explicitly physical-phone-only and should ignore emulators, matching
  `deploy_debug.sh`.
- **No iOS simulator verification:** The feature does not change iOS behavior.

## Risks / mitigations

- **Risk:** Copying private values could expose secrets in logs or tracked
  files.
  **Mitigation:** Synchronize only non-secret keys to ignored
  `android/local.properties`, keep signing passwords transient in-memory/env,
  never print secret values, and keep `.gitignore` coverage intact.
- **Risk:** Relative `KEYSTORE_PATH` from the source project could resolve
  differently in the Flutter Android project.
  **Mitigation:** Validate path resolution during synchronization and normalize
  to a usable private value before building.
- **Risk:** Changing debug/profile application IDs could break deployment
  script package assumptions.
  **Mitigation:** Update only package-derived constants and prove behavior with
  the existing debug shell-test scenarios.
- **Risk:** Release install could accidentally affect the older native app.
  **Mitigation:** Preserve the current native-app detection/verification pattern
  and add release-script tests asserting no uninstall or clear behavior.
- **Risk:** Release signing Gradle failures might be confusing.
  **Mitigation:** Add release-script preflight before build/install, validate
  the keystore with `keytool`, and keep Gradle release signing checks direct
  and explicit.

## Rollout / fallback

The scripts are local operator tooling, so rollout is repository-local. If
release deployment fails, no package should be installed unless preflight and
build succeed. Debug deployment remains available under `./deploy_debug.sh`
with the new debug package identity.

Fallback for a failed release deploy is to fix the private config values and
rerun `./deploy_release.sh`. If the debug identity change causes unexpected
device-side confusion, the release app `com.wrait.flutter` remains isolated
from `com.wrait.flutter.dev` and should not need data migration or cleanup.

## Open questions

None.
