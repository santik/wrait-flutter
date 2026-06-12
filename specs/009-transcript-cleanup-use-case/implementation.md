# Implementation Notes: Transcript Cleanup Use Case

> **Feature number:** 009
> **Spec:** [`spec.md`](spec.md)
> **Plan:** [`plan.md`](plan.md)
> **Tasks:** [`tasks.md`](tasks.md)
> **Author:** Codex
> **Date:** 2026-06-12

---

## Summary

US-008 is implemented as a new app-facing `CleanupTranscriptUseCase` layered
over the existing backend cleanup client and entry repository.

Implemented behavior:

- fresh post-transcription cleanup that persists a text draft before backend
  cleanup and finalizes the same entry on success
- existing text-draft cleanup that reuses the supplied entry id, updates the
  stored raw transcript before cleanup, and leaves the draft intact on failure
- typed cleanup failures for missing retry entries, finalized retry entries,
  repository persistence failures, and repository finalization failures
- transcript-language reuse when available, with `en-US` fallback only when a
  supported non-null language is required
- cleanup request truncation to 10,000 characters while preserving the full
  stored raw transcript
- shared session quota propagation from cleanup success and failure results
- backend cleanup hardening so malformed nominal success payloads with blank
  `cleanedText` still surface valid quota while downgrading to failure

## Key implementation details

- Added `lib/domain/usecase/cleanup_transcript_use_case.dart`.
  - defines `CleanupTranscriptUseCase`
  - defines typed success/failure result shapes where success always includes
    the affected `entryId` and failure includes it when draft persistence
    reached a concrete entry
  - persists fresh drafts before cleanup and rewrites existing drafts before
    retry cleanup
  - counts cleaned-text words with the spec-approved whitespace split rule
  - rejects blank cleanup input without a backend call while still preserving
    the persisted draft
  - converts invalid retry targets and repository exceptions into typed cleanup
    failures after logging warnings
- Expanded the entry repository/DAO contract.
  - adds `updateDraftTranscriptAndLanguage(...)` so retry cleanup updates the
    draft transcript, word count, canonical language, and `audioPath`
    atomically before the backend call
  - preserves the repository's existing missing-row `StateError` semantics,
    which the use case now catches and downgrades to cleanup failure
- Updated `lib/data/api/backend_providers.dart`.
  - adds `cleanupTranscriptCallbackProvider`
  - adds `cleanupWarningLoggerProvider`
  - adds `cleanupTranscriptUseCaseProvider`
- Updated `lib/data/api/backend_client.dart`.
  - malformed cleanup success payloads with blank `cleanedText` now return
    `CleanupFailure(apiError, quota)` instead of discarding valid quota
- Added `integration_test/cleanup_transcript_use_case_flow_test.dart`.
  - exercises the real provider graph and real local entry database wiring for
    fresh success, fresh failure, existing draft retry success, malformed
    nominal success downgrading, and request truncation behavior
  - uses an isolated temporary database per test harness so Android/iOS
    integration runs do not leak persisted state across test cases
- Added `test/domain/usecase/cleanup_transcript_use_case_test.dart`.
  - covers fresh-path persistence, retry-path reuse, blank-input rejection,
    malformed-success failure downgrading with quota propagation, invalid
    retry ids, repository failure downgrading, and request truncation
- Extended `test/data/api/backend_client_test.dart`.
  - verifies cleanup-client quota preservation on malformed nominal success
- Extended `test/data/entries/entry_repository_impl_test.dart`.
  - verifies the atomic draft transcript/language update clears stale
    `audioPath` and writes the expected retry state in one repository call

## Review remediation

The external review drove one remediation pass after the first implementation.

Applied fixes:

- added atomic retry-path draft persistence so transcript, word count,
  language, and audio-draft cleanup happen in one repository update
- handled missing and non-draft `entryId` values as typed cleanup failures
  instead of uncaught `StateError`s
- caught repository load, draft-persistence, and finalization exceptions inside
  the use case so callers consistently receive `BackendFailureReason.apiError`
- kept malformed-success blank-text validation in `WraitBackendClient` so the
  downgrade-to-failure rule lives in one place while still preserving quota
- expanded unit, repository, and provider-graph integration coverage for the
  remediated failure paths

## Validation evidence

### Static and unit validation

```text
$ /opt/homebrew/bin/flutter test --no-pub test/domain/usecase/cleanup_transcript_use_case_test.dart test/data/api/backend_client_test.dart test/data/entries/entry_repository_impl_test.dart
All tests passed.

$ /opt/homebrew/bin/flutter analyze
No issues found!

$ /opt/homebrew/bin/flutter test --no-pub
All tests passed.
```

### Provider-graph integration validation

```text
$ /opt/homebrew/bin/flutter test --no-pub -d emulator-5554 integration_test/cleanup_transcript_use_case_flow_test.dart
All tests passed.

$ /opt/homebrew/bin/flutter test --no-pub -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/cleanup_transcript_use_case_flow_test.dart
All tests passed.
```

## Follow-up notes

- The remediation pass kept the existing schema but did add one repository
  method, `updateDraftTranscriptAndLanguage()`, to guarantee atomic retry-path
  draft updates.
- Branch creation succeeded in this environment on
  `codex/feat-transcript-cleanup-use-case-us-008`.
