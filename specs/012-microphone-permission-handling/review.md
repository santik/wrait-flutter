# Code Review: Microphone Permission Handling

> **Feature number:** 012
> **Reviewer:** Cascade
> **Date:** 2026-06-19

---

## Priority Legend

- **PO** - Product Owner: Critical user-facing or business logic issues
- **P1** - High: Significant technical issues that could cause bugs or crashes
- **P2** - Medium: Code quality, maintainability, or edge case issues
- **P3** - Low: Minor improvements or suggestions

---

## Findings

### PO - Missing iOS-specific permission handling

**Location:** `lib/data/audio/microphone_permission_service.dart`

**Issue:** The spec explicitly mentions iOS speech-recognition permission is out of scope for US-012, but the iOS Info.plist already contains speech-recognition usage descriptions. The current implementation only handles microphone permission via `permission_handler`. On iOS, when a user denies microphone permission, the system may not present the prompt again (treating it as effectively blocked), but the code treats `denied` as retryable. This could lead to a confusing UX where users see "mic needed · tap again" but tapping does nothing because iOS won't show the prompt again.

**Impact:** Users on iOS may get stuck in a retryable denial state that cannot actually be retried, violating the spec requirement that retryable denial should allow future prompts.

**Recommendation:** Consider platform-specific handling where iOS `denied` after the first prompt is treated as `microphoneBlocked` instead of `microphoneDenied`, or add platform detection to adjust the UX accordingly.

---

### P1 - Race condition in permission revocation during recording

**Location:** `lib/presentation/main/main_recording_controller.dart:140-159`

**Issue:** The `onAppResumed()` method checks permission state and cancels recording if permission is lost. However, there's a race condition: if the app is resumed while recording is active and permission is still granted, but permission is revoked immediately after the check but before the recording completes, the recording could continue without permission. The check happens at resume time, not continuously during recording.

**Impact:** Recording could continue after permission revocation if the timing is unlucky, potentially capturing audio without proper authorization.

**Recommendation:** Consider adding a periodic permission check during active recording, or listen to platform-specific permission change events if available. At minimum, document this limitation.

---

### P1 - No validation that settings actually opened

**Location:** `lib/presentation/main/main_recording_controller.dart:161-182`

**Issue:** The `openMicrophoneSettings()` method logs a warning if `openMicrophonePermissionSettings()` returns false, but it does not prevent the blocked state from being cleared or provide any user feedback. If settings fail to open, the user has no way to know and may be stuck.

**Impact:** Users may be unable to recover from blocked state if settings fail to open silently.

**Recommendation:** Consider showing a user-facing error or alternative recovery path when settings fail to open, or at minimum ensure the blocked state remains so the user can try again.

---

### P1 - Missing error handling in cancelLiveTranscription

**Location:** `lib/data/transcription/cloud_transcription_service.dart:110-124`

**Issue:** The `cancelLiveTranscription()` method catches no exceptions from `audioRecordingService.cancelRecording()`. If the audio service throws an exception during cancel, the state is set to idle but the recorder may still be active, leaving the system in an inconsistent state.

**Impact:** Recording could continue after cancellation attempt, or the service could be left in a bad state.

**Recommendation:** Wrap the `cancelRecording()` call in a try-catch and handle errors appropriately, potentially logging and ensuring state consistency.

---

### P2 - Inconsistent state management in cancelLiveTranscription

**Location:** `lib/data/transcription/cloud_transcription_service.dart:110-124`

**Issue:** The method sets `_state = _CloudTranscriptionState.idle` in the finally block even if the recording was never active (the early return case). This means calling cancel when nothing is recording still transitions through `stoppingLiveRecording` state unnecessarily.

**Impact:** Minor state inconsistency and potential confusion in debugging.

**Recommendation:** Restructure to only set state to `stoppingLiveRecording` when actually stopping, and avoid unnecessary state transitions for no-op cancels.

---

### P2 - No timeout on permission check during resume

**Location:** `lib/presentation/main/main_recording_controller.dart:140-159`

**Issue:** The `getMicrophoneAccess()` call in `onAppResumed()` has no timeout. If the permission check hangs (e.g., due to platform plugin issues), the entire resume handler could block indefinitely.

**Impact:** App could become unresponsive on resume if permission check hangs.

**Recommendation:** Add a timeout to the permission check or make it non-blocking with a fallback.

---

### P2 - Missing accessibility labels for permission states

**Location:** `lib/presentation/main/main_screen_status.dart:81-92`

**Issue:** The spec requires "Main-screen permission states expose meaningful assistive technology labels and actions." The current implementation adds the text "mic needed · tap again" and "mic blocked · tap settings" but does not add specific accessibility semantics beyond the generic status message handling in `main_screen.dart`.

**Impact:** Screen reader users may not get appropriate context about what the permission states mean or what actions are available.

**Recommendation:** Add specific accessibility labels and hints for the permission states, particularly for the settings action when blocked.

---

### P2 - No handling for restricted permission on Android

**Location:** `lib/data/audio/microphone_permission_service.dart:35-45`

