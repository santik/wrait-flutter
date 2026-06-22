# Code Review: Draft Retry System

> **Feature number:** 015
> **Review date:** 2026-06-20
> **Reviewer:** Codex

## Summary

This review identifies problems and potential issues in the US-015 draft retry system implementation. The implementation adds launch-only background retry for failed recordings, but has several critical and high-priority issues that should be addressed.

---

## P0 - Critical Issues

### P0-1: Missing Android emulator verification

**Location:** `specs/015-draft-retry-system/implementation.md` lines 110-117

**Issue:** The implementation.md states that Android emulator verification could not be completed because no Android target became available. The approved plan explicitly required Android emulator verification, and no validation exception was approved by the user.

**Impact:** This is a blocking issue per the project's spec-driven workflow. The feature cannot be considered complete without the required platform verification.

**Recommendation:** Complete Android emulator verification before proceeding with final approval, or obtain explicit user approval for a validation exception documenting why Android verification cannot be performed.

---

## P1 - High Priority Issues

### P1-1: Single-flight guard race condition

**Location:** `lib/domain/usecase/app_launch_work_use_case.dart` lines 18-34, `lib/domain/usecase/retry_pending_drafts_use_case.dart` lines 28-44

**Issue:** The single-flight guard implementation has a race condition:

```dart
final inFlight = _inFlight;
if (inFlight != null) {
  return inFlight;
}
final future = _run();
_inFlight = future;
```

If two calls enter this block concurrently between the null check and setting `_inFlight`, both will proceed and execute `_run()` twice. The `identical` check in `whenComplete` prevents clearing the wrong future, but doesn't prevent the duplicate execution.

**Impact:** Duplicate registration or retry operations could run concurrently, leading to duplicate backend calls, race conditions in database updates, or inconsistent state.

**Recommendation:** Use a proper synchronization primitive such as:
- A `Completer`-based mutex pattern
- `package:async`'s `AsyncLock` or `Mutex`
- An atomic flag with proper synchronization

### P1-2: Insufficient audio file validation

**Location:** `lib/data/launch/app_launch_providers.dart` lines 37-64

**Issue:** The `validateDraftAudioPathProvider` only checks:
- File exists
- File can be opened for reading
- File length > 0

It does not validate that the file contains valid audio data. A corrupted file, wrong file type, or truncated audio file would pass validation but fail during transcription.

**Impact:** Invalid audio files will be sent to the transcription service, wasting quota, causing unnecessary network calls, and failing retry. The draft will be preserved for future launches, repeating the failure on every app start.

**Recommendation:** Add basic audio format validation:
- Check file extension against expected audio formats (.m4a, .wav, etc.)
- Optionally add lightweight header validation for common formats
- Consider adding a "validation failed" state that marks drafts as permanently failed after N attempts

### P1-3: No cancellation mechanism for retry operations

**Location:** `lib/domain/usecase/retry_pending_drafts_use_case.dart`

**Issue:** The retry process has no cancellation mechanism. If the app is backgrounded, killed, or the user navigates away during a long-running retry operation, there's no way to cancel it gracefully.

**Impact:** Long-running retry operations could continue in the background after app termination, potentially wasting resources, quota, or leaving the system in an inconsistent state if operations complete after the app is gone.

**Recommendation:** Add cancellation support:
- Accept a `CancellationToken` or `AbortSignal` parameter
- Check cancellation status between draft retries
- Propagate cancellation to transcription and cleanup operations
- Ensure cleanup happens on cancellation

### P1-4: Missing exception handling for TranscriptionServiceFailure

**Location:** `lib/domain/usecase/retry_pending_drafts_use_case.dart` lines 110-128

**Issue:** The code assumes `transcriptionService.transcribeAudioDraft` only returns `TranscriptionResult`. However, the `TranscriptionService` interface shows it can throw `TranscriptionServiceFailure` exceptions (e.g., `TranscriptionAlreadyInProgressFailure`, `NoActiveLiveTranscriptionFailure`). These are not caught in `_retryAudioDraft`.

**Impact:** Unhandled exceptions will crash the retry process, preventing subsequent drafts from being retried. The error will be caught at the per-draft level, but the specific failure type is lost, making debugging harder.

**Recommendation:** Wrap the transcription call in a try-catch that handles `TranscriptionServiceFailure` explicitly, converting it to an appropriate log message and treating it as a retry failure.

### P1-5: No retry limit for individual drafts

**Location:** `lib/domain/usecase/retry_pending_drafts_use_case.dart`

**Issue:** A draft that consistently fails (e.g., corrupted audio file that passes validation, or a backend that consistently rejects it) will be retried on every app launch indefinitely. There's no maximum retry count or "permanently failed" state.

**Impact:** Permanently failing drafts will waste resources on every launch, clutter logs with repeated failures, and prevent the retry system from making progress on newer drafts.

