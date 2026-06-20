# Tasks: Draft Retry System

> **Feature number:** 015
> **Plan:** [`plan.md`](plan.md)
> **Author:** Codex
> **Date:** 2026-06-19

---

## Legend

- `[ ]` — not started
- `[x]` — complete
- `[P]` — can be parallelized with other `[P]` tasks in the same group
- `[B]` — blocked (note the blocker)

## Task groups

Tasks are organized into sequential groups. Tasks within the same group marked
`[P]` can be worked on in parallel after their group prerequisites are met.

### Group 1: Launch Contracts

Create the explicit launch-work contracts before wiring retry behavior into
startup.

- [x] Modify launch registration to return an explicit success/failure result
      while preserving quota updates, warning logs, and swallowed exceptions —
      `lib/domain/usecase/register_device_on_launch_use_case.dart`
- [x] Update registration use-case tests for success, handled registration
      failure, and caught exception return values —
      `test/data/api/register_device_on_launch_use_case_test.dart`
- [x] Create launch-work use case that calls registration once and calls draft
      retry only after registration success —
      `lib/domain/usecase/app_launch_work_use_case.dart`
- [x] Add launch-work tests for registration-success retry, registration-failure
      skip, and swallowed/logged retry exceptions —
      `test/domain/usecase/app_launch_work_use_case_test.dart`

### Group 2: Draft Retry Use Case

Implement the core draft retry workflow independent of widgets and app startup.

- [x] Create retry warning logger and injectable file validation/deletion
      contracts for retained audio files —
      `lib/domain/usecase/retry_pending_drafts_use_case.dart`
- [x] Implement single-flight retry guard and sequential newest-first pending
      draft processing — `lib/domain/usecase/retry_pending_drafts_use_case.dart`
- [x] Run stale draft deletion before loading pending drafts —
      `lib/domain/usecase/retry_pending_drafts_use_case.dart`
- [x] Implement audio-draft validation that deletes blank, missing, unreadable,
      or empty audio drafts before transcription —
      `lib/domain/usecase/retry_pending_drafts_use_case.dart`
- [x] Implement audio-draft transcription success path that passes raw
      transcript, detected language, and existing draft id to cleanup —
      `lib/domain/usecase/retry_pending_drafts_use_case.dart`
- [x] Implement audio-draft transcription failure path that leaves the draft
      and retained audio intact — `lib/domain/usecase/retry_pending_drafts_use_case.dart`
- [x] Implement audio transcription plus cleanup success path that finalizes
      the same draft id and deletes retained audio best-effort —
      `lib/domain/usecase/retry_pending_drafts_use_case.dart`
- [x] Implement audio transcription success plus cleanup failure path that
      preserves a text draft and deletes retained audio best-effort —
      `lib/domain/usecase/retry_pending_drafts_use_case.dart`
- [x] Implement text-draft cleanup success and failure paths —
      `lib/domain/usecase/retry_pending_drafts_use_case.dart`
- [x] Ensure quota exhaustion and proxy authentication failures preserve audio
      and text drafts — `lib/domain/usecase/retry_pending_drafts_use_case.dart`
- [x] Ensure per-draft exceptions are logged and do not prevent later drafts
      from being attempted — `lib/domain/usecase/retry_pending_drafts_use_case.dart`
- [x] Add retry use-case tests for stale deletion, ordering, single-flight
      behavior, audio success, audio transcription failure, audio-to-text
      promotion, missing/unreadable audio deletion, text success/failure,
      quota/proxy preservation, and per-draft isolation —
      `test/domain/usecase/retry_pending_drafts_use_case_test.dart`

### Group 3: Provider Wiring and Startup

Wire launch work into the app while preserving non-blocking bootstrap behavior.

- [x] Update registration provider compatibility for the new launch
      registration result contract — `lib/data/api/backend_providers.dart`
      (no source edit required)
- [x] Create launch providers for `AppLaunchWorkUseCase`,
      `RetryPendingDraftsUseCase`, logging, file operations, entry repository,
      transcription service, and cleanup use case —
      `lib/data/launch/app_launch_providers.dart`
- [x] Update `startAppLaunchWork` to call the new launch-work use case as
      fire-and-forget work — `lib/main.dart`
- [x] Confirm bootstrap tests still cover loading/success/error/retry behavior
      with the new launch-work boundary — `test/bootstrap_app_test.dart`
      (no source edit required)

### Group 4: Integration Coverage

Cover every in-scope launch/draft flow through real app/provider wiring.

- [x] Update device-registration launch integration coverage for non-blocking
      registration success triggering retry and registration failure skipping
      retry — `integration_test/device_registration_launch_flow_test.dart`
- [x] Create draft retry launch integration harness with local encrypted entry
      database, fake backend/transcription/cleanup controls, and deterministic
      app launch work — `integration_test/draft_retry_launch_flow_test.dart`
- [x] Cover pending audio draft finalization after launch registration success
      — `integration_test/draft_retry_launch_flow_test.dart`
- [x] Cover pending text draft finalization after launch registration success
      — `integration_test/draft_retry_launch_flow_test.dart`
- [x] Cover failed audio retry preserving draft and retained audio for the next
      launch — `integration_test/draft_retry_launch_flow_test.dart`
- [x] Cover failed text retry preserving draft for the next launch —
      `integration_test/draft_retry_launch_flow_test.dart`
- [x] Cover stale draft deletion before retry —
      `integration_test/draft_retry_launch_flow_test.dart`
- [x] Cover missing or unreadable audio draft deletion —
      `integration_test/draft_retry_launch_flow_test.dart`
- [x] Cover finalized retry entries appearing through existing list/detail/stats
      surfaces without separate foreground success feedback —
      `integration_test/draft_retry_launch_flow_test.dart`
