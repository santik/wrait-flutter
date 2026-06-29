# Tasks: Entry Type Classification

> **Feature number:** 037
> **Plan:** [`plan.md`](plan.md)
> **Author:** Codex
> **Date:** 2026-06-29

---

## Legend

- `[ ]` — not started
- `[x]` — complete
- `[P]` — can be parallelized with other `[P]` tasks in the same group
- `[B]` — blocked (note the blocker)

## Task groups

Tasks are organized into sequential groups. Tasks within the same group marked
`[P]` can be worked on in parallel.

### Group 1: Baseline and branch setup

Confirm the current entry classification surface and prepare the implementation
branch before changing code.

- [x] Create or switch to a feature branch for US-037 following the project git
      convention
- [x] Capture the current `isDraft`/`is_draft` reference list with `rg` so
      implementation can verify all source-of-truth usages are replaced
- [x] Inspect the current Drift generation command and confirm the generator
      path needed for `local_entry_database.g.dart`
- [x] Confirm no backend OpenAPI, app-lock, capture-privacy, startup, release
      signing, or backend-registration files need changes for this story

### Group 2: Domain and persistence model

Introduce the explicit entry type and replace the old boolean field with a
fresh-install type-based store.

- [x] Add `EntryType` with `draft` and `saved` values and replace
      `Entry.isDraft` with required `Entry.type` —
      `lib/domain/model/entry.dart`
  - Depends on: Group 1
- [x] Update `Entry.copyWith`, equality, and hash semantics to use
      `Entry.type` — `lib/domain/model/entry.dart`
  - Depends on: `EntryType` task
- [x] Replace the Drift `is_draft` column with a required constrained `type`
      column in the supported entry store —
      `lib/data/entries/local_entry_database.dart`
  - Depends on: Group 1
- [x] Roll the type-based store out as a fresh local database instead of
      migrating the legacy `is_draft` file in place —
      `lib/data/entries/local_entry_database.dart`
  - Depends on: schema task
- [x] Regenerate Drift output for the updated schema —
      `lib/data/entries/local_entry_database.g.dart`
  - Depends on: schema tasks
- [x] Update or remove the stale entry mapper helper so generated rows map via
      `EntryType` instead of `isDraft` —
      `lib/data/entries/entry_mapper.dart`
  - Depends on: generated database task

### Group 3: Repository and use-case behavior

Move all entry workflow behavior to the new type source of truth while keeping
business operation names stable.

- [x] Update new saved-entry writes to persist `type='saved'` —
      `lib/data/entries/entry_repository_impl.dart`,
      `lib/data/entries/entry_dao.dart`
  - Depends on: Group 2
- [x] Update new text-draft and audio-draft writes to persist `type='draft'` —
      `lib/data/entries/entry_repository_impl.dart`,
      `lib/data/entries/entry_dao.dart`
  - Depends on: Group 2
- [x] Update pending-draft and stale-draft queries/deletes to match exactly
      `type='draft'` —
      `lib/data/entries/entry_dao.dart`
  - Depends on: Group 2
- [x] Add explicit persisted-type parsing/validation at the repository mapping
      boundary so unsupported values are not silently coerced —
      `lib/data/entries/entry_repository_impl.dart`
  - Depends on: Group 2
- [x] Update draft transcript and draft language updates to preserve
      `EntryType.draft` —
      `lib/data/entries/entry_repository_impl.dart`,
      `lib/data/entries/entry_dao.dart`
  - Depends on: Group 2
- [x] Update cleanup completion and draft finalization to promote drafts from
      `EntryType.draft` to `EntryType.saved` —
      `lib/domain/usecase/cleanup_transcript_use_case.dart`,
      `lib/data/entries/entry_repository_impl.dart`,
      `lib/data/entries/entry_dao.dart`
  - Depends on: Group 2
- [x] Update retry validation so draft retry only processes
      `EntryType.draft` entries and still distinguishes audio/text drafts by
      `audioPath` and transcript content —
      `lib/domain/usecase/retry_pending_drafts_use_case.dart`
  - Depends on: repository draft-query tasks
