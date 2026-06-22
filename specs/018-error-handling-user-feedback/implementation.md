# Implementation: Error Handling and User Feedback

> **Feature number:** 018
> **Spec:** [`spec.md`](spec.md)
> **Plan:** [`plan.md`](plan.md)
> **Tasks:** [`tasks.md`](tasks.md)
> **Author:** Codex
> **Date:** 2026-06-22

---

## Summary

US-018 is implemented in the Flutter app with the smallest approved behavior
changes:

- preserved-draft errors now show category-specific copy instead of the generic
  `saved as draft`
- blocked microphone errors now auto-clear on the same timer as other error
  feedback
- the current no-draft fallback copy remains unchanged
- the retryable microphone-denied copy remains unchanged
- the status-line `AnimatedSwitcher` now uses a generation-aware key so rapid
  returns to the same visible status do not trigger duplicate-key failures

The approved review remediation pass also tightened the implementation by:

- narrowing the status-line key workaround so it only rotates keys on
  transitions into or out of error states
- adding preserved-draft integration coverage for proxy-auth and generic API
  failures
- adding controller coverage for blocked microphone mapping, draft-persistence
  fallback, non-shake preserved-draft errors, and rapid error-to-error
  transitions

## Changed files

| File | Change |
| --- | --- |
| `lib/presentation/main/main_screen_status.dart` | Added approved preserved-draft copy mapping for network, backend unavailable, proxy-auth, and generic API failures while preserving existing fallback copy and permission copy. |
| `lib/presentation/main/main_recording_controller.dart` | Removed the blocked-microphone special case so all error states schedule auto-clear. |
| `lib/presentation/main/main_screen.dart` | Added a status-line generation counter to keep `AnimatedSwitcher` child keys unique across rapid transitions. |
| `test/presentation/main/main_screen_status_test.dart` | Added preserved-draft copy coverage and explicit no-draft fallback coverage. |
| `test/presentation/main/main_recording_controller_test.dart` | Added blocked-microphone auto-clear coverage and kept blocked-permission behavior tests stable with longer test delays where needed. |
| `integration_test/main_recording_controller_flow_test.dart` | Added user-facing preserved-draft status assertions for network and backend draft flows. |
| `integration_test/main_screen_flow_test.dart` | Added main-screen coverage for draft-preserved feedback, auto-clear, and blocked-microphone re-entry after auto-clear. |

## Validation

### Automated

```text
flutter test test/presentation/main/main_screen_status_test.dart test/presentation/main/main_recording_controller_test.dart test/presentation/main/button_area_test.dart
Result: passed

flutter test integration_test/main_recording_controller_flow_test.dart integration_test/main_screen_flow_test.dart integration_test/main_screen_permission_flow_test.dart
Result: passed on Android physical device Pixel 8 (4A181FDJH0030G)

flutter analyze
Result: No issues found.
```

### Runtime verification

```text
flutter test -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/main_screen_flow_test.dart
Result: passed on iPhone 17 simulator (iOS 26.5)

flutter test -d emulator-5554 integration_test/main_screen_flow_test.dart
Result: passed on sdk gphone16k arm64 emulator (Android 17 / API 37)
```

Observed iOS runtime behaviors from the validated flow:

- draft-preserved network feedback shows `no connection · saved as draft`
  and returns to idle
- blocked microphone feedback shows `mic blocked · tap settings`, auto-clears,
  and can be shown again by tapping

Observed Android emulator runtime behaviors from the validated flow:

- draft-preserved network feedback shows `no connection · saved as draft`
  and returns to idle
- blocked microphone feedback shows `mic blocked · tap settings`, auto-clears,
  and can be shown again by tapping

Android emulator note:

- `flutter emulators --launch Pixel_8_emulator` was not sufficient by itself
  in this environment
- direct launch through
  `~/Library/Android/sdk/emulator/emulator -avd Pixel_8_emulator -no-window -no-audio -no-snapshot-save -gpu swiftshader_indirect`
  successfully brought up `emulator-5554`, which then passed the focused
  runtime validation

## Notes

- The implementation intentionally does not add new offline, mode-specific,
  language-settings, or snackbar-driven product scope.
- The iOS simulator was not initially booted, but became available through
  `flutter emulators --launch apple_ios_simulator` and then passed the focused
  main-screen runtime validation.
- The external `review.md` remediation items accepted for US-018 were
  implemented in this pass.
