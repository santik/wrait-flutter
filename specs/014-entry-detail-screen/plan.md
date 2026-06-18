# Implementation Plan: Entry Detail Screen

> **Feature number:** 014
> **Spec:** [`spec.md`](spec.md)
> **Author:** Codex
> **Date:** 2026-06-16

---

## Approach summary

Replace the `/entry/:id` placeholder with a repository-backed entry-detail
screen that loads exactly one readable entry, redirects invalid or unavailable
entries back to `/entries`, displays localized metadata and readable text,
supports selectable/readable and editable text, shares the displayed text, and
reuses the entry-list deletion confirmation behavior. Editing will auto-save
to `cleanedText` only, update `wordCount`, and leave `rawTranscript`
unchanged. The implementation will add focused presentation helpers and
controller/service seams for auto-save, share, and delete behavior while
preserving the existing entry-list contracts.

## Architecture decisions

| Decision | Choice | Rationale |
| --- | --- | --- |
| Route id validation | Parse `/entry/:id` as a positive integer in router/detail code and redirect invalid ids to `/entries` | Entry ids are integer primary keys. Redirecting invalid ids satisfies the spec and avoids rendering detail UI for impossible entries. |
| Entry loading | Use a Riverpod stream provider family over `EntryRepository.watchEntryById(id)` | The repository already exposes reactive per-entry loading. Watching keeps detail, list, and deletion state consistent without duplicate storage reads. |
| Missing/deleted/unreadable behavior | Redirect to `/entries` when the selected id has no stored entry or has no readable text | The spec requires redirect instead of an unavailable detail state. Audio-only drafts already remain non-navigable from the list and should not become readable in detail. |
| Detail display text | Prefer `cleanedText`; fall back to `rawTranscript` | Matches the spec and existing entry-list preview preference. |
| Edit target | Add a repository operation that updates only `cleanedText` and `wordCount` | Existing cleanup methods also finalize drafts and clear audio metadata. Editing must preserve `rawTranscript` and avoid cleanup side effects. |
| Auto-save behavior | Enter edit mode through an edit affordance, debounce text changes, and persist edits through a single-flight revision-based save pipeline that flushes on back/dispose | This keeps auto-save finite and race-resistant while still satisfying the no explicit Save action requirement. Flushing on exit preserves the latest approved edit revision. |
| Edit failure handling | Keep the current visible edit text, leave the previous stored entry available, log the failure, and show a generic non-sensitive failure message | This avoids a false saved state and gives user feedback without leaking implementation details. |
| Word count | Recalculate word count from edited cleaned text in the repository implementation | Keeping word-count derivation close to persistence preserves consistency with existing save/update methods. |
| Deletion reuse | Extract the existing entry-list confirmation dialog and deletion controller behavior into shared entry deletion helpers used by both list and detail | The spec requires matching wording, semantics, and outcomes. Shared helpers reduce drift between list and detail deletion. |
| Share behavior | Wrap `share_plus` behind an injectable presentation service/provider | `share_plus` is already a dependency. A small service makes success/failure behavior testable without invoking platform UI in widget tests. |
| Date formatting | Create detail-specific formatter helpers using `intl` with locale fallback, mirroring entry-list formatter resilience | The detail screen needs full date/day labels, while the list helper is optimized for compact row labels. A separate helper keeps tests focused. |
| Text selection and editing | Use selectable text in read mode and an editable multiline text field in edit mode | Flutter has native selection/editing behavior. Separating modes prevents accidental edits while keeping copy behavior in read mode. |
| Data schema | No schema migration | Existing `cleanedText`, `rawTranscript`, `wordCount`, and `createdAt` fields satisfy the feature. |

## File changes

