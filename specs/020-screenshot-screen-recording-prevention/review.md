# Review: Screenshot and Screen Recording Prevention

> **Feature number:** 020
> **Spec:** [`spec.md`](spec.md)
> **Plan:** [`plan.md`](plan.md)
> **Tasks:** [`tasks.md`](tasks.md)
> **Implementation:** [`implementation.md`](implementation.md)
> **Date:** 2026-06-23

---

## Summary

This review identifies architectural deviations, validation gaps, and platform-specific concerns in the US-020 implementation. The Android implementation uses an undocumented workaround for flag persistence that was not specified in the plan. iOS runtime validation did not demonstrate the privacy cover behavior due to system passcode interference. Several critical acceptance criteria lack direct runtime evidence.

---

## Findings

### P0 - Critical

#### P0-1: Android secure flag reapplication is an undocumented architectural deviation

**Location:** `android/app/src/main/kotlin/com/wrait/flutter/MainActivity.kt`

**Issue:** The implementation reapplies `FLAG_SECURE` in four locations:
- Before `super.onCreate()` (line 16)
- After `super.onCreate()` (line 33)
- In `onResume()` (line 38)
- In `onWindowFocusChanged(hasFocus: true)` (line 44)

The plan specifies only "Add the secure-window flag in `MainActivity.onCreate` before `super.onCreate(...)`". The implementation.md states this reapplication is intentional because "emulator validation showed that the initial pre-`super` flag alone did not remain present on the final live Flutter window."

This is a significant architectural deviation from the approved plan. The plan did not document this platform behavior or propose the multi-location reapplication strategy. The spec requires "The flag must not be cleared during ordinary lifecycle transitions," but the implementation works around a platform that apparently clears or fails to apply the flag during those transitions.

**Impact:** The implementation relies on a workaround for platform behavior that was not anticipated, documented, or approved in the plan. This workaround may be fragile across Android versions, OEM skins, or physical devices. The deviation was not captured as an approved change to the plan before implementation.

**Recommendation:** Document this platform behavior as a known limitation in `plan.md` and `implementation.md`, or investigate the root cause of why the single pre-`super` application fails. If the workaround is necessary, it should be explicitly approved as a plan deviation with rationale and risk assessment.

---

#### P0-2: iOS privacy cover behavior never demonstrated in runtime validation

**Location:** `ios/Runner/SceneDelegate.swift`, `specs/020-screenshot-screen-recording-prevention/implementation.md`

**Issue:** The iOS runtime validation evidence states: "Runtime standalone simulator screenshot: `/private/tmp/wrait_us020_ios_foreground.png`; Wrait app content was hidden by the US-019 system passcode prompt." The validation also notes: "simulator recording did not expose Wrait content, but the visible surface remained the system passcode prompt, so this did not demonstrate the native `wrait is private` cover."

The spec requires: "iOS captured output does not show journal content when the platform provides a supported way to protect screenshots or capture snapshots." The plan requires: "Verify iOS simulator app-switch/background snapshot behavior shows the native privacy cover instead of app content."

The actual validation never observed the `SceneDelegate.swift` privacy cover in action. All iOS evidence was blocked by the system passcode prompt from US-019. The privacy cover implementation exists in source code but was never verified to function correctly at runtime.

**Impact:** The core iOS capture-prevention mechanism has no runtime evidence that it works. The integration test with app lock disabled verified Flutter launch, but the native cover behavior during capture or app-switching was never observed. This leaves the iOS implementation unvalidated for its primary purpose.

**Recommendation:** Re-run iOS simulator validation with app lock disabled (as done in the integration test) to demonstrate the privacy cover during app-switcher snapshots and screen capture attempts. Document the actual privacy cover behavior, not the passcode prompt behavior.

---

### P1 - High

#### P1-1: iOS app-switcher snapshot protection lacks runtime validation

**Location:** `ios/Runner/SceneDelegate.swift`, `specs/020-screenshot-screen-recording-prevention/implementation.md`

**Issue:** The implementation.md states: "iOS app-switcher limitation: `simctl` exposes no app-switcher command in this environment, and AppleScript `System Events` keystrokes to the Simulator were denied by macOS accessibility permissions. App-switch privacy-cover behavior is therefore covered by source regression tests and native build validation, with a physical-device/manual Simulator GUI path preserved for stronger future evidence."