- [x] Update saved-entry edit flows so editing cleaned text keeps
      `EntryType.saved` —
      `lib/data/entries/entry_repository_impl.dart`,
      `lib/data/entries/entry_dao.dart`
  - Depends on: Group 2

### Group 4: Presentation behavior

Replace UI and presentation logic that still depends on the old boolean field.

- [x] Update entry-list row draft labels and draft-specific row behavior to
      use `Entry.type` — `lib/presentation/entries/entry_list_row.dart`
  - Depends on: Group 2
- [x] Update entry-detail draft-specific rendering, editing, and action
      behavior to use `Entry.type` —
      `lib/presentation/entries/entry_detail_screen.dart`
  - Depends on: Group 2
- [x] Update entry list/detail formatters or controllers that branch on draft
      state to use `Entry.type` —
      `lib/presentation/entries/entry_list_formatters.dart`,
      `lib/presentation/entries/entry_list_controller.dart`
  - Depends on: Group 2
- [x] Update main-screen stats so saved and draft counts come from
      `Entry.type` — `lib/presentation/main/main_screen_stats.dart`
  - Depends on: Group 2
- [x] Update any router, main-screen, or sharing code that constructs or
      checks entries so saved entries remain shareable/editable and drafts
      retain current draft-visible behavior —
      `lib/presentation/main/**`, `lib/core/router/app_router.dart`,
      `lib/presentation/entries/**`
  - Depends on: Group 2

### Group 5: Automated tests

Update focused coverage and integration flows for the new type model.

- [x] [P] Add or update domain model coverage for `EntryType`, `copyWith`,
      equality, and removal of `isDraft` construction —
      `test/domain/model/entry_test.dart` or existing affected tests
  - Depends on: Group 2
- [x] [P] Update repository tests for saved entries, text drafts, audio drafts,
      pending drafts, stale cleanup, draft transcript updates, draft promotion,
      saved-entry edits, audio cleanup, and invalid stored type handling —
      `test/data/entries/entry_repository_impl_test.dart`
  - Depends on: Groups 2 and 3
- [x] [P] Add fresh-install persistence tests that prove the legacy
      `is_draft` file is ignored, invalid direct SQL types are rejected, and
      corrupted current-shape rows fail explicitly on read —
      `test/data/entries/entry_database_test.dart`
  - Depends on: Group 2
- [x] [P] Update cleanup use-case tests so cleanup creates saved entries,
      preserves failures as drafts, and promotes drafts to saved entries —
      `test/domain/usecase/cleanup_transcript_use_case_test.dart`
  - Depends on: Group 3
- [x] [P] Update draft-retry use-case tests so pending retry, failed retry,
      stale cleanup, malformed audio handling, and promotion assert
      `EntryType` — `test/domain/usecase/retry_pending_drafts_use_case_test.dart`
  - Depends on: Group 3
- [x] [P] Update entry presentation tests for list rows, list screen, detail
      screen, formatters, sharing, deletion, and controller behavior —
      `test/presentation/entries/**`
  - Depends on: Group 4
- [x] [P] Update main-screen stats and main-screen tests to construct entries
      with `EntryType` and assert saved/draft counts from type —
      `test/presentation/main/**`
  - Depends on: Group 4
- [x] [P] Update router and any remaining unit/widget tests that construct
      `Entry(isDraft: ...)` to use `Entry(type: ...)` —
      `test/core/router/app_router_test.dart`, `test/**`
  - Depends on: Group 4
- [x] Update draft retry integration coverage so successful retry promotes
      drafts to `EntryType.saved` and failed retry leaves
      `EntryType.draft` — `integration_test/draft_retry_launch_flow_test.dart`
  - Depends on: Groups 3 and 4
- [x] Update main recording controller integration coverage so recording
      success creates `EntryType.saved` and retryable recording failure creates
      `EntryType.draft` —
      `integration_test/main_recording_controller_flow_test.dart`
  - Depends on: Groups 3 and 4
- [x] Update cleanup integration coverage so successful cleanup creates or
      promotes saved entries and cleanup failures preserve draft entries —
      `integration_test/cleanup_transcript_use_case_flow_test.dart`
  - Depends on: Groups 3 and 4
