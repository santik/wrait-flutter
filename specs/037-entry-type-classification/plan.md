# Implementation Plan: Entry Type Classification

> **Feature number:** 037
> **Spec:** [`spec.md`](spec.md)
> **Author:** Codex
> **Date:** 2026-06-29

---

## Approach summary

Replace the app's binary persisted entry classification with an explicit
entry type across the domain model, local database, repository, draft retry,
entry UI, and tests. The domain model will expose `Entry.type` with
`EntryType.draft` and `EntryType.saved`; it will not expose `isDraft` as a
normal app-facing compatibility property. The local database will use a fresh
type-based schema with constrained persisted values and a new database file
name so the rollout does not depend on preserving or transforming the legacy
`is_draft` store. Existing repository workflow methods such as `saveDraft`,
`saveEntry`, and `finalizeDraftWithCleanedText` will keep their names because
they describe business actions, but their writes and queries will use the
entry type as the source of truth.

## Architecture decisions

| Decision | Choice | Rationale |
| --- | --- | --- |
| Domain classification | Add an `EntryType` enum with `draft` and `saved`, and replace `Entry.isDraft` with `Entry.type` | A typed domain value makes invalid category checks explicit and satisfies the spec's requirement that `type` is the source of truth. |
| Completed-entry type name | Use persisted value `saved` and domain value `EntryType.saved` | The user clarified that `final` is misleading because completed entries remain editable. |
| Compatibility surface | Do not keep an `Entry.isDraft` getter on the domain model | Keeping it would make the old boolean vocabulary continue to look like the classification source of truth and would hide incomplete replacement work. |
| Repository API names | Keep methods such as `saveDraft`, `saveEntry`, `getPendingDrafts`, and `finalizeDraftWithCleanedText` | These are workflow-level operations rather than storage fields. Renaming them would widen the change without improving the new model contract. |
| Persistence representation | Store entry type as a constrained text value, initially `draft` or `saved` | Text values are stable, inspectable, and extensible for future approved entry categories. |
| Fresh-install rollout | Use a new local database file for the type-based store and do not migrate legacy `is_draft` data | This makes the approved no-migration requirement explicit and avoids silent partial upgrades against the old schema. |
| Generated database code | Regenerate `local_entry_database.g.dart` with the project's Drift generator | The generated file is committed in this repo and must match the schema source. |
| Unknown type handling | Validate persisted type values at the repository mapping boundary and never query unknown values as drafts | Normal writes and schema constraints prevent bad values. If data is malformed, it must fail explicitly or remain outside draft workflows rather than silently becoming retryable. |
| Audio-vs-text drafts | Continue distinguishing draft shape by `audioPath` and transcript content | The spec says entry type must not erase the existing distinction between audio drafts and text drafts. |
| Backend/API scope | No OpenAPI or backend contract change | Entry classification is local app state and does not change the backend endpoints. |

## File changes