The spec requires: "Android recent-apps previews of Wrait do not show journal content" and "Capture protection covers all Wrait surfaces that can show sensitive diary content." The plan requires: "Verify iOS simulator app-switch/background snapshot behavior shows the native privacy cover instead of app content."

The iOS app-switcher snapshot protection has no runtime validation. Source-level tests confirm the code exists, but there is no evidence that the cover actually appears during app-switcher snapshots. The approved validation exception was for "OS screenshot, screen-recording, and app-switch pixel contents will be validated with emulator/simulator runtime evidence instead of direct Flutter integration-test assertions." This exception assumed runtime evidence would be collected, but it was not.

**Impact:** A critical privacy protection (app-switcher snapshots) has no runtime validation. The implementation may not work correctly, and this would only be discovered on physical devices or in production.

**Recommendation:** Manually trigger app-switcher snapshots in the iOS Simulator GUI and capture screenshots to verify the privacy cover appears. If accessibility permissions prevent automation, perform the validation manually and document the evidence. If this is genuinely impossible in the current environment, document it as a validation gap that requires physical-device testing before release.

---

#### P1-2: iOS screen capture detection behavior not validated

**Location:** `ios/Runner/SceneDelegate.swift`, `specs/020-screenshot-screen-recording-prevention/implementation.md`

**Issue:** The implementation.md states: "Runtime recording attempt: `/private/tmp/wrait_us020_ios_record.mov` and `/private/tmp/wrait_us020_ios_during_recording.png`; simulator recording did not expose Wrait content, but the visible surface remained the system passcode prompt, so this did not demonstrate the native `wrait is private` cover."

The plan requested: "Attempt simulator video capture with `xcrun simctl io booted recordVideo` where practical; expected evidence: the privacy cover appears if the simulator reports active screen capture, or the simulator limitation is documented."

The validation did not determine whether `UIScreen.main.isCaptured` becomes true during simulator recording. The privacy cover logic depends on this flag, but its behavior in the simulator was never verified. The implementation notes the limitation but does not confirm whether the flag toggles.

**Impact:** The iOS screen capture detection logic has no runtime validation. If `UIScreen.main.isCaptured` does not toggle in the simulator, the privacy cover will not appear during screen recording on simulators, and this behavior is unknown.

**Recommendation:** Add logging to `SceneDelegate.swift` to print when `UIScreen.main.isCaptured` changes, or verify through debugger inspection whether the flag toggles during `xcrun simctl io booted recordVideo`. Document the actual behavior. If the flag does not toggle in simulators, document this as a platform limitation and require physical-device validation for screen capture behavior.

---

#### P1-3: Android screen recording validation incomplete

**Location:** `specs/020-screenshot-screen-recording-prevention/implementation.md`

**Issue:** The implementation.md states: "PASS screenrecord artifact creation: `/private/tmp/wrait_us020_screenrecord.mp4`; Android `screenrecord` completed and produced a small artifact. Local `qlmanage` thumbnail extraction hung and was stopped, so no decoded video-frame inspection was available in this session."

The spec requires: "Android screen recordings of Wrait produce protected output that does not show journal content." The plan requested: "Run a short emulator screen recording with `adb shell screenrecord` where practical; expected evidence: the resulting video does not expose Wrait app content."

The video artifact was created but never visually inspected. The validation relied on foreground screenshot and recents artifacts instead. This is incomplete validation for the screen-recording acceptance criterion.

**Impact:** The Android screen recording protection has no direct evidence. The assumption is that `FLAG_SECURE` applies to screen recording the same way it applies to screenshots, but this was not verified on the actual recording artifact.

**Recommendation:** Use a different tool to inspect the video artifact (e.g., `ffmpeg`, VLC, or frame extraction) to verify the recording content is black. Document the actual video content. If the video cannot be inspected, document this as a validation gap.

---

### P2 - Medium

#### P2-1: No validation that Android secure flag survives app lifecycle transitions

**Location:** `android/app/src/main/kotlin/com/wrait/flutter/MainActivity.kt`, `specs/020-screenshot-screen-recording-prevention/implementation.md`

**Issue:** The spec requires: "Protection state survives ordinary lifecycle transitions including app resume, backgrounding, app-switching, and return to foreground." The plan requested: "Verify the app reaches the expected Wrait UI and remains usable" and capture screenshots/recents.