**Recommendation:** Add a retry counter to the entry model or a separate tracking table:
- Increment retry count on each attempt
- Skip drafts that exceed a threshold (e.g., 5 retries)
- Add a "permanently failed" state that excludes drafts from retry
- Consider adding a user-visible indicator for permanently failed drafts

### P1-6: File handle leak potential in validation

**Location:** `lib/data/launch/app_launch_providers.dart` lines 46-52

**Issue:** The file validation opens a handle with `file.open(mode: FileMode.read)` and closes it, but if an exception occurs between open and close (e.g., from `file.exists()` or another operation), the handle might not be closed properly.

**Impact:** File handle leaks could accumulate over time, especially if validation is called frequently during development or testing with many drafts.

**Recommendation:** Use a try-finally block or Dart's `use` pattern (if available) to ensure the handle is always closed:

```dart
final handle = await file.open(mode: FileMode.read);
try {
  // validation logic
} finally {
  await handle.close();
}
```

### P1-7: Hardcoded stale draft age

**Location:** `lib/domain/usecase/retry_pending_drafts_use_case.dart` line 48

**Issue:** The 7-day stale draft age is hardcoded in the call to `entryRepository.deleteStaleDrafts()`. This magic number appears in multiple places (repository interface default, implementation) without a single source of truth.

**Impact:** Inconsistent behavior if the value is changed in one place but not another. Difficult to tune the retention policy without code changes.

**Recommendation:** Extract to a named constant or configuration value:
```dart
static const Duration staleDraftRetention = Duration(days: 7);
```

### P1-8: Potential memory leak in single-flight guard

**Location:** `lib/domain/usecase/app_launch_work_use_case.dart` lines 18-34, `lib/domain/usecase/retry_pending_drafts_use_case.dart` lines 28-44

**Issue:** If a future never completes (hangs indefinitely due to a deadlock, network issue, or bug), the `_inFlight` field will never be cleared. This prevents any future retry attempts for the lifetime of the use case instance.

**Impact:** A single hung operation would permanently disable retry functionality for the app session, requiring a full app restart to recover.

**Recommendation:** Add a timeout mechanism:
- Use `Future.timeout()` on the operation
- Clear `_inFlight` on timeout
- Log a warning when timeout occurs
- Consider making the timeout configurable

---

## P2 - Medium Priority Issues

### P2-1: Inconsistent error handling patterns

**Location:** `lib/domain/usecase/retry_pending_drafts_use_case.dart`

**Issue:** Error handling is inconsistent across the code:
- `_run()` has try-catch around stale deletion and draft loading
- `_retryAudioDraft()` has no try-catch around transcription
- `_retryTextDraft()` has no try-catch around cleanup
- Per-draft loop has try-catch around each draft

**Impact:** Different failure modes are handled differently, making the code harder to reason about and test. Some exceptions might propagate unexpectedly.

**Recommendation:** Standardize error handling:
- Either wrap all external calls in try-catch at the appropriate level
- Or document which exceptions are expected to be caught where
- Ensure consistent logging for all failure paths

### P2-2: Missing draft state validation

**Location:** `lib/domain/usecase/retry_pending_drafts_use_case.dart` lines 93-96

**Issue:** The `_isAudioDraft()` check only looks at `audioPath` being non-null and non-empty. It doesn't validate the overall consistency of the draft state. For example:
- An entry with `audioPath=null` but `rawTranscript=""` would be treated as a text draft
- An entry with `audioPath` set but `isDraft=false` would still be processed

**Impact:** Malformed or inconsistent draft states could be processed incorrectly, leading to unexpected behavior or data corruption.

**Recommendation:** Add comprehensive state validation:
- Validate that audio drafts have `isDraft=true`
- Validate that text drafts have non-empty `rawTranscript`
- Log warnings for inconsistent states
- Consider deleting or skipping inconsistent drafts

### P2-3: No deduplication of in-progress retry attempts

**Location:** `lib/domain/usecase/retry_pending_drafts_use_case.dart`

**Issue:** If the retry process is interrupted (e.g., app killed) and restarted on the next launch, there's no mechanism to detect that a draft was already being processed. The draft could be partially updated (e.g., transcription succeeded but cleanup didn't run) and re-processing could cause issues.

**Impact:** Duplicate processing could lead to:
- Duplicate transcription calls
- Inconsistent state updates
- Lost data if cleanup overwrites a partial result

**Recommendation:** Add an "in-progress" flag or timestamp to track retry state:
- Set a `retryInProgressAt` timestamp when starting retry
- Clear it when retry completes (success or failure)
- Skip drafts with recent `retryInProgressAt` on startup
- Add a cleanup mechanism to stale `retryInProgressAt` flags

