# Tasks: Terminal No-Speech Transcription Handling

> **Feature number:** 036
> **Plan:** [`plan.md`](plan.md)
> **Author:** Codex
> **Date:** 2026-06-25

---

## Legend

- `[ ]` — not started
- `[x]` — complete
- `[P]` — can be parallelized with other `[P]` tasks in the same group
- `[B]` — blocked (note the blocker)

## Task groups

Tasks are organized into sequential groups. Tasks within the same group marked
`[P]` can be worked on in parallel.

### Group 1: Foundation

Pin the current no-word, retryable-draft, and quota contracts in focused tests
before changing implementation.

- [x] [P] Update cloud transcription unit coverage so blank live transcript
      success expects `nothingCaught`, no audio-draft path, and deleted
      service-owned live temp audio —
      `test/data/transcription/cloud_transcription_service_test.dart`
- [x] [P] Confirm or update cloud transcription unit coverage that blank draft
      transcription keeps caller-owned draft audio untouched —
      `test/data/transcription/cloud_transcription_service_test.dart`
- [x] [P] Confirm or update cloud transcription unit coverage that retryable
      live backend/network failures still preserve retryable audio paths and
      backend quota —
      `test/data/transcription/cloud_transcription_service_test.dart`
- [x] [P] Add recording-controller unit coverage that `nothingCaught` with an
      audio path still maps to no-match feedback without saving an audio draft
      or setting `preservedDraft=true` —
      `test/presentation/main/main_recording_controller_test.dart`
- [x] [P] Add recording-controller unit coverage that retryable failure draft
      persistence does not publish or infer a second quota update —
      `test/presentation/main/main_recording_controller_test.dart`
- [x] [P] Identify whether existing main-screen integration coverage already
      verifies visible no-match text; plan a `main_screen_flow_test.dart`
      update only if provider-graph coverage is not enough for the approved
      user-visible flow; existing provider-graph and status-resolution coverage
      was sufficient — `integration_test/main_screen_flow_test.dart`

### Group 2: Core implementation

Implement the smallest contract changes from the approved plan.

- [x] Return terminal no-word live transcription failures without retryable
      audio-draft paths when blank successful transcription payloads are
      received — `lib/data/transcription/cloud_transcription_service.dart`
  - Depends on: Group 1
- [x] Delete service-owned live temp audio after blank successful transcription
      payloads, using the existing best-effort deletion behavior —
      `lib/data/transcription/cloud_transcription_service.dart`
  - Depends on: Group 1
- [x] Keep caller-owned draft transcription audio untouched for blank draft
      transcription results —
      `lib/data/transcription/cloud_transcription_service.dart`
  - Depends on: Group 1
- [x] Guard audio-draft persistence so
      `TranscriptionFailureReason.nothingCaught` never creates a retryable
      draft even if an audio path is present —
      `lib/presentation/main/main_recording_controller.dart`
  - Depends on: Group 1
- [x] Preserve existing retryable failure draft behavior for network, timeout,
      backend unavailable, proxy-auth, quota, and generic API failures —
      `lib/data/transcription/cloud_transcription_service.dart`,
      `lib/presentation/main/main_recording_controller.dart`
  - Depends on: Group 1
- [x] Keep quota updates sourced from backend-provided quota only; ensure local
      audio-draft persistence success or failure does not synthesize or publish
      a second quota state —
      `lib/presentation/main/main_recording_controller.dart`,
      `lib/data/transcription/cloud_transcription_service.dart`,
      `lib/domain/usecase/cleanup_transcript_use_case.dart`,
      `lib/domain/usecase/retry_pending_drafts_use_case.dart`
  - Depends on: Group 1

### Group 3: Integration coverage

Validate the in-scope flows through existing provider and main-screen
integration paths.

- [x] Add provider-graph integration coverage for blank live transcript success
      returning terminal `nothingCaught`, no audio-draft path, and deleted live
      temp audio — `integration_test/cloud_transcription_service_flow_test.dart`
  - Depends on: Group 2
- [x] Add provider-graph integration coverage for no-word recording feedback,
      no saved draft, no pending draft, and no saved-draft copy —
      `integration_test/main_recording_controller_flow_test.dart`
  - Depends on: Group 2
- [x] Keep or strengthen provider-graph integration coverage that retryable
      live transcription failure still creates a pending audio draft and shows
      draft-preserved feedback —
      `integration_test/main_recording_controller_flow_test.dart`
  - Depends on: Group 2
- [x] Add provider-graph integration coverage that quota after retryable
      failure draft preservation equals the backend-provided quota and is not
      locally advanced again —
      `integration_test/main_recording_controller_flow_test.dart`
  - Depends on: Group 2
- [x] If needed, add visible main-screen integration coverage for existing
      no-match text without saved-draft copy; not needed after validating the
      existing provider-graph status assertions and `main_screen_status` copy
      coverage —
      `integration_test/main_screen_flow_test.dart`
  - Depends on: Group 2

### Group 4: Validation

Run the planned automated tests and runtime verification.

- [x] Run focused unit tests:
      `flutter test test/data/transcription/cloud_transcription_service_test.dart test/domain/usecase/cleanup_transcript_use_case_test.dart test/presentation/main/main_recording_controller_test.dart`
- [x] Run focused integration tests:
      `flutter test integration_test/cloud_transcription_service_flow_test.dart integration_test/main_recording_controller_flow_test.dart integration_test/main_screen_flow_test.dart`
