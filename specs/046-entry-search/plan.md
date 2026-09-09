# Implementation Plan: Entry list text search

> **Feature number:** 046
> **Spec:** [`spec.md`](spec.md)
> **Author:** Codex
> **Date:** 2026-09-08

---

## Approach summary

Keep the existing reactive, newest-first entry list as the source collection
and add a screen-local query that filters that collection in the presentation
layer. The entries screen will render a non-autofocused text field beneath its
existing navigation and import/export controls, show either the filtered rows,
the established empty state, or a clearable no-results state, and continue to
use the unfiltered collection for export. The implementation deliberately adds
no persistence, API, database, or dependency change; it is the smallest path
that fulfils the approved search contract while preserving a future option to
replace the local matching implementation.

## Architecture decisions

| Decision | Choice | Rationale |
| --- | --- | --- |
| Search data source | Filter the existing `entryListEntriesProvider` output in the presentation layer | The list already receives every current entry and applies newest-first ordering there. Reusing it avoids a new repository method, database migration, or duplicate reactive data path. |
| Query lifetime | An auto-disposed Riverpod string state scoped to the entries screen | The finalized spec requires the query to reset after leaving `/entries`. Auto-disposal supplies that behavior without persisting user text or adding reset lifecycle code. |
| Matching contract | Split trimmed input on whitespace; lower-case each term and each searchable field; retain an entry only when every term occurs in cleaned text, raw transcript, or both | This directly implements the agreed literal, case-insensitive all-term behavior without allowing a term to span the boundary between the two fields. Punctuation keeps no special meaning. |
| Matching execution | Filter immediately on query changes; do not debounce | Filtering the collection already displayed by the screen is synchronous and local. Debouncing adds state, timing edge cases, and test complexity without a user-visible need in this intentionally small version. |
| Sorting | Sort first through the existing provider, then preserve that order while filtering | It maintains the established newest-first list behavior rather than introducing relevance ranking. |
| Screen ownership | Convert `EntryListScreen` to a `ConsumerStatefulWidget` with a text controller used only by the field | A controller makes the clear action reset both the visible field and query state reliably. It is disposed with the screen, and `autofocus` remains disabled. |
| UI layout | Place the existing back/import/export controls and the search field in a normal top section above an expanded list area | This prevents the field, keyboard, and list content from competing in the current overlay layout, while retaining existing navigation and action controls. |
| Export scope | Keep `allEntries` separate from `filteredEntries` and pass only `allEntries` to export | Export must remain a full collection export even when the visible list is filtered. The explicit separation prevents an accidental behavior change. |
| Storage/search index | No database search index, schema migration, or model change | The spec explicitly excludes storage changes. An indexed full-text implementation would introduce migration and cross-platform database validation beyond this first version. |
| Privacy/diagnostics | Do not add query/content logging | Search terms and entries are private journal data; the feature needs no observability beyond existing sanitized error handling. |

## File changes

| File | Action | Description |
| --- | --- | --- |
| `lib/presentation/entries/entry_list_controller.dart` | Modify | Add the auto-disposed search-query and filtered-entry providers plus pure whitespace-token, case-insensitive filtering that preserves incoming ordering. |
| `lib/presentation/entries/entry_list_screen.dart` | Modify | Add the screen-local text controller, non-autofocused accessible search field, clear control, no-results state, constrained header/list layout, and full-collection export input. |
| `test/presentation/entries/entry_list_controller_test.dart` | Modify | Cover query normalization and pure filtering behavior, including both text fields, drafts, audio-only drafts, all-term matching, and ordering. |
| `test/presentation/entries/entry_list_screen_test.dart` | Modify | Cover field rendering/focus, live filtering, no-results/clear behavior, semantics, reactive list changes, matching-row navigation/deletion, and full-scope export while filtered. |
| `integration_test/entry_list_flow_test.dart` | Modify | Exercise the real local entry store and entries route for search, clear, matching-row interaction, no-result recovery, and import/export scope under an active query. |
| `specs/046-entry-search/spec.md` | Modify | Record the approved specification status. |
| `specs/046-entry-search/plan.md` | Modify | Record the approved implementation approach and validation plan. |

No change is planned for the entry repository, DAO, encrypted database,
domain entry model, router, native Android/iOS code, dependencies, CSV
contract, or backend API.

## API contract details

No HTTP API contract is added or changed.

The internal presentation contract will be:

```text
entryListSearchQueryProvider -> current unpersisted query String
entryListFilteredEntriesProvider -> current newest-first entries filtered by query
EntryListController.filterEntries(entries, query) -> ordered matching entries
```

`filterEntries` will:

1. Trim the query and split it on one-or-more whitespace characters.
2. Return the source list unchanged when no non-empty terms remain.
3. Compare every lower-cased literal term independently against the lower-cased
   `cleanedText` (when present) and `rawTranscript` values of the same entry.
4. Return an entry only when every term occurs in at least one of those two
   searchable text values; a term must not match by spanning their boundary.
5. Retain source ordering and never mutate the source list or entry values.

No parsing syntax, phrase operator, fuzzy matching, accent normalization,
ranking, logging, backend request, or user-visible error state is introduced.

## Data model changes

No persisted data model change is planned.

### Before

```text
Entry {
  id, rawTranscript, cleanedText, type, language, createdAt, wordCount, audioPath
}

Encrypted entries database: unchanged
```

### After

```text
Entry {
  id, rawTranscript, cleanedText, type, language, createdAt, wordCount, audioPath
}

Encrypted entries database: unchanged
```

### Migration

None. The query is transient UI state and no existing entry needs to be read,
rewritten, indexed, or migrated.

## Test strategy

The in-scope user flow is: a user opens the entries list, enters a query,
reviews the matching newest-first records, clears a no-result or active query,
and continues to use existing row/import/export actions without changing the
underlying collection.

