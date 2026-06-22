# Code Review: Error Handling and User Feedback (US-018)

> **Feature number:** 018
> **Review date:** 2026-06-22
> **Reviewer:** Codex

## Summary

This review identifies problems, potential issues, and improvement opportunities in the US-018 implementation. The implementation adds category-specific draft-preserved error copy and auto-clears blocked microphone errors, but has validation gaps, architectural concerns, and missing test coverage.

## Findings

### PO - Critical Issues

**PO-1: Missing Android emulator validation**
- **Location:** `specs/018-error-handling-user-feedback/implementation.md` lines 67-74
- **Issue:** The spec requires both Android emulator and iOS simulator verification, but Android emulator validation is blocked and not completed. The implementation states "Android emulator verification could not be completed in this implementation pass" with no explicit user-approved validation exception.
- **Impact:** The spec's validation requirements are not satisfied. Physical device testing does not substitute for emulator verification as specified in the plan.
- **Recommendation:** Either complete Android emulator validation or obtain explicit user approval for a validation exception before final approval.

### P1 - High Priority Issues

**P1-1: Over-engineered status line generation counter**
- **Location:** `lib/presentation/main/main_screen.dart` lines 36, 204, 264
- **Issue:** The `_statusLineGeneration` counter increments on EVERY state transition (line 264), not just error transitions. This causes unnecessary widget rebuilds and key changes for normal transitions like idle → listening → uploading. The implementation.md claims this prevents "rapid returns to the same visible status do not trigger duplicate-key failures," but the spec only requires this for error states.
- **Impact:** Unnecessary performance overhead and potential for subtle bugs if the generation counter overflows or causes unexpected widget key changes during normal flows.
- **Recommendation:** Only increment the generation counter when transitioning to or from error states, or use a more targeted approach that only affects error status transitions.

**P1-2: Missing integration test coverage for proxy-auth and generic API failures**
- **Location:** `integration_test/main_recording_controller_flow_test.dart`
- **Issue:** The integration tests cover network (`noInternet`) and backend (`backendUnavailable`) draft preservation, but do not test `proxyAuthFailed` or `apiFailed` with `preservedDraft=true`. The plan specifies coverage for all four categories.
- **Impact:** The user-facing copy for `server config error · saved as draft` and `saved as draft · will retry` is not validated at the integration level.
- **Recommendation:** Add integration test cases for proxy-auth failure and generic API failure with draft preservation to match the plan's test strategy.

**P1-3: Auto-clear timer race condition with rapid state changes**
- **Location:** `lib/presentation/main/main_recording_controller.dart` lines 529-536
- **Issue:** The `_scheduleAutoClear` method cancels the previous timer before scheduling a new one, but if a state transition occurs while the timer callback is executing, the callback may still fire and reset to idle even after the state has changed. The check `if (state.recordingState == targetState)` helps but doesn't prevent the timer from firing if the state changes between the check and the reset.
- **Impact:** In rare cases with very rapid state changes, the auto-clear timer could reset the controller to idle at an unexpected time, potentially interrupting a new recording or error state.
- **Recommendation:** Add a generation counter to the timer callback similar to the saved auto-clear pattern in `main_screen.dart`, or use a more robust timer management pattern that prevents stale callbacks from executing.

**P1-4: No test coverage for rapid error state transitions**
- **Location:** Test files
- **Issue:** No tests verify behavior when error states change rapidly (e.g., network error → user taps → new error before auto-clear). The existing tests only cover single error transitions and auto-clear timing.
- **Impact:** The implementation may have race conditions or unexpected behavior when users trigger multiple errors in quick succession that are not caught by tests.
- **Recommendation:** Add unit or integration tests that simulate rapid error state transitions to verify the controller handles them correctly.

### P2 - Medium Priority Issues

**P2-1: Incomplete error mapping coverage in transcription failure test**
- **Location:** `test/presentation/main/main_recording_controller_test.dart` lines 528-560
- **Issue:** The test `transcription failure mapping covers all supported outcomes` does not include `TranscriptionFailureReason.micBlocked` in the test cases, even though this is a valid reason that maps to `RecordingError.microphoneBlocked`.
- **Impact:** The mapping for micBlocked transcription failures is not explicitly tested, leaving a gap in coverage.
- **Recommendation:** Add `TranscriptionFailureReason.micBlocked` to the test cases to ensure complete coverage.

