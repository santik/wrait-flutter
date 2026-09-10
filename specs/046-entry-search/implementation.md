# Implementation: Entry list text search

> **Feature number:** 046
> **Spec:** [spec.md](spec.md)
> **Plan:** [plan.md](plan.md)
> **Implementation date:** 2026-09-08

## Summary

The entries screen now has a local Search entries field. It filters the
existing newest-first collection as the user types, supports literal
case-insensitive multi-term matching across cleaned text and raw transcripts,
does not persist, transmit, or log the query. Pressing the keyboard Search
action dismisses focus while preserving the active query and results.

The first version intentionally remains presentation-layer filtering rather
than database full-text search. It therefore adds no schema, repository,
backend, API, CSV, dependency, or migration change.

## Design delivered

- Added an auto-disposed query provider scoped to the entries screen. Leaving
  the route disposes the query, so returning starts with the full collection.
- Added a derived filtered-entry provider and a pure filter helper. It trims
  and whitespace-splits the query, lower-cases literal terms, requires every
  term to occur in either cleaned text or raw transcript, and preserves the
  incoming newest-first order. A term cannot match across the boundary between
  those two fields. Dart's default case conversion is intentionally used; full
  locale-aware Unicode case folding remains a future internationalization
  decision.
- Converted the entries screen to a stateful Riverpod consumer so it owns and
  disposes its text controller. The Search entries field does not autofocus.
- Refined the header into one compact row: Back sits at the leading edge, the
  expanded Search entries field sits between the actions, and adjacent
  normal-sized Import/Export actions sit at the trailing edge. The list keeps
  its normal content insets, and only the filtered collection drives visible
  rows.
- Added a clear icon and a distinct No matching entries state with a second
  accessible Clear search action.
- Added a Search-key completion behavior that dismisses the keyboard without
  clearing the query or changing the result set.
- Preserved the real all-entries collection for export, so a query never
  narrows exported data.

## Changed files

### Production code

- lib/presentation/entries/entry_list_controller.dart
  - Added transient query and filtered-entry providers.
  - Added the pure ordered multi-term text-matching helper and a documented
    case-folding limitation.
- lib/presentation/entries/entry_list_screen.dart
  - Added the search controller, accessible non-autofocused field, clear
    actions, Search-key focus dismissal, no-results state, and dedicated
    header/list layout.
  - Kept export bound to the complete collection and existing navigation,
    deletion, import, and row behavior intact.

### Tests

- test/presentation/entries/entry_list_controller_test.dart
  - Added provider and filter coverage for blank input, cross-field all-term
    matching, source order, drafts, audio-only drafts, punctuation, emoji,
    repeated terms, SQL-shaped input, and a long query.
- test/presentation/entries/entry_list_screen_test.dart
  - Added field semantics/focus, live filtering, no-results, clear, reactive
    update, route-reset, deletion, import, export-scope, and compact-header
    geometry coverage, plus Search-key focus dismissal.
- integration_test/entry_list_flow_test.dart
  - Added a persisted-entry flow that searches synthetic records, verifies
    export scope while filtered, dismisses focus on Search, re-enters
    unfiltered, deletes a match, clears a no-results state, and verifies a
    matching import is visible.
- integration_test/orientation_lock_flow_test.dart
  - Replaced its invalid direct paused-to-resumed lifecycle jump with the
    platform-valid inactive, hidden, paused, hidden, inactive, resumed
    sequence. The new search field exposed this latent test-fixture issue
    because Flutter EditableText registers an AppLifecycleListener.

## Privacy and data outcome

Search reads only the in-memory collection already shown on the device. No
query, transcript, or cleaned text is added to logs or sent to a backend.
Entry values and ordering are never modified by filtering. The encrypted
database, API client, CSV contract, native bridges, and domain model are
unchanged.

### SQL-injection assessment

The search query has no SQL-injection surface in this implementation. It flows
from the `TextField` to `entryListSearchQueryProvider`, then into
`EntryListController.filterEntries`, which uses Dart `String.contains` on the
already materialized `List<Entry>`. The query is not passed to the repository
or DAO.

`EntryDao.watchAllEntries()` retains a fixed Drift `select(entryRecords)` query
ordered by `createdAt`; it accepts no search argument. The database module's
raw `sqlite_master` and `PRAGMA cipher` checks are fixed literals unrelated to
search. The SQL-shaped-input regression test therefore verifies literal search
behavior, while the provider-to-Dart-filter boundary prevents construction or
execution of SQL from user input.