| File | Action | Description |
| --- | --- | --- |
| `lib/core/router/app_router.dart` | Modify | Route `/entry/:id` to `EntryDetailScreen`, redirect blank/invalid/non-positive ids to `/entries`, and remove the placeholder detail builder. |
| `lib/domain/repository/entry_repository.dart` | Modify | Add an entry-edit operation that saves cleaned text and word count for one entry. |
| `lib/data/entries/entry_repository_impl.dart` | Modify | Implement the edit operation, recalculate word count, and throw when the target entry is missing. |
| `lib/data/entries/entry_dao.dart` | Modify | Add a DAO update that writes only `cleanedText` and `wordCount`. |
| `lib/data/entries/local_entry_database.g.dart` | Modify | Regenerate Drift code after DAO changes. |
| `lib/presentation/entries/entry_delete_confirmation.dart` | Create | Shared confirmation dialog with the existing title/body, buttons, keys, and semantics labels used by list and detail. |
| `lib/presentation/entries/entry_deletion_controller.dart` | Create | Shared delete controller/provider that logs failures and keeps UI state non-destructive. |
| `lib/presentation/entries/entry_list_screen.dart` | Modify | Replace the screen-local delete dialog with the shared confirmation helper and shared deletion controller. |
| `lib/presentation/entries/entry_list_controller.dart` | Modify | Remove or delegate duplicated deletion handling while preserving sorting provider behavior. |
| `lib/presentation/entries/entry_detail_screen.dart` | Create | Compose loading, redirect, metadata, read/edit text, auto-save, share, delete, and back behavior for one entry. |
| `lib/presentation/entries/entry_detail_controller.dart` | Create | Entry-detail providers/controller for watched entry state, edit auto-save, failure logging, and pending flush on exit. |
| `lib/presentation/entries/entry_detail_formatters.dart` | Create | Pure helpers for readable text selection, full weekday/date labels, and word-count display inputs. |
| `lib/presentation/entries/entry_share_service.dart` | Create | Injectable wrapper around platform sharing and share failure reporting. |
| `lib/main.dart` | No change | Existing provider overrides already allow integration tests to inject a fake share service without changing bootstrap code. |
| `test/data/entries/entry_repository_impl_test.dart` | Modify | Cover the new edit operation, cleaned-text-only updates, word-count recalculation, missing-entry failure, and raw transcript preservation. |
| `test/presentation/entries/entry_detail_formatters_test.dart` | Create | Unit tests for detail readable-text preference and localized full date/day fallback behavior. |
| `test/presentation/entries/entry_detail_controller_test.dart` | Create | Provider/controller tests for auto-save, failure handling, missing-entry redirect signal, and delete/share delegation where practical. |
| `test/presentation/entries/entry_detail_screen_test.dart` | Create | Widget coverage for detail display, edit mode, auto-save, share, delete, redirect, accessibility, and back behavior. |
| `test/presentation/entries/entry_list_screen_test.dart` | Modify | Verify the list still uses the shared delete dialog semantics and delete outcomes. |
| `test/presentation/entries/entry_list_controller_test.dart` | Modify | Adjust or replace delete-controller expectations after shared deletion extraction. |
| `test/core/router/app_router_test.dart` | Modify | Replace placeholder entry-detail expectations with real detail/redirect behavior. |
| `test/presentation/main/main_screen_test.dart` | Modify | Update saved-feedback navigation expectation from placeholder UI to real detail UI. |
| `integration_test/entry_detail_flow_test.dart` | Create | Device/simulator coverage for all in-scope entry-detail user flows. |
| `integration_test/entry_detail_device_smoke_test.dart` | Create | Screenshot-free real-device smoke coverage for the remediated edit/save and route-safety flows. |
| `integration_test/entry_list_flow_test.dart` | Modify | Update row-tap expectations from placeholder detail to real detail and keep existing list delete coverage intact. |
| `integration_test/main_screen_flow_test.dart` | Modify | Update saved-feedback entry-detail expectations if existing integration coverage asserts the placeholder route. |
| `specs/014-entry-detail-screen/implementation.md` | Create later | Record implementation details and validation evidence during implementation. |

## API contract details

No backend HTTP contract changes are required.

Application-facing contracts:

- `/entry/:id` accepts only positive integer ids. Blank, non-integer, and
  non-positive ids redirect to `/entries`.
- The detail screen watches `EntryRepository.watchEntryById(id)`.
- A watched `null` entry redirects to `/entries`.
- An audio-only entry with blank `cleanedText` and blank `rawTranscript`
  redirects to `/entries`.
- The displayed/shareable text is `cleanedText` when it is non-blank,
  otherwise `rawTranscript`.
- Auto-save writes edited text to `cleanedText` and updates `wordCount`.
- Auto-save never mutates `rawTranscript`.
- Delete uses the shared confirmation helper before calling the shared delete
  controller.
- Delete success navigates to `/entries`.
- Delete failure logs the failure, keeps the entry stored, and avoids a false
  deleted state.
- Share uses the displayed text. Share failures show a clear generic message
  without requiring exact wording.

## Data model changes

No persistent schema change is planned.

### Before

```text
Entry {
  id: int
  rawTranscript: String
  cleanedText: String?
  isDraft: bool
  language: String
  createdAt: int
  wordCount: int
  audioPath: String?
}
```

### After

