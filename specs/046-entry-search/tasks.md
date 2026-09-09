# Tasks: Entry list text search

> **Feature number:** 046
> **Plan:** [`plan.md`](plan.md)
> **Author:** Codex
> **Date:** 2026-09-08

---

## Legend

- `[ ]` — not started
- `[x]` — complete
- `[P]` — can be parallelized with other `[P]` tasks in the same group
- `[B]` — blocked (note the blocker)

## Task groups

### Group 1: Feature setup and filtering contract

- [x] Create or confirm the feature branch using the repository/Codex naming
  convention; preserve unrelated worktree changes. Update the feature status to
  `In Progress` only when implementation starts —
  `specs/046-entry-search/spec.md`
- [x] Add the screen-local auto-disposed query provider and the derived
  filtered-entry provider. Add pure filtering helpers that trim/split
  whitespace, compare every lower-cased literal term against cleaned/raw text
  fields independently, require every term, preserve source ordering, and
  never log query/content —
  `lib/presentation/entries/entry_list_controller.dart`

### Group 2: Entries-screen search UI

- [x] Convert the entries list to own and dispose a text controller, retain the
  current back/import/export behaviors, and lay out a non-autofocused search
  field below the top actions without obscuring the scrollable content —
  `lib/presentation/entries/entry_list_screen.dart`
  - Depends on: Group 1 filtering contract
- [x] Render filtered rows while preserving the established `no entries yet`
  state for an actually empty collection. For a non-empty collection with no
  matches, render `No matching entries` and an accessible `Clear search`
  action. Add stable keys and meaningful semantics for the field and clear
  controls — `lib/presentation/entries/entry_list_screen.dart`
  - Depends on: Group 1 filtering contract
- [x] Keep `allEntries` distinct from `filteredEntries`, pass only the former to
  the existing export action, and ensure reactive import/edit/delete changes
  continue to derive the current visible list —
  `lib/presentation/entries/entry_list_screen.dart`
  - Depends on: Group 1 filtering contract

### Group 3: Automated coverage

- [x] [P] Add unit/provider coverage for blank/whitespace queries,
  case-insensitive all-term matching, cleaned/raw cross-field matching,
  saved/draft inclusion, audio-only-draft exclusion under a non-empty query,
  and preserved newest-first ordering —
  `test/presentation/entries/entry_list_controller_test.dart`
  - Depends on: Group 1 filtering contract
- [x] [P] Add widget/accessibility coverage for visible non-autofocused search,
  typing and clear behavior, no-results state, keyboard-safe rendering,
  query reset after leaving/re-entering the screen, matching-row
  navigation/deletion, and reactive result updates —
  `test/presentation/entries/entry_list_screen_test.dart`
  - Depends on: Groups 1–2
- [x] [P] Add widget coverage proving an active query never narrows the
  existing export payload and that a matching import becomes visible while a
  query remains active —
  `test/presentation/entries/entry_list_screen_test.dart`
  - Depends on: Groups 1–2
- [x] Add the persisted-entry integration flow: seed saved/draft entries, run
  a multi-term query, open/delete a matching record, clear a no-result query,
  and verify import/export scope while filtered using synthetic content —
  `integration_test/entry_list_flow_test.dart`
  - Depends on: Groups 1–2

### Group 4: Automated and device validation

- [x] Run `dart format` on all changed Dart files and confirm no unintended
  generated, database, API, CSV, or native-platform files were changed.
- [x] Run the targeted entry-list unit/widget suite, the updated
  `integration_test/entry_list_flow_test.dart`, `flutter analyze`, and the
  appropriate broader regression suite. Record exact commands and outcomes in
  the validation evidence.
  - Depends on: Group 3
- [x] Verify on the Android emulator: launcher-style cold start; non-focused
  field; keyboard open/close; raw/cleaned/draft/audio-only/no-result cases;
  clear; matching-row navigation/deletion; and full-scope export. Use synthetic
  records and document that the system document picker itself is not automated.
  - Depends on: Group 3
- [x] Verify the equivalent flow on the iOS simulator, including keyboard
  layout, re-entering `/entries` unfiltered, row interaction, and full-scope
  export. Use synthetic records and document the native document-picker limit.
  - Depends on: Group 3
- [x] Update acceptance-criteria checkboxes, task statuses, and validation
  evidence with completed automated and dual-platform results —
  `specs/046-entry-search/spec.md`, `specs/046-entry-search/tasks.md`
  - Depends on: all previous validation tasks

### Group 5: Implementation record and external review

- [x] Create `implementation.md` describing the final design, modified files,
  validation commands/results, Android/iOS evidence, known limitations, and
  the no-migration/no-backend outcome —
  `specs/046-entry-search/implementation.md`
  - Depends on: Group 4
- [ ] Stop and wait for an externally authored
  `specs/046-entry-search/review.md`, unless the user explicitly skips review.
- [ ] When `review.md` arrives, read it and prepare a finding-by-finding
  remediation plan without changing files. Present that plan and wait for
  explicit approval before any remediation.
- [ ] Implement only approved remediation, refresh artifacts/code/tests and
  validation evidence when scope, approach, or behavior changes, and repeat
  the review/fix loop if the same review file is updated.

### Group 6: Finalization

- [ ] Decide whether the completed feature creates durable product or
  architecture guidance. If so, propose exact updates to `AGENTS.md`,
  `docs/application-description.md`, and/or `docs/agent-findings.md`; wait for
  explicit approval before editing them.
- [ ] Record the approved documentation outcome (updates or explicit no-update
  decision), mark the feature complete only after review and finalization are
  handled, and update the final status/history —
  `specs/046-entry-search/spec.md`, `specs/046-entry-search/tasks.md`

## Completion criteria

All implementation and validation tasks are checked, validation evidence is
recorded, external review is handled or explicitly skipped, and the final
knowledge-capture gate is completed.

## Validation evidence

```text
2026-09-08 implementation and validation evidence:

- dart format was run on all five changed Dart files.
- flutter test test/presentation/entries/entry_list_controller_test.dart
  test/presentation/entries/entry_list_screen_test.dart passed: 39 tests.
- flutter analyze passed with no issues.
- flutter test passed: 463 tests.
- flutter test -d emulator-5554 integration_test/entry_list_flow_test.dart
  passed: 17 of 17 flows.
- flutter test -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156
  integration_test/entry_list_flow_test.dart passed: 17 of 17 flows.
- Android emulator: the freshly built debug app cold-started successfully as
  com.wrait.flutter.dev; the initial field was unfocused and labelled Search
  entries, a harmless query produced Clear search with the IME-visible layout,
  and clearing restored the empty query state. Synthetic persisted-data
  behavior and full-scope export/import were covered by the passed integration
  flow.
- iOS simulator: the passed real-simulator integration flow covers the
  synthetic persisted-data path. A normal simulator launch additionally reached
  the expected system iPhone passcode prompt before Wrait UI; no unsupported
  security bypass was attempted. The native document picker remains outside
  the integration harness on both platforms.
```

## Notes

- No validation exception has been requested. Android emulator and iOS
  simulator verification are both required before final approval.
- The first version intentionally does not add a database full-text index,
  fuzzy matching, relevance ranking, metadata filters, query persistence, or
  backend search.
