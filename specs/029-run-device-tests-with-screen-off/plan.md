# Implementation Plan: Connected Device Tests With Screen Off

> **Feature number:** 029
> **Spec:** [`spec.md`](spec.md)
> **Author:** Codex
> **Date:** 2026-06-17

---

## Approach summary

Add a locked-screen preparation step to the Android debug deployment path and
make the debug Android activity compatible with locked-screen automated runs.
`deploy_debug.sh` will continue to be the single entry point: it will still find
one physical phone, validate `PROXY_SECRET`, build the debug APK for the
`integration_test` phase, run the existing suite on the phone, then install a
launchable final non-release artifact only after tests pass, and verify the
final app launch. Physical-device validation showed that this phone wedges on a
standalone debug cold launch but opens the equivalent profile build normally, so
the final installed artifact will be profile while the test phase remains
debug/integration based. Before device-dependent phases, the script will wake
the phone and attempt non-interactive keyguard dismissal through the local
development channel. The debug Android activity will allow locked-screen launch
only when an automation-specific Android setting is enabled in a debuggable
process, so ordinary locked-phone state does not block Flutter integration
tests. The script will keep the phone awake while it is actively preparing or
testing, validate that its temporary automation setting actually sticks, and
restore the temporary device settings when the command exits. Because
locked-device recording tests cannot clear a runtime microphone prompt by hand,
the deploy script will also auto-grant `android.permission.RECORD_AUDIO` to the
app under test throughout the deploy-time `flutter test` session. Release and
profile runtime behavior remain unchanged.

## Architecture decisions

| Decision | Choice | Rationale |
| --- | --- | --- |
| Entry point scope | Keep `./deploy_debug.sh` as the only command changed | The spec explicitly limits scope to `deploy_debug.sh`; a standalone test command would add maintenance surface without solving the requested workflow. |
| Device preparation | Add a reusable shell helper that wakes the phone, attempts keyguard dismissal, verifies the phone remains connected, and prints clear readiness status | This keeps all deploy workflow behavior in one place and preserves existing fail-fast command output. Reusing the helper before multiple device phases avoids relying on one early wake surviving a long build/test run. |
| Locked-screen app launch | Configure the Android Flutter activity to show/turn on over lock screen and keep the screen awake only when the app process is debuggable and an automation-specific Android global setting is enabled | ADB cannot bypass secure Android credentials. An automation-gated debug-only launch path is the least invasive way to make tests work from an ordinary locked phone without weakening release/profile privacy or requiring physical interaction. |
| Automation-state signaling | Use a namespaced Android global setting validated by readback and restored after the run | The setting lets the script opt the debug activity into lock-screen behavior only for automated runs. Namespacing plus readback reduces collision and silent-failure risk. |
| Final installed artifact | Keep debug for the test phase, but install a profile APK as the final deployed artifact | Physical-device validation showed that the standalone debug install wedges on the splash screen on the validation phone while the profile build launches correctly. The workflow still tests via the debug/integration channel before any final install. |
| Runtime microphone permission | Auto-grant `android.permission.RECORD_AUDIO` to `com.wrait.flutter` throughout deploy-time integration setup, and continue granting to `com.wrait.flutter.test` while the test package is reinstalled | Recording-related integration tests can trigger the system microphone prompt. On a locked phone, that prompt cannot be accepted manually, and the Flutter test flow can reinstall both app packages during the suite. |
| Permission watchdog lifecycle | Run a bounded watchdog process with stale-PID cleanup at startup | A timeout prevents runaway permission loops if the test session hangs or the parent shell is killed abruptly. Startup cleanup reduces the chance that an old watchdog survives into a later run. |
| Failure handling | Treat ADB wake/connectivity failures as fatal with readiness-specific errors; treat keyguard-dismiss denial as non-fatal when debug locked-screen launch support is available | Secure keyguards may refuse credential dismissal. That is acceptable if the debug activity can still launch over the keyguard. Fatal failures should be limited to states that prevent automation outright. |
| Test coverage | Extend the existing shell-level deploy script tests with fake `adb` readiness scenarios; do not add app user-flow integration tests | The feature changes developer automation, not in-app user behavior. Shell tests can precisely assert command order, errors, and no uninstall/data-clear behavior. The existing integration suite is still run by `deploy_debug.sh` during real-device validation. |
| Documentation | Update README Android debug deployment notes | The spec requires developer documentation for locked-screen behavior and preconditions; README is the current documented entry point for `deploy_debug.sh`. |
| Data migration | None | The feature does not change user data, schemas, preferences, device IDs, quotas, or drafts. |

## File changes

