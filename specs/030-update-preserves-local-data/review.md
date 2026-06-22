# Code Review: App Updates Preserve Local Data

> **Feature number:** 030
> **Reviewer:** Codex
> **Date:** 2026-06-22

## Summary

This review identifies architectural concerns, implementation issues, and missing validation in the US-030 implementation. The core database safety change (removing silent database reset on open failure) is correctly implemented, but the draft audio path portability layer introduces complexity and potential data integrity risks.

---

## Findings

### P0 - Critical

#### P0-1: DraftAudioPathCodec.resolve() fallback logic can silently return incorrect paths

**Location:** `lib/data/entries/draft_audio_path_codec.dart:33-68`

**Issue:** The `resolve()` method implements a complex multi-stage fallback that can return paths that don't actually exist or point to wrong files:

1. If a stored absolute path doesn't exist at the original location, it falls back to checking the cache directory with the same basename
2. If the fallback file exists, it returns that path even though it may be a different file (e.g., from a different entry or a previous installation)
3. If neither exists, it returns the original normalized path which is guaranteed to be invalid

**Risk:** This can cause:
- Audio playback from wrong files if basename collisions occur across entries
- Silent data corruption where an entry's audio is replaced with another entry's audio
- Confusing error states where the app returns a non-existent path to callers expecting a valid file

**Example scenario:**
- Entry A has audio at `/cache/old-container/draft-audio.m4a`
- After iOS reinstall, cache becomes `/cache/new-container/`
- Entry B is created with audio at `/cache/new-container/draft-audio.m4a`
- Entry A's resolve() falls back to `/cache/new-container/draft-audio.m4a` and returns Entry B's audio file

**Recommendation:** Remove the basename fallback logic. If a stored path doesn't exist at its expected location, either:
- Return `null` and let the caller handle missing audio
- Throw a specific exception indicating the audio file is missing
- Log a warning and return `null`

The legacy absolute path support should only resolve the exact stored path if it exists, not attempt basename-based recovery.

---

#### P0-2: DraftAudioPathCodec lacks validation for path traversal attacks

**Location:** `lib/data/entries/draft_audio_path_codec.dart:9-31`

**Issue:** The `store()` method normalizes paths but does not validate that the resolved path is actually within the cache directory before storing it as a relative path. The `_isWithinDirectory()` check only runs after normalization, but a malicious or malformed path could potentially escape the cache directory through path normalization edge cases.

**Risk:** If an attacker can control the audio path (e.g., through file picker or external input), they could store paths that resolve outside the cache directory, potentially:
- Reading arbitrary files from the device
- Writing to unintended locations
- Bypassing app sandbox boundaries

**Recommendation:** Add explicit validation that the final resolved path is strictly within the cache directory before storing. Use `path.isWithin()` after all normalization and resolution steps, and throw if the path escapes the intended boundary.

---

### P1 - High

#### P1-1: EntryRepositoryImpl changes stream semantics from sync to async

**Location:** `lib/data/entries/entry_repository_impl.dart:32-47`

**Issue:** The implementation changes `watchAllEntries()` and `watchEntryById()` from synchronous `.map()` to asynchronous `.asyncMap()` with `Future.wait()`. This changes the stream emission semantics:

- **Before:** Each database query produced a single synchronous emission
- **After:** Each database query now produces an emission after all audio path resolutions complete asynchronously

**Risk:**
- Increased latency in UI updates due to async path resolution for every entry
- Potential for stream backpressure if many entries have audio paths
- Changed error propagation behavior - async errors in path resolution will fail the entire stream emission
- Tests that relied on synchronous emission timing may now be flaky

**Recommendation:** Consider whether audio path resolution should be lazy (resolved on-demand when accessed) rather than eager (resolved for all entries on stream emission). Alternatively, document the async emission semantics clearly and ensure all callers handle the latency correctly.

---

#### P1-2: No integration test for actual Android/iOS app update scenario

**Location:** `integration_test/local_data_lifecycle_flow_test.dart`

**Issue:** The integration test simulates update scenarios by:
- Creating a runtime, seeding data, disposing
- Creating a new runtime with the same storage

However, this does not actually test a real app update where:
- The Flutter engine process terminates
- The app binary is replaced
- A new process starts with the old data