### P2-4: Language update not atomic with state transition

**Location:** `lib/domain/usecase/retry_pending_drafts_use_case.dart` lines 131-165

**Issue:** When an audio draft is successfully transcribed with a different detected language, the language is updated via the cleanup use case. However, if cleanup fails after updating the language but before finalizing or promoting to text draft, the entry could be left in an inconsistent state (language updated but still an audio draft).

**Impact:** Inconsistent state where the stored language doesn't match the actual state of the draft, potentially causing issues in future retries or UI display.

**Recommendation:** Ensure atomic state transitions:
- Either update language and state in a single transaction
- Or validate and correct inconsistent states before retry
- Add a validation step that checks for and repairs inconsistent states

### P2-5: No observability beyond logging

**Location:** Throughout the implementation

**Issue:** The only observability is developer logging. There's no metrics collection for:
- Retry success/failure rates
- Failure reason distribution
- Retry operation duration
- Draft age distribution
- Per-draft retry counts

**Impact:** Difficult to monitor the health of the retry system in production, detect regressions, or make data-driven decisions about retry policies.

**Recommendation:** Add metrics collection:
- Use a metrics library (e.g., `package:metrics` or custom)
- Track key metrics for each retry operation
- Expose metrics for monitoring and alerting
- Consider adding crash reporting integration for retry failures

### P2-6: Provider recreation potential

**Location:** `lib/data/launch/app_launch_providers.dart` lines 82-102

**Issue:** Using `ref.watch()` in provider constructors (`appLaunchWorkUseCaseProvider` and `retryPendingDraftsUseCaseProvider`) can cause providers to be recreated when watched dependencies change. This could lead to multiple use case instances being created during the app lifecycle, potentially with different single-flight guard states.

**Impact:** Multiple use case instances could lead to:
- Conflicting single-flight guards
- Lost in-flight state
- Duplicate operations

**Recommendation:** Use `ref.read()` for dependencies that should not trigger recreation, or document the expected lifecycle behavior clearly.

### P2-7: Test coverage gaps for edge cases

**Location:** Test files

**Issue:** The tests don't cover several edge cases:
- What happens when the app is killed mid-retry
- Database corruption scenarios
- File system full errors
- Very large numbers of pending drafts
- Concurrent retry attempts (testing the single-flight guard)
- Transcription service throwing unexpected exceptions

**Impact:** These edge cases could cause production failures that aren't caught by tests.

**Recommendation:** Add test coverage for:
- Interruption scenarios (simulate app termination)
- Error injection for database and file operations
- Performance tests with large draft counts
- Concurrency tests for the single-flight guard
- Exception handling for all service layer exceptions

### P2-8: No validation of transcription result data

**Location:** `lib/domain/usecase/retry_pending_drafts_use_case.dart` lines 114-121

**Issue:** The code doesn't validate that `TranscriptionSuccess.transcript` is non-empty or that `detectedLanguage` is a valid language code before passing it to cleanup.

**Impact:** Empty or invalid transcription results could be passed to cleanup, potentially causing downstream errors or creating invalid entries.

**Recommendation:** Add validation:
- Check that transcript is non-empty
- Validate language code format if possible
- Log warnings for invalid results
- Treat invalid results as transcription failures

---

## P3 - Low Priority Issues

### P3-1: Incomplete documentation of retry behavior

**Location:** `lib/domain/usecase/retry_pending_drafts_use_case.dart`

**Issue:** The use case lacks detailed documentation explaining:
- The exact retry semantics
- What constitutes a retryable vs non-retryable failure
- The state machine for draft transitions
- The single-flight guard behavior

**Impact:** Future maintainers may misunderstand the retry logic, leading to bugs or incorrect modifications.

**Recommendation:** Add comprehensive doc comments explaining the retry behavior, state transitions, and invariants.

### P3-2: Magic numbers in tests

**Location:** `test/domain/usecase/retry_pending_drafts_use_case_test.dart`

**Issue:** Tests use magic numbers for timestamps (e.g., `DateTime.utc(2026, 6, 19)`) without named constants or helper functions.

**Impact:** Tests are harder to read and maintain. Time-based calculations are error-prone.

**Recommendation:** Extract test time constants and helper functions for clearer, more maintainable tests.

### P3-3: No integration test for retry interruption

**Location:** Integration test files

**Issue:** No integration test verifies what happens when retry is interrupted (e.g., app backgrounded/killed during retry).

**Impact:** The interruption behavior is untested at the integration level, relying only on unit tests.

**Recommendation:** Add an integration test that simulates app termination during retry and verifies state on next launch.

---

## Summary Statistics

- **P0 (Critical):** 1 issue
- **P1 (High):** 8 issues
- **P2 (Medium):** 8 issues
- **P3 (Low):** 3 issues

**Total:** 20 issues identified