- [x] Cover registration failure skipping retry until a future launch —
      `integration_test/draft_retry_launch_flow_test.dart`
- [x] Verify existing main recording controller integration coverage remains
      aligned so audio/text draft creation still feeds launch retry —
      `integration_test/main_recording_controller_flow_test.dart`
      (no source edit required)
- [x] Verify draft creation preserves the best available language for audio and
      text drafts in existing controller/use-case tests —
      `test/presentation/main/main_recording_controller_test.dart`,
      `test/domain/usecase/retry_pending_drafts_use_case_test.dart`
- [x] Verify existing cleanup transcript integration coverage remains aligned
      with launch retry orchestration —
      `integration_test/cleanup_transcript_use_case_flow_test.dart`
      (no source edit required)

### Group 5: Validation

Run automated and platform validation from the approved plan, recording
evidence as each check completes.

- [x] Run Dart formatting on changed Dart files
- [x] Run static analysis
- [x] Run focused unit/widget tests for registration, launch work, retry use
      case, bootstrap, and recording-controller draft creation
- [x] Run the full Flutter test suite, including any prerequisite generation
      steps if required by changed generated/backend artifacts
- [x] Run `integration_test/draft_retry_launch_flow_test.dart` on an Android
      emulator
- [x] Run `integration_test/device_registration_launch_flow_test.dart` on an
      Android emulator
- [x] Run relevant entry-surface integration coverage on an Android emulator to
      verify finalized retry entries appear in list/detail/stats
- [x] Run `integration_test/draft_retry_launch_flow_test.dart` on an iOS
      simulator
- [x] Run `integration_test/device_registration_launch_flow_test.dart` on an
      iOS simulator
- [x] Run relevant entry-surface integration coverage on an iOS simulator to
      verify finalized retry entries appear in list/detail/stats
- [x] Record validation command output, state evidence, and any approved
      exceptions in this file and `implementation.md`

### Group 6: Implementation Artifact

Document implementation details and validation evidence for review.

- [x] Create `implementation.md` with implementation summary, architecture
      notes, file-change summary, and validation evidence —
      `specs/015-draft-retry-system/implementation.md`
- [x] Update `tasks.md` task statuses and validation evidence as work is
      completed — `specs/015-draft-retry-system/tasks.md`

### Group 7: Review and Fix

Handle external review after implementation.

- [x] Stop and wait for external `review.md`, unless the user explicitly
      skips review
- [x] Read `review.md` and prepare a remediation plan without changing files
- [x] Present the remediation plan and wait for approval before making any
      changes
- [x] Implement approved review fixes and update `spec.md`, `plan.md`,
      `tasks.md`, `implementation.md`, code, and tests when review changes
      scope, approach, or validation
- [x] Repeat the review/fix loop if the same `review.md` file is updated for
      another pass (not needed; no additional review revision was provided)

### Group 8: Finalization

Handle durable documentation follow-up and closeout.

- [x] Decide whether US-015 produced durable learnings or long-lived
      product/architecture changes worth preserving
- [x] If needed, propose updates to `docs/application-description.md` for the
      single cloud-backed recording flow and draft retry behavior
- [x] If needed, propose updates to `docs/agent-findings.md` for launch-work
      sequencing and draft retry use-case boundaries
- [x] Decide whether `AGENTS.md` needs durable workflow or validation guidance
      updates
- [x] Wait for explicit approval before editing long-lived guidance documents
- [x] Record whether the knowledge-capture gate resulted in updates or an
      explicit no-update decision
- [x] Mark `spec.md` status as `Complete` only after implementation, review,
      validation, and final knowledge-capture gates are handled

## Completion criteria

All tasks checked, validation evidence documented, review handled or explicitly
skipped, and the final knowledge-capture gate handled.

## Validation evidence

Record test results, emulator/simulator evidence, command output, approved
exceptions, or review-related notes here when complete.

```text
Completed:
- `dart format` on changed Dart files
- `/opt/homebrew/bin/flutter analyze`
- Focused tests:
  `/opt/homebrew/bin/flutter test test/data/api/register_device_on_launch_use_case_test.dart test/domain/usecase/app_launch_work_use_case_test.dart test/domain/usecase/retry_pending_drafts_use_case_test.dart test/bootstrap_app_test.dart test/presentation/main/main_recording_controller_test.dart`
- Full suite:
  `/opt/homebrew/bin/flutter test`
- Android emulator launch:
  `/Users/alexander/Library/Android/sdk/emulator/emulator -avd Pixel_8_emulator -no-snapshot-load`
- Android emulator launch + retry coverage:
  `/opt/homebrew/bin/flutter test integration_test/device_registration_launch_flow_test.dart integration_test/draft_retry_launch_flow_test.dart -d emulator-5554`
- Android device launch + retry coverage:
  `/opt/homebrew/bin/flutter test integration_test/device_registration_launch_flow_test.dart integration_test/draft_retry_launch_flow_test.dart -d 4A181FDJH0030G`
- iOS simulator launch + retry coverage:
  `/opt/homebrew/bin/flutter test integration_test/device_registration_launch_flow_test.dart integration_test/draft_retry_launch_flow_test.dart -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156`
- iOS simulator alignment coverage:
  `/opt/homebrew/bin/flutter test integration_test/main_recording_controller_flow_test.dart integration_test/cleanup_transcript_use_case_flow_test.dart -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156`
```

## Notes

- The approved plan requested no validation exceptions. Android emulator and
  iOS simulator verification are now complete.
- No app modes were added. Launch retry applies to the app's single
  cloud-backed recording flow.
- Knowledge capture result: updated `docs/application-description.md` and
  `docs/agent-findings.md`; no durable `AGENTS.md` update was needed.
