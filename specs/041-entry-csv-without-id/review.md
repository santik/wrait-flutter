# Code Review: Entry CSV Without Id

> **Feature number:** 041
> **Reviewer:** Cascade
> **Date:** 2026-07-01

---

## Priority Findings

### P0: Missing validation for `created_at` upper bounds

**Location:** `lib/domain/service/entry_import_service.dart:196-201`

**Issue:** The import service validates that `created_at` is a non-negative integer but does not validate an upper bound. This allows importing entries with arbitrarily large future timestamps (e.g., `9999999999999`), which could cause sorting issues or unexpected behavior in the UI.

**Current code:**
```dart
final createdAt = int.tryParse(row[1]);
if (createdAt == null || createdAt < 0) {
  throw const FormatException(
    'Entry import CSV contains an invalid created_at value.',
  );
}
```

**Recommendation:** Add an upper bound validation to prevent unreasonable timestamps. Consider using a reasonable future limit (e.g., 10 years from now) or validate against a maximum epoch value like `DateTime.utc(2100).millisecondsSinceEpoch`.

---

### P1: No validation for `created_at` monotonicity within CSV

**Location:** `lib/domain/service/entry_import_service.dart:188-227`

**Issue:** The import service does not validate that `created_at` values within a single CSV file are in a reasonable order or that they don't contain duplicates. While the spec requires additive import behavior, importing entries with identical timestamps or wildly out-of-order timestamps could lead to confusing user experiences when entries display in the UI.

**Recommendation:** Consider adding a validation pass that checks for duplicate `created_at` values within the CSV and optionally warns or rejects files with non-monotonic timestamps. This would improve data quality without breaking the additive import requirement.

---

### P1: CSV header validation uses custom `_listEquals` instead of Dart's built-in

**Location:** `lib/domain/service/entry_import_service.dart:333-343`

**Issue:** The implementation includes a custom `_listEquals` function for header validation when Dart's `listEquals` from `dart:collection` could be used. This adds unnecessary maintenance burden and potential for bugs.

**Current code:**
```dart
static bool _listEquals(List<String> left, List<String> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var i = 0; i < left.length; i += 1) {
    if (left[i] != right[i]) {
      return false;
    }
  }
  return true;
}
```

**Recommendation:** Replace with `import 'package:collection/collection.dart';` and use the built-in `const ListEquality().equals(left, right)` or `listEquals(left, right)`.

---

### P2: Missing test for `created_at` boundary values

**Location:** `test/domain/service/entry_import_service_test.dart`

**Issue:** The test suite does not include boundary tests for `created_at` values, such as:
- Zero timestamp (`0`)
- Very large future timestamps
- Timestamps at epoch boundaries
- Negative edge cases (already covered by `< 0` check)

**Recommendation:** Add test cases for:
```dart
test('accepts zero timestamp', () async { ... });
test('rejects unreasonably large future timestamp', () async { ... });
test('accepts reasonable future timestamp', () async { ... });
```

---

### P2: No test for CSV with extra columns after valid header

**Location:** `test/domain/service/entry_import_service_test.dart`

**Issue:** The validation checks that row length matches header length, but there is no explicit test for a CSV that has extra columns in data rows beyond what the header defines. This could be a potential attack vector or data corruption issue.

**Recommendation:** Add a test case:
```dart
test('rejects rows with extra columns beyond header', () async {
  final csv = [
    'type,created_at,language,word_count,raw_transcript,cleaned_text',
    'saved,123,en-US,2,hello,clean,extra_column',
  ].join('\n');
  // Expect failure
});
```

---

### P2: Error message for invalid `created_at` is generic

**Location:** `lib/domain/service/entry_import_service.dart:198-200`

**Issue:** The error message "Entry import CSV contains an invalid created_at value" does not distinguish between parsing failures (non-integer) and validation failures (negative value). This makes debugging harder for users.

**Current code:**
```dart
if (createdAt == null || createdAt < 0) {
  throw const FormatException(
    'Entry import CSV contains an invalid created_at value.',
  );
}
```

**Recommendation:** Split the validation to provide more specific error messages:
```dart
if (createdAt == null) {
  throw const FormatException(
    'Entry import CSV created_at must be an integer.',
  );
}
if (createdAt < 0) {
  throw const FormatException(
    'Entry import CSV created_at cannot be negative.',
  );
}
```

---

### P2: No validation for empty string `created_at`

**Location:** `lib/domain/service/entry_import_service.dart:196`

**Issue:** `int.tryParse('')` returns `null`, which is caught by the null check. However, the error message doesn't clearly indicate that an empty string was the problem. A user might be confused if they have a CSV with an empty `created_at` field.

**Recommendation:** Consider adding an explicit check for empty strings before parsing to provide a clearer error message, or ensure the existing error message is sufficient for this case.

---

### P3: Manual CSV parsing instead of using a CSV library

**Location:** `lib/domain/service/entry_import_service.dart:229-289`

**Issue:** The implementation includes a custom CSV parser (`_parseRows`) that handles quotes, commas, and line endings. While this works, it reinvents wheel functionality that well-tested CSV libraries (like `csv` package) provide. This increases maintenance burden and risk of edge-case bugs.

**Recommendation:** Consider using the `csv` package (`package:csv/csv.dart`) for parsing, which would:
- Reduce custom code maintenance
- Provide better handling of edge cases
- Be more auditable and trusted

However, this is lower priority since the current implementation appears to handle the required cases correctly based on test coverage.

---

### P3: No documentation of CSV contract version

**Location:** `lib/domain/service/entry_export_service.dart`

**Issue:** The CSV contract changed significantly (removed `id` and `created_at_epoch_ms`), but there is no version identifier in the exported CSV. If future changes need to distinguish between CSV formats, there will be no way to identify which version a file represents.

**Recommendation:** Consider adding a version comment or metadata row to the CSV export, e.g., as a comment line `# Wrait CSV v2` at the start of the file. This would make future migrations easier.

---

### P3: Test fixtures use hardcoded timestamps

**Location:** Multiple test files

**Issue:** Test fixtures use hardcoded timestamps like `DateTime.utc(2026, 6, 30, 12).millisecondsSinceEpoch`. While this works, it makes tests brittle if the date logic needs to change and doesn't clearly communicate the intent of the timestamp value.

**Recommendation:** Consider using named constants or helper functions to make the intent clearer:
```dart
const _testTimestamp = 1719748800000; // 2024-07-01 12:00:00 UTC
```

---

## Summary

The implementation successfully removes the `id` and `created_at_epoch_ms` columns from the CSV contract as specified. The code is well-structured and test coverage is good. However, there are opportunities to improve:

1. **Robustness:** Add upper bound validation for timestamps
2. **Data quality:** Consider monotonicity checks
3. **Code quality:** Use built-in Dart utilities instead of custom implementations
4. **Test coverage:** Add boundary and edge case tests
5. **Error messages:** Provide more specific feedback for validation failures
6. **Future-proofing:** Consider CSV versioning

The P0 finding (missing upper bound validation) should be addressed before release. P1 findings are recommended for production quality. P2 and P3 are improvements that could be deferred if needed.