```text
Entry {
  id: int
  rawTranscript: String       // unchanged by editing
  cleanedText: String?        // updated by editing
  isDraft: bool
  language: String
  createdAt: int
  wordCount: int              // updated from edited cleanedText
  audioPath: String?
}
```

### Migration

None. Existing rows already contain the needed columns.

## Test strategy

### Automated tests

| Test case | Type | File |
| --- | --- | --- |
| Router redirects blank, invalid, and non-positive entry ids to `/entries` | Widget | `test/core/router/app_router_test.dart` |
| Router renders real entry detail for a stored readable entry id | Widget | `test/core/router/app_router_test.dart` |
| Entry list row tap opens real entry detail | Widget | `test/presentation/entries/entry_list_screen_test.dart` |
| Main saved feedback opens real entry detail | Widget | `test/presentation/main/main_screen_test.dart` |
| Detail prefers full cleaned text and falls back to full raw transcript | Unit/widget | `test/presentation/entries/entry_detail_formatters_test.dart`, `test/presentation/entries/entry_detail_screen_test.dart` |
| Detail redirects missing/deleted/invalid/unreadable entries to `/entries` | Widget/integration | `test/presentation/entries/entry_detail_screen_test.dart`, `integration_test/entry_detail_flow_test.dart` |
| Detail displays localized full weekday/date and stored word count | Unit/widget | `test/presentation/entries/entry_detail_formatters_test.dart`, `test/presentation/entries/entry_detail_screen_test.dart` |
| Long detail text scrolls | Widget | `test/presentation/entries/entry_detail_screen_test.dart` |
| Read mode text is selectable/copyable where widget APIs can observe selection | Widget | `test/presentation/entries/entry_detail_screen_test.dart` |
| Edit affordance enters edit mode | Widget | `test/presentation/entries/entry_detail_screen_test.dart` |
| Edited text auto-saves without tapping a Save action | Widget/integration | `test/presentation/entries/entry_detail_screen_test.dart`, `integration_test/entry_detail_flow_test.dart` |
| Auto-save writes only `cleanedText` and recalculates `wordCount` | Unit/integration | `test/data/entries/entry_repository_impl_test.dart`, `integration_test/entry_detail_flow_test.dart` |
| Auto-save preserves `rawTranscript` | Unit/integration | `test/data/entries/entry_repository_impl_test.dart`, `integration_test/entry_detail_flow_test.dart` |
| Auto-save failure leaves previous stored text available and shows no false saved state | Unit/widget | `test/presentation/entries/entry_detail_controller_test.dart`, `test/presentation/entries/entry_detail_screen_test.dart` |
| Back control flushes latest edits and returns to `/entries` | Widget/integration | `test/presentation/entries/entry_detail_screen_test.dart`, `integration_test/entry_detail_flow_test.dart` |
| Share action sends currently displayed/edited text through the share service | Widget | `test/presentation/entries/entry_detail_screen_test.dart` |
| Share failure shows a clear generic message and leaves the entry unchanged | Widget | `test/presentation/entries/entry_detail_screen_test.dart` |
| Delete dialog wording, actions, keys, and semantics match entry-list deletion | Widget | `test/presentation/entries/entry_detail_screen_test.dart`, `test/presentation/entries/entry_list_screen_test.dart` |
| Delete cancel keeps the user on detail and leaves the entry stored | Widget/integration | `test/presentation/entries/entry_detail_screen_test.dart`, `integration_test/entry_detail_flow_test.dart` |
| Delete confirm removes the entry and returns to `/entries` | Widget/integration | `test/presentation/entries/entry_detail_screen_test.dart`, `integration_test/entry_detail_flow_test.dart` |
| Delete failure keeps the entry stored and logs without a false deleted state | Unit/widget | `test/presentation/entries/entry_detail_controller_test.dart`, `test/presentation/entries/entry_detail_screen_test.dart` |
| Entry-detail controls and text expose meaningful accessibility labels/actions | Widget | `test/presentation/entries/entry_detail_screen_test.dart` |
| Entry-list deletion still works after shared deletion extraction | Widget/integration | `test/presentation/entries/entry_list_screen_test.dart`, `integration_test/entry_list_flow_test.dart` |

`integration_test/entry_detail_flow_test.dart` will cover every in-scope
entry-detail user flow:

