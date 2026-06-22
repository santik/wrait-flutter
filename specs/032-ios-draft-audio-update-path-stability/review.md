# Code Review: iOS Draft Audio Update Path Stability

> **Feature number:** 032
> **Reviewer:** Codex
> **Date:** 2026-06-22
> **Review scope:** Implementation changes in current branch vs main

## Findings

### PO - Critical Issues

**PO-1: Missing migration strategy for existing absolute paths**

The implementation assumes no existing draft rows exist and therefore provides no migration path. However, the spec states "Because there are no existing draft rows to preserve before this story, no draft-audio reference migration or legacy draft-reference recovery is required." This creates a fragile assumption: if any draft rows exist in production (e.g., from manual testing, data seeding, or unexpected app state), they will become permanently unusable after this change. The codec will throw `FormatException` on any absolute path read from the database, with no recovery mechanism.

**Location:** `lib/data/entries/draft_audio_path_codec.dart` - `resolve()` method

**Recommendation:** Add a best-effort migration path that attempts to resolve legacy absolute paths against the current temp directory, logging a warning when legacy paths are encountered. This provides a safety net for unexpected production state without violating the spec's intent to avoid broad migration complexity.

---

### P1 - High Priority Issues

**P1-1: Case-sensitive scheme validation without normalization**

The codec validates the `app-cache://` scheme with case-sensitive string matching (`startsWith(cacheScheme)`). If the database contains values with different casing (e.g., `APP-CACHE://`, `App-Cache://`), they will be rejected. This could occur if data is manipulated externally, through database tools, or if future code changes introduce case variations. The spec does not define case-sensitivity requirements for the scheme.

**Location:** `lib/data/entries/draft_audio_path_codec.dart:50`

**Recommendation:** Normalize the scheme to lowercase during validation and storage, or explicitly document the case-sensitivity requirement in the codec documentation.

---

**P1-2: Insufficient path traversal validation**

The `_validateRelativeReference` function checks for `..` segments individually but does not validate the fully normalized path for directory traversal. While `path.normalize()` resolves `a/../b` to `b`, the validation should check the final normalized result rather than individual segments. The current approach could miss complex traversal patterns or edge cases where normalization produces unexpected results.

**Location:** `lib/data/entries/draft_audio_path_codec.dart:106`

**Recommendation:** After normalization, verify that the resolved path remains within the cache directory by checking if `path.isWithin(normalizedCachePath, resolvedPath)` returns true, in addition to the segment-level check.

---

**P1-3: Test deviation from production startup behavior**

The `platform-update-retry-verify` scenario directly calls `appLaunchWorkUseCaseProvider.call()` instead of relying on the natural startup flow. The implementation.md notes this was done to avoid timing sensitivity, but this means the test does not validate the actual production behavior where launch retry happens asynchronously during app startup. This could miss race conditions, initialization ordering issues, or problems with the fire-and-forget startup contract.

**Location:** `integration_test/local_data_lifecycle_flow_test.dart:283`

**Recommendation:** Add a retry mechanism with appropriate timeouts to test the actual startup flow, or document why testing the direct call is sufficient and what production behavior is not being validated.

---

### P2 - Medium Priority Issues

**P2-1: No validation for empty or whitespace-only relative path components**

The `_validateRelativeReference` function checks for empty trimmed paths and `.` but does not explicitly validate that the path contains actual file components. A path like `//` or `/.` could pass validation after normalization in some edge cases. The spec requires the reference to identify a file, but the validation is not comprehensive.

**Location:** `lib/data/entries/draft_audio_path_codec.dart:83-96`

**Recommendation:** Add validation to ensure the normalized path contains at least one non-segment character after normalization.

---

**P2-2: Missing test for Unicode normalization in paths**

The codec does not handle Unicode normalization. Paths with visually identical but differently encoded characters (e.g., composed vs decomposed Unicode) could be treated as different paths, leading to duplicate files or lookup failures. This is particularly relevant for iOS where file systems may normalize paths differently than the in-memory representation.

**Location:** `lib/data/entries/draft_audio_path_codec.dart` - overall

**Recommendation:** Document whether Unicode normalization is required, or add normalization using `path.normalize()` combined with explicit Unicode normalization if needed for cross-platform consistency.

---

**P2-3: Integration test file cleanup lacks error handling**

The `writeManagedAudioFile` methods in multiple integration test harnesses add files to a `_managedAudioFiles` list for cleanup, but the cleanup loop does not handle exceptions. If one file deletion fails, subsequent files may not be cleaned up, potentially leaving test artifacts that interfere with subsequent test runs.

**Location:** 
- `integration_test/draft_retry_launch_flow_test.dart:277-282`
- `integration_test/entry_list_flow_test.dart:262-267`
- `integration_test/entry_detail_flow_test.dart:337-342`
- `integration_test/main_recording_controller_flow_test.dart:252-257`

**Recommendation:** Wrap individual file deletions in try-catch blocks and log failures, ensuring cleanup continues for remaining files even if one deletion fails.