The validation checked cold launch, foreground screenshot, recents, and screen recording. It did not explicitly verify that the secure flag remains active after backgrounding the app and returning to foreground, or after app-switching away and back. The implementation reapplies the flag in `onResume()` and `onWindowFocusChanged()`, which suggests the flag may not persist, but this was not validated.

**Impact:** The lifecycle persistence requirement has no direct validation. The reapplication workaround may be masking a platform issue where the flag is cleared during transitions.

**Recommendation:** Add runtime validation steps: background the app with `adb shell am start -W -n com.wrait.flutter.dev/com.wrait.flutter.MainActivity`, then bring it to foreground and verify `dumpsys window` still shows the SECURE flag. Capture screenshots after backgrounding and returning to foreground.

---

#### P2-2: iOS privacy cover text may violate "no user-specific app data" requirement

**Location:** `ios/Runner/SceneDelegate.swift` lines 66, 61

**Issue:** The privacy cover displays the text "wrait is private" and has accessibility label "wrait is private". The spec requires: "The cover must contain no diary content, backend data, local paths, stack traces, secrets, or user-specific app data."

While "wrait is private" is not sensitive user data, it is app-specific branding. The spec allows "optional generic privacy or locked-state copy when it is the simplest platform-appropriate way to hide content." However, the plan states: "The cover must contain no diary content, backend data, local paths, stack traces, secrets, or user-specific app data."

The implementation uses app-specific branding ("wrait") instead of truly generic copy like "Private" or "Content hidden". This is a minor deviation from the "no user-specific app data" guidance, though likely acceptable.

**Impact:** Minimal. The text is not sensitive, but it is app-specific rather than generic.

**Recommendation:** Consider whether the cover should use truly generic text like "Private" or "Content hidden" to align more closely with the "no user-specific app data" requirement. If the current text is acceptable, document the rationale.

---

#### P2-3: No validation of capture prevention during app lock state

**Location:** `integration_test/capture_prevention_flow_test.dart`

**Issue:** The integration test disables app lock (`appLockEnabledProvider.overrideWithValue(false)`). The spec requires: "Capture-prevention behavior works alongside app locking without exposing the content behind the lock surface." The plan notes: "US-020 works alongside US-019 app lock. Android secure-window protection wraps the whole activity, including the app-lock surface. iOS native privacy cover sits above Flutter content during capture/app-switch states, so it can cover the app-lock screen too when needed."

There is no runtime validation that capture prevention works correctly when the app lock is active. The integration test only validates the unlocked state.

**Impact:** The interaction between capture prevention and app lock has no runtime validation. If the privacy cover conflicts with the app lock UI or fails to cover it, this would not be detected.

**Recommendation:** Add an integration test variant with app lock enabled to verify that capture prevention does not interfere with the lock surface and that captured output during the locked state does not reveal content behind the lock.

---

#### P2-4: Source-level tests are brittle and may miss refactoring breaks

**Location:** `test/platform/android_capture_prevention_test.dart`, `test/platform/ios_capture_privacy_test.dart`

**Issue:** The source-level tests use string searching (`indexOf`, `contains`) to verify code structure. These tests are brittle and may break with harmless refactoring (e.g., renaming methods, changing code organization, adding comments). They also cannot verify runtime behavior.

The plan acknowledges this risk: "Source-level tests become brittle after native refactors" with mitigation "Keep tests focused on required observable contracts: secure flag order and lifecycle/capture observer presence."

**Impact:** The tests may fail due to unrelated refactoring, creating maintenance burden. They provide weak assurance compared to runtime tests.

**Recommendation:** Consider whether these source-level tests provide sufficient value given their brittleness. If kept, ensure they are clearly documented as regression tests for specific contracts, not general code structure tests. Add comments explaining what each test verifies and why it's critical.

---

#### P2-5: No validation of performance impact

**Location:** `specs/020-screenshot-screen-recording-prevention/spec.md`

**Issue:** The spec requires: "Capture protection must not add noticeable delay to first frame, foreground resume, navigation, recording start, recording stop, or app-lock unlock."

There is no performance measurement or validation in the implementation evidence. The Android implementation calls `enableCaptureProtection()` multiple times during lifecycle transitions, which could theoretically add overhead. The iOS implementation adds notification observers and view manipulation during scene lifecycle.

