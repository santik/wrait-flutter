# Code Review: Connected Device Tests With Screen Off

> **Feature number:** 029
> **Reviewer:** Codex
> **Date:** 2026-06-18

---

## Summary

This review examines the implementation of US-029, which adds locked-screen and screen-off support to the Android debug deployment workflow. The implementation introduces device preparation logic, debug-only Android activity modifications, and a persistent permission watchdog to enable automated testing without manual phone interaction.

---

## Findings

### PO: Critical architectural or security issues

**PO-1: Profile APK build introduced without spec justification**

The implementation builds both debug and profile APKs, installing the profile APK for the final deployed app. This is a significant scope expansion not mentioned in the spec or plan:

- `deploy_debug.sh` line 412-415: Builds profile APK after integration tests
- `deploy_debug.sh` line 429: Installs profile APK instead of debug APK
- Spec acceptance criteria state: "`./deploy_debug.sh` still builds the debug app, runs the integration test suite on the connected phone, installs only after tests pass, and verifies the app launch"
- Plan file changes table only mentions modifying `deploy_debug.sh` to add readiness helpers, not changing the build type

**Impact:** This changes the deployed artifact from debug to profile builds without explicit approval. Profile builds have different optimization, debugging, and runtime characteristics than debug builds. The spec explicitly says "builds the debug app" and "installs only after tests pass" - it does not mention profile builds.

**Recommendation:** Either revert to installing the debug APK (as specified) or update the spec/plan to explicitly justify why a profile build is now required for the final deployed artifact.

---

**PO-2: Global settings namespace pollution risk**

The implementation uses a custom global setting `wrait_debug_automation_lockscreen_mode` to control Android activity behavior:

- `MainActivity.kt` line 65-66: Defines `AUTOMATION_LOCKSCREEN_MODE_SETTING = "wrait_debug_automation_lockscreen_mode"`
- `MainActivity.kt` line 77-80: Reads this global setting to decide whether to enable lockscreen bypass
- `deploy_debug.sh` line 7: Defines the same constant
- `deploy_debug.sh` line 206-236: Sets and restores this global setting via ADB

**Impact:** Using a custom global setting without a namespaced prefix risks collisions with other apps or system settings. The `wrait_` prefix is better than nothing, but `wrait_debug_automation_lockscreen_mode` is still generic. If another app uses the same setting name, behavior could be unpredictable. Global settings persist across app installations and are not automatically cleaned up if the script crashes before restoration.

**Recommendation:** Use a more specific, namespaced setting name such as `com.wrait.flutter.debug.automation_lockscreen_mode` or use app-specific SharedPreferences instead of global settings. Consider whether the setting can be passed as an intent extra or activity flag instead of persisted state.

---

**PO-3: Permission watchdog may grant permissions indefinitely on failure**

The runtime permission watchdog runs in a background loop without proper bounds checking:

- `deploy_debug.sh` line 264-299: `start_runtime_permission_watchdog()` runs an infinite loop
- `deploy_debug.sh` line 271-295: Loop grants permissions every 0.5 seconds forever
- `deploy_debug.sh` line 301-312: `stop_background_watchdog()` attempts to kill the process
- If the script crashes or is interrupted (SIGKILL), the watchdog may continue running
- The watchdog grants permissions to both `com.wrait.flutter` and `com.wrait.flutter.test` packages

**Impact:** If the script is terminated abruptly (e.g., user Ctrl+C, system crash, or SIGKILL), the background watchdog process may not be cleaned up. This could leave a background process continuously granting RECORD_AUDIO permissions, which is a security concern and could interfere with normal device operation. The trap on EXIT (line 379) handles normal exits but not SIGKILL.

**Recommendation:** Add a PID file mechanism or use a more robust cleanup strategy that can survive SIGKILL (e.g., check for existing watchdog PIDs at startup and kill them). Consider using a timeout-based approach instead of an infinite loop. Add logging to the watchdog to make runaway processes easier to detect.

---

### P1: High-priority implementation issues

**P1-1: Duplicate launch sequence adds unnecessary complexity**

The script launches the Flutter app twice at the end:

- `deploy_debug.sh` line 441-443: First launch with "verified locked-screen cold launch"
- `deploy_debug.sh` line 448-450: Second launch with "final normal launch"
- Both calls use `prepare_phone_for_automation()` and `launch_flutter_app()`
- The spec does not require two launches; it only requires "verifies the app launch"

**Impact:** This doubles the launch verification time and adds complexity without clear benefit. The spec acceptance criteria state: "`./deploy_debug.sh` still builds the debug app, runs the integration test suite on the connected phone, installs only after tests pass, and verifies the app launch" - singular "launch". The plan mentions "Re-prepare the phone before the final cold launch" but doesn't justify two separate launches with different preparation modes.

