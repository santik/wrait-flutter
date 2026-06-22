# Code Review: Release-Signed Android Deploy Flow

> **Feature number:** 031
> **Review date:** 2026-06-22
> **Reviewer:** Codex

## Summary

This review identifies problems and potential issues in the implementation of US-031, which adds a release-signed Android deployment flow and splits debug/release package identities.

## Findings

### PO - Critical security or correctness issues

**PO-1: Signing credentials stored in plaintext in android/local.properties**

The `deploy_release.sh` script synchronizes `KEYSTORE_PASSWORD` and `KEY_PASSWORD` into `android/local.properties` in plaintext. While this file is git-ignored, the Gradle build reads these values directly from the file. This approach has several security weaknesses:

- Passwords remain in plaintext on disk during and after the build process
- The file could be accidentally committed if `.gitignore` is misconfigured
- The file persists between builds, increasing exposure window
- No mechanism to automatically clear credentials after the build

**Location:** `deploy_release.sh` lines 346-352 (sync_target_local_properties function)

**Recommendation:** Consider using environment variables or Gradle's `signingConfig` with environment variable injection. Alternatively, add a cleanup step to remove sensitive keys from `android/local.properties` after the build completes.

---

### P1 - High priority issues

**P1-1: No validation that keystore is actually usable**

The script validates that the keystore file exists and is readable, but does not verify that:
- The file is a valid keystore format
- The keystore password is correct
- The key alias exists in the keystore
- The key password is correct

These validations only happen during the Gradle build, which occurs after significant work has already been done. A failure at this point wastes time and provides less clear error messages.

**Location:** `deploy_release.sh` lines 388-391 (load_and_validate_private_config function)

**Recommendation:** Add preflight validation using `keytool` to verify keystore usability before invoking the Flutter build. For example:
```bash
keytool -list -v -keystore "$RESOLVED_KEYSTORE_PATH" -storepass "$RESOLVED_KEYSTORE_PASSWORD" -alias "$RESOLVED_KEY_ALIAS" -keypass "$RESOLVED_KEY_PASSWORD" >/dev/null 2>&1
```

---

**P1-2: KEYSTORE_PATH resolution may not match operator intent**

The script resolves relative `KEYSTORE_PATH` values relative to the source config file (`wrait-android/local.properties`). However, operators may have intended the path to be relative to the Flutter project root or the wrait-android project root. The current implementation could cause confusion if the keystore location was set up with a different reference point in mind.

**Location:** `deploy_release.sh` lines 280-291 (resolve_source_relative_path function)

**Recommendation:** Document the resolution behavior clearly in the script comments and error messages. Consider adding a validation warning if the resolved path does not exist, with guidance on how to specify absolute paths if the relative resolution is incorrect.

---

**P1-3: No validation for BACKEND_URL format beyond http/https prefix**

The script validates that `BACKEND_URL` starts with `http://` or `https://`, but does not validate that it is a well-formed URL. Malformed URLs could cause runtime errors in the deployed app.

**Location:** `deploy_release.sh` lines 393-399 (load_and_validate_private_config function)

**Recommendation:** Add more robust URL validation, or at least check for basic URL structure (e.g., contains a domain).

---

**P1-4: Release build falls back to debug signing if credentials missing**

In `android/app/build.gradle.kts`, the release build type only uses the release signing config if `hasReleaseSigning` is true. If the signing keys are missing, the build silently falls back to debug signing (the default behavior when no signing config is specified). This could result in a release build that is not actually release-signed, defeating the purpose of the feature.

**Location:** `android/app/build.gradle.kts` lines 58-62

**Recommendation:** Make the release build fail explicitly if signing credentials are not available, rather than silently falling back to debug signing. Add a Gradle task that checks for required signing properties and fails the build if they are missing.

---

**P1-5: Manual uninstall step required for initial deployment**

The implementation notes indicate that the initial `./deploy_release.sh` run failed with `INSTALL_FAILED_UPDATE_INCOMPATIBLE` because the device had a debug-signed `com.wrait.flutter` installed. The operator had to manually run `adb uninstall com.wrait.flutter` before the release deployment would succeed. This manual step is not documented in the script usage or error messages and could confuse operators.

**Location:** `implementation.md` lines 120-128

**Recommendation:** Improve the error message for `INSTALL_FAILED_UPDATE_INCOMPATIBLE` to explicitly mention that a manual uninstall may be required if the existing package was signed with a different key. Consider adding a `--force` flag to the release script that performs the uninstall automatically after confirmation.

---

### P2 - Medium priority issues

**P2-1: No test for keystore password/key password validation**

The shell tests include scenarios for missing keystore file and blank key alias, but do not test scenarios where the keystore file exists but the password or key password are incorrect. This is a common failure mode that should be tested.

**Location:** `test/deploy_release_script_test.sh`

