# Code Review: Keep Screen On During Recording

> **Feature number:** 021
> **Review date:** 2026-06-24
> **Updated:** 2026-06-24
> **Reviewer:** Codex

---

## Summary

This review identifies architectural, implementation, and testing concerns in the US-021 keep-screen-on-during-recording implementation. The initial review found race conditions, state synchronization issues, and test coverage gaps. After code updates, most critical issues have been addressed through improved state tracking, error handling, and enhanced test coverage.

---

## PO - Critical Issues

### ~~PO-1: Race condition in coordinator disposal vs pending async operations~~ ✅ RESOLVED

**Location:** `lib/presentation/main/recording_display_awake_coordinator.dart:62-69`

**Issue:** The coordinator's `dispose()` method does not wait for pending `_operationQueue` operations before releasing keep-awake. If a `setAwake(true)` operation is in flight when `dispose()` is called, the coordinator will immediately call `setAwake(false)`, potentially creating a race where:

1. The platform receives `enable` after `disable` due to async timing
2. The internal `_lastRequestedAwake` state is set to `false` while the platform state may be `true`
3. No mechanism exists to recover from this desynchronization

**Resolution:** The coordinator now tracks `_desiredAwake` and `_appliedAwake` separately. The `dispose()` method sets `_desiredAwake = false` and calls `_queueSync()`, which properly queues the release operation after any pending operations complete. The `_appliedAwake` state is only updated after successful platform operations, preventing state desynchronization. Added test "dispose releases after an in-flight enable completes" validates this behavior.

---

### ~~PO-2: Unsafe lifecycle state assumption in coordinator initialization~~ ✅ RESOLVED

**Location:** `lib/presentation/main/main_screen.dart:51-52`

**Issue:** The coordinator is initialized with `WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed`. This assumes that if lifecycle state is null, the app is in a resumed state. However, the app could legitimately start in a backgrounded or paused state (e.g., if launched while device is locked). This would incorrectly enable keep-awake on startup when the app is not actually foregrounded.

**Resolution:** The default has been changed from `AppLifecycleState.resumed` to `AppLifecycleState.inactive`. This conservative default ensures that keep-awake is not enabled until the app explicitly transitions to a resumed state. Added test "startup while inactive does not enable keep-awake until resume" validates this behavior.

---

### ~~PO-3: State synchronization issue when platform operations fail~~ ✅ RESOLVED

**Location:** `lib/presentation/main/recording_display_awake_coordinator.dart:87-111`

**Issue:** The coordinator updates `_lastRequestedAwake` immediately before the async platform operation completes. If the platform operation fails (caught and logged in the service), the coordinator's internal state will be desynchronized from the actual platform state. Subsequent state changes will not retry the failed operation because the coordinator believes it already succeeded.

**Resolution:** The coordinator now tracks `_desiredAwake` and `_appliedAwake` separately. The `_appliedAwake` state is only updated after successful platform operations via `_setAwakeSafely()`, which returns a boolean indicating success. Failed operations do not update `_appliedAwake`, so the `_needsSync` getter will return true and subsequent state changes will retry the operation. The service now returns `Future<bool>` instead of `Future<void>` to indicate success/failure. Added test "retries a failed enable on a repeated listening update" validates this behavior.

---

## P1 - High Priority Issues

### ~~P1-1: No test coverage for rapid state transitions~~ ✅ RESOLVED

**Location:** `test/presentation/main/recording_display_awake_coordinator_test.dart:140-161`

**Issue:** The unit tests do not cover rapid state transitions that could expose race conditions in the operation queue. For example:
- Listening → background → foreground → listening in quick succession
- Multiple lifecycle changes before the first operation completes
- App-lock state changes interleaved with recording state changes

**Resolution:** Added test "coalesces rapid transitions to the final inactive state before any platform call starts" which uses `autoComplete: false` to simulate async delays and verifies that rapid state transitions are coalesced to the final state before any platform call is made.

---

### ~~P1-2: Test fake service is synchronous, hiding timing bugs~~ ✅ RESOLVED

**Location:** `test/test_doubles/fake_display_awake_service.dart`

**Issue:** The fake display awake service implementations are synchronous, which does not accurately simulate the real async behavior of `wakelock_plus`. This could hide timing-related bugs that would only manifest with real async platform calls.

