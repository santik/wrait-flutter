# Code Review: Transcript Cleanup Use Case

> **Feature number:** 009
> **Reviewer:** Cascade
> **Date:** 2026-06-12
> **Branch:** codex/feat-transcript-cleanup-use-case-us-008

---

## Summary

This review identifies architectural, implementation, and testing issues in the transcript cleanup use case implementation. The implementation follows the spec and plan but has several critical gaps in error handling, state management, and test coverage that could lead to data loss, inconsistent state, or runtime crashes.

---

## Findings

### PO - Critical Issues

#### PO-1: Missing error handling for repository operations
**Location:** `lib/domain/usecase/cleanup_transcript_use_case.dart` lines 109, 112-120, 176-180

**Issue:** The use case calls repository methods (`saveDraft`, `updateDraftTranscript`, `updateEntryLanguage`, `updateWithCleanedText`) without any try-catch blocks. If these operations fail due to database errors, I/O errors, or constraint violations, the entire use case will crash with an unhandled exception rather than returning a `CleanupTranscriptFailure`.

**Impact:** Users could experience app crashes instead of graceful failure handling. Transcripts could be lost if draft persistence fails mid-flow.

**Evidence:**
```dart
// Line 109 - No error handling
return entryRepository.saveDraft(rawTranscript, language);

// Lines 112-120 - No error handling
await entryRepository.updateDraftTranscript(
  entryId,
  rawTranscript,
  _countWords(rawTranscript),
);

if (existingEntry != null && existingEntry.language != language) {
  await entryRepository.updateEntryLanguage(entryId, language);
}

// Lines 176-180 - No error handling
await entryRepository.updateWithCleanedText(
  entryId,
  cleanedText,
  _countWords(cleanedText),
);
```

**Recommendation:** Wrap all repository operations in try-catch blocks and return `CleanupTranscriptFailure` with an appropriate `BackendFailureReason` (e.g., `apiError`) on failure. Log the actual error for debugging.

---

#### PO-2: StateError thrown instead of returning failure result
**Location:** `lib/domain/usecase/cleanup_transcript_use_case.dart` lines 84-88

**Issue:** When an entry is not found or is not a draft, the use case throws `StateError`. This is harsh and inconsistent with the use case's contract of returning typed success/failure results. Callers cannot catch this gracefully without knowing it's a special exception.

**Impact:** App crashes if a caller passes an invalid or already-finalized entry ID. This violates the principle that use cases should return typed results, not throw exceptions for expected failure modes.

**Evidence:**
```dart
final entry = await entryRepository.getEntryById(entryId);
if (entry == null) {
  throw StateError('Entry with id $entryId not found or already deleted');
}
if (!entry.isDraft) {
  throw StateError('Entry with id $entryId is not a draft');
}
```

**Recommendation:** Return `CleanupTranscriptFailure` with a specific `BackendFailureReason` (e.g., add a new `invalidEntry` reason or reuse `apiError`) instead of throwing `StateError`. This maintains consistency with the use case's result contract.

---

#### PO-3: Race condition and inconsistent state in draft persistence
**Location:** `lib/domain/usecase/cleanup_transcript_use_case.dart` lines 102-123

**Issue:** The `_ensureDraftPersisted` method performs multiple repository operations without atomicity. If `updateDraftTranscript` succeeds but `updateEntryLanguage` fails, the entry could be left in an inconsistent state. There are no transaction semantics or rollback mechanisms.

**Impact:** Entries could have mismatched transcript/language combinations. Users could see corrupted or partially updated drafts.

**Evidence:**
```dart
await entryRepository.updateDraftTranscript(
  entryId,
  rawTranscript,
  _countWords(rawTranscript),
);

if (existingEntry != null && existingEntry.language != language) {
  await entryRepository.updateEntryLanguage(entryId, language);
}
```

**Recommendation:** Either:
1. Add transaction support to the repository layer, or
2. Combine the transcript and language update into a single repository method, or
3. Accept the risk but document it clearly and add error handling to at least return a failure if the second operation fails.