The validation in `tasks.md` uses `flutter drive --keep-app-running` which keeps the same process alive, not a true cold-start after update.

**Risk:** The implementation may pass tests but fail in production because:
- Static initialization order differs between cold start and warm restart
- File handles or database connections may not be properly closed on process termination
- Platform-specific update behaviors (Android APK install, iOS app replacement) are not exercised

**Recommendation:** Add a true cold-start integration test that:
1. Seeds data in a first app instance
2. Terminates the app completely
3. Uses platform-specific commands (adb install, xcrun simctl install) to install the new build
4. Launches the app fresh and verifies data persistence

The current `flutter drive --keep-app-running` approach should be supplemented with actual process termination and restart.

---

#### P1-3: Missing test for database corruption scenario

**Location:** `test/data/entries/entry_database_test.dart`

**Issue:** The tests cover key loss (wrong key) but do not test database file corruption (e.g., truncated file, invalid SQLite header, encryption corruption). The spec requires: "If an update cannot safely read or migrate existing local data, the app presents a simple understandable error state."

**Risk:** If the database file is corrupted (not just key mismatch), the current implementation may:
- Throw an uncaught SQLite exception
- Show a generic error instead of the intended bootstrap error screen
- Leave the database in an ambiguous state

**Recommendation:** Add a test that:
- Creates a valid database
- Corrupts the file (write random bytes to middle of file)
- Attempts to open it
- Verifies that it throws an exception and the database file is not deleted

---

### P2 - Medium

#### P2-1: DraftAudioPathCodec scheme string is not validated on read

**Location:** `lib/data/entries/draft_audio_path_codec.dart:39-43`

**Issue:** The `resolve()` method checks if the path starts with `app-cache://` but does not validate the scheme format. If a stored path is `app-cache://` with no relative path, or `app-cache://../escape`, the behavior is undefined.

**Risk:** Malformed stored paths could cause:
- Path resolution to unexpected locations
- Crashes in path manipulation
- Silent failures where invalid paths are returned

**Recommendation:** Add validation that after stripping the scheme, the relative path is non-empty and does not contain path traversal components (`..`).

---

#### P2-2: No test for Android allowBackup=false on different API levels

**Location:** `test/platform/android_manifest_data_lifecycle_test.dart`

**Issue:** The test only checks that `android:allowBackup="false"` is present in the manifest. It does not verify that this setting actually works on different Android API levels, where backup behavior may vary.

**Risk:** The manifest setting may not be sufficient on all Android versions. Some API levels may require additional configuration (e.g., `fullBackupContent`, `dataExtractionRules`) to fully disable backup.

**Recommendation:** Either:
- Add documentation noting which API levels are supported
- Add additional manifest attributes for comprehensive backup control across API levels
- Add runtime verification on device that backup is actually disabled

---

#### P2-3: Integration test hardcodes expected entry IDs (1 and 2)

**Location:** `integration_test/local_data_lifecycle_flow_test.dart:516-518`

**Issue:** The `_platformExpectedState()` function hardcodes `savedEntryId: 1` and `draftEntryId: 2`. This assumes auto-increment behavior and that no other entries exist. If the database schema changes or if tests run in a different order, this will fail.

**Risk:** Tests may be fragile and fail when:
- Database seeding order changes
- Additional test data is added
- Auto-increment behavior changes

**Recommendation:** Query the actual entry IDs after seeding rather than hardcoding them. Store the IDs in the seeded state and use those for verification.

---

#### P2-4: No validation that draft audio files are actually in cache directory

**Location:** `lib/data/entries/draft_audio_path_codec.dart:15-28`

**Issue:** The `store()` method checks if a path is within the cache directory before converting to relative format. However, if a path is outside the cache directory, it stores the absolute path as-is. There is no validation that audio files should only be in the cache directory.

**Risk:** This allows:
- Audio files to be stored in arbitrary locations (documents, external storage)
- Inconsistent behavior where some audio is portable and some is not
- Potential security issues if audio is stored in accessible locations

**Recommendation:** Either:
- Reject paths outside the cache directory with a clear error
- Document that only cache-directory audio is supported for portability
- Add a warning log when storing absolute paths outside cache

---

### P3 - Low

#### P3-1: Delete database artifacts utility is still public but unused