**P2-2: Missing accessibility test coverage for draft-preserved errors**
- **Location:** `test/presentation/main/main_screen_status_test.dart`
- **Issue:** The tests verify accessibility copy for microphone denied and blocked states, but do not verify that draft-preserved error states (network, backend, proxy-auth, API) have appropriate accessibility labels and hints.
- **Impact:** Screen reader users may not receive appropriate feedback for draft-preserved errors, violating the spec's accessibility requirement.
- **Recommendation:** Add accessibility assertions for draft-preserved error states to ensure they have proper semantics labels and hints.

**P2-3: No validation of shake animation for draft-preserved errors**
- **Location:** Test files
- **Issue:** The spec requires that "No other error category triggers the shake feedback" besides too-short and no-match, but there are no explicit tests verifying that draft-preserved errors (network, backend, proxy-auth, API) do NOT trigger shake.
- **Impact:** A future change could accidentally add shake to these errors without violating existing tests.
- **Recommendation:** Add explicit negative tests that verify draft-preserved errors do not increment the shake key.

**P2-4: Hardcoded fallback language in audio draft persistence**
- **Location:** `lib/presentation/main/main_recording_controller.dart` line 418
- **Issue:** The `_persistAudioDraftIfNeeded` method uses `cleanupTranscriptFallbackLanguage` when saving audio drafts, but this constant is not defined in the visible code and its source is unclear.
- **Impact:** If the fallback language is incorrect or changes, audio drafts may be saved with the wrong language metadata, affecting future transcription attempts.
- **Recommendation:** Ensure the fallback language is well-documented, sourced from a reliable configuration, and tested.

**P2-5: No test for audio draft persistence failure handling**
- **Location:** `lib/presentation/main/main_recording_controller.dart` lines 421-428
- **Issue:** When audio draft persistence fails, the method logs a warning and returns `false`, but there are no tests verifying this behavior or that the error state is still set correctly with `preservedDraft=false`.
- **Impact:** If draft persistence fails silently, the user may see "saved as draft" when no draft was actually saved, violating the spec's requirement that draft preservation copy must be accurate.
- **Recommendation:** Add a test that simulates audio draft persistence failure and verifies that the error state shows the fallback copy without "saved as draft".

### P3 - Low Priority Issues

**P3-1: Magic number in minimum recording duration**
- **Location:** `lib/presentation/main/main_recording_controller.dart` line 267
- **Issue:** The code references `minimumRecordingDuration` which appears to be a constant but is not defined in the visible file. Its source and value are unclear.
- **Impact:** Makes the code harder to understand and maintain; the value may be inconsistent across the codebase.
- **Recommendation:** Define this constant in a clear location with documentation, or import it from a well-defined constants file.

**P3-2: Inconsistent error message format**
- **Location:** `lib/presentation/main/main_screen_status.dart` lines 75-102
- **Issue:** The draft-preserved error messages use the format `[error] · saved as draft` except for `apiFailed` which uses `saved as draft · will retry`. This inconsistency is intentional per the spec but could confuse users or future developers.
- **Impact:** May cause confusion about the pattern for error messages; makes the code less predictable.
- **Recommendation:** Document this exception clearly in comments or consider standardizing the format if user testing shows it causes confusion.

**P3-3: No test for cleanupTranscriptFallbackLanguage usage**
- **Location:** Test files
- **Issue:** The `cleanupTranscriptFallbackLanguage` is used in audio draft persistence but there are no tests verifying its value or that it's used correctly.
- **Impact:** If the fallback language is incorrect, it could cause issues in draft transcription that are not caught by tests.
- **Recommendation:** Add tests that verify the fallback language is correctly applied when saving audio drafts.

**P3-4: Potential for integer overflow in shake key**
- **Location:** `lib/presentation/main/main_recording_controller.dart` lines 513-516
- **Issue:** The `shakeErrorKey` increments without bound. In theory, after billions of shake errors, it could overflow (though this is extremely unlikely in practice).
- **Impact:** Negligible in practice, but represents a theoretical robustness issue.
- **Recommendation:** Consider using a modulo operation or reset mechanism if shake errors could occur millions of times, or document why this is not a concern.