**Recommendation:** Remove the duplicate launch. If the intent is to verify both locked-screen and normal launch behavior, this should be explicitly specified in the spec and justified. Otherwise, a single launch verification is sufficient.

---

**P1-2: Foreground verification logic is fragile**

The `flutter_app_is_foreground()` function uses string matching on dumpsys output:

- `deploy_debug.sh` line 314-328: Parses `dumpsys activity activities` and `dumpsys window` output
- `deploy_debug.sh` line 320-323: Checks for substring matches in activity output
- `deploy_debug.sh` line 325-327: Checks for substring matches in window output
- No validation that the matched activity is the correct one (could match other activities with similar names)

**Impact:** String matching on dumpsys output is fragile and can break across Android versions. The function checks if the output contains `com.wrait.flutter/.MainActivity` as a substring, which could match other activities or windows with similar names. The function doesn't verify that the matched activity is actually the resumed/focused one - it just checks for the presence of the string anywhere in the output.

**Recommendation:** Use more robust parsing (e.g., extract the actual resumed activity name and compare exactly) or use Android's `am stack` command which provides structured output. Add validation that the matched activity is actually in the resumed state, not just present in the output.

---

**P1-3: Missing error handling for ADB command failures in critical paths**

Several ADB commands use `|| true` or lack proper error handling:

- `deploy_debug.sh` line 118: `appops set` uses `|| true` - failures are silently ignored
- `deploy_debug.sh` line 254: `wm dismiss-keyguard` failure is handled, but only prints a message
- `deploy_debug.sh` line 165: `svc power stayon usb` failure is fatal, but `restore_stay_awake()` uses `|| true` (line 178, 182)
- `deploy_debug.sh` line 202: `settings put global` failure is fatal, but restoration uses `|| true` (line 227, 230)

**Impact:** Silent failures in restoration logic can leave the device in an inconsistent state. If `appops set` fails, the permission may not be properly granted, causing tests to fail with unclear error messages. If restoration commands fail silently, the device may stay awake or have automation mode enabled after the script completes.

**Recommendation:** Remove `|| true` from restoration commands and log failures explicitly. For `appops set`, either make it fatal or log the failure clearly so test failures can be diagnosed. Consider adding a final verification step to check that device state was properly restored.

---

**P1-4: No validation that automation lockscreen mode setting actually exists**

The script assumes the global setting `wrait_debug_automation_lockscreen_mode` can be set and read:

- `deploy_debug.sh` line 206-216: Sets the global setting without checking if it's supported
- `deploy_debug.sh` line 187-195: Reads the setting assuming it returns a value
- `MainActivity.kt` line 77-80: Reads the setting assuming it exists

**Impact:** On some Android versions or device configurations, custom global settings may not be writable or may be ignored. The script doesn't validate that the setting was actually set or that the Android activity will respect it. This could lead to silent failures where the automation mode doesn't actually enable, causing tests to fail on locked devices.

**Recommendation:** Add validation after setting the global setting (read it back and verify it matches the expected value). Add a fallback or error message if the setting cannot be set. Consider using a different mechanism (e.g., intent extras) if global settings are unreliable.

---

### P2: Medium-priority implementation issues

**P2-1: Permission watchdog grants permissions to test package unnecessarily**

The watchdog grants RECORD_AUDIO to both `com.wrait.flutter` and `com.wrait.flutter.test`:

- `deploy_debug.sh` line 272-281: Grants to `com.wrait.flutter`
- `deploy_debug.sh` line 283-292: Grants to `com.wrait.flutter.test`
- The spec only mentions granting to `com.wrait.flutter`

**Impact:** Granting permissions to the test package may not be necessary and could interfere with normal test behavior. The spec acceptance criteria state: "auto-grant `android.permission.RECORD_AUDIO` to `com.wrait.flutter` during deploy-time integration setup" - it doesn't mention the test package. This adds complexity without clear justification.

**Recommendation:** Remove the test package permission granting unless there's evidence it's needed. If it is needed, document why in the spec and plan.

---

**P2-2: Stay-awake and automation mode restoration order is fragile**

The cleanup function calls restoration in a specific order:

- `deploy_debug.sh` line 238-242: `cleanup_on_exit()` calls `stop_background_watchdog`, then `restore_automation_lockscreen_mode`, then `restore_stay_awake`
- `deploy_debug.sh` line 447-448: Manual restoration calls `restore_automation_lockscreen_mode` before the final launch
- `deploy_debug.sh` line 454-455: Final cleanup calls `cleanup_on_exit` again

**Impact:** The order of restoration matters, but there's no documentation explaining why. If the order is wrong, device state may not be properly restored. The script calls restoration manually in some places and relies on the trap in others, which is confusing and error-prone.

