# Implementation: Entry list text search

> **Feature number:** 046
> **Spec:** [spec.md](spec.md)
> **Plan:** [plan.md](plan.md)
> **Implementation date:** 2026-09-08

## Summary

The entries screen now has a local Search entries field. It filters the
existing newest-first collection as the user types, supports literal
case-insensitive multi-term matching across cleaned text and raw transcripts,
and does not persist, transmit, or log the query.

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
  those two fields.
- Converted the entries screen to a stateful Riverpod consumer so it owns and
  disposes its text controller. The Search entries field does not autofocus.
- Kept the top navigation/import/export controls, placed the field below them,
  and used the filtered collection only for visible rows.
- Added a clear icon and a distinct No matching entries state with a second
  accessible Clear search action.
- Preserved the real all-entries collection for export, so a query never
  narrows exported data.

## Changed files

### Production code

- lib/presentation/entries/entry_list_controller.dart
  - Added transient query and filtered-entry providers.
  - Added the pure ordered multi-term text-matching helper.
- lib/presentation/entries/entry_list_screen.dart
  - Added the search controller, accessible non-autofocused field, clear
    actions, no-results state, and dedicated header/list layout.
  - Kept export bound to the complete collection and existing navigation,
    deletion, import, and row behavior intact.

### Tests

- test/presentation/entries/entry_list_controller_test.dart
  - Added provider and filter coverage for blank input, cross-field all-term
    matching, source order, drafts, and audio-only drafts.
- test/presentation/entries/entry_list_screen_test.dart
  - Added field semantics/focus, live filtering, no-results, clear, reactive
    update, route-reset, deletion, import, and export-scope coverage.
- integration_test/entry_list_flow_test.dart
  - Added a persisted-entry flow that searches synthetic records, verifies
    export scope while filtered, re-enters unfiltered, deletes a match, clears
    a no-results state, and verifies a matching import is visible.

## Privacy and data outcome

Search reads only the in-memory collection already shown on the device. No
query, transcript, or cleaned text is added to logs or sent to a backend.
Entry values and ordering are never modified by filtering. The encrypted
database, API client, CSV contract, native bridges, and domain model are
unchanged.

## Validation evidence

All commands were run from the repository root on 2026-09-08.

### Static and host-side validation

- dart format ran successfully on the five changed Dart files.
- flutter test test/presentation/entries/entry_list_controller_test.dart
  test/presentation/entries/entry_list_screen_test.dart passed: 39 tests.
- flutter analyze passed with no issues.
- flutter test passed: 463 tests.
- git diff --check passed.

### Android emulator

- flutter test -d emulator-5554 integration_test/entry_list_flow_test.dart
  passed: 17 of 17 flows.
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
  search, route-reset, deletion, import, and full-export-scope path on iOS.
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

Implementation and required automated/device validation are complete. The
feature is awaiting an externally authored review.md. No review artifact has
been created or pre-filled.
