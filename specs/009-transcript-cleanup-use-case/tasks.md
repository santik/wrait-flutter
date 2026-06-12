# Tasks: Transcript Cleanup Use Case

> **Feature number:** 009
> **Plan:** [`plan.md`](plan.md)
> **Author:** Codex
> **Date:** 2026-06-12

---

## Legend

- `[ ]` — not started
- `[x]` — complete
- `[P]` — can be parallelized with other `[P]` tasks in the same group
- `[B]` — blocked (note the blocker)

## Task groups

_Tasks are organized into sequential groups.
Tasks within the same group marked `[P]` can be worked on in parallel._

### Group 1: Cleanup contract and wiring

_Define the app-facing cleanup boundary and wire it into the existing provider
graph._

- [x] Create the cleanup use case contract, typed success/failure results, transcript bounding, language resolution, cleaned-text word counting, and fresh-versus-retry persistence orchestration — `lib/domain/usecase/cleanup_transcript_use_case.dart`
- [x] Modify backend/provider wiring to expose the cleanup use case plus any cleanup-specific callback or logger providers needed to compose backend cleanup, entry persistence, and shared session quota updates — `lib/data/api/backend_providers.dart`
- [x] Modify the backend cleanup client so malformed cleanup success payloads with blank cleaned text still surface any valid quota while being treated as failures — `lib/data/api/backend_client.dart`

### Group 2: Cleanup persistence behavior

_Implement the story-specific behavior on top of the existing backend and entry
repository foundations._

- [x] Implement fresh post-transcription cleanup so a new text draft is persisted before backend cleanup and the same entry is finalized on success — `lib/domain/usecase/cleanup_transcript_use_case.dart`
  - Depends on: Group 1
- [x] Implement existing-draft cleanup so the supplied draft entry is updated with the current raw transcript before cleanup and remains a text draft on failure — `lib/domain/usecase/cleanup_transcript_use_case.dart`
  - Depends on: Group 1
- [x] Implement session-quota propagation so valid cleanup quota updates shared in-memory quota on success and failure, while missing or invalid quota leaves the last valid quota untouched — `lib/domain/usecase/cleanup_transcript_use_case.dart`
  - Depends on: Group 1
- [x] Implement transcript-language handling so the use case reuses the transcript language when usable and falls back to `en-US` only when a supported non-null language is required for persistence or request construction — `lib/domain/usecase/cleanup_transcript_use_case.dart`
  - Depends on: Group 1

### Group 3: Automated coverage

_Add deterministic tests for every in-scope cleanup flow from the plan._

- [x] Add unit tests for fresh-path draft creation, retry-path entry reuse, blank-input failure, blank-cleaned-text failure with quota propagation, request truncation, language fallback, quota propagation, and cleaned-text word counting — `test/domain/usecase/cleanup_transcript_use_case_test.dart`
  - Depends on: Group 2
- [x] Add fake-driven provider-graph `integration_test` coverage for fresh cleanup success, fresh cleanup failure, existing text-draft retry success, transcript-language reuse, `en-US` fallback, request truncation with full raw-transcript persistence, and quota-state preservation/update rules — `integration_test/cleanup_transcript_use_case_flow_test.dart`
  - Depends on: Group 2
- [x] Add lower-level backend cleanup coverage for malformed-success quota preservation, and expand repository coverage only if implementation uncovers another concrete contract gap — `test/data/api/backend_client_test.dart`, `test/data/entries/entry_repository_impl_test.dart`
  - Depends on: Group 2

### Group 4: Validation

_Run the approved automated coverage and cross-platform verification._

- [x] Run the planned cleanup use case unit tests and record the results — `test/domain/usecase/cleanup_transcript_use_case_test.dart`
- [x] Run the planned `integration_test` cleanup flow coverage and record the results — `integration_test/cleanup_transcript_use_case_flow_test.dart`
- [x] Verify the feature on an Android emulator by running the cleanup integration flow and confirming fresh success and fresh failure both persist the expected entry state, then record the evidence
- [x] Verify the feature on an iOS simulator by running the cleanup integration flow and confirming fresh success and fresh failure both persist the expected entry state, then record the evidence
- [x] Verify project analysis and test commands complete successfully and record the command evidence

### Group 5: Review and fix

_Handle external review after implementation._

- [x] Create `implementation.md` with implementation notes and validation evidence
- [x] Stop and wait for external `review.md`, unless the user explicitly skips review
- [x] Read `review.md` and prepare a remediation plan without changing files
- [x] Present the remediation plan and wait for approval before making any changes
- [x] Implement approved review fixes and update `spec.md`, `plan.md`, `tasks.md`, `implementation.md`, code, and tests when review changes scope, approach, or validation
- [ ] Repeat the review/fix loop if the same `review.md` file is updated for another pass

### Group 6: Finalization

_Handle durable documentation follow-up and closeout._

- [x] Decide whether the feature produced durable learnings or long-lived product/architecture changes worth preserving
- [x] If needed, propose updates to `AGENTS.md`, `docs/application-description.md`, and `docs/agent-findings.md`
- [x] Wait for explicit approval before editing those long-lived guidance documents
- [x] Record whether the knowledge-capture gate resulted in updates or an explicit no-update decision

## Completion criteria

All tasks checked, validation evidence documented, review handled or explicitly
skipped, and the final knowledge-capture gate handled.

## Validation evidence

_Record test results, screenshots, command output, approved exceptions, or
review-related notes here when complete._

```text
$ /opt/homebrew/bin/flutter test --no-pub test/domain/usecase/cleanup_transcript_use_case_test.dart test/data/api/backend_client_test.dart test/data/entries/entry_repository_impl_test.dart
All tests passed.

$ /opt/homebrew/bin/flutter test --no-pub -d emulator-5554 integration_test/cleanup_transcript_use_case_flow_test.dart
All tests passed.

$ /opt/homebrew/bin/flutter test --no-pub -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/cleanup_transcript_use_case_flow_test.dart
All tests passed.

$ /opt/homebrew/bin/flutter analyze
No issues found!

$ /opt/homebrew/bin/flutter test --no-pub
All tests passed.

$ /opt/homebrew/bin/flutter test --no-pub -d emulator-5554
All tests passed.

$ /opt/homebrew/bin/flutter test --no-pub -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156
All tests passed.

$ /opt/homebrew/bin/flutter test --no-pub -d emulator-5554 integration_test
All tests passed.

$ /opt/homebrew/bin/flutter test --no-pub -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test
All tests passed.
```

## Notes

- The backend cleanup client was hardened during implementation because the
  approved spec requires valid quota to survive malformed nominal success
  payloads with blank `cleanedText`.
- The approved remediation pass added one repository contract expansion,
  `updateDraftTranscriptAndLanguage()`, so retry cleanup can update transcript,
  word count, language, and `audioPath` atomically before the backend call.
- The cleanup result contract now allows `entryId` to be null on failure when
  draft persistence fails before an entry exists, while successful cleanup
  still always returns the finalized entry id.
- The knowledge-capture gate resulted in updates to
  `docs/application-description.md` and `docs/agent-findings.md`; `AGENTS.md`
  was reviewed and intentionally left unchanged because US-008 did not add a
  new lasting repo-level workflow rule.
- Branch creation succeeded for this implementation on
  `codex/feat-transcript-cleanup-use-case-us-008`.