**Recommendation:** Document the required restoration order and why it matters. Consider consolidating all restoration logic into a single place to avoid duplication and inconsistency.

---

**P2-3: No timeout for permission watchdog sleep**

The permission watchdog sleeps for 0.5 seconds in each iteration:

- `deploy_debug.sh` line 294: `sleep 0.5`
- If the test suite hangs, the watchdog continues running indefinitely
- No maximum runtime or iteration limit

**Impact:** If the Flutter test suite hangs (e.g., due to a device issue or test bug), the permission watchdog will continue running forever, consuming resources and continuously granting permissions. This could mask the actual test failure and make debugging harder.

**Recommendation:** Add a maximum runtime or iteration limit to the watchdog. Consider making the sleep duration configurable or adaptive based on test progress.

---

**P2-4: Missing test coverage for device state restoration failure**

The test script doesn't verify that device state is properly restored on failure:

- `test/deploy_debug_script_test.sh` line 451-455: Tests wake failure, but doesn't verify cleanup
- `test/deploy_debug_script_test.sh` line 430-441: Tests test failure, but doesn't verify that stay-awake and automation mode were restored
- No test scenario validates that the global setting is restored to its original value

**Impact:** If the script fails mid-execution, device state may not be properly restored. The tests don't verify that cleanup happens on failure paths, which could leave devices in an inconsistent state after failed runs.

**Recommendation:** Add test scenarios that verify device state is properly restored even when the script fails at various points (e.g., after wake failure, after test failure, after install failure).

---

**P2-5: Hardcoded package names reduce maintainability**

Package names are hardcoded in multiple places:

- `deploy_debug.sh` line 274, 285: `com.wrait.flutter` and `com.wrait.flutter.test`
- `deploy_debug.sh` line 321, 326, 327: `com.wrait.flutter/.MainActivity`
- `deploy_debug.sh` line 335, 350: `com.wrait.flutter/com.wrait.flutter.MainActivity`
- `deploy_debug.sh` line 418, 431, 434, 439, 446: `com.wrait.flutter`
- `deploy_debug.sh` line 420, 434: `com.wrait.app`

**Impact:** If package names change in the future, they must be updated in many places. This increases the risk of inconsistencies and makes refactoring harder. The script already has some constants (e.g., `AUTOMATION_LOCKSCREEN_MODE_SETTING`) but package names are not constants.

**Recommendation:** Define package names as constants at the top of the script and use those constants throughout. This makes it easier to change package names in the future and reduces the risk of typos.

---

### P3: Low-priority issues and improvements

**P3-1: Inconsistent error message formatting**

Error messages use different formats:

- `deploy_debug.sh` line 14: `printf 'error: %s\n' "$*" >&2`
- `deploy_debug.sh` line 252: `fail "failed to wake Android phone $phone_serial for $phase_description"`
- `deploy_debug.sh` line 347: `fail "com.wrait.flutter launch timed out after install and foreground verification failed; force-stop the app and inspect device logs"`

**Impact:** Inconsistent error message formatting makes it harder to parse errors programmatically and creates a less polished user experience. Some messages include device serials and phase descriptions, while others don't.

**Recommendation:** Standardize error message formatting. Consider including device serial, phase, and actionable next steps in all error messages where applicable.

---

**P3-2: No validation that phone actually woke up**

The wake command doesn't verify the phone screen actually turned on:

- `deploy_debug.sh` line 251-252: Sends `input keyevent KEYCODE_WAKEUP` and assumes success if the command doesn't fail
- No check of screen state or power state after wake
- Relies on subsequent commands failing if the phone didn't wake

**Impact:** If the phone doesn't actually wake up (e.g., due to hardware issues or power management), the script may continue and fail later with unclear error messages. The wake command succeeding doesn't guarantee the screen is on.

**Recommendation:** Add a check after wake to verify the phone screen is actually on (e.g., check `dumpsys power` or screen state). If wake fails, fail immediately with a clear message.

---

**P3-3: Permission watchdog announcement logic is redundant**

The watchdog uses announcement flags to avoid duplicate messages:

- `deploy_debug.sh` line 268-269: `announced_app_package` and `announced_test_package` flags
- `deploy_debug_script_test.sh` line 486-487: Tests expect both messages

**Impact:** This adds complexity for minimal value. The messages are only printed once per package, but the script already prints "Preparing Android phone..." messages that indicate progress. The permission grant messages are useful but the announcement logic is unnecessary.

**Recommendation:** Simplify by removing the announcement flags and printing the message every time a permission is successfully granted, or move the announcement outside the loop and print it once when the watchdog starts.

---

**P3-4: No documentation of Android version compatibility**

