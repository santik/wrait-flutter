# Implementation: Entry Type Classification

> **Feature number:** 037
> **Spec:** [`spec.md`](spec.md)
> **Plan:** [`plan.md`](plan.md)
> **Tasks:** [`tasks.md`](tasks.md)
> **Author:** Codex
> **Date:** 2026-06-29

---

## Summary

US-037 replaces the app's binary entry draft flag with an explicit entry type.
`Entry.isDraft` is removed as the source-of-truth classification and replaced
with `Entry.type`, backed by `EntryType.draft` and `EntryType.saved`.

After external review, the rollout scope changed from migration to fresh
installation. The supported entry store now lives in a new local database file
with a constrained `type` column. Legacy `is_draft` databases are left
untouched instead of being transformed in place.

## Implemented behavior

- The domain entry model now requires `Entry.type` and exposes
  `EntryType.tryParse` for repository-side validation.
- New saved entries persist `type = 'saved'`.
- New text drafts and audio drafts persist `type = 'draft'`.
- Draft completion and cleanup promotion change entries from `draft` to
  `saved`.
- Pending-draft and stale-draft queries only select persisted draft entries.
- The retry flow now relies on the draft-only repository query instead of a
  second redundant type guard inside the retry loop.
- The supported entry schema constrains persisted `type` values to `draft` or
  `saved`.
- The type-based store uses a new database file name so the rollout behaves as
  a fresh local install rather than a legacy-schema migration.
- Corrupted current-shape rows still fail explicitly on read:
  - unsupported string values raise a `StateError` during repository mapping
  - null `type` values fail during row decoding instead of being treated as a
    valid entry category

## Changed files

| File | Change |
| --- | --- |
| `lib/domain/model/entry.dart` | Added `EntryType`, replaced `isDraft` with `type`, and updated `copyWith` plus equality/hash semantics. |
| `lib/data/entries/local_entry_database.dart` | Replaced the old boolean column with constrained `type`, switched the supported store to a fresh-install database file, and removed the migration path. |
| `lib/data/entries/local_entry_database.g.dart` | Regenerated Drift output for the constrained schema. |
| `lib/data/entries/entry_dao.dart` | Switched draft queries and draft/saved writes to the `type` column. |
| `lib/data/entries/entry_repository_impl.dart` | Persisted and mapped `EntryType`, validated persisted type values, and kept draft audio-path handling unchanged. |
| `lib/data/entries/entry_mapper.dart` | Removed the unused stale mapping helper. |
| `lib/domain/usecase/cleanup_transcript_use_case.dart` | Replaced draft checks with `EntryType.draft`. |
| `lib/domain/usecase/retry_pending_drafts_use_case.dart` | Removed the redundant retry-loop draft-type guard and kept retry behavior driven by the draft-only repository query. |
| `lib/presentation/entries/entry_list_formatters.dart` | Updated draft-only formatter behavior to use `Entry.type`. |
| `lib/presentation/entries/entry_list_row.dart` | Updated draft labels and semantics to use `Entry.type`. |
| `test/domain/model/entry_test.dart` | Added direct model coverage for `EntryType` parsing and `copyWith` behavior. |
| `test/data/entries/entry_database_test.dart` | Replaced migration coverage with fresh-install isolation, direct constraint-failure coverage, and corrupted current-shape read coverage. |
| `test/data/entries/entry_repository_impl_test.dart` | Updated repository expectations to `EntryType` and removed the now-invalid direct-SQL invalid-type insertion path. |
| `test/domain/usecase/**`, `test/presentation/entries/**`, `test/presentation/main/**`, `test/core/router/app_router_test.dart` | Replaced `isDraft` construction/assertions with `Entry.type` assertions. |
| `integration_test/draft_retry_launch_flow_test.dart` | Updated draft retry expectations to assert `EntryType.draft` and `EntryType.saved`. |
| `integration_test/main_recording_controller_flow_test.dart` | Updated recording success/failure expectations to assert saved vs draft types. |
| `integration_test/cleanup_transcript_use_case_flow_test.dart` | Updated cleanup-flow expectations to assert draft preservation and saved promotion via type. |
| `integration_test/entry_list_flow_test.dart` | Reused as device-visible entry-list validation during review remediation. |
| `integration_test/entry_detail_device_smoke_test.dart` | Reused as device-visible entry-detail/edit validation during review remediation. |

No production code changes were required in `entry_detail_screen.dart`,
`entry_list_controller.dart`, or `main_screen_stats.dart` because those paths
did not branch on `isDraft`; only the affected tests and entry constructors
needed updating there.

## Fresh-install rollout details

- The supported entry database file is now `wrait_entries_v2.sqlite`.
- The type-based schema is treated as the first supported version of that file.
- Legacy `wrait_entries.sqlite` files are not migrated or interpreted.
- Database-level integrity now rejects invalid `type` values before repository
  code sees them.
- Repository validation remains as a second line of defense for corrupted
  current-shape databases that bypass normal constraints.

## Validation

### Automated

```text
dart run build_runner build --delete-conflicting-outputs
Result: passed; this build_runner version logged that
--delete-conflicting-outputs was ignored, but Drift output regenerated.

dart format lib/data/entries/local_entry_database.dart lib/domain/usecase/retry_pending_drafts_use_case.dart test/data/entries/entry_database_test.dart test/data/entries/entry_repository_impl_test.dart
Result: passed.

flutter analyze
Result: passed.

flutter test test/data/entries
Result: passed.

flutter test test/domain/usecase
Result: passed.

flutter test test/domain/model test/presentation/entries test/presentation/main test/core/router
Result: passed.
```

### Android emulator verification

```text
/opt/homebrew/bin/flutter test -d emulator-5554 integration_test/draft_retry_launch_flow_test.dart integration_test/main_recording_controller_flow_test.dart integration_test/cleanup_transcript_use_case_flow_test.dart integration_test/entry_list_flow_test.dart integration_test/entry_detail_device_smoke_test.dart
Result: passed on Android emulator emulator-5554.
```

Observed visible behavior through the device smoke suite:

- saved entries render and open normally
- draft rows retain the draft label and audio-only retry affordance
- entry detail edit/back flows remain intact

### iOS simulator verification

```text
/opt/homebrew/bin/flutter test -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/draft_retry_launch_flow_test.dart integration_test/main_recording_controller_flow_test.dart integration_test/cleanup_transcript_use_case_flow_test.dart integration_test/entry_list_flow_test.dart integration_test/entry_detail_device_smoke_test.dart
Result: passed on iOS simulator 491CD949-D3C0-4C4C-A6B9-15BAB1859156.
```

Observed visible behavior through the device smoke suite:

- saved entries render and open normally
- draft rows retain the draft label and audio-only retry affordance
- entry detail edit/back flows remain intact

## Review remediation applied

- Removed the migration path entirely after user-approved scope change.
- Added a constrained `type` column at the database layer.
- Replaced migration tests with:
  - fresh-install legacy-file isolation coverage
  - direct invalid-`type` constraint coverage
  - corrupted current-shape invalid/null `type` read coverage
- Removed the redundant retry-loop draft-type check.

## Deviations and notes

- No backend HTTP contract changed.
- No intentional app-lock, capture-privacy, startup, deployment, or release
  signing behavior changed.
- `integration_test/local_data_lifecycle_flow_test.dart` remains updated for
  `Entry.type` construction, but update-preservation behavior is no longer part
  of US-037 validation after the approved fresh-install scope change.
- External review remediation is now applied. The next SDD step is the
  knowledge-capture gate: propose any durable `AGENTS.md` or docs updates
  before editing them.