| File | Action | Description |
| --- | --- | --- |
| `specs/037-entry-type-classification/spec.md` | Modify | Mark the finalized spec as approved for planning. |
| `specs/037-entry-type-classification/plan.md` | Modify | This implementation plan. |
| `specs/037-entry-type-classification/tasks.md` | Modify later | Replace the copied template with the approved task breakdown in the next SDD phase. |
| `specs/037-entry-type-classification/implementation.md` | Create later | Record implementation details and validation evidence during implementation. |
| `lib/domain/model/entry.dart` | Modify | Add `EntryType`, replace `isDraft` with `type`, and update equality/copy semantics. |
| `lib/data/entries/local_entry_database.dart` | Modify | Replace `is_draft` with constrained `type`, reset the supported schema to a fresh-install type store, and use a new database file name. |
| `lib/data/entries/local_entry_database.g.dart` | Regenerate | Update generated Drift table, companion, query, and integrity code for the new constrained type column. |
| `lib/data/entries/entry_dao.dart` | Modify | Query drafts and stale drafts by `type = draft`, and write `type = saved` when completing drafts. |
| `lib/data/entries/entry_repository_impl.dart` | Modify | Persist and map `EntryType`, validate stored type values, and update draft/saved writes. |
| `lib/data/entries/entry_mapper.dart` | Modify or remove | Update stale mapping helper to use `type`, or remove it if unused. |
| `lib/presentation/entries/entry_list_row.dart` | Modify | Use `entry.type` for draft label and draft-specific row behavior. |
| `lib/presentation/entries/entry_detail_screen.dart` | Modify | Use `entry.type` for draft-specific detail behavior. |
| `lib/presentation/entries/entry_list_formatters.dart` | Modify if needed | Use `entry.type` wherever formatting depends on draft status. |
| `lib/presentation/entries/entry_list_controller.dart` | Modify if needed | Replace any `isDraft` checks with type checks. |
| `lib/presentation/main/main_screen_stats.dart` | Modify | Count saved and draft entries from `Entry.type`. |
| `lib/domain/usecase/cleanup_transcript_use_case.dart` | Modify | Replace draft checks with `EntryType.draft` and promote to `EntryType.saved`. |
| `lib/domain/usecase/retry_pending_drafts_use_case.dart` | Modify | Replace draft checks with type checks for retry validation. |
| `test/**` entry-related tests | Modify | Replace `isDraft` construction/assertions with `EntryType` construction/assertions. |
| `integration_test/**` entry and draft tests | Modify | Replace `isDraft` assertions with `type` assertions and keep device-visible entry flows aligned with the new type model. |

During implementation, `rg -n "isDraft|is_draft"` will be used to ensure no
old model or schema source-of-truth references remain except in historical
spec/review text or legacy-file isolation tests.

## API contract details

No backend HTTP contract changes are required.

Application-facing entry contract after the change:

- `Entry.type` is required.
- `EntryType.draft` represents incomplete entries eligible for draft-only
  workflows.
- `EntryType.saved` represents completed, editable saved entries.
- Repository writes for new drafts must persist `draft`.
- Repository writes for new saved entries must persist `saved`.
- Draft promotion must change `draft` to `saved`.
- Pending-draft and stale-draft queries must select only persisted `draft`
  entries.
- Invalid persisted type values are not draft eligible. They are rejected by
  validation when mapped into the normal app domain model rather than silently
  coerced to either `draft` or `saved`.

## Data model changes

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

entries table:
  id INTEGER PRIMARY KEY AUTOINCREMENT
  raw_transcript TEXT NOT NULL
  cleaned_text TEXT NULL
  is_draft BOOLEAN NOT NULL
  language TEXT NOT NULL
  created_at INTEGER NOT NULL
  word_count INTEGER NOT NULL DEFAULT 0
  audio_path TEXT NULL
```

### After

```text
enum EntryType {
  draft
  saved
}

Entry {
  id: int
  rawTranscript: String
  cleanedText: String?
  type: EntryType
  language: String
  createdAt: int
  wordCount: int
  audioPath: String?
}

entries table:
  id INTEGER PRIMARY KEY AUTOINCREMENT
  raw_transcript TEXT NOT NULL
  cleaned_text TEXT NULL
  type TEXT NOT NULL
  language TEXT NOT NULL
  created_at INTEGER NOT NULL
  word_count INTEGER NOT NULL DEFAULT 0
  audio_path TEXT NULL