**Recommendation:** Add test scenarios for invalid keystore password and invalid key password. These would require the fake `flutter` command to simulate a Gradle build failure with appropriate error messages.

---

**P2-2: Config synchronization is not atomic**

The `sync_target_local_properties` function writes to a temporary file and then moves it into place, which is good. However, if the script is interrupted after the temp file is created but before the move completes, the target file could be left in an inconsistent state. Additionally, if multiple concurrent deployments were attempted (though unlikely in practice), they could race.

**Location:** `deploy_release.sh` lines 306-356

**Recommendation:** The current approach is reasonable for single-operator use, but consider adding a lock file mechanism if concurrent deployments might occur. Document that the script should not be run concurrently.

---

**P2-3: No validation that resolved keystore path is within expected bounds**

The script resolves relative keystore paths but does not validate that the resolved path is within a reasonable directory structure. A misconfigured path could point outside the project or to system directories.

**Location:** `deploy_release.sh` lines 385-391

**Recommendation:** Add a sanity check to ensure the resolved keystore path is within the project directory or a known external location, and warn if it points to an unexpected location.

---

**P2-4: INTERNET permission moved to main manifest without clear justification**

The implementation moves the `INTERNET` permission from debug/profile manifests to the main manifest. While this is technically correct (release builds need backend access), the commit message and implementation notes do not explain why this change was made as part of this feature. This change affects all build types, not just release builds.

**Location:** `android/app/src/main/AndroidManifest.xml`, `android/app/src/debug/AndroidManifest.xml`, `android/app/src/profile/AndroidManifest.xml`

**Recommendation:** Either move this change to a separate feature with its own justification, or clearly document in the implementation notes why this permission reorganization is necessary for the release deployment feature.

---

**P2-5: Release script does not verify debug package is not affected**

The release script verifies that `com.wrait.flutter` is installed after deployment and that `com.wrait.app` remains installed. However, it does not verify that `com.wrait.flutter.dev` was not accidentally affected by the release deployment (e.g., uninstalled or replaced). While the script never targets the debug package, a verification would provide additional safety.

**Location:** `deploy_release.sh` lines 443-453

**Recommendation:** Add a check to verify that if `com.wrait.flutter.dev` was installed before deployment, it remains installed afterward. This would catch any unexpected interactions between the release and debug packages.

---

### P3 - Low priority issues

**P3-1: Duplicate code between deploy_debug.sh and deploy_release.sh**

Both scripts contain significant duplicate code for phone discovery, package verification, launch verification, and helper functions. This increases maintenance burden and the risk of divergence.

**Location:** `deploy_debug.sh`, `deploy_release.sh`

**Recommendation:** Extract common functions into a shared script file (e.g., `deploy_shared.sh`) that both scripts can source. This would reduce duplication and make future changes easier to apply consistently.

---

**P3-2: No integration test coverage for release deployment**

The plan explicitly excludes integration tests from the release deployment flow, which is appropriate for the scope. However, there is no automated verification that the release-signed app actually functions correctly with the backend using the provided runtime configuration.

**Location:** `plan.md` lines 259-262

**Recommendation:** Consider adding a separate manual verification step or a lightweight smoke test that can be run after release deployment to verify basic app functionality with the release configuration.

---

**P3-3: Hardcoded Flutter path in configure_java**

The `configure_java` function hardcodes the path to Android Studio's JBR. If an operator uses a different Android Studio installation or a different JDK, this fallback may not work.

**Location:** `deploy_release.sh` lines 63-64

**Recommendation:** Make the Android Studio path configurable via environment variable, or improve the fallback logic to search for common Android Studio installation locations.

---

**P3-4: No validation for PROXY_SECRET format beyond length and whitespace**

The script validates that `PROXY_SECRET` is at least 8 characters and contains no whitespace, but does not validate any other format requirements. If the backend has specific format requirements (e.g., special characters, entropy), these are not enforced at deployment time.

**Location:** `deploy_release.sh` lines 50-57

**Recommendation:** If the backend has specific PROXY_SECRET format requirements, add validation for those requirements. Otherwise, the current validation is sufficient.

---

**P3-5: Error messages could be more actionable**

Some error messages could provide more specific guidance on how to resolve the issue. For example, when the keystore file is not found, the message could suggest checking the path relative to the source config file.

**Location:** Various locations in `deploy_release.sh`

**Recommendation:** Review all error messages and ensure they include actionable guidance where appropriate.

---

## Summary Statistics

- **PO issues:** 1
- **P1 issues:** 5
- **P2 issues:** 5
- **P3 issues:** 5

## Overall Assessment

The implementation successfully achieves the stated goals of separating debug and release package identities and providing a release deployment flow. However, there are several areas where security, validation, and error handling could be improved. The most critical issue (PO-1) involves the handling of signing credentials in plaintext, which should be addressed to improve the security posture of the deployment process.