**Location:** `lib/data/entries/local_entry_database.dart:89-103`

**Issue:** The `deleteDatabaseArtifacts()` method remains public even though it is no longer called from the open failure path. The plan states it should "only be available as an explicit utility" but there is no documented use case for calling it explicitly.

**Risk:** Future developers may call this method inappropriately, causing data loss.

**Recommendation:** Either:
- Document the intended use case (e.g., "for explicit user-initiated reset in a future recovery feature")
- Make it private with an underscore since it's currently unused
- Add a comment warning that this should only be called with explicit user consent

---

#### P3-2: Test uses Platform.pathSeparator for path construction

**Location:** `test/data/entries/entry_repository_impl_test.dart:260-264`

**Issue:** The test manually constructs paths using `Platform.pathSeparator` which is brittle and may not work correctly on all platforms.

**Risk:** Tests may fail on platforms with different path separator conventions.

**Recommendation:** Use `path.join()` consistently for all path construction.

---

#### P3-3: No documentation of the app-cache:// scheme

**Location:** `lib/data/entries/draft_audio_path_codec.dart`

**Issue:** The `app-cache://` custom URI scheme is not documented. Future developers may not understand its purpose or format.

**Risk:** The scheme may be misused or misunderstood, leading to bugs.

**Recommendation:** Add a file-level comment documenting:
- The purpose of the scheme (portability across app container changes)
- The format (app-cache://relative-path-from-cache-root)
- When it's used vs when absolute paths are stored
- Migration strategy for existing absolute paths

---

## Architecture Concerns

### A-1: Draft audio path portability is a workaround, not a fundamental fix

The `DraftAudioPathCodec` was added to work around an iOS simulator issue where cache paths change across reinstalls. This is a platform-specific workaround that adds complexity to the data layer.

**Concern:** This couples the data layer to platform-specific app container behavior. If Android or future iOS versions have different path stability characteristics, this workaround may not generalize.

**Recommendation:** Consider whether this should be:
- A platform-specific abstraction in the presentation/data boundary layer
- Documented as a known platform limitation with a clear migration path
- Replaced with a more fundamental solution (e.g., storing audio in the documents directory which is more stable across updates)

---

### A-2: Callback injection pattern adds complexity

The use of callback injection for `storeDraftAudioPath` and `resolveDraftAudioPath` in both `EntryRepositoryImpl` and `LocalEntryStartupBootstrap` adds complexity for testability. While this enables testing, it spreads the audio path concern across multiple layers.

**Concern:** This pattern may be difficult to maintain as more path-related concerns are added. It also makes the constructor signatures longer and more complex.

**Recommendation:** Consider whether a dedicated `AudioPathResolver` service (injected as a dependency) would be cleaner than callback injection.

---

## Missing Cases

### M-1: No test for concurrent database access during update

The implementation does not test what happens if the database is open when an update occurs. While app updates typically terminate the process first, there may be edge cases on some platforms.

**Recommendation:** Document the assumption that updates only occur when the app is not running, or add a test for concurrent access if the platform allows it.

---

### M-2: No test for very long audio paths

The implementation does not test behavior with very long file paths or paths with special characters. The relative path encoding may have edge cases.

**Recommendation:** Add tests with:
- Very long filenames
- Unicode characters in filenames
- Special characters (spaces, parentheses, etc.)
- Maximum path length scenarios

---

### M-3: No verification of Android backup behavior on actual device

The manifest change disables backup, but there is no verification that this actually works on a physical Android device with Google Backup enabled.

**Recommendation:** Either add a manual verification step in the plan or document this as a known assumption that requires device testing.

---

## Summary

The core safety change (removing silent database reset) is correctly implemented and well-tested. However, the draft audio path portability layer introduces significant complexity and potential data integrity risks that should be addressed before merging.

**Critical issues (P0)** that block merge:
- P0-1: Fallback logic can return wrong files
- P0-2: Missing path traversal validation

**High priority (P1)** issues that should be resolved:
- P1-1: Stream semantics change
- P1-2: Missing true cold-start update test
- P1-3: Missing corruption test

**Medium priority (P2)** issues should be addressed for robustness:
- P2-1: Scheme validation
- P2-2: Android API level backup testing
- P2-3: Hardcoded test IDs
- P2-4: Cache directory validation
