# Implementation: Connected Device Tests With Screen Off

> **Feature number:** 029
> **Spec:** [`spec.md`](spec.md)
> **Plan:** [`plan.md`](plan.md)
> **Tasks:** [`tasks.md`](tasks.md)
> **Author:** Codex
> **Date:** 2026-06-18

---

## Summary

US-029 is implemented, with review-driven remediation applied.

The connected Android deploy flow now supports starting from a locked,
screen-off phone without requiring manual interaction during the test run.
`deploy_debug.sh` wakes the phone before device-dependent phases, attempts a
best-effort keyguard dismissal, temporarily enables an automation-gated
debug-only lock-screen launch path, keeps the phone awake while the automated
run is active, and restores the temporary automation/power settings before
exit.

Physical-device validation exposed two important realities during
implementation:

1. Recording-related integration tests could still hit the system microphone
   permission dialog after package reinstalls, which reintroduced phone
   interaction.
2. On the validation phone, the final standalone debug install could remain
   stuck on the Flutter splash screen even though the real-device debug test
   phase itself completed successfully.

The final implementation addresses the first issue with a bounded
runtime-permission watchdog during the Flutter test session. It addresses the
second issue by keeping the test phase on the debug/integration channel but
installing a profile APK as the final deployed artifact, because that artifact
launches correctly on the same physical phone.

## Code changes

### `deploy_debug.sh`

- Added reusable readiness helpers to:
  - re-check device readiness before critical phases
  - wake the phone with `input keyevent KEYCODE_WAKEUP`
  - attempt `wm dismiss-keyguard` without treating refusal as fatal
- Added temporary stay-awake handling:
  - cache the original `stay_on_while_plugged_in` value
  - enable `svc power stayon usb` during the run
  - restore the original value on exit
- Added automation-mode handling:
  - use the namespaced setting
    `com.wrait.flutter.debug.automation_lockscreen_mode`
  - read back the value after writes and fail clearly if it does not stick
  - restore the original value before final launch verification and on exit
- Reworked runtime microphone permission handling:
  - keep the one-shot pre-test grant attempt
  - run a bounded watchdog process for the full
    `flutter test --no-pub -d <phone> integration_test` session
  - continue granting to both `com.wrait.flutter` and
    `com.wrait.flutter.test` so test-session reinstalls do not reintroduce the
    audio prompt
  - clean up a stale watchdog PID file on startup
- Split artifact responsibilities:
  - build the debug APK for the Flutter integration-test phase
  - build the profile APK for the final installed app
  - install the profile APK only after tests pass
- Simplified final launch behavior:
  - removed the duplicate launch sequence
  - use one final installed-app launch verification
  - restore automation mode before that final verification
- Tightened launch verification:
  - use exact resumed/focused-line checks from `dumpsys`
  - accept `am start -W` timeout only when foreground verification confirms
    `com.wrait.flutter/.MainActivity`
- Preserved existing deploy invariants:
  - single physical phone selection
  - `PROXY_SECRET` validation
  - install only after tests pass
  - native `com.wrait.app` preservation
  - no uninstall or data-clear behavior

### `android/app/src/main/kotlin/com/wrait/flutter/MainActivity.kt`

- Added debuggable-build detection.
- Added automation-mode detection through the namespaced global setting.
- Enable show-over-lock-screen, turn-screen-on, and keep-screen-on behavior
  only when both conditions are true:
  - the app process is debuggable
  - automation mode is explicitly enabled
- Preserved the existing device-ID method-channel behavior unchanged.

### `test/deploy_debug_script_test.sh`

- Extended fake ADB coverage for:
  - wake commands
  - keyguard-dismiss success and refusal
  - global-setting readback
  - stay-awake restoration
  - runtime permission grants
  - `appops` allowance
  - launch-timeout foreground fallback
- Added success/failure cleanup assertions so temporary automation and
  stay-awake state restoration are tested explicitly.
- Added custom-initial-state coverage to verify restoration back to non-default
  device settings.
- Updated artifact expectations so the successful install path is
  `app-profile.apk`, while the test phase still builds `app-debug.apk`.
- Kept static assertions that the script never uninstalls apps or clears
  package data.

### `README.md`

- Documented locked, screen-off phone support.
- Documented the temporary automation/stay-awake behavior and what is restored
  versus what is not.
- Documented automatic microphone permission handling during the Flutter test
  phase.
- Documented the debug-for-tests/profile-for-final-install split and why it
  exists on the validation phone.

### SDD artifacts

- Updated [`spec.md`](spec.md) to state that the final deployed non-release
  artifact may differ from the debug test artifact when the validation phone
  requires that split.
- Updated [`plan.md`](plan.md) to cover:
  - the namespaced automation setting
  - bounded watchdog lifecycle and stale-PID cleanup
  - the debug-test/profile-final-install artifact split
  - cleanup and restoration coverage
- Updated [`tasks.md`](tasks.md) to reflect the reviewed implementation and
  latest validation evidence.

## Validation evidence

```text
2026-06-18

$ bash test/deploy_debug_script_test.sh
deploy_debug_script_test.sh: all tests passed

$ /opt/homebrew/bin/flutter build apk --debug --dart-define=PROXY_SECRET=test-proxy-secret
✓ Built build/app/outputs/flutter-apk/app-debug.apk

$ /opt/homebrew/bin/flutter build apk --profile --dart-define=PROXY_SECRET=test-proxy-secret
✓ Built build/app/outputs/flutter-apk/app-profile.apk

Build notes:
- Flutter emitted existing Kotlin Gradle Plugin compatibility warnings for:
  package_info_plus, share_plus, speech_to_text, wakelock_plus

Earlier physical-device evidence gathered during implementation:
- A pre-review `PROXY_SECRET=... ./deploy_debug.sh` run completed the locked
  debug test phase on phone `4A181FDJH0030G`, including the audio-recording
  flow after the watchdog fix.
- Subsequent investigation showed the final standalone debug install could
  remain on the Flutter splash screen on that same phone.
- Manual device validation then confirmed that:
  - the app UI existed behind the wedged standalone debug launch
  - manual install plus cold launch of `app-profile.apk` opened normally

Current validation gap:
- The fully reviewed script revision has not yet been rerun end-to-end on the
  physical phone from `./deploy_debug.sh` in an unsandboxed session.

Validation exceptions approved in planning:
- no new Flutter `integration_test` file
- no Android emulator verification
- no iOS simulator verification
```

## Implementation notes

- The one-shot `RECORD_AUDIO` grant was not enough because `flutter test
  integration_test` can reinstall packages during the suite.
- The bounded watchdog keeps permission re-grants alive for the duration that
  matters, without leaving an unbounded loop behind if the parent shell dies.
- The namespaced automation setting keeps the lock-screen override out of
  ordinary debug/profile use and gives the deploy script an explicit switch it
  can validate and restore.
- The profile final-install path is not a speculative optimization. It is a
  direct response to physical-device evidence that the standalone debug install
  was not reliably launchable after deployment on the validation phone.

## Review status

External review has been read, the approved remediation has been implemented,
and the artifacts have been updated accordingly. Long-lived documentation
follow-up has also been handled:

- updated `AGENTS.md`
- updated `docs/agent-findings.md`
- intentionally left `docs/application-description.md` unchanged because
  US-029 changes developer workflow, not product behavior

The remaining workflow gate is the final physical rerun of the updated script.