```

Persisted type values:

```text
draft -> EntryType.draft
saved -> EntryType.saved
```

### Fresh-install rollout

1. Define the supported entry store directly with the type-based schema.
2. Constrain persisted `type` values to `draft` or `saved` in the database.
3. Use a new database file name so pre-US-037 local data is left untouched
   rather than being reinterpreted as the new schema.
4. Keep repository-side type parsing validation as a second line of defense
   for corrupted current-shape databases.
5. Add tests that prove:
   - new writes use the constrained `type` column
   - invalid direct SQL writes are rejected by the schema
   - corrupted current-shape rows still fail explicitly on read
   - a legacy `is_draft` database file is ignored by the new store

## Test strategy

### Automated tests

| Test case | Type | File |
| --- | --- | --- |
| `Entry` equality/copy uses `EntryType` and no longer accepts `isDraft` | Unit | `test/domain/model/entry_test.dart` or existing affected model tests |
| Repository saves completed entries as `EntryType.saved` | Unit | `test/data/entries/entry_repository_impl_test.dart` |
| Repository saves text and audio drafts as `EntryType.draft` | Unit | `test/data/entries/entry_repository_impl_test.dart` |
| Repository pending-draft query returns only `EntryType.draft` rows | Unit | `test/data/entries/entry_repository_impl_test.dart` |
| Repository stale-draft cleanup deletes only `EntryType.draft` rows and linked draft audio | Unit | `test/data/entries/entry_repository_impl_test.dart` |
| Draft transcript updates preserve `EntryType.draft` | Unit | `test/data/entries/entry_repository_impl_test.dart` |
| Draft cleanup/promotion changes `EntryType.draft` to `EntryType.saved` | Unit | `test/data/entries/entry_repository_impl_test.dart` and `test/domain/usecase/cleanup_transcript_use_case_test.dart` |
| Editing a saved entry keeps `EntryType.saved` | Unit | `test/data/entries/entry_repository_impl_test.dart` and entry detail tests |
| Fresh-install startup ignores the legacy `is_draft` database file and creates a clean type-based store | Unit | `test/data/entries/entry_database_test.dart` |
| Direct SQL writes with invalid `type` values fail against the constrained schema | Unit | `test/data/entries/entry_database_test.dart` |
| Corrupted current-shape rows with invalid or null `type` values fail explicitly on read | Unit | `test/data/entries/entry_database_test.dart` |
| Invalid stored type values are not returned as pending drafts and fail explicit mapping validation | Unit | `test/data/entries/entry_database_test.dart` or `test/data/entries/entry_repository_impl_test.dart` |
| Entry list row shows draft label only for `EntryType.draft` | Widget | `test/presentation/entries/entry_list_row_test.dart` |
| Entry detail draft-specific behavior depends on `EntryType.draft` | Widget | `test/presentation/entries/entry_detail_screen_test.dart` |
| Main screen stats count saved and draft entries from `Entry.type` | Unit/widget | `test/presentation/main/main_screen_stats_test.dart` and `test/presentation/main/main_screen_test.dart` |
| Draft retry finalizes pending drafts and leaves failed retries as `EntryType.draft` | Integration | `integration_test/draft_retry_launch_flow_test.dart` |
| Recording success creates a saved entry and retryable recording failure creates a draft entry | Integration | `integration_test/main_recording_controller_flow_test.dart` |
| Cleanup flow creates saved entries, preserves cleanup failures as drafts, and promotes drafts to saved entries | Integration | `integration_test/cleanup_transcript_use_case_flow_test.dart` |
| Entry list/detail/share flows still work for saved entries and draft-visible surfaces still work for draft entries | Integration or widget-backed coverage | Existing entry/list/detail/share tests updated in `test/presentation/entries/**` plus relevant `integration_test` coverage |

Planned validation commands:

```text
dart format lib test integration_test
flutter analyze
flutter test test/data/entries test/domain/usecase test/presentation/entries test/presentation/main test/core/router
flutter test integration_test/draft_retry_launch_flow_test.dart integration_test/main_recording_controller_flow_test.dart integration_test/cleanup_transcript_use_case_flow_test.dart
```

If generated Drift output is stale during implementation, run the project's
normal build-runner command for Drift generation and record the exact command
in `implementation.md`.

### Android emulator verification

1. Boot an Android emulator and confirm the target app identity for the run.
2. Run focused integration coverage on the emulator for:
   - recording success creates `EntryType.saved`
   - retryable recording failure creates `EntryType.draft`
   - draft retry promotes completed drafts to `EntryType.saved`
   - failed draft retry leaves entries as `EntryType.draft`
3. Run the entry list/detail device-visible flows needed to support a visual
   spot-check of saved-entry, draft-label, and share behavior.
4. Manually inspect the visible entry list/detail paths after the integration
   run: saved entries appear normally, draft entries retain the draft label,
   and sharing a saved entry still works.
5. Record emulator id, commands, and results in `tasks.md` and
   `implementation.md`.

### iOS simulator verification

1. Boot an iOS simulator and confirm the Runner bundle identity is unchanged.
2. Run focused integration coverage on the simulator for:
   - recording success creates `EntryType.saved`
   - retryable recording failure creates `EntryType.draft`
   - draft retry promotes completed drafts to `EntryType.saved`
   - failed draft retry leaves entries as `EntryType.draft`
3. Run the entry list/detail device-visible flows needed to support a visual
   spot-check of saved-entry, draft-label, and share behavior.
4. Manually inspect the visible entry list/detail paths after the integration
   run: saved entries appear normally, draft entries retain the draft label,
   and sharing a saved entry still works.
5. Record simulator id, commands, and results in `tasks.md` and
   `implementation.md`.

### Validation exception request

None. This story is expected to satisfy the default integration-test coverage
plus Android emulator and iOS simulator verification requirements.

## Review and finalization

- `review.md` will be externally authored if review occurs.
- After reading `review.md`, no files may be changed until the remediation plan
  is explicitly approved.
- This feature is likely to require durable updates to `AGENTS.md` and
  `docs/agent-findings.md` after final approval because it changes the local
  entry model guidance from `isDraft` to `type` and records the approved
  fresh-install rollout behavior.
- `docs/application-description.md` may need a small product-language update
  only if the completed work changes how entry categories are described to
  users.

## Integration notes

- Existing app code may keep business names such as draft, saved entry,
  pending draft, and stale draft where they describe user or workflow behavior.
  The storage/model boolean name is what changes.
- `RetryPendingDraftsUseCase` should still decide audio-vs-text draft behavior
  from `audioPath` and transcript fields after drafts are loaded from the
  draft-only repository query.
- `CleanupTranscriptUseCase` should promote a draft by setting `type = saved`
  when cleanup succeeds.
- Entry editing should update cleaned text and word count without changing the
  saved type.
- No OpenAPI generation or backend API regeneration is required because
  `api/wrait-backend.yaml` is unchanged.
- App-lock, startup bootstrap, capture privacy, release signing, and backend
  registration behavior are not intentionally changed by this feature.

## Rollout & compatibility

This rolls out as a fresh local entry-store installation in the next app build.
No feature flag is planned because the old and new model shapes are not
supported side by side.

Compatibility behavior:

- The supported entry database file is the new type-based file.
- Legacy `is_draft` database files are not migrated or interpreted.
- New databases create rows with `type` directly.

Rollback concern:

- Because the new store lives in a separate file, the legacy file remains
  untouched. Rollback concerns move from schema translation to product-level
  expectations about whether legacy local data should still be surfaced.

## Risks & mitigations

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| Legacy database is accidentally opened as the new schema | Low | High | Use a new database file name and add a fresh-install isolation test that proves the old file is ignored. |
| Old `isDraft` checks remain in UI or retry code | Medium | High | Use `rg -n "isDraft|is_draft"` during implementation and require remaining hits to be legacy-file tests or historical spec/review text only. |
| A saved editable entry is accidentally treated as immutable because of older "final" naming | Low | Medium | Use `saved` consistently in domain and persisted values; avoid `final` naming in new code except Dart language syntax. |
| Invalid persisted type becomes retryable | Low | High | Constrain the database column to valid values, query pending/stale drafts by exact `type = draft`, and validate type parsing at repository boundaries. |
| Generated database code drifts from schema source | Medium | High | Regenerate Drift output and include analyzer/test coverage in validation. |
| Integration tests fail broadly because many helpers construct `Entry(isDraft: ...)` | High | Medium | Update test builders mechanically to use `EntryType`, then use focused tests to catch behavioral regressions. |
| Platform verification is delayed by emulator/simulator availability | Medium | High | Keep validation requirements explicit; final approval remains blocked unless the user approves a planning-time exception or platform verification succeeds. |

## Open items from spec

None.