---

### P1 - High Priority Issues

#### P1-1: Duplicate blank-cleaned-text validation logic
**Location:** `lib/data/api/backend_client.dart` lines 132-136 and `lib/domain/usecase/cleanup_transcript_use_case.dart` lines 164-174

**Issue:** Both the backend client and the use case check for blank cleaned text and downgrade success to failure. This creates confusion about which layer owns this validation and could lead to inconsistent behavior if the logic diverges.

**Impact:** Maintenance burden - changes to blank-text handling must be made in two places. Potential for logic drift over time.

**Evidence:**
```dart
// backend_client.dart lines 132-136
if (cleanedText.isEmpty) {
  return CleanupFailure(
    reason: BackendFailureReason.apiError,
    quota: response.data.quota?.toValidatedStateOrNull(),
  );
}

// cleanup_transcript_use_case.dart lines 164-174
final cleanedText = result.cleanedText.trim();
if (cleanedText.isEmpty) {
  logWarning('Cleanup transcript returned blank cleaned text in a success payload.');
  return CleanupTranscriptFailure(
    entryId: entryId,
    reason: backend.BackendFailureReason.apiError,
    quota: result.quota,
  );
}
```

**Recommendation:** Choose one layer to own this validation. Given that the spec requires preserving quota from malformed successes, keep the check in the use case (which has access to the full result) and remove it from the backend client. The backend client should return the raw success/failure from the API, and the use case should apply business logic validation.

---

#### P1-2: Missing test coverage for repository failure scenarios
**Location:** `test/domain/usecase/cleanup_transcript_use_case_test.dart`

**Issue:** The unit tests use a fake repository that never throws exceptions. There are no tests for what happens when repository operations fail, which is a critical gap given PO-1.

**Impact:** The implementation's error handling (or lack thereof) for repository failures is untested. This could lead to runtime crashes in production.

**Recommendation:** Add test cases where the fake repository throws exceptions for:
- `saveDraft` failure
- `updateDraftTranscript` failure
- `updateEntryLanguage` failure
- `updateWithCleanedText` failure

Verify that the use case returns `CleanupTranscriptFailure` instead of crashing.

---

#### P1-3: Missing test coverage for invalid entry ID scenarios
**Location:** `test/domain/usecase/cleanup_transcript_use_case_test.dart`