**Impact:** The performance requirement has no validation. If the implementation adds noticeable delay, this would not be detected until user reports.

**Recommendation:** Add basic performance validation: measure cold launch time with and without the secure flag (though this may be difficult to isolate). For iOS, verify that scene lifecycle transitions with the privacy cover do not introduce visible lag. Document that performance was validated subjectively during manual testing if automated measurement is impractical.

---

### P3 - Low

#### P3-1: iOS privacy cover accessibility label may not be sufficient for screen readers

**Location:** `ios/Runner/SceneDelegate.swift` line 60-61

**Issue:** The privacy cover is marked as an accessibility element with label "wrait is private". However, when the cover is hidden (`isHidden = true`), screen readers may still announce it or may not announce it when it becomes visible. The cover's accessibility behavior during show/hide transitions is not validated.

**Impact:** Screen reader users may experience unexpected announcements or may not receive appropriate feedback when the cover appears. This is a minor accessibility concern.

**Recommendation:** Verify accessibility behavior with VoiceOver during manual testing. Consider whether the cover should dynamically change its accessibility properties when shown/hidden, or whether it should be removed from the accessibility tree when hidden.

---

#### P3-2: No validation on physical devices

**Location:** `specs/020-screenshot-screen-recording-prevention/implementation.md`

**Issue:** All runtime validation was performed on emulator and simulator. The plan acknowledges: "Android emulator capture behavior differs from physical devices or OEM builds" as a risk with mitigation "Validate on emulator for the required gate, document behavior, and preserve a physical-device validation path when stronger evidence is needed."

No physical-device validation was performed. Emulator and simulator behavior may not match physical devices, especially for OEM-specific Android builds or iOS hardware-specific behaviors.

**Impact:** The implementation may behave differently on physical devices. OEM Android skins may handle `FLAG_SECURE` differently. iOS hardware may have different screen capture behavior than simulators.

**Recommendation:** Document physical-device validation as a required step before production release. Preserve the validation commands and evidence collection process for future physical-device testing.

---

#### P3-3: Android debug automation lockscreen flags may interact with secure flag

**Location:** `android/app/src/main/kotlin/com/wrait/flutter/MainActivity.kt` lines 18-30

**Issue:** The automation lockscreen mode adds `FLAG_SHOW_WHEN_LOCKED`, `FLAG_TURN_SCREEN_ON`, and `FLAG_KEEP_SCREEN_ON`. The plan states: "Existing debug lockscreen automation may continue to add its own flags, but it must not remove secure-window protection."

There is no validation that these automation flags do not interfere with `FLAG_SECURE`. Window flags can interact in complex ways, and adding multiple flags may have unexpected effects.

**Impact:** The interaction between automation flags and the secure flag is not validated. In debug automation mode, the secure protection may not work as expected.

**Recommendation:** Add runtime validation in automation mode: enable the automation lockscreen setting, launch the app, and verify that `dumpsys window` still shows the SECURE flag and that screenshots are still black.

---

#### P3-4: No validation of capture prevention during Flutter route transitions

**Location:** `integration_test/capture_prevention_flow_test.dart`

**Issue:** The spec requires: "Capture protection is active before any sensitive diary content is displayed during a cold launch" and "Capture protection covers all Wrait surfaces that can show sensitive diary content."

The integration test only validates launch and basic navigation to the stats screen and entry list. It does not validate route transitions between different screens (e.g., main screen to entry detail, settings, error states).

**Impact:** Route transitions could briefly expose content before capture protection is active, though this is unlikely given the native-layer implementation.

**Recommendation:** Add integration test coverage for additional route transitions if Flutter-layer routing could affect native window/scene state. If native protection is truly route-agnostic, document this assumption.

---

## Summary of Critical Gaps

1. **Android secure flag reapplication** is an undocumented workaround for platform behavior that was not approved in the plan.
2. **iOS privacy cover behavior** was never demonstrated in runtime validation due to passcode interference.
3. **iOS app-switcher snapshot protection** has no runtime validation.
4. **iOS screen capture detection** behavior in simulator is unknown.
5. **Android screen recording** artifact was never visually inspected.

These gaps should be addressed before considering the implementation complete.