**Resolution:** A shared `FakeDisplayAwakeService` has been extracted to `test/test_doubles/fake_display_awake_service.dart` with configurable async behavior via the `autoComplete` parameter. The service uses `Completer` objects to simulate async delays, and tests can manually complete pending operations via `completeNext()`. This allows tests to simulate realistic async timing and verify operation queue behavior.

---

### ~~P1-3: Missing test for coordinator initialization with null lifecycle state~~ ✅ RESOLVED

**Location:** `test/presentation/main/recording_display_awake_coordinator_test.dart:61-72`

**Issue:** No test verifies coordinator behavior when initialized with a null lifecycle state (which defaults to `resumed` in MainScreen). This is the unsafe assumption identified in PO-2.

**Resolution:** Added test "starts released when initialized outside the resumed lifecycle" which verifies that when initialized with `AppLifecycleState.inactive`, the coordinator does not enable keep-awake even if the recording state is `RecordingListening`. This validates the conservative default behavior.

---

### ~~P1-4: No integration test for error recovery~~ ✅ RESOLVED

**Location:** `test/presentation/main/main_screen_test.dart:609-646`

**Issue:** The integration tests only cover happy-path scenarios. There is no test for what happens when the display awake service throws an error during recording. The spec requires that failures be logged and not break recording, but this is not validated at the integration level.

**Resolution:** Added widget test "failed enable retries on later state changes without breaking UI" which uses `enqueueResult(false)` to simulate a failed enable operation. The test verifies that:
1. The failed enable is retried on subsequent state changes
2. The UI continues to function without exceptions
3. The final state is correctly applied after the retry succeeds

---

### P1-5: Coordinator has no mechanism to query actual platform state

**Location:** `lib/presentation/main/recording_display_awake_coordinator.dart`