**Issue:** The `_resolveState()` function maps `PermissionStatus.restricted` to `MicrophoneAccessState.restricted`, which is correct. However, the Android platform documentation indicates that `restricted` can occur in enterprise-managed devices or specific policy scenarios. The implementation treats this the same as `permanentlyDenied`, but there may be scenarios where restricted permissions can be changed by policy without user action.

**Impact:** Enterprise users or policy-managed devices may not get appropriate recovery guidance.

**Recommendation:** Consider whether `restricted` needs distinct handling or messaging from `permanentlyDenied`, or document that they are treated equivalently by design.

---

### P2 - Potential memory leak in lifecycle observer

**Location:** `lib/presentation/main/main_screen.dart:38-52`

**Issue:** The `MainScreen` adds itself as a `WidgetsBindingObserver` in `initState()` and removes it in `dispose()`. However, if the widget is rebuilt or the controller is disposed unexpectedly, the observer might not be properly cleaned up in all edge cases.

**Impact:** Potential memory leak or duplicate lifecycle callbacks in edge cases.

**Recommendation:** Ensure observer cleanup is robust, potentially using a more explicit lifecycle management pattern.

---

### P2 - No debouncing on resume permission check

**Location:** `lib/presentation/main/main_screen.dart:54-63`

**Issue:** The `didChangeAppLifecycleState()` method calls `onAppResumed()` every time the app resumes. If the app rapidly resumes multiple times (e.g., due to quick background/foreground switches), this could trigger multiple concurrent permission checks and state transitions.

**Impact:** Potential race conditions or unnecessary permission checks.

**Recommendation:** Add debouncing or a guard to prevent concurrent resume handlers.

---

### P3 - Magic string for status text

**Location:** `lib/presentation/main/main_screen_status.dart:84, 90`

**Issue:** The status texts "mic needed · tap again" and "mic blocked · tap settings" are hardcoded strings. While the spec specifies these exact strings, hardcoding them makes localization difficult in the future.

**Impact:** Future localization work will require finding and replacing these strings.

**Recommendation:** Consider using a constants file or localization keys even if not immediately needed, to prepare for future i18n work.

---

### P3 - Missing test for restricted permission state

**Location:** `integration_test/main_screen_permission_flow_test.dart`

**Issue:** The integration tests cover `denied`, `permanentlyDenied`, and `granted` states, but do not explicitly test the `restricted` permission state. While `restricted` is mapped to `microphoneBlocked` like `permanentlyDenied`, it's a distinct platform state that should be validated.

**Impact:** The `restricted` state path is not explicitly validated in integration tests.

**Recommendation:** Add an integration test case for the `restricted` permission state to ensure it behaves correctly.

---

### P3 - No validation of permission state after settings return

**Location:** `lib/presentation/main/main_recording_controller.dart:140-159`

**Issue:** The `onAppResumed()` method checks permission and clears blocked state if granted. However, it does not validate that the permission was actually granted via settings vs. some other mechanism. There's no way to distinguish between a user granting permission via settings vs. the permission state changing for other reasons.

**Impact:** Limited observability into how permission state changes occur.

**Recommendation:** Consider adding logging or metrics to track how permission state changes (though the spec says analytics are out of scope, internal logging could be useful for debugging).

---

### P3 - Incomplete error handling in record_audio_recording_service

**Location:** `lib/data/audio/record_audio_recording_service.dart:149-161`

**Issue:** The `cancelRecording()` method sets `_activeSession = null` before calling `_cancelRecorderBestEffort()`. If the cancel fails, the session is already cleared, making it impossible to retry cleanup.

**Impact:** If cancel fails, the partial audio file may not be cleaned up and the session state is lost.

**Recommendation:** Consider keeping the session state until cleanup is confirmed, or add retry logic for failed cancels.

---

### P3 - No distinction between user-initiated and system-initiated resume

**Location:** `lib/presentation/main/main_screen.dart:54-63`

**Issue:** The lifecycle observer treats all resume events the same. However, a resume from settings (user-initiated) vs. a resume from another app (system-initiated) might warrant different handling or logging.

**Impact:** Limited ability to distinguish different resume scenarios for debugging or UX purposes.

**Recommendation:** Consider tracking the reason for resume if the platform provides this information, or add logging to help debug resume scenarios.

---

### P3 - Potential for stale permission state in tests

**Location:** `integration_test/main_screen_permission_flow_test.dart:243-269`

**Issue:** The `_FakeMicrophonePermissionService` has a `nextRequestState` that updates `currentState` on request. However, if a test doesn't set `nextRequestState`, it defaults to `currentState`, which could lead to tests passing for the wrong reasons if the initial state isn't explicitly set.

**Impact:** Tests may not be as explicit as they should be about the permission state transitions.

**Recommendation:** Consider making the fake service more strict by requiring explicit state transitions or adding validation that unexpected state changes don't occur.

---

## Summary

The implementation is generally solid and follows the spec well. The main concerns are:

1. **PO**: iOS-specific permission behavior may not match the retryable denial assumption
2. **P1**: Several race conditions and error handling gaps that could lead to inconsistent state
3. **P2**: Accessibility and edge case handling that could improve user experience
4. **P3**: Minor code quality and test coverage improvements

The feature appears functionally complete for the happy path, but could benefit from more robust error handling and platform-specific considerations.
