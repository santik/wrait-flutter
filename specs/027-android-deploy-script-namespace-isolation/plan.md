# Implementation Plan: Android Deploy Script and App Namespace Isolation

> **Feature number:** 027
> **Spec:** [`spec.md`](spec.md)
> **Author:** Codex
> **Date:** 2026-06-15

---

## Approach summary

Implement US-027 as a small Android tooling and identity change. The Flutter
Android app will use `com.wrait.flutter` for its Android namespace and
application identity, with the Kotlin `MainActivity` package moved to match.
A root `deploy_debug.sh` command will build the Flutter debug APK, detect the
single connected Android phone, run the Flutter integration test suite on that
phone, and install the APK without touching `com.wrait.app` only after tests
pass. The command will be documented in `README.md` and validated with focused
shell tests, Flutter checks, a debug APK build, and a physical Android phone
test-and-install run.

## Architecture decisions

| Decision | Choice | Rationale |
| --- | --- | --- |
| Android application identity | Use `com.wrait.flutter` for both `namespace` and `applicationId` | The spec requires this exact identity, and keeping namespace and applicationId aligned avoids stale package assumptions in Android source and generated binding behavior. |
| Activity package move | Move `MainActivity` from `com.wrait.app` to `com.wrait.flutter` | The Kotlin package should match the Android namespace so source paths, package declarations, and manifest-relative activity resolution stay consistent. |
| Deployment command location | Add root-level `deploy_debug.sh` | A root command is discoverable, short to run from the repository, and mirrors the sibling native Android project's developer workflow. |
| Deployment command scope | Build and install debug APK only | The finalized spec explicitly excludes non-debug deployment automation and release distribution. |
| Device handling | Require exactly one connected Android phone in `device` state and ignore emulator entries | The spec assumes one connected phone and excludes emulator-specific behavior. Failing when no usable phone is connected is simpler and clearer than adding target selection or emulator handling. |
| Build tool | Use Flutter's debug APK build output | This is the Flutter-native path for producing `build/app/outputs/flutter-apk/app-debug.apk` and avoids coupling the root script to Android subproject Gradle internals. |
| Real-device test command | Run `flutter test --no-pub -d "$serial" integration_test` before final install | Existing project findings show this command shape is reliable for device-backed Flutter integration tests, and `--no-pub` avoids unnecessary dependency refresh during deployment. |
| Script test strategy | Add dependency-free shell tests with fake `adb` and `flutter` commands | The risky behavior is shell orchestration, not Dart app logic. Fake commands can verify no-phone failure and one-phone install behavior without a real device. |
| Documentation | Replace the default README content with focused project commands | Acceptance requires a documented single command. The current README is a Flutter template and does not document this repo's deploy flow. |

## File changes

| File | Action | Description |
| --- | --- | --- |
| `android/app/build.gradle.kts` | Modify | Change `namespace` and `applicationId` from `com.wrait.app` to `com.wrait.flutter`. |
| `android/app/src/main/kotlin/com/wrait/app/MainActivity.kt` | Delete | Remove the old package-path activity source. |
| `android/app/src/main/kotlin/com/wrait/flutter/MainActivity.kt` | Create | Recreate `MainActivity` under package `com.wrait.flutter` with existing platform-channel behavior preserved. |
| `deploy_debug.sh` | Create | Root debug deployment command that builds the Flutter debug APK, runs integration tests on the single connected Android phone, and installs the APK when tests pass. |
| `README.md` | Modify | Document `./deploy_debug.sh`, prerequisites, and expected no-phone behavior. |
| `test/deploy_debug_script_test.sh` | Create | Dependency-free shell tests for deployment script no-phone and one-phone paths using fake command shims. |
| `specs/027-android-deploy-script-namespace-isolation/plan.md` | Modify | Record this implementation plan and validation strategy. |

## API contract details

This feature has no backend HTTP contract.

Internal developer command contract:

- Command: `./deploy_debug.sh`
- Success path:
  - Requires one connected Android phone reported by `adb devices` in `device`
    state.
  - Builds the Flutter Android debug APK.
  - Runs `flutter test --no-pub -d "$serial" integration_test` on that phone.
  - Installs `build/app/outputs/flutter-apk/app-debug.apk` to that phone.
  - Leaves any existing `com.wrait.app` installation untouched.
- Failure path:
  - If no usable Android phone is connected, exits non-zero before building or
    installing.
  - If only emulator targets are connected, exits non-zero before building or
    installing because emulator-specific behavior is out of scope.
  - If the phone is unauthorized, offline, or otherwise not in `device` state,
    exits non-zero with a clear message.
  - If real-device integration tests fail, exits non-zero before the final
    debug APK install.
  - If the build or install fails, propagates a non-zero exit and prints the
    failing command context.

The script will not implement multi-target selection, emulator-specific
behavior, release deployment, or automatic uninstall behavior.

## Data model changes

No persistent user-data schema changes are required.

### Before

```text
Android namespace:     com.wrait.app
Android applicationId: com.wrait.app
MainActivity package:  com.wrait.app
```

### After

```text
Android namespace:     com.wrait.flutter
Android applicationId: com.wrait.flutter
MainActivity package:  com.wrait.flutter
```

### Migration

No user-data migration is planned. Existing installs under `com.wrait.app` are
left intact. A previous Flutter debug install that used `com.wrait.app`, if
present, is not automatically removed by this feature.