| File | Action | Description |
| --- | --- | --- |
| `deploy_debug.sh` | Modify | Add readiness helpers, automation-state gating, bounded audio-permission watchdog behavior, profile final-install handling, and stricter launch/cleanup safeguards. |
| `android/app/src/main/kotlin/com/wrait/flutter/MainActivity.kt` | Modify | Add automation-gated debuggable-only locked-screen launch support for the Flutter activity. Release and profile builds remain unaffected. |
| `test/deploy_debug_script_test.sh` | Modify | Extend fake `adb` coverage for wake/keyguard commands, locked-phone success, readiness failure, and command-order invariants. |
| `README.md` | Modify | Document that `deploy_debug.sh` supports locked/screen-off phones, uses debug for tests and profile for the final install, temporarily changes automation/power settings, and still requires USB debugging authorization. |
| `specs/029-run-device-tests-with-screen-off/tasks.md` | Modify later | Replace the copied template with the approved task checklist in the next SDD phase. |
| `specs/029-run-device-tests-with-screen-off/implementation.md` | Create later | Record implementation details and validation evidence during implementation. |

## API contract details

This feature does not change backend APIs.

### Deploy command contract

Command:

```sh
PROXY_SECRET=<non-blank secret with no whitespace and length >= 8> ./deploy_debug.sh
```

Inputs:

- one connected physical Android phone visible through `adb devices`
- phone authorized for USB debugging
- phone may start with display off and keyguard active
- local Flutter/Android toolchain
- valid `PROXY_SECRET`

Expected sequence:

1. Validate required commands and `PROXY_SECRET`.
2. Find exactly one connected physical Android phone, ignoring emulators.
3. Prepare the phone for automated locked-screen testing.
4. Build the debug APK with `PROXY_SECRET` as a dart define.
5. Verify the APK exists and is non-empty.
6. Re-prepare and re-check the phone before running `flutter test`.
7. Enable a namespaced automation setting for the debuggable Android activity
   and verify the setting readback before the test phase.
8. Auto-grant `android.permission.RECORD_AUDIO` to `com.wrait.flutter` for the
   whole `flutter test` session and continue granting it to
   `com.wrait.flutter.test` when the companion package is reinstalled so
   recording tests do not block on a system prompt.
9. Run `flutter test --no-pub -d <phone-serial> integration_test`.
10. Build the profile APK with the same `PROXY_SECRET` dart define.
11. Force-stop stale `com.wrait.flutter` work without uninstalling or clearing
    data.
12. Verify the phone remains connected before install.
13. Install the profile APK only after tests pass.
14. Verify `com.wrait.flutter` is installed.
15. Preserve `com.wrait.app` if it was present before deployment.
16. Restore the automation setting before the final launch verification so the
    installed app runs under ordinary non-automation conditions.
17. Re-prepare the phone before the final launch verification.
18. Launch `com.wrait.flutter/.MainActivity` once and verify successful launch
    output.

Failure behavior:

- Missing/invalid `PROXY_SECRET`: fail before build/test/install.
- No physical phone, multiple phones, unauthorized phone, or offline phone:
  fail before build/test/install with the existing phone-selection messages.
- Wake/connectivity failure: fail with a readiness-specific message.
- Keyguard dismissal refusal: continue when the phone is otherwise connected,
  because debug locked-screen activity support is responsible for ordinary
  locked-phone execution.
- Build failure, missing APK, zero-byte APK, test failure, install failure,
  package verification failure, or launch timeout: preserve existing failure
  behavior.
- If the automation setting cannot be written or read back correctly, fail with
  a readiness-specific error before the test phase.

## Data model changes

No persistent data model changes.

### Before

```text
deploy_debug.sh:
  - validates phone, PROXY_SECRET, build output, install, and launch
  - assumes the connected phone is ready enough for visible test execution

MainActivity:
  - standard FlutterActivity behavior for all build types
```

### After

```text
deploy_debug.sh:
  - validates phone, PROXY_SECRET, build output, install, and launch
  - actively prepares a connected physical phone for locked-screen testing
  - preserves existing no-uninstall/no-data-clear behavior

MainActivity:
  - release/profile behavior remains standard
  - debuggable processes can show/turn on over keyguard and keep the screen
    awake only while the namespaced automation setting is enabled
```

### Migration

No migration is required.

## Test strategy

### Automated tests