### Automated tests

| Test case | Type | File |
| --- | --- | --- |
| Blank and whitespace-only queries retain every incoming entry in newest-first order | Unit/provider | `test/presentation/entries/entry_list_controller_test.dart` |
| Case-insensitive all-term filtering matches terms in cleaned text, raw transcript, or a combination of both and preserves source order | Unit/provider | `test/presentation/entries/entry_list_controller_test.dart` |
| Saved/draft text entries can match, while an audio-only draft only appears for an empty query | Unit/provider | `test/presentation/entries/entry_list_controller_test.dart` |
| The field is visible, does not autofocus, filters as text changes, supports keyboard input, and has labelled search/clear semantics | Widget/accessibility | `test/presentation/entries/entry_list_screen_test.dart` |
| A non-empty unmatched query shows `No matching entries`; clearing restores the full list | Widget | `test/presentation/entries/entry_list_screen_test.dart` |
| Matching readable rows still open, matching rows can still be deleted, and stream-driven import/edit/delete changes refresh visible results | Widget | `test/presentation/entries/entry_list_screen_test.dart` |
| Export includes nonmatching entries while a query is active; import continues to operate on the full collection and matching imports appear reactively | Widget | `test/presentation/entries/entry_list_screen_test.dart` |
| Real `/entries` flow filters persisted saved/draft entries, opens/deletes a match, clears a no-result query, and retains full import/export scope | Integration | `integration_test/entry_list_flow_test.dart` |
| Existing entry-list, entry-detail, import/export, and main-to-entries navigation coverage remains green | Regression | Existing entry presentation tests and integration flows |

All automated entries use synthetic text. No test or runtime evidence may log
real journal content.

### Android emulator verification

1. Build and launch the debug app on the configured phone-sized Android
   emulator, including a launcher-style cold start with
   `adb -s emulator-5554 shell am start -W -n com.wrait.flutter.dev/com.wrait.flutter.MainActivity`.
   The debug package is the relevant target for the debug artifact and
   integration harness; the separate release package is not used for this
   feature validation.
2. Open `/entries`, verify the field is visible but the keyboard stays closed,
   then enter synthetic multi-term queries that exercise raw-text, cleaned-text,
   draft, audio-only-draft, and no-result behavior.
3. With the keyboard open, clear the query, open a matching entry, return to
   the list, delete a matching row, and verify the list remains responsive and
   newest-first.
4. Run the entry-list integration flow and verify that export still contains a
   deliberately nonmatching entry while a query is active. Use the existing
   integration harness for import behavior; do not claim automation of the
   platform document picker itself.
5. Record command output and screenshots or equivalent runtime evidence, with
   only synthetic entry content.

### iOS simulator verification

1. Build and launch the app on the configured iOS simulator and open
   `/entries` through the existing integration harness or normal navigation.
2. Repeat the Android search, keyboard, no-result, clear, matching-row
   navigation, and deletion checks using synthetic entries.
3. Verify the search field and top controls remain usable with the iOS keyboard
   visible, and that returning to the entries list after leaving it starts
   unfiltered.
4. Run the entry-list integration flow and retain test output plus screenshots
   or equivalent runtime evidence. Native document-picker interaction remains
   outside the automated harness and must not be represented as verified.

### Validation exception request

No exception is requested. Android emulator and iOS simulator validation,
including the entry-list integration flow, remain required before final
approval.

## Review and finalization

- `review.md` will be externally authored if review occurs.
- After reading `review.md`, no files may be changed until the remediation plan
  is explicitly approved.
- The implementation will stop after `implementation.md` is complete and wait
  for the external review unless the user explicitly skips it.
- The initial expectation is that this presentation-only feature will not need
  durable updates to `AGENTS.md`, `docs/application-description.md`, or
  `docs/agent-findings.md`. That decision will be re-evaluated after approved
  implementation and review.

## Integration notes

The entries screen remains the only feature boundary. It consumes the existing
entry stream, row callbacks, deletion controller, import service, and export
service without changing their public contracts. The screen will distinguish
the full collection used by import/export from the filtered collection used by
the visible list.

There is no backend, startup, app-lock, native platform, encrypted-database,
or CSV-format integration change. Existing app-lock provider overrides remain
in entry-list tests so they test list behavior rather than authentication.

## Rollout & migration

Ship in a normal Android and iOS app update. No feature flag, remote
configuration, database migration, data reindexing, API deployment, or import
format change is required. Existing installs receive the field on update with
their current entries untouched; fresh installs behave identically once
entries exist.

## Risks & mitigations

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| A filtered list is accidentally passed to export | Medium | High | Keep explicit `allEntries` and `filteredEntries` values in the screen and assert a nonmatching entry is exported in widget and integration coverage. |
| The query survives leaving `/entries` | Low | Medium | Use an auto-disposed provider, screen-owned controller, and widget/runtime coverage that re-enters the list unfiltered. |
| The new field crowds existing controls or becomes obscured by the keyboard | Medium | Medium | Use a dedicated header/list layout instead of competing positioned overlays; verify focus, semantics, and keyboard use on both platforms. |
| A reactive import, edit, or deletion leaves stale visible results | Low | Medium | Derive filtered rows solely from the existing entry stream plus current query; cover stream-driven changes in widget and integration tests. |
| Filtering becomes slow for a much larger journal | Low for the current first-version scope | Medium | Reuse the already materialized list now and retain the functional contract for a future indexed-search story if usage demonstrates a need. |
| Query or journal text appears in logs | Low | High | Add no search logging and keep test/runtime evidence synthetic. |

## Open items from spec

None. The approved spec deliberately defers indexed, fuzzy, language-aware,
and semantic search to future work.