### Group 6: Source cleanup and host validation

Run local checks and remove old source-of-truth references before platform
verification.

- [x] Run `rg -n "isDraft|is_draft"` and resolve all remaining app-code hits;
      only legacy-file tests plus historical spec/review text may remain
  - Depends on: Groups 2 through 5
- [x] Run `dart format lib test integration_test`
  - Depends on: source cleanup
- [x] Run `flutter analyze`
  - Depends on: formatting
- [x] Run focused entry persistence tests:
      `flutter test test/data/entries`
  - Depends on: analyzer success
- [x] Run focused domain/use-case tests:
      `flutter test test/domain/usecase`
  - Depends on: analyzer success
- [x] Run focused presentation/router tests:
      `flutter test test/presentation/entries test/presentation/main test/core/router`
  - Depends on: analyzer success
- [x] Run focused host integration tests:
      `flutter test integration_test/draft_retry_launch_flow_test.dart integration_test/main_recording_controller_flow_test.dart integration_test/cleanup_transcript_use_case_flow_test.dart`
  - Depends on: focused unit/widget tests
- [x] Fix any validation failures without expanding scope beyond the approved
      spec and plan
  - Depends on: validation results

### Group 7: Android emulator validation

Collect required runtime evidence on Android.

- [x] Boot or select an Android emulator and record the emulator id
  - Depends on: Group 6
- [x] Run focused integration coverage on the Android emulator for recording
      success, retryable recording failure, draft retry promotion, failed
      retry preservation, plus entry list/detail visible behavior
  - Depends on: Android emulator availability
- [x] Inspect the visible entry list/detail paths on Android through the
      device-visible smoke suite: saved entries appear normally, draft entries
      show the draft label, and sharing/edit flows remain intact
  - Depends on: Android integration run
- [x] Record Android commands, target id, and pass/fail evidence in
      `tasks.md` and `implementation.md`
  - Depends on: Android verification tasks

### Group 8: iOS simulator validation

Collect required runtime evidence on iOS.

- [x] Boot or select an iOS simulator and record the simulator id
  - Depends on: Group 6
- [x] Run focused integration coverage on the iOS simulator for recording
      success, retryable recording failure, draft retry promotion, failed
      retry preservation, plus entry list/detail visible behavior
  - Depends on: iOS simulator availability
- [x] Inspect the visible entry list/detail paths on iOS through the
      device-visible smoke suite: saved entries appear normally, draft entries
      show the draft label, and sharing/edit flows remain intact
  - Depends on: iOS integration run
- [x] Record iOS commands, target id, and pass/fail evidence in `tasks.md` and
      `implementation.md`
  - Depends on: iOS verification tasks

### Group 9: Artifact updates

Record implementation details and keep SDD artifacts aligned.

- [x] Update this task list as implementation progresses —
      `specs/037-entry-type-classification/tasks.md`
- [x] Create `implementation.md` with implementation summary, changed files,
      fresh-install rollout details, automated validation output, Android emulator
      evidence, iOS simulator evidence, and deviations —
      `specs/037-entry-type-classification/implementation.md`
- [x] Confirm `spec.md`, `plan.md`, and `tasks.md` still match the
      implemented behavior; update them only when implementation findings
      require scope, approach, or validation corrections —
      `specs/037-entry-type-classification/spec.md`,
      `specs/037-entry-type-classification/plan.md`,
      `specs/037-entry-type-classification/tasks.md`
- [x] Confirm no backend API, generated backend client, app-lock, capture
      privacy, startup, or deployment behavior changed intentionally
- [x] Stop after implementation and wait for external `review.md`, unless the
      user explicitly skips review

### Group 10: Review and fix

Handle external review after implementation.

- [x] Read `review.md` and prepare a remediation plan without changing files
- [x] Present the remediation plan and wait for approval before making any
      changes
- [x] Implement approved review fixes and update `spec.md`, `plan.md`,
      `tasks.md`, `implementation.md`, code, and tests when review changes
      scope, approach, or validation
- [ ] Repeat the review/fix loop if the same `review.md` file is updated for
      another pass

### Group 11: Finalization

