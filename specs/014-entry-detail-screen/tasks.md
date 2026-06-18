# Tasks: Entry Detail Screen

> **Feature number:** 014
> **Plan:** [`plan.md`](plan.md)
> **Author:** Codex
> **Date:** 2026-06-16

---

## Legend

- `[ ]` — not started
- `[x]` — complete
- `[P]` — can be parallelized with other `[P]` tasks in the same group
- `[B]` — blocked (note the blocker)

## Task groups

Tasks are organized into sequential groups. Tasks within the same group marked
`[P]` can be worked on in parallel after their group prerequisites are met.

### Group 1: Storage and Domain Contract

Add the persistence operation required for automatic entry editing.

- [x] Add `updateCleanedTextOnly` or equivalent edit operation to the entry
      repository contract — `lib/domain/repository/entry_repository.dart`
- [x] Add DAO update that writes only `cleanedText` and `wordCount` for one
      entry — `lib/data/entries/entry_dao.dart`
- [x] Implement repository edit operation with word-count recalculation,
      missing-entry failure, and raw-transcript preservation —
      `lib/data/entries/entry_repository_impl.dart`
- [x] Regenerate Drift output after DAO changes —
      `lib/data/entries/local_entry_database.g.dart`
- [x] Add repository tests for cleaned-text-only edit, word-count
      recalculation, missing-entry failure, and raw-transcript preservation —
      `test/data/entries/entry_repository_impl_test.dart`

### Group 2: Shared Entry Actions

Extract reusable deletion behavior and add the share abstraction before the
detail screen consumes them.

- [x] Create shared delete confirmation dialog with existing title, body,
      action labels, keys, and semantics — `lib/presentation/entries/entry_delete_confirmation.dart`
- [x] Create shared entry deletion controller/provider that logs failures and
      keeps UI state non-destructive —
      `lib/presentation/entries/entry_deletion_controller.dart`
- [x] Refactor entry-list deletion to use the shared confirmation dialog and
      deletion controller — `lib/presentation/entries/entry_list_screen.dart`
- [x] Adjust or remove duplicated delete handling while preserving newest-first
      sorting provider behavior — `lib/presentation/entries/entry_list_controller.dart`
- [x] Create injectable share service/provider over `share_plus` —
      `lib/presentation/entries/entry_share_service.dart`
- [x] Add integration-test bootstrap support for overriding the share service
      when a platform share sheet cannot be asserted directly — existing
      provider-override harness support (no `lib/main.dart` change required)
- [x] Update entry-list deletion tests for the shared dialog/controller —
      `test/presentation/entries/entry_list_screen_test.dart`
- [x] Update entry-list controller tests after shared deletion extraction —
      `test/presentation/entries/entry_list_controller_test.dart`

### Group 3: Entry Detail Foundation

Build detail-specific formatting, state, and controller behavior.

- [x] Create detail formatter helpers for readable text preference, full
      weekday/date labels, locale fallback, and word-count display inputs —
      `lib/presentation/entries/entry_detail_formatters.dart`
- [x] Add formatter unit tests for cleaned-text preference, raw-transcript
      fallback, blank/unreadable detection, localized date labels, and fallback
      formatting — `test/presentation/entries/entry_detail_formatters_test.dart`
- [x] Create detail providers/controller for watched entry state,
      loaded-null/unreadable redirect signal, edit mode, debounced auto-save,
      flush-on-exit, save failure logging, share delegation, and delete
      delegation — `lib/presentation/entries/entry_detail_controller.dart`
- [x] Add controller/provider tests for auto-save success, auto-save failure,
      stale save protection, flush-on-exit, missing/unreadable redirect signal,
      share delegation, and delete delegation —
      `test/presentation/entries/entry_detail_controller_test.dart`

### Group 4: Entry Detail Screen and Routing

Replace the placeholder route with the user-facing detail experience.

- [x] Create entry-detail screen with header back/edit/share/delete controls,
      localized date metadata, word count, selectable read mode, multiline edit
      mode, scrollable long text, auto-save feedback, generic share failure
      feedback, and accessibility labels —
      `lib/presentation/entries/entry_detail_screen.dart`
- [x] Route `/entry/:id` to real detail, parse only positive integer ids, and
      redirect blank/invalid/non-positive ids to `/entries` —
      `lib/core/router/app_router.dart`
- [x] Redirect loaded missing, deleted, and unreadable entries from detail to
      `/entries` without crashing — `lib/presentation/entries/entry_detail_screen.dart`
- [x] Wire shared delete confirmation so Cancel keeps the user on detail and
      Delete removes the entry then returns to `/entries` —
      `lib/presentation/entries/entry_detail_screen.dart`
- [x] Wire share action to send the currently displayed or edited text through
      the share service — `lib/presentation/entries/entry_detail_screen.dart`