The implementation uses Android APIs that may not be available on all versions:

- `MainActivity.kt` line 15: Uses `Build.VERSION_CODES.O_MR1` for show-when-locked API
- `MainActivity.kt` line 18-23: Falls back to deprecated flags for older versions
- No documentation of minimum Android version required

**Impact:** It's unclear what the minimum Android version is for this feature to work. The fallback to deprecated flags suggests it should work on older versions, but there's no explicit documentation or testing of version boundaries.

**Recommendation:** Document the minimum Android version required for locked-screen automation. Add a check in the script to verify the device meets the minimum version, or fail with a clear message if it doesn't.

---

**P3-5: Test scenarios don't validate all new code paths**

The test script adds new scenarios but doesn't cover all new functionality:

- `test/deploy_debug_script_test.sh` line 451-455: Tests wake failure
- `test/deploy_debug_script_test.sh` line 476-480: Tests keyguard dismiss refusal
- `test/deploy_debug_script_test.sh` line 482-497: Tests locked phone success
- No test for permission watchdog failure
- No test for foreground verification failure when app is not actually foreground
- No test for global setting read/write failure

**Impact:** Some code paths (e.g., permission watchdog, foreground verification) are not fully tested. This increases the risk of bugs in those paths going undetected.

**Recommendation:** Add test scenarios for permission watchdog failure, foreground verification failure, and global setting failures. Ensure all new functions have corresponding test coverage.

---

**P3-6: Script builds APK twice unnecessarily**

The script builds both debug and profile APKs:

- `deploy_debug.sh` line 386-389: Builds debug APK
- `deploy_debug.sh` line 412-415: Builds profile APK
- The debug APK is only used for testing, then discarded
- The profile APK is installed as the final artifact

**Impact:** Building two APKs doubles the build time. If the intent is to test with debug and deploy with profile, this should be explicitly justified in the spec. The spec says "builds the debug app" and doesn't mention profile builds.

**Recommendation:** If profile builds are required for the final artifact, document why in the spec. If not, consider building only one APK type to reduce build time. Alternatively, consider building the profile APK first and using it for both testing and deployment if that's valid.

---

**P3-7: No validation that PROXY_SECRET is actually used in profile build**

The script passes `PROXY_SECRET` to both debug and profile builds:

- `deploy_debug.sh` line 381-383: Defines `flutter_build_args` with PROXY_SECRET
- `deploy_debug.sh` line 387: Uses args for debug build
- `deploy_debug.sh` line 414: Uses args for profile build
- Profile builds typically strip debugging features and may not honor dart-defines the same way

**Impact:** If profile builds don't respect the dart-define, the installed app may not have the PROXY_SECRET configured correctly, causing runtime failures. The script doesn't validate that the secret was actually baked into the profile APK.

**Recommendation:** Verify that profile builds honor the dart-define for PROXY_SECRET. Add a validation step (e.g., extract and check the APK metadata) to ensure the secret is present in the profile build.

---

**P3-8: Cleanup function may run multiple times**

The script calls cleanup both manually and via trap:

- `deploy_debug.sh` line 379: Sets trap to call `cleanup_on_exit` on EXIT
- `deploy_debug.sh` line 454: Clears the trap with `trap - EXIT`
- `deploy_debug.sh` line 455: Manually calls `cleanup_on_exit`
- If the script exits before line 454, the trap runs cleanup
- If the script reaches line 455, cleanup runs manually

**Impact:** This is confusing and error-prone. If someone adds code after line 455 that might exit, cleanup won't run. The manual trap clearing and cleanup call suggest the trap approach isn't fully trusted.

**Recommendation:** Either rely entirely on the trap or entirely on manual cleanup. Don't mix both approaches. If using the trap, ensure it's set up correctly at the start and never cleared prematurely.

---

## Summary

The implementation successfully adds locked-screen and screen-off support to the Android debug deployment workflow, but introduces several issues:

1. **PO-level issues**: Profile APK build without spec justification, global settings namespace pollution risk, and permission watchdog cleanup concerns
2. **P1-level issues**: Duplicate launch sequence, fragile foreground verification, missing error handling, and no validation of automation mode setting
3. **P2-level issues**: Unnecessary test package permission granting, fragile restoration order, missing watchdog timeout, missing restoration failure tests, and hardcoded package names
4. **P3-level issues**: Inconsistent error messages, no wake validation, redundant announcement logic, missing version compatibility docs, incomplete test coverage, unnecessary dual builds, no PROXY_SECRET validation in profile builds, and confusing cleanup logic

The most critical issue is the introduction of profile APK builds without explicit spec approval, which changes the deployed artifact type. The global settings approach and permission watchdog cleanup also need attention to avoid security and reliability issues.