**Issue:** The coordinator maintains its own `_appliedAwake` state but has no way to query the actual platform wakelock state. If the platform state changes externally (e.g., system power management overrides the app's request), the coordinator will never know and may make incorrect decisions.

**Impact:** Low-Medium - Could lead to redundant or incorrect platform calls if external factors change the wakelock state.

**Recommendation:** Consider adding a `isEnabled` query to the `WakelockClient` interface and periodically sync the coordinator's state, or document that external platform state changes are outside the app's control.

---

## P2 - Medium Priority Issues

### ~~P2-1: Duplicate fake service implementations across test files~~ ✅ RESOLVED

**Location:** `test/test_doubles/fake_display_awake_service.dart`

**Issue:** Three different test files implement their own `_FakeDisplayAwakeService` with identical logic. This creates maintenance burden and could lead to inconsistencies if one implementation is updated but not others.

**Resolution:** A shared `FakeDisplayAwakeService` has been extracted to `test/test_doubles/fake_display_awake_service.dart` and is now imported by all test files that need it. This eliminates duplication and ensures consistent behavior across all tests.

---

### ~~P2-2: No documentation of operation queue behavior~~ ✅ RESOLVED

**Location:** `lib/presentation/main/recording_display_awake_coordinator.dart:89-90`

**Issue:** The operation queue implementation is not documented. It's not clear why a queue is needed (presumably to serialize platform calls), what the ordering guarantees are, or how it handles failures.

**Resolution:** Added a comment above `_queueSync()` explaining that it serializes platform calls so the last desired state wins without overlapping wakelock toggles. The implementation now clearly shows that the queue uses `then()` to chain operations and that each operation checks `_needsSync` before executing.

---

### P2-3: Magic number in test delay

**Location:** `test/test_doubles/fake_display_awake_service.dart:45-48`

**Issue:** The `flush()` method in the fake service uses two `Duration.zero` delays, which appears to be a workaround for async test timing. This is not documented and may be fragile.

**Impact:** Low - Test implementation detail that may be brittle.

**Recommendation:** Document why two delays are needed, or use a more explicit synchronization mechanism (e.g., a Completer).

---

### P2-4: No validation that wakelock_plus is the best library choice

**Location:** `pubspec.yaml:53`, `lib/data/display/display_awake_service.dart`

**Issue:** The implementation uses `wakelock_plus: ^1.6.1` without justification in the spec or plan. There are other wakelock packages available (e.g., the original `wakelock` package, `screen_wake_lock`). The plan does not explain why `wakelock_plus` was chosen over alternatives.

**Impact:** Low - Library choice appears sound, but lack of justification makes it harder to evaluate if this is the best long-term choice.

**Recommendation:** Document in the plan why `wakelock_plus` was chosen (e.g., active maintenance, platform support, API design).

---

### P2-5: Coordinator update methods check disposed state

**Location:** `lib/presentation/main/recording_display_awake_coordinator.dart:29-60`

**Issue:** The coordinator's update methods do not validate that the provided states are valid (e.g., non-null recording state, valid lifecycle state). While the current callers (MainScreen) should provide valid states, defensive programming would make the coordinator more robust.

**Resolution:** The update methods now check `_isDisposed` and return early if disposed, preventing operations after disposal. Added test "updates are ignored after disposal" validates this behavior. However, input validation for null states is still not implemented.

---

## P3 - Low Priority Issues

### P3-1: No performance metrics for keep-awake operations

**Location:** `lib/data/display/display_awake_service.dart`

**Issue:** The spec requires that keep-awake state changes must not add noticeable delay, but there is no measurement or validation of this requirement. The implementation does not include any performance monitoring or benchmarking.

**Impact:** Low - Performance requirement exists but is not validated.

**Recommendation:** Consider adding performance benchmarks or at least manual validation notes in the implementation.md.

---

### P3-2: Integration test does not verify actual platform behavior

**Location:** `integration_test/main_screen_display_awake_flow_test.dart`

**Issue:** The integration test uses a fake display awake service, so it only validates the app's internal contract. It does not verify that the actual `wakelock_plus` plugin is called correctly on real devices. The validation exception acknowledges this, but it's worth noting as a limitation.

**Impact:** Low - Acknowledged in the validation exception, but still a gap in end-to-end validation.

**Recommendation:** Consider adding a manual verification step or a separate integration test that uses the real service on a physical device.

---

### ~~P3-3: No test for coordinator behavior after multiple disposals~~ ✅ RESOLVED

**Location:** `test/presentation/main/recording_display_awake_coordinator_test.dart:227-249`

**Issue:** While there is a test for double disposal, there is no test for calling update methods after disposal. The current implementation guards against this with `_isDisposed`, but this is not explicitly tested.

**Resolution:** Added test "updates are ignored after disposal" which verifies that calling `updateRecordingState()`, `updateLifecycleState()`, and `updateAppLockState()` after disposal are no-ops and do not trigger additional platform calls.

---

## Positive Observations (Not Issues)

The following aspects of the implementation are well-done and should be preserved:

- Clean separation of concerns with the service/coordinator pattern
- Proper use of dependency injection for testability
- Comprehensive unit test coverage for the coordinator's state machine
- Integration test that validates the end-to-end wiring
- Idempotency guards to prevent redundant platform calls
- Proper cleanup on disposal
- Alignment with the spec's requirement to not use `RecordingControllerState.isActive`

---

## Conclusion

The implementation has been significantly improved since the initial review. All three PO (critical) issues have been resolved through improved state tracking (`_desiredAwake` vs `_appliedAwake`), conservative lifecycle defaults, and proper error handling with retry logic. Most P1 (high priority) issues have also been addressed through enhanced test coverage including rapid transition tests, async simulation in the fake service, and error recovery tests.

**Remaining issues to consider:**

**P1-5:** Coordinator has no mechanism to query actual platform state - This remains a potential issue if external factors change the wakelock state, but is acceptable given the spec acknowledges manual device lock and system power policies may override keep-awake behavior.

**P2-3:** Magic number in test delay - The two `Duration.zero` delays in `flush()` should be documented or replaced with a more explicit synchronization mechanism.

**P2-4:** No validation that wakelock_plus is the best library choice - Consider documenting the rationale for choosing `wakelock_plus` over alternatives in the plan.

**P2-5:** Partially resolved - Disposed state checks are in place, but input validation for null states is still missing. This is acceptable given the current trusted callers.

**P3-1, P3-2:** Low priority issues around performance metrics and end-to-end platform validation - These are acknowledged limitations that are acceptable given the approved validation exception.

The implementation is now production-ready with robust state synchronization, comprehensive test coverage, and proper error handling. The remaining issues are minor and do not block merging.