- [x] Update router tests from placeholder expectations to real detail and
      redirect behavior — `test/core/router/app_router_test.dart`
- [x] Update main-screen saved-feedback navigation test to expect real entry
      detail UI — `test/presentation/main/main_screen_test.dart`
- [x] Update entry-list row-tap widget test to expect real entry detail UI —
      `test/presentation/entries/entry_list_screen_test.dart`

### Group 5: Detail Widget Coverage

Prove the user-facing detail screen behavior at widget level.

- [x] Add widget tests for cleaned-text display, raw-transcript fallback,
      localized date/day, stored word count, and long-text scrolling —
      `test/presentation/entries/entry_detail_screen_test.dart`
- [x] Add widget tests for selectable read mode and edit affordance entering
      multiline edit mode — `test/presentation/entries/entry_detail_screen_test.dart`
- [x] Add widget tests for automatic edit save without a Save action,
      flushed edits on back, save failure behavior, and previous stored text
      remaining available — `test/presentation/entries/entry_detail_screen_test.dart`
- [x] Add widget tests for share success delegation, share failure message, and
      unchanged entry data after share failure —
      `test/presentation/entries/entry_detail_screen_test.dart`
- [x] Add widget tests for delete dialog wording, action labels, keys,
      destructive semantics, Cancel behavior, Delete behavior, delete failure,
      and post-delete navigation — `test/presentation/entries/entry_detail_screen_test.dart`
- [x] Add widget tests for missing/deleted/invalid/unreadable redirects and
      meaningful accessibility labels/actions —
      `test/presentation/entries/entry_detail_screen_test.dart`

### Group 6: Integration Coverage

Cover every in-scope user flow through real app wiring and local storage.

- [x] Create `entry_detail_flow_test.dart` harness using the local encrypted
      entry database test setup — `integration_test/entry_detail_flow_test.dart`
- [x] Cover direct `/entry/:id` open for a readable entry —
      `integration_test/entry_detail_flow_test.dart`
- [x] Cover opening detail from an entry-list row —
      `integration_test/entry_detail_flow_test.dart`
- [x] Cover cleaned-text display and raw-transcript fallback —
      `integration_test/entry_detail_flow_test.dart`
- [x] Cover missing, deleted, invalid, and unreadable entry redirect to
      `/entries` — `integration_test/entry_detail_flow_test.dart`
- [x] Cover automatic edit save to `cleanedText`, updated `wordCount`, and
      preserved `rawTranscript` — `integration_test/entry_detail_flow_test.dart`
- [x] Cover back navigation to `/entries` with latest edits flushed —
      `integration_test/entry_detail_flow_test.dart`
- [x] Cover share action smoke path through injectable test share service —
      `integration_test/entry_detail_flow_test.dart`
- [x] Cover delete Cancel and delete Confirm flows —
      `integration_test/entry_detail_flow_test.dart`
- [x] Cover long-text scrolling checkpoint —
      `integration_test/entry_detail_flow_test.dart`
- [x] Update entry-list integration row-tap expectation from placeholder detail
      to real detail and keep delete coverage intact —
      `integration_test/entry_list_flow_test.dart`
- [x] Update main-screen integration saved-feedback detail expectation if the
      existing file asserts placeholder detail —
      `integration_test/main_screen_flow_test.dart`

### Group 7: Validation

Run the planned automated and device/simulator checks, recording evidence as
they complete.

- [x] Run code generation after DAO changes and confirm generated files are
      up to date
- [x] Run Dart formatting on changed Dart files
- [x] Run `flutter analyze`
- [x] Run `flutter test`
- [x] Run targeted detail/list/router/main widget and repository tests if a
      narrower debugging pass is needed
- [x] Run Android emulator integration coverage for
      `integration_test/entry_detail_flow_test.dart`,
      `integration_test/entry_list_flow_test.dart`, and any updated
      `integration_test/main_screen_flow_test.dart`
- [x] Capture Android runtime screenshot checkpoints for readable detail, edit
      mode, edited detail after auto-save, delete confirmation, post-delete
      entry list, and missing-entry redirect
- [x] Run iOS simulator integration coverage for
      `integration_test/entry_detail_flow_test.dart`,
      `integration_test/entry_list_flow_test.dart`, and any updated
      `integration_test/main_screen_flow_test.dart`
- [x] Capture iOS runtime screenshot checkpoints for readable detail, edit
      mode, edited detail after auto-save, delete confirmation, post-delete
      entry list, and missing-entry redirect
- [x] Record validation command output, screenshot checkpoint names, and any
      approved exceptions in this file and `implementation.md`

### Group 8: Review and Fix

Handle external review after implementation.

- [x] Create `implementation.md` with implementation notes and validation
      evidence — `specs/014-entry-detail-screen/implementation.md`