**P3-5: Missing documentation for RecordingFeedbackDelays defaults**
- **Location:** `lib/presentation/main/main_recording_controller.dart` lines 25-33
- **Issue:** The `RecordingFeedbackDelays` class has default values but no documentation explaining why these specific durations were chosen or what they represent in the UX.
- **Impact:** Makes it harder for future developers to understand the timing decisions or adjust them appropriately.
- **Recommendation:** Add documentation explaining the rationale for the default delay values and their UX significance.

## Architectural Concerns

**A-1: Status resolver switch statement complexity**
- **Location:** `lib/presentation/main/main_screen_status.dart` lines 39-149
- **Issue:** The `resolveMainScreenStatus` function uses a large switch statement with multiple pattern matches. Adding more error categories or states will make this increasingly complex and harder to maintain.
- **Impact:** The function will become more error-prone as the codebase grows; pattern matching errors could introduce bugs.
- **Recommendation:** Consider refactoring to a more modular approach, such as separate resolver functions for different state categories or a strategy pattern for error state resolution.

**A-2: Timer management scattered across multiple classes**
- **Location:** `lib/presentation/main/main_recording_controller.dart` and `lib/presentation/main/main_screen.dart`
- **Issue:** Auto-clear timer logic exists in both the controller (for errors) and the main screen (for saved state). The patterns are similar but not identical, making maintenance harder.
- **Impact:** Inconsistent timer management behavior; bugs in one may not be reflected in the other; harder to add new timer-based behaviors.
- **Recommendation:** Consider extracting a reusable timer management utility or mixin that handles generation-aware timer scheduling and cancellation.

## Missing Test Coverage

**T-1: No integration test for proxy-auth draft preservation**
- **Location:** `integration_test/main_recording_controller_flow_test.dart`
- **Issue:** Missing test case for `proxyAuthFailed` with `preservedDraft=true` to verify "server config error · saved as draft" copy.
- **Recommendation:** Add test case similar to the network and backend draft preservation tests.

**T-2: No integration test for generic API draft preservation**
- **Location:** `integration_test/main_recording_controller_flow_test.dart`
- **Issue:** Missing test case for `apiFailed` with `preservedDraft=true` to verify "saved as draft · will retry" copy.
- **Recommendation:** Add test case for API failure with draft preservation.

**T-3: No test for settings action accessibility after auto-clear**
- **Location:** `integration_test/main_screen_flow_test.dart`
- **Issue:** The test verifies blocked microphone auto-clear and re-showing, but does not verify that the settings action remains accessible after the message re-appears.
- **Recommendation:** Add accessibility verification for the settings action in the re-entry test.

**T-4: No test for concurrent error state transitions**
- **Location:** Test files
- **Issue:** No tests simulate scenarios where an error state transitions to another error state before auto-clear (e.g., network error → user taps → backend error).
- **Recommendation:** Add tests for rapid error-to-error transitions to verify timer cancellation and state management.

## Library and Implementation Suggestions

**L-1: Consider using a dedicated state machine library**
- **Issue:** The recording state management uses manual switch statements and pattern matching. As states and transitions become more complex, this approach becomes error-prone.
- **Recommendation:** Consider using a state machine library (e.g., `flutter_state_machine` or similar) to formalize state transitions and make them more testable and maintainable.

**L-2: Consider extracting error message constants**
- **Location:** `lib/presentation/main/main_screen_status.dart`
- **Issue:** Error messages are hardcoded strings in the switch statement. This makes localization difficult and increases the risk of typos.
- **Recommendation:** Extract error messages to a constants file or a localization system to support future internationalization and reduce duplication.

**L-3: Consider using a more robust timer abstraction**
- **Location:** Timer usage across multiple files
- **Issue:** Direct use of `dart:async` Timer makes testing timing-dependent behavior harder and less reliable.
- **Recommendation:** Consider using a timer abstraction that can be controlled in tests (e.g., a fake clock or timer provider) to make timing tests more deterministic.

## Conclusion

The US-018 implementation satisfies the core functional requirements but has significant validation gaps (PO-1), architectural concerns (A-1, A-2), and missing test coverage (T-1, T-2, T-3, T-4). The most critical issue is the missing Android emulator validation, which must be resolved before final approval. The over-engineered status line generation counter (P1-1) and missing integration test coverage (P1-2) should also be addressed to ensure robustness and completeness.