- [x] Run `flutter analyze`
- [x] Verify US-036 focused integration coverage on an Android emulator,
      including no-word no-draft behavior, retryable draft preservation, and
      quota remaining/count after local draft preservation
- [x] Verify US-036 focused integration coverage on an iOS simulator,
      including no-word no-draft behavior, retryable draft preservation, and
      quota remaining/count after local draft preservation
- [x] If required Android emulator or iOS simulator verification cannot be
      completed, stop and request an explicit user-approved validation
      exception before final approval; no exception was required

### Group 5: Implementation record

Document what changed and the validation evidence for review.

- [x] Create `implementation.md` with implementation summary, changed files,
      validation commands, Android emulator evidence, iOS simulator evidence,
      and any deviations —
      `specs/036-terminal-no-speech-transcription/implementation.md`
- [x] Update task statuses and validation evidence in this file as work is
      completed — `specs/036-terminal-no-speech-transcription/tasks.md`
- [x] Confirm `spec.md` and `plan.md` still match the implemented behavior —
      `specs/036-terminal-no-speech-transcription/spec.md`,
      `specs/036-terminal-no-speech-transcription/plan.md`

### Group 6: Review and fix

Handle external review after implementation.

- [x] Stop and wait for external `review.md`, unless the user explicitly skips
      review
- [x] Read `review.md` and prepare a remediation plan without changing files
- [x] Present the remediation plan and wait for approval before making any
      changes
- [x] Implement approved review fixes and update `spec.md`, `plan.md`,
      `tasks.md`, `implementation.md`, code, and tests when review changes
      scope, approach, or validation
- [x] Implement approved reopened-regression fixes for backend blank-success
      and punctuation-only no-speech payloads, and update story artifacts and
      validation evidence
- [ ] Repeat the review/fix loop if the same `review.md` file is updated for
      another pass

### Group 7: Finalization

Handle durable documentation follow-up and closeout.

- [ ] Decide whether the feature produced durable learnings or long-lived
      product/architecture changes worth preserving
- [ ] If needed, propose updates to `AGENTS.md`,
      `docs/application-description.md`, and `docs/agent-findings.md`
- [ ] Wait for explicit approval before editing those long-lived guidance
      documents
- [ ] Record whether the knowledge-capture gate resulted in updates or an
      explicit no-update decision
- [ ] Mark `spec.md` status `Complete` only after implementation, validation,
      review/fix handling, and knowledge capture are complete

## Completion criteria

All tasks checked, validation evidence documented, review handled or explicitly
skipped, and the final knowledge-capture gate handled.

## Validation evidence

Record test results, screenshots, command output, approved exceptions, or
review-related notes here when complete.

```text
2026-06-29

Focused unit tests:
flutter test test/data/transcription/cloud_transcription_service_test.dart test/domain/usecase/cleanup_transcript_use_case_test.dart test/presentation/main/main_recording_controller_test.dart
Result: passed

Focused integration tests:
flutter test integration_test/cloud_transcription_service_flow_test.dart integration_test/main_recording_controller_flow_test.dart integration_test/main_screen_flow_test.dart
Result: passed

Static analysis:
flutter analyze
Result: No issues found.

Android emulator verification on Pixel_8_emulator (emulator-5554):
flutter test -d emulator-5554 integration_test/main_recording_controller_flow_test.dart
Result: passed

iOS simulator verification on iPhone 17 simulator (491CD949-D3C0-4C4C-A6B9-15BAB1859156):
flutter test -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/main_recording_controller_flow_test.dart
Result: passed

Review remediation rerun:

Focused unit tests:
flutter test test/data/transcription/cloud_transcription_service_test.dart test/domain/usecase/cleanup_transcript_use_case_test.dart test/domain/usecase/retry_pending_drafts_use_case_test.dart test/presentation/main/main_recording_controller_test.dart
Result: passed

Focused integration tests on Android emulator (multiple devices required an explicit target):
flutter test -d emulator-5554 integration_test/cloud_transcription_service_flow_test.dart integration_test/main_recording_controller_flow_test.dart integration_test/main_screen_flow_test.dart
Result: passed

Static analysis:
flutter analyze
Result: No issues found.

iOS simulator remediation verification on iPhone 17 simulator (491CD949-D3C0-4C4C-A6B9-15BAB1859156):
flutter test -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/main_recording_controller_flow_test.dart
Result: passed

2026-06-30 reopened regression rerun:

Focused unit tests:
flutter test test/data/api/backend_client_test.dart test/data/transcription/cloud_transcription_service_test.dart test/presentation/main/main_recording_controller_test.dart
Result: passed

Static analysis:
flutter analyze
Result: No issues found.

Android runtime verification on connected Pixel 8 device (4A181FDJH0030G):
flutter test -d 4A181FDJH0030G integration_test/main_recording_controller_flow_test.dart
Result: passed
Note: the planned Android emulator target `emulator-5554` was unavailable in this session; prior emulator validation from 2026-06-29 remains recorded above.

iOS simulator reopened-regression verification on iPhone 17 simulator (491CD949-D3C0-4C4C-A6B9-15BAB1859156):
flutter test -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/main_recording_controller_flow_test.dart
Result: passed
```

## Notes

- Existing no-word audio drafts created before US-036 remain out of scope.
- Backend quota accounting, quota response shapes, and quota limits remain out
  of scope.
- Local draft preservation must not publish or infer quota consumption.