- [ ] Stop and wait for external `review.md`, unless the user explicitly
- [x] Stop and wait for external `review.md`, unless the user explicitly
      skips review
- [x] Read `review.md` and prepare a remediation plan without changing files
- [x] Present the remediation plan and wait for approval before making any
      changes
- [x] Implement approved review fixes and update `spec.md`, `plan.md`,
      `tasks.md`, `implementation.md`, code, and tests when review changes
      scope, approach, or validation
- [ ] Repeat the review/fix loop if the same `review.md` file is updated for
      another pass

### Group 9: Finalization

Handle durable documentation follow-up and closeout.

- [x] Decide whether US-014 produced durable learnings or long-lived
      product/architecture changes worth preserving
- [x] Propose updates to `docs/application-description.md` for the real
      `/entry/:id` detail/edit/share/delete surface
- [x] Propose updates to `docs/agent-findings.md` for reusable entry-detail,
      auto-save, share-service, and shared-deletion guidance
- [x] Decide whether `AGENTS.md` needs any durable workflow or architecture
      guidance update
- [x] Wait for explicit approval before editing long-lived guidance documents
- [x] Record whether the knowledge-capture gate resulted in updates or an
      explicit no-update decision
- [x] Mark `spec.md` status as `Complete` only after implementation, review,
      validation, and final knowledge-capture gates are handled

## Completion criteria

All tasks checked, validation evidence documented, review handled or explicitly
skipped, and the final knowledge-capture gate handled.

## Validation evidence

Record test results, screenshots, command output, approved exceptions, or
review-related notes here when complete.

```text
2026-06-16

- `dart run build_runner build --delete-conflicting-outputs`
  - Passed. Drift outputs were refreshed and remained compatible with the repo.
  - Note: current build_runner prints that `--delete-conflicting-outputs` is ignored in this setup.
- `dart format lib/... test/... integration_test/...`
  - Passed for all changed Dart files in the US-014 scope.
- `flutter analyze`
  - Passed with no issues.
- `npm run build`
  - Passed. Required to regenerate `tool/openapi-generator/output/backend_api/` before a full Flutter test sweep.
- `flutter test`
  - Passed. Full repository test suite finished green after the OpenAPI generation prerequisite.
- Focused debug pass:
  - `flutter test test/presentation/entries/entry_detail_screen_test.dart test/presentation/entries/entry_detail_controller_test.dart test/presentation/entries/entry_detail_formatters_test.dart test/data/entries/entry_repository_impl_test.dart`
  - Passed.
- Android emulator (`emulator-5554`)
  - `flutter test integration_test/entry_detail_flow_test.dart -d emulator-5554`
  - `flutter test integration_test/entry_list_flow_test.dart integration_test/main_screen_flow_test.dart -d emulator-5554`
  - Passed.
- iOS simulator (`491CD949-D3C0-4C4C-A6B9-15BAB1859156`)
  - `flutter test integration_test/entry_detail_flow_test.dart integration_test/entry_list_flow_test.dart integration_test/main_screen_flow_test.dart -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156`
  - Passed.
- Connected Android device (`4A181FDJH0030G`, Pixel 8)
  - `flutter test integration_test/entry_detail_device_smoke_test.dart -d 4A181FDJH0030G`
  - Passed.

Screenshot checkpoints captured during integration runs:

- Android detail: `entry-detail-readable`, `entry-detail-long-after-scroll`, `entry-detail-invalid-redirect`, `entry-detail-missing-redirect`, `entry-detail-unreadable-redirect`, `entry-detail-edit-mode`, `entry-detail-edited-back-to-list`, `entry-detail-delete-confirmation`, `entry-detail-after-delete`
- Android list/main updates: existing `entry-list-*` and `main-screen-*` checkpoints from the updated integration files
- iOS detail/list/main: same checkpoint names as the corresponding integration tests above

Notes:

- US-014 implementation reused the existing provider-override test harness support for share-service injection, so no `lib/main.dart` change was required to satisfy the integration-share smoke coverage.
- Review remediation replaced the original open-ended auto-save drain loop with a revision-based single-flight save sequence and added explicit real-device smoke coverage without screenshot capture.
- Knowledge-capture gate outcome:
  - Updated `docs/application-description.md`
  - Updated `docs/agent-findings.md`
  - No `AGENTS.md` update was needed
- Android builds emit existing plugin warnings about Kotlin Gradle Plugin migration for `package_info_plus`, `share_plus`, `speech_to_text`, and `wakelock_plus`; these warnings did not block the feature validation run.
```

## Notes

- No validation exception is planned. Android emulator and iOS simulator
  verification are required before final approval.
- Entry editing must update only `cleanedText` and `wordCount`; it must not
  mutate `rawTranscript`.
- Deletion confirmation behavior must remain shared between entry list and
  entry detail.