---

**P2-4: Brittle test assertion relaxed without root cause fix**

The implementation.md notes that an exact stats-text assertion in `draft_retry_launch_flow_test.dart` was relaxed to use the `statsLineButton` key because the exact text differed. This addresses the symptom but not the root cause. The text difference could indicate a localization issue, a timing problem with UI state, or an actual regression in the displayed content.

**Location:** `integration_test/draft_retry_launch_flow_test.dart:86` and `implementation.md:82-86`

**Recommendation:** Investigate why the exact text differed and ensure the relaxation is appropriate. If the text is intentionally variable, document why the exact match is not required.

---

**P2-5: No validation for maximum path length**

The codec does not validate that the stored `app-cache://` reference or the resolved absolute path will fit within filesystem limits. Extremely long relative paths could cause filesystem errors during resolution or file operations, particularly on iOS where path length limits may be more restrictive.

**Location:** `lib/data/entries/draft_audio_path_codec.dart` - overall

**Recommendation:** Add validation for maximum reasonable path length (e.g., 255 characters for filename components, 1024 for full path) and throw appropriate errors when limits are exceeded.

---

### P3 - Low Priority Issues

**P3-1: Code duplication in test harnesses**

The `writeManagedAudioFile` method is duplicated across four integration test files with identical implementation. This creates maintenance burden and increases the risk of inconsistencies if the logic needs to change.

**Location:** Multiple integration test files

**Recommendation:** Extract the common file management logic into a shared test utility file or mixin.

---

**P3-2: Documentation updates mix US-030 and US-032 concerns**

The changes to `AGENTS.md`, `docs/agent-findings.md`, and `docs/application-description.md` include US-030 findings and guidance. While related, this blurs the boundary between the two stories and makes it harder to trace which documentation changes belong to which feature.

**Location:** `AGENTS.md`, `docs/agent-findings.md`, `docs/application-description.md`

**Recommendation:** Consider separating the documentation updates or clearly marking which sections are US-030 vs US-032 in the commit message or implementation notes.

---

**P3-3: iOS simulator uninstall requires manual escalation**

The validation notes that `xcrun simctl uninstall` required an escalated rerun outside the sandbox due to CoreSimulator access denial. This suggests the validation process is not fully automated and may not be reproducible in CI/CD environments.

**Location:** `tasks.md:172-174` and `implementation.md:114-116`

**Recommendation:** Document the required permissions or automation setup for iOS simulator uninstall in CI/CD, or consider alternative fresh-state verification approaches that don't require simctl uninstall.

---

**P3-4: Missing documentation for scheme design rationale**

The codec uses a custom `app-cache://` scheme but does not document why this scheme was chosen over alternatives (e.g., a simple relative path without a scheme, a UUID-based reference, or a different URI scheme). Future maintainers may not understand the design constraints that led to this choice.

**Location:** `lib/data/entries/draft_audio_path_codec.dart:4-6`

**Recommendation:** Expand the codec documentation to explain the rationale for the `app-cache://` scheme, why it's preferable to alternatives, and any security or portability considerations.

---

**P3-5: No test for concurrent access to codec methods**

The codec methods are static and could be called concurrently from multiple isolates or async operations. There are no tests to verify thread-safety or concurrent access behavior, particularly around the `_cacheRootPath()` caching behavior (if any) or the path normalization operations.

**Location:** `lib/data/entries/draft_audio_path_codec.dart` - overall

**Recommendation:** Add concurrent access tests if the codec is expected to be used from multiple isolates, or document that it is not thread-safe and should only be used from the main isolate.

---

**P3-6: Hardcoded test values reduce flexibility**

The lifecycle test uses hardcoded values for device ID, language, and transcript content (`_platformRawDeviceId`, `_draftLanguage`, `_savedRawTranscript`, etc.). This makes it harder to test different locales or device scenarios without modifying the test code.

**Location:** `integration_test/local_data_lifecycle_flow_test.dart:41-50`

**Recommendation:** Consider parameterizing these values or using test fixtures that can be easily varied for different test scenarios.

---

**P3-7: No validation for filesystem symlink behavior**

The codec does not account for symbolic links in the path resolution. If the app temporary directory or a parent directory is a symlink, the `_isWithinDirectory` check may behave unexpectedly depending on how the filesystem resolves symlinks. This could be a security concern if symlinks could be used to escape the intended directory.

**Location:** `lib/data/entries/draft_audio_path_codec.dart:116-122`

**Recommendation:** Document symlink handling behavior or add explicit checks to resolve symlinks before validation if security is a concern.

---

## Summary

The implementation successfully simplifies the draft audio path handling to a shared `app-cache://` scheme across iOS and Android, removing the complex fallback behavior. However, there are critical gaps around migration strategy for unexpected production state and validation robustness that should be addressed before deployment.

**Total findings:** 7 PO/P1 issues, 5 P2 issues, 7 P3 issues