| Test case | Type | File |
| --- | --- | --- |
| Locked/screen-off preparation commands run before the real-device test phase and final launch | Shell unit/integration | `test/deploy_debug_script_test.sh` |
| Runtime `RECORD_AUDIO` grant is maintained through the Flutter test session so recording tests avoid a permission dialog across app-package reinstalls | Shell unit/integration | `test/deploy_debug_script_test.sh` |
| Locked-phone happy path still builds the debug test artifact, runs `flutter test --no-pub -d PHONE123 integration_test`, installs the profile final artifact only after tests pass, preserves `com.wrait.app`, and launches `com.wrait.flutter` | Shell unit/integration | `test/deploy_debug_script_test.sh` |
| Wake/readiness ADB failure exits non-success with a readiness-specific message and does not install | Shell unit/integration | `test/deploy_debug_script_test.sh` |
| Keyguard dismissal refusal does not fail the command when the device remains connected | Shell unit/integration | `test/deploy_debug_script_test.sh` |
| Cleanup restores temporary stay-awake and automation-setting state on success and failure paths | Shell unit/integration | `test/deploy_debug_script_test.sh` |
| Existing missing phone, unauthorized/offline phone, invalid secret, build output, test failure, disconnect-before-install, native-app preservation, and launch-timeout safeguards still pass | Regression shell tests | `test/deploy_debug_script_test.sh` |
| Debug automation-gated locked-screen activity code compiles as part of Android debug build | Build validation | `flutter build apk --debug --dart-define=PROXY_SECRET=...` |
| Final installed profile artifact compiles with the same runtime config | Build validation | `flutter build apk --profile --dart-define=PROXY_SECRET=...` |

### Android emulator verification

Exception requested. `./deploy_debug.sh` intentionally ignores Android
emulators and targets exactly one physical Android phone. Emulator runtime
verification would contradict the accepted US-027 deploy contract and the
US-029 scope.

Physical Android verification planned instead:

1. Connect and authorize one physical Android phone.
2. Lock the phone and switch the screen off.
3. Run `PROXY_SECRET=... ./deploy_debug.sh`.
4. Confirm the script prepares the phone without physical interaction, runs the
   real-device integration test phase, clears the recording permission prompt
   through the development channel, keeps the phone awake when needed,
   installs the final profile artifact only after tests pass, and verifies
   launch.
5. Confirm command output documents readiness preparation and any failure cause.

### iOS simulator verification

Exception requested. This feature changes only Android physical-device
deployment behavior in `deploy_debug.sh` and a debug-only Android activity
launch path. It has no iOS runtime surface.

### Validation exception request

Approval of this plan should also approve these validation exceptions:

- No new Flutter `integration_test` file is required for this story. The
  in-scope flow is a developer shell workflow, and it is better covered by
  deterministic shell tests plus a real locked-phone deploy run. The existing
  `integration_test` suite still runs unchanged inside `deploy_debug.sh`.
- Android emulator verification is not required because `deploy_debug.sh`
  intentionally ignores emulators and this story is physical-phone specific.
- iOS simulator verification is not required because the feature has no iOS
  code path or user-facing app behavior.

## Review and finalization

- `review.md` will be externally authored if review occurs.
- After reading `review.md`, no files may be changed until the remediation plan
  is explicitly approved.
- This feature is likely to require durable updates to `AGENTS.md` and
  `docs/agent-findings.md` after final approval because it changes the
  preferred Android real-device validation assumptions.
- `docs/application-description.md` is unlikely to need an update because this
  is a developer workflow change, not product behavior.

## Integration notes

- `deploy_debug.sh` remains the canonical real-device Android debug deployment
  command when backend registration, transcription, or proxy-authenticated
  traffic is relevant.
- The script must continue to pass `--dart-define=PROXY_SECRET=...` to both the
  debug test build and the final profile build.
- The script must not uninstall packages, clear package data, or mutate user
  diary content during readiness preparation.
- Automation-gated debug-only locked-screen and keep-awake behavior must not
  affect release or profile builds.

## Rollout & migration

The change is local to developer tooling and Android debug builds. No feature
flag, backend rollout, user-data migration, or app-store migration is required.

Existing development phones may need to remain authorized for USB debugging.
If a device policy prevents launching debug/test activities while locked until
credentials are entered by hand, the script should fail with a clear message
rather than looping or silently weakening validation.

## Risks & mitigations

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| Debug locked-screen or keep-awake behavior accidentally affects release/profile builds | Low | High | Gate Android activity flags on the app debuggable state plus an automation-specific Android setting, and validate via code review/build checks. |
| ADB readiness commands vary across Android versions | Medium | Medium | Use common `input keyevent KEYCODE_WAKEUP` plus best-effort keyguard dismissal, keep dismissal non-fatal, and rely on debug activity locked-screen support for secure keyguard cases. |
| Script hides real integration-test failures by over-handling device state | Low | High | Keep `flutter test` exit behavior unchanged and add shell tests that test failure still prevents install. |
| Readiness helper mutates user data | Low | High | Limit helper to wake/keyguard/connectivity commands; keep existing static test guard against uninstall and add assertions that no clear-data commands are introduced. |
| Final installed debug artifact still wedges on the validation phone | High | High | Treat the profile APK as the final deployed artifact while preserving debug/integration execution for the test phase. |
| Real locked-phone validation is hard to reproduce in fake shell tests | Medium | Medium | Combine deterministic fake `adb` tests with required physical Android validation where the phone starts locked and screen-off. |

## Open items from spec

None.
