# Code Review: Entry Type Classification (US-037)

> **Feature number:** 037
> **Review date:** 2026-06-29
> **Reviewer:** Code Review
> **Updated:** 2026-06-29 (Second review after remediation)

---

## Summary

This review examines the implementation of US-037, which replaces the binary `isDraft` entry classification with an explicit `EntryType` enum. After the initial review, the implementation scope was changed from in-place migration to fresh-install rollout per user approval. The remediated implementation now uses a new database file with a constrained schema, comprehensive test coverage for corrupted data scenarios, and removes redundant defensive checks. All previous findings have been addressed. No new issues were identified.

---

## Previous Findings Status

### P1: Migration does not handle corrupted `is_draft` values defensively

**Status:** FIXED - Scope change eliminated this concern

**Resolution:** The implementation changed from in-place migration to fresh-install rollout. The legacy `is_draft` database is no longer migrated or interpreted. The new type-based store starts fresh with `wrait_entries_v2.sqlite`, so migration edge cases are no longer applicable.

---

### P1: No CHECK constraint on new `type` column

**Status:** FIXED

**Resolution:** The schema now includes a CHECK constraint:

```dart
TextColumn get type =>
    text().customConstraint("NOT NULL CHECK (type IN ('draft', 'saved'))")();
```

This enforces valid type values at the database layer, providing schema-level validation before repository code sees the data.

---

### P2: Missing test for NULL type value handling

**Status:** FIXED

**Resolution:** Added comprehensive test coverage:

```dart
test(
  'repository fails explicitly when a corrupted current-shape row has a null type',
  () async {
    // ... test that verifies NULL type causes explicit failure
  },
);
```

The test seeds a corrupted current-shape database with NULL type values and verifies that repository mapping fails explicitly rather than silently treating NULL as a valid category.

---

### P2: Migration test coverage limited to happy path

**Status:** FIXED - Scope change eliminated this concern

**Resolution:** Migration was removed entirely. The new test suite covers:
- Fresh-install legacy-file isolation (ensures legacy database is not interpreted)
- Direct invalid-type constraint violation coverage
- Corrupted current-shape invalid/null type read coverage

These tests are more appropriate for the fresh-install rollout approach.

---

### P2: Redundant type check in retry flow

**Status:** FIXED

**Resolution:** The redundant type check was removed from the retry loop. The retry flow now relies solely on the draft-only repository query (`getPendingDrafts()` filters by `type = 'draft'`). This eliminates the redundancy that could have masked DAO query bugs.

---

### P2: No test for type column constraint violation

**Status:** FIXED

**Resolution:** Added direct constraint violation test:

```dart
test('entry schema rejects invalid persisted type values', () async {
  await expectLater(
    harness.database.customStatement('''
      INSERT INTO entries (..., type, ...) VALUES (..., 'mystery', ...);
    '''),
    throwsA(
      predicate(
        (error) =>
            error.toString().contains('CHECK constraint failed') ||
            error.toString().contains('constraint failed'),
        'constraint failure for invalid entry type',
      ),
    ),
  );
});
```

This test verifies that the database rejects invalid type values at the persistence layer.

---

### P3: Manual verification tasks incomplete

**Status:** FIXED

**Resolution:** The tasks.md file now shows all manual verification tasks as completed (checked). The implementation.md documents that Android emulator and iOS simulator verification passed with device-visible smoke suite coverage for entry list/detail behavior.

---

## New Findings

None. The remediated implementation addresses all previous concerns and introduces no new issues.

---

## Positive Observations

- The fresh-install rollout approach is cleaner and eliminates migration complexity
- The CHECK constraint on the `type` column provides robust schema-level validation
- Test coverage for corrupted data scenarios is comprehensive (invalid string values, NULL values, constraint violations)
- The removal of the redundant retry-loop type check simplifies the code without sacrificing safety
- Legacy database isolation is properly tested to ensure the old file is not accidentally interpreted
- The decision to use a new database file name (`wrait_entries_v2.sqlite`) makes the rollout boundary explicit
- Repository-level validation remains as a defense-in-depth measure for corrupted databases that bypass constraints
- The stale `entry_mapper.dart` file was correctly removed
- Integration tests properly assert entry type values in all relevant flows
- The separation of concerns between domain model (`EntryType`) and persistence (string values) is well-designed

---

## Conclusion

The remediated implementation successfully addresses all findings from the initial review. The scope change to fresh-install rollout eliminated migration-related concerns, and the addition of schema-level constraints plus comprehensive corrupted-data tests significantly strengthens data integrity. The implementation is now production-ready with robust defensive programming at both the database and repository layers.