**Issue:** No tests verify behavior when an invalid entry ID is passed (entry doesn't exist or is already finalized). Given PO-2, this is a critical gap.

**Impact:** The current implementation throws `StateError`, but this is untested. Callers may not expect this behavior.

**Recommendation:** Add test cases for:
- Passing a non-existent entry ID
- Passing an entry ID for a finalized (non-draft) entry

Verify the behavior matches the intended design (should return failure, not throw).

---

#### P1-4: Word count calculation duplicated across test fake and use case
**Location:** `test/domain/usecase/cleanup_transcript_use_case_test.dart` lines 342-348 and `lib/domain/usecase/cleanup_transcript_use_case.dart` lines 207-213

**Issue:** The word count calculation logic is duplicated in the test fake and the use case. If the algorithm changes, tests could pass even if the implementation is wrong.

**Impact:** False confidence in test coverage. Bugs in word counting could go undetected.

**Evidence:**
```dart
// Test fake (lines 342-348)
int _countWords(String text) {
  return text
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .length;
}

// Use case (lines 207-213)
int _countWords(String text) {
  return text
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .length;
}
```

**Recommendation:** Extract the word count logic to a shared utility function that both the use case and tests import. This ensures tests validate the actual implementation logic.

---

#### P1-5: Integration test doesn't verify quota preservation on malformed success
**Location:** `integration_test/cleanup_transcript_use_case_flow_test.dart`

**Issue:** The integration tests have a test for fresh cleanup failure that preserves quota when no quota is returned, but no test specifically verifies that quota IS preserved when a malformed success (blank cleaned text with valid quota) occurs.

**Impact:** The quota preservation behavior for malformed successes (the main reason for the backend client change) is not validated at the integration level.

**Recommendation:** Add an integration test case where the cleanup callback returns a `CleanupSuccess` with blank `cleanedText` but valid quota, and verify that:
1. The result is a `CleanupTranscriptFailure`
2. The quota from the response is preserved
3. The session quota state is updated

---

### P2 - Medium Priority Issues

#### P2-1: No validation that entryId belongs to a text draft vs audio draft
**Location:** `lib/domain/usecase/cleanup_transcript_use_case.dart` lines 77-91

**Issue:** The use case checks if an entry is a draft but doesn't distinguish between audio drafts and text drafts. The spec mentions that cleanup should support audio-draft-to-text-draft promotion, but the implementation doesn't explicitly validate or document this transition.

**Impact:** The behavior when cleaning up an audio draft is implicit rather than explicit. This could lead to confusion about whether audio drafts should be cleaned up directly or require a separate promotion step.

**Recommendation:** Either:
1. Add explicit validation that rejects audio drafts with a specific failure reason, or
2. Add a test case that explicitly verifies audio-draft-to-text-draft promotion works as intended, or
3. Add documentation clarifying that audio drafts are accepted and will be promoted to text drafts.

---

#### P2-2: Magic number for transcript length limit not documented
**Location:** `lib/domain/usecase/cleanup_transcript_use_case.dart` line 16

**Issue:** The constant `cleanupTranscriptMaxLength = 10000` is defined but not documented with a comment explaining why this value was chosen or referencing the spec/backend requirement.

**Impact:** Future maintainers may not understand the constraint's origin and might change it incorrectly.

**Recommendation:** Add a documentation comment referencing the spec requirement and/or backend API limit.

---

#### P2-3: Provider callback captures provider in closure
**Location:** `lib/data/api/backend_providers.dart` lines 46-54

**Issue:** The `cleanupTranscriptCallbackProvider` creates a closure that captures `ref.watch(wraitBackendClientProvider)`. This pattern works but is less idiomatic than directly providing the client or using a different provider pattern.

**Impact:** The callback pattern adds indirection. If the backend client provider's dependencies change, the callback may not update correctly in all scenarios.

**Evidence:**
```dart
final cleanupTranscriptCallbackProvider = Provider<CleanupTranscriptCallback>((
  ref,
) {
  return ({required String transcript, required String language}) {
    return ref
        .watch(wraitBackendClientProvider)
        .cleanupTranscript(transcript: transcript, language: language);
  };
});
```

**Recommendation:** Consider passing the `WraitBackendClient` directly to the use case instead of wrapping it in a callback. The callback pattern is useful for testability, but the use case already accepts a callback type, so the extra provider layer may be unnecessary.

---

#### P2-4: Missing test for language fallback when both transcript and entry language are invalid
**Location:** `test/domain/usecase/cleanup_transcript_use_case_test.dart`

**Issue:** Tests cover language fallback when the input language is invalid, but there's no test for the case where both the input language AND the existing entry's language are invalid, forcing the fallback to `en-US`.

**Impact:** The language resolution logic has multiple fallback paths that aren't fully exercised by tests.

**Recommendation:** Add a test case where:
- An existing draft has an invalid language (e.g., 'zz-ZZ')
- The cleanup call provides no language or another invalid language
- Verify that the fallback to `en-US` occurs correctly

---

#### P2-5: No test for transcript truncation at exact boundary
**Location:** `test/domain/usecase/cleanup_transcript_use_case_test.dart` lines 230-257

**Issue:** The truncation test uses a transcript that is 25 characters over the limit, but there's no test for a transcript that is exactly at the limit (10,000 characters) or one character over.

**Impact:** Boundary conditions are not fully tested. Off-by-one errors could go undetected.

**Recommendation:** Add test cases for:
- Transcript exactly 10,000 characters (should not be truncated)
- Transcript exactly 10,001 characters (should be truncated to 10,000)

---

### P3 - Low Priority Issues

#### P3-1: Inconsistent logging levels
**Location:** `lib/domain/usecase/cleanup_transcript_use_case.dart` lines 51-53, 147-151, 166-168

**Issue:** All warnings use the same `logWarning` callback without distinguishing between different severity levels (e.g., user input validation vs backend crashes vs unexpected state).

**Impact:** Debugging production issues may be difficult without log level granularity.

**Recommendation:** Consider adding different log callbacks (e.g., `logInfo`, `logError`, `logWarning`) or structure the log messages to include severity/context information.

---

#### P3-2: Test fake doesn't implement all repository methods
**Location:** `test/domain/usecase/cleanup_transcript_use_case_test.dart` lines 350-376

**Issue:** The `_FakeEntryRepository` throws `UnimplementedError` for several methods. While the use case doesn't call these methods, this makes the fake less reusable for other tests.

**Impact:** If the use case is later extended to use these methods, tests will fail with `UnimplementedError` rather than providing useful fake behavior.

**Recommendation:** Either implement the methods with reasonable no-op behavior or add a comment explaining why they're unimplemented (e.g., "Not used by CleanupTranscriptUseCase").

---

#### P3-3: Hardcoded fallback language not validated against supported languages
**Location:** `lib/domain/usecase/cleanup_transcript_use_case.dart` line 17

**Issue:** The fallback language `'en-US'` is hardcoded but not validated against the `supportedLanguages` list at runtime. If the supported languages list changes to remove English, the fallback would be invalid.

**Impact:** Configuration drift could lead to invalid language codes being used.

**Recommendation:** Add an assertion or runtime check that `cleanupTranscriptFallbackLanguage` is in `supportedLanguageCodes`, or derive the fallback from the supported languages list.

---

#### P3-4: No documentation for public result classes
**Location:** `lib/domain/usecase/cleanup_transcript_use_case.dart` lines 216-241

**Issue:** The `CleanupTranscriptResult`, `CleanupTranscriptSuccess`, and `CleanupTranscriptFailure` classes lack documentation comments explaining when each result type occurs and what callers should do with them.

**Impact:** Future developers may not understand the contract without reading the implementation.

**Recommendation:** Add Dart doc comments explaining the result contract, when each type is returned, and what the fields mean.

---

## Test Coverage Gaps

Beyond the issues identified above, the following test scenarios are missing or incomplete:

1. **Repository failure modes** - No tests for database errors, constraint violations, or I/O failures
2. **Concurrent cleanup attempts** - No tests for what happens if cleanup is called twice on the same entry
3. **Very long transcripts** - No tests for transcripts significantly longer than 10,000 characters
4. **Special characters in transcripts** - No tests for emojis, unicode, or special characters
5. **Quota validation edge cases** - No tests for quota with zero remaining, negative values, or malformed dates
6. **Language code edge cases** - No tests for null, empty string, or malformed language codes beyond the basic cases

---

## Library and Dependency Usage

No issues identified with library usage. The implementation uses appropriate Flutter/Dart libraries and follows existing patterns in the codebase.

---

## Architecture Concerns

1. **Separation of concerns**: The use case mixes persistence logic with business logic. While this is acceptable for this feature, consider whether a service layer would better separate these concerns as the codebase grows.

2. **Error handling strategy**: The codebase lacks a consistent error handling strategy. Some parts throw exceptions, others return failure results. Consider establishing a project-wide convention.

3. **Transaction support**: The repository layer lacks transaction support, which limits the ability to ensure atomic multi-step operations. This may become a problem as more complex use cases are added.

---

## Conclusion

The implementation successfully delivers the transcript cleanup functionality as specified, but has critical gaps in error handling (PO-1, PO-2) and state management (PO-3) that could lead to runtime crashes or data corruption. The test coverage is insufficient for these failure scenarios (P1-2, P1-3). Addressing the PO and P1 issues should be prioritized before merging this feature.