## Validation evidence

Commands were run from the repository root on 2026-09-08 and 2026-09-09.

### Static and host-side validation

- dart format ran successfully on the five changed Dart files.
- flutter test test/presentation/entries/entry_list_controller_test.dart
  test/presentation/entries/entry_list_screen_test.dart passed: 39 tests.
- flutter analyze passed with no issues.
- flutter test passed: 463 tests.
- git diff --check passed.
- Post-implementation regression correction on 2026-09-09:

    flutter test -d 4A181FDJH0030G integration_test/orientation_lock_flow_test.dart

  passed on the same Android phone that originally reported the failure.
  This change affects only the integration test's lifecycle simulation; it
  does not modify production search behavior.
- Compact-header refinement on 2026-09-09:

    dart format lib/presentation/entries/entry_list_screen.dart test/presentation/entries/entry_list_screen_test.dart
    flutter test test/presentation/entries/entry_list_controller_test.dart test/presentation/entries/entry_list_screen_test.dart
    flutter analyze

  all passed; the targeted test command completed 40 tests.
- Approved review remediation on 2026-09-09:

    dart format lib/presentation/entries/entry_list_controller.dart lib/presentation/entries/entry_list_screen.dart test/presentation/entries/entry_list_controller_test.dart test/presentation/entries/entry_list_screen_test.dart integration_test/entry_list_flow_test.dart
    flutter test test/presentation/entries/entry_list_controller_test.dart test/presentation/entries/entry_list_screen_test.dart
    flutter analyze
    flutter test

  passed; the focused suite completed 42 tests and the full suite completed
  466 tests.

### Android emulator

- flutter test -d emulator-5554 integration_test/entry_list_flow_test.dart
  passed: 17 of 17 flows.
- The compact-header refinement reran the same Android entry-list flow on
  2026-09-09 and passed all 17 flows. The first post-change emulator attempt
  stalled before Flutter rendered a frame; after an emulator restart, the
  rerun installed normally and completed all assertions.
- The approved review remediation reran the entry-list flow on 2026-09-09 and
  passed all 17 flows, including Search-key focus dismissal.
- flutter build apk --debug completed successfully.
- Launcher-style cold start of the actual debug identity succeeded:

    adb -s emulator-5554 shell am start -W -n com.wrait.flutter.dev/com.wrait.flutter.MainActivity

  It returned Status: ok with LaunchState: COLD.
- Direct accessibility inspection showed an initially unfocused Search entries
  edit field. Focusing it and entering the synthetic query nomatch produced
  the accessible Clear search control while the IME compressed the list area.
  Activating Clear search removed both the query and control.
- The passed integration flow provides the persisted raw-text, cleaned-text,
  saved/draft, audio-only-draft, no-results, navigation, deletion, import, and
  full-scope export evidence with synthetic data.

### iOS simulator

- flutter test -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156
  integration_test/entry_list_flow_test.dart passed: 17 of 17 flows.
- flutter build ios --debug --simulator completed successfully.
- The simulator integration flow exercised the same synthetic persisted-data
  search, Search-key focus dismissal, route-reset, deletion, import, and
  full-export-scope path on iOS.
- The approved review remediation reran the iOS entry-list flow on 2026-09-09
  and passed all 17 flows.
- A normal direct launch of the built simulator app reached the expected
  system iPhone passcode prompt before Wrait UI. Existing secure startup
  behavior was not weakened or bypassed. Direct normal-app keyboard imagery is
  therefore not claimed; the real simulator integration suite is the iOS
  behavioral evidence.

## Validation limitations

The native Android and iOS document picker dialogs are not automated by the
repo-local integration harness. Import behavior is verified through its
injected reader and the real entries screen, but picker interaction itself is
not claimed. The intentionally excluded full-text index, ranking, fuzzy
matching, metadata filters, query persistence, and backend search remain
future work rather than limitations of this approved first version.

## Review status

The external review was read on 2026-09-09. Its approved remediation is
complete: the Unicode limitation and no-debounce decision are documented,
Search dismisses focus, boundary coverage is added, the user-approved
orientation-fixture correction is retained, and the SQL-injection boundary is
recorded. The external review file was not modified.

## Finalization

On 2026-09-10, the user approved durable documentation updates. `AGENTS.md`
now preserves the presentation-only/no-SQL search boundary and the Unicode
case-folding constraint; `docs/application-description.md` records the
user-visible local search capability; and `docs/agent-findings.md` records the
implementation boundary and Search-key behavior.