Handle durable documentation follow-up and closeout.

- [x] Decide whether this entry-type story produced durable guidance for
      `AGENTS.md`, `docs/application-description.md`, or
      `docs/agent-findings.md`
- [x] If durable guidance is needed, propose exact documentation updates to the
      user
- [x] Wait for explicit approval before editing long-lived guidance documents
- [x] Record whether the knowledge-capture gate resulted in updates or an
      explicit no-update decision
- [x] Mark `spec.md` status `Complete` only after implementation, validation,
      review/fix handling, and knowledge capture are complete

## Completion criteria

All tasks checked, validation evidence documented, review handled or explicitly
skipped, and the final knowledge-capture gate handled.

## Validation evidence

Record test results, screenshots, command output, approved exceptions, Android
emulator evidence, iOS simulator evidence, and review-related notes here during
implementation.

```text
Source cleanup:
- `rg -n "isDraft|is_draft" lib test integration_test`
  Current hits are limited to legacy-file isolation tests plus historical
  spec/review text. No app runtime path still uses `isDraft`/`is_draft` as a
  source of truth.

Generation and host validation:
- `dart run build_runner build --delete-conflicting-outputs`
  Result: passed; this build_runner version reported that
  `--delete-conflicting-outputs` was ignored, but Drift generation completed and
  `lib/data/entries/local_entry_database.g.dart` was regenerated.
- `dart format lib/data/entries/local_entry_database.dart lib/domain/usecase/retry_pending_drafts_use_case.dart test/data/entries/entry_database_test.dart test/data/entries/entry_repository_impl_test.dart`
  Result: passed.
- `flutter analyze`
  Result: passed.
- `flutter test test/data/entries`
  Result: passed.
- `flutter test test/domain/usecase`
  Result: passed.
- `flutter test test/domain/model test/presentation/entries test/presentation/main test/core/router`
  Result: passed.
- Plain host integration command was not reused during review remediation
  because multiple attached devices require explicit `-d` selection in this
  environment. Device-targeted validation below covers the touched flows.

Android emulator verification:
- Target id: `emulator-5554`
- `/opt/homebrew/bin/flutter test -d emulator-5554 integration_test/draft_retry_launch_flow_test.dart integration_test/main_recording_controller_flow_test.dart integration_test/cleanup_transcript_use_case_flow_test.dart integration_test/entry_list_flow_test.dart integration_test/entry_detail_device_smoke_test.dart`
  Result: passed.
- Observed visible behavior through the device smoke suite:
  - saved entries render and open normally
  - draft rows retain the draft label and audio-only retry affordance
  - entry detail edit/back flows remain intact

iOS simulator verification:
- Target id: `491CD949-D3C0-4C4C-A6B9-15BAB1859156`
- `/opt/homebrew/bin/flutter test -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/draft_retry_launch_flow_test.dart integration_test/main_recording_controller_flow_test.dart integration_test/cleanup_transcript_use_case_flow_test.dart integration_test/entry_list_flow_test.dart integration_test/entry_detail_device_smoke_test.dart`
  Result: passed.
- Observed visible behavior through the device smoke suite:
  - saved entries render and open normally
  - draft rows retain the draft label and audio-only retry affordance
  - entry detail edit/back flows remain intact

Review remediation:
- Approved remediation removed the migration path entirely and changed the
  rollout to a fresh-install type-based database file with a constrained `type`
  column.
- Added direct schema-constraint coverage for invalid `type` values.
- Added corrupted current-shape read coverage for unsupported and null `type`
  values.
- Removed the redundant retry-loop draft-type guard.

Knowledge capture:
- Approved durable documentation updates were applied to `AGENTS.md`,
  `docs/application-description.md`, and `docs/agent-findings.md` to record
  the fresh-install `wrait_entries_v2.sqlite` rollout and `Entry.type` as the
  only supported runtime classification source of truth.
```

## Notes

- Completed but editable entries use `EntryType.saved`, not `final`.
- The old `isDraft`/`is_draft` vocabulary may remain only where it is required
  to isolate the legacy pre-US-037 database file in tests, or in historical
  SDD artifacts.