- opening a readable entry from `/entry/:id`
- opening detail from an entry-list row
- cleaned-text display and raw-transcript fallback
- missing/deleted/invalid/unreadable entry redirect to `/entries`
- automatic edit save with `cleanedText` and `wordCount` updates
- `rawTranscript` preservation after edit
- back navigation to `/entries` with latest edits flushed
- share action smoke path with an injectable test share service where platform
  UI cannot be asserted directly
- delete cancel
- delete confirm and return to `/entries`
- long-text scrolling checkpoint

Main-screen saved-feedback navigation is already covered in widget tests and
will be kept there. If existing `integration_test/main_screen_flow_test.dart`
asserts saved-feedback detail navigation, it will be updated to assert the real
detail screen rather than the placeholder.

### Android emulator verification

1. Run the full planned automated integration coverage on an Android emulator:
   `integration_test/entry_detail_flow_test.dart`,
   `integration_test/entry_list_flow_test.dart`, and any updated
   `integration_test/main_screen_flow_test.dart` coverage.
2. Verify runtime screenshots/checkpoints for readable detail, edit mode,
   edited detail after auto-save, delete confirmation, post-delete entry list,
   and missing-entry redirect.
3. Record command output and screenshot checkpoint names in `tasks.md` and
   `implementation.md`.

### iOS simulator verification

1. Run the full planned automated integration coverage on an iOS simulator:
   `integration_test/entry_detail_flow_test.dart`,
   `integration_test/entry_list_flow_test.dart`, and any updated
   `integration_test/main_screen_flow_test.dart` coverage.
2. Verify runtime screenshots/checkpoints for readable detail, edit mode,
   edited detail after auto-save, delete confirmation, post-delete entry list,
   and missing-entry redirect.
3. Record command output and screenshot checkpoint names in `tasks.md` and
   `implementation.md`.

### Validation exception request

None requested. This feature is expected to satisfy the default
`integration_test`, Android emulator, and iOS simulator verification
requirements.

## Review and finalization

- `review.md` will be externally authored if review occurs.
- After reading `review.md`, no files may be changed until the remediation plan
  is explicitly approved.
- This feature is likely to require durable updates to:
  - `docs/application-description.md` because `/entry/:id` will become a real
    detail/edit/share/delete surface rather than a placeholder.
  - `docs/agent-findings.md` because reusable entry-detail, edit auto-save,
    share service, and shared deletion guidance will matter for future entry
    management stories.
- `AGENTS.md` changes are not expected unless implementation reveals durable
  workflow or architecture guidance.

## Integration notes

- Entry list navigation remains `/entry/<id>` for readable entries.
- Audio-only draft rows remain non-navigable and are still handled by US-013
  list behavior.
- Main-screen saved feedback keeps navigating to `/entry/<id>` but now lands on
  real detail content.
- Entry-list deletion and detail deletion will share confirmation behavior and
  delete failure handling.
- Editing affects entry-list previews because previews prefer `cleanedText`.
- Sharing uses the already-declared `share_plus` dependency through an
  injectable wrapper.
- No backend API generation or OpenAPI contract changes are required.

## Rollout & migration

The feature rolls out as the new `/entry/:id` route implementation. No feature
flag or data migration is planned. Existing rows remain compatible. Entries
without cleaned text can still be displayed through `rawTranscript`, and the
first edit creates/updates `cleanedText` while preserving `rawTranscript`.

## Risks & mitigations

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| Auto-save writes too often while typing | Medium | Medium | Debounce edit saves and flush only pending latest text on exit/dispose. |
| Auto-save race overwrites newer text with stale text | Medium | High | Track latest requested text in the controller and ignore stale completions where needed. |
| Editing accidentally mutates `rawTranscript` or finalizes drafts | Low | High | Add repository tests proving only `cleanedText` and `wordCount` change. Avoid cleanup-specific update methods. |
| Missing-entry redirect fires before a stream has loaded | Medium | Medium | Distinguish loading from loaded-null state in the detail screen tests. |
| Detail delete behavior drifts from list delete behavior | Low | Medium | Extract shared confirmation/deletion helpers and cover both list and detail tests. |
| Share plugin behavior is hard to assert in tests | Medium | Medium | Use an injectable share service and limit integration tests to an app-level smoke path. |
| Long editable text causes layout overflow | Medium | Medium | Use scrollable detail content, multiline editing, and widget tests for long entries. |
| Platform text selection behavior differs across Android/iOS | Medium | Low | Use Flutter-native selectable/editable text widgets and verify on both emulator and simulator. |
| Generated Drift code gets stale | Low | High | Run build/code generation after DAO changes and include generated file diff in implementation. |

## Open items from spec

None. The spec has no open questions.