## Test strategy

### Automated tests

| Test case | Type | File |
| --- | --- | --- |
| `deploy_debug.sh` exits before build/install with a clear no-phone message when `adb devices` reports no usable phone | Shell | `test/deploy_debug_script_test.sh` |
| `deploy_debug.sh` exits before build/install with a clear no-phone message when `adb devices` reports only an emulator | Shell | `test/deploy_debug_script_test.sh` |
| `deploy_debug.sh` exits before build/install with a clear unavailable-phone message when a phone is unauthorized or offline | Shell | `test/deploy_debug_script_test.sh` |
| `deploy_debug.sh` builds, runs integration tests, and installs the debug APK to the single connected phone serial when fake `adb devices` reports one usable phone | Shell | `test/deploy_debug_script_test.sh` |
| `deploy_debug.sh` exits before final install when the fake real-device integration test command fails | Shell | `test/deploy_debug_script_test.sh` |
| Android app identity references no longer use `com.wrait.app` in project-owned Android app source/build files | Static check | command: `rg -n "com\\.wrait\\.app" android/app/build.gradle.kts android/app/src/main android/app/src/debug android/app/src/profile` should return no matches; deploy-script and README references to the native app are allowed only when clearly protecting or describing coexistence |
| Existing Dart/Flutter tests still pass | Unit/widget/integration as currently configured | command: `/opt/homebrew/bin/flutter test` |
| Flutter static analysis still passes | Static analysis | command: `/opt/homebrew/bin/flutter analyze` |
| Debug Android APK builds with the new identity | Build | command: `/opt/homebrew/bin/flutter build apk --debug` |
| Flutter integration tests run on the connected Android phone | Real-device integration | command: `./deploy_debug.sh` includes `flutter test --no-pub -d <phone-serial> integration_test` |

### Android emulator verification

Exception requested: Android emulator verification will not be performed for
this story.

Rationale: the finalized spec explicitly targets one connected Android phone
and excludes emulator-specific deployment behavior. The runtime verification
for this feature will use the connected physical Android phone instead.

### Android phone verification

1. Confirm one Android phone is connected and authorized with `adb devices`.
2. If the existing native Wrait Android app is installed, record that
   `com.wrait.app` is present before deployment.
3. Run `./deploy_debug.sh` and confirm it runs `integration_test` on the
   connected phone.
4. Verify `com.wrait.flutter` is installed on the phone only after tests pass.
5. Verify `com.wrait.app` remains installed if it was present before
   deployment.
6. Launch `com.wrait.flutter` on the phone and confirm the app opens.

### iOS simulator verification

Exception requested: iOS simulator runtime verification will not be performed
for this story.

Rationale: US-027 changes only Android application identity and Android debug
deployment tooling. It does not change iOS source, runtime behavior, or user
flows. Non-Android behavior will be covered by unchanged Flutter tests and
static analysis.

### Validation exception request

Explicit approval is requested for these validation exceptions:

- No Android emulator verification. The spec targets one connected Android
  phone and excludes emulator-specific behavior.
- No iOS simulator runtime verification. The feature is Android-only and does
  not alter iOS behavior.

## Review and finalization

- `review.md` will be externally authored if review occurs.
- After reading `review.md`, no files may be changed until the remediation plan
  is explicitly approved.
- This feature is likely to require a durable update to
  `docs/agent-findings.md` after final approval because that document currently
  records `com.wrait.app` as the Flutter package/application ID.
- `docs/application-description.md` is unlikely to need a product update
  because this feature is developer tooling and Android identity isolation, not
  user-facing functionality.
- `AGENTS.md` is unlikely to need an update unless implementation discovers a
  reusable deploy or validation rule future agents should follow.

## Integration notes

- The existing native Android app continues to own `com.wrait.app`.
- The Flutter rewrite will own `com.wrait.flutter` after this feature.
- The Android manifest currently references `.MainActivity`; keeping the
  activity package aligned with the namespace preserves that relative activity
  reference.
- The existing `wrait/preferences` platform channel behavior in
  `MainActivity` must be preserved exactly while moving packages.
- Sibling native Android deploy scripts are references only; this feature will
  not modify the sibling project.

## Rollout & migration

This is a local developer workflow change. Developers will run:

```sh
./deploy_debug.sh
```

No feature flag is needed. No automatic uninstall or migration is planned. If a
developer has a previous Flutter build installed under `com.wrait.app`, it will
remain as-is unless they manually remove it.

## Risks & mitigations

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| Package rename misses an Android source or build reference | Medium | High | Use `rg` to scan project-owned Android app identity surfaces for stale `com.wrait.app` references and build the debug APK. |
| Deploy script accidentally installs to the wrong device | Low | Medium | Scope the script to one connected Android phone and fail before install if no usable phone is detected. |
| Deploy script behavior is brittle on local machines | Medium | Medium | Keep dependencies to `flutter` and `adb`, preserve the sibling script's Java environment cleanup where relevant, use `--no-pub` for the real-device integration run, and cover orchestration with fake-command shell tests. |
| Existing native Android app is overwritten | Low | High | Change Flutter `applicationId` to `com.wrait.flutter` and verify installed package coexistence on the phone. |
| iOS or Dart app behavior regresses unexpectedly | Low | Medium | Run `flutter analyze` and `flutter test`; no iOS files are planned to change. |

## Open items from spec

None.
