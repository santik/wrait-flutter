# Implementation: Screenshot and Screen Recording Prevention

> **Feature number:** 020
> **Spec:** [`spec.md`](spec.md)
> **Plan:** [`plan.md`](plan.md)
> **Tasks:** [`tasks.md`](tasks.md)
> **Author:** Codex
> **Date:** 2026-06-23

---

## Summary

Implemented native capture protection for Android and iOS without changing
Flutter route behavior, backend behavior, persisted data, recording, drafts,
quota, entries, sharing, deletion, or app-lock authentication.

Android now applies `FLAG_SECURE` through a shared `enableCaptureProtection()`
helper before `super.onCreate(...)`, again after Flutter activity setup, and
again during resume/window-focus transitions. The repeated application is
intentional: emulator validation showed that the initial pre-`super` flag alone
did not remain present on the final live Flutter window, so the approved
review-fix pass documented and kept the reassertion strategy.

iOS now installs a scene-level native privacy cover in `SceneDelegate.swift`.
The cover is shown while the scene is inactive/backgrounded for app-switch
snapshot protection and while `UIScreen.main.isCaptured` reports active screen
capture. It is hidden again when the scene is active and no capture is
detected. The review-fix pass also made the cover copy generic (`Private`) and
explicitly hid its accessibility state while the cover is not visible.

Because normal simulator bootstrap continued to surface a system passcode prompt
before any Flutter content rendered, `lib/main.dart` now includes a compile-time
`CAPTURE_VALIDATION_MODE=true` launch path that shows non-sensitive placeholder
content for native iOS privacy-cover verification. Production launches remain
on the normal bootstrap path.

## Changed files

| File | Change |
| --- | --- |
| `android/app/src/main/kotlin/com/wrait/flutter/MainActivity.kt` | Added always-on secure-window protection before first render and during later activity lifecycle/focus transitions. |
| `ios/Runner/SceneDelegate.swift` | Added native privacy cover, screen-capture notification observer, and scene lifecycle handling. |
| `lib/main.dart` | Added a compile-time validation-only launch screen used to bypass simulator passcode-gated startup dependencies during native privacy-cover validation. |
| `test/platform/android_capture_prevention_test.dart` | Added source regression tests for Android secure-window ordering, reapplication, and unconditional scope. |
| `test/platform/ios_capture_privacy_test.dart` | Added source regression tests for iOS capture observation, inactive/background cover behavior, and observer cleanup. |
| `integration_test/capture_prevention_flow_test.dart` | Added integration smoke coverage for launch and basic navigation with app lock disabled. |
| `specs/020-screenshot-screen-recording-prevention/spec.md` | Recorded SDD approvals and implementation start. |
| `specs/020-screenshot-screen-recording-prevention/tasks.md` | Updated implementation statuses and validation evidence. |

## Validation

Automated checks:

```text
PASS dart format test/platform/android_capture_prevention_test.dart test/platform/ios_capture_privacy_test.dart integration_test/capture_prevention_flow_test.dart
PASS dart format lib/data/auth/app_lock_providers.dart lib/main.dart test/platform/android_capture_prevention_test.dart test/platform/ios_capture_privacy_test.dart
PASS /opt/homebrew/bin/flutter test test/platform/android_capture_prevention_test.dart test/platform/ios_capture_privacy_test.dart test/app_smoke_test.dart test/core/router/app_router_test.dart
PASS /opt/homebrew/bin/flutter test test/platform/android_capture_prevention_test.dart test/platform/ios_capture_privacy_test.dart test/app_smoke_test.dart test/bootstrap_app_test.dart
PASS /opt/homebrew/bin/flutter test -d emulator-5554 integration_test/capture_prevention_flow_test.dart
PASS /opt/homebrew/bin/flutter test -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/capture_prevention_flow_test.dart
PASS /opt/homebrew/bin/flutter test -d emulator-5554 integration_test/app_lock_flow_test.dart
PASS /opt/homebrew/bin/flutter analyze
PASS ./gradlew --no-daemon compileDebugKotlin
PASS /opt/homebrew/bin/flutter build apk --profile
PASS /opt/homebrew/bin/flutter build ios --simulator
```

Android emulator runtime evidence:

```text
PASS profile APK cold launch:
adb -s emulator-5554 shell am start -W -n com.wrait.flutter.dev/com.wrait.flutter.MainActivity
Status: ok
LaunchState: COLD
Activity: com.wrait.flutter.dev/com.wrait.flutter.MainActivity
TotalTime: 1044

PASS dumpsys window showed live profile window flag:
fl=LAYOUT_IN_SCREEN SECURE LAYOUT_INSET_DECOR SPLIT_TOUCH HARDWARE_ACCELERATED DRAWS_SYSTEM_BAR_BACKGROUNDS

PASS /private/tmp/wrait_us020_review_android_foreground.png
Foreground screenshot was fully black.

PASS /private/tmp/wrait_us020_review_android_recents.png
Recent-apps output remained black during the app-switch validation path.

PASS /private/tmp/us020_android_window_after_resume.txt
Secure flags were still present on the live activity window after app-switching
away and returning with debug automation lockscreen mode enabled.

PASS /private/tmp/wrait_us020_review_android_after_resume.png
Foreground screenshot after the return-to-foreground path was also fully black.

PASS /private/tmp/wrait_us020_review_android_screenrecord.mp4
PASS /private/tmp/wrait_us020_review_android_screenrecord_frame.png
Android screenrecord completed, and an extracted video frame was visually black.
```

iOS simulator runtime evidence:

```text
PASS iOS simulator integration smoke on iPhone 17 simulator
Device id: 491CD949-D3C0-4C4C-A6B9-15BAB1859156

PASS /opt/homebrew/bin/flutter build ios --simulator
Native SceneDelegate privacy-cover code compiled.

PASS xcrun simctl install booted build/ios/iphonesimulator/Runner.app
PASS xcrun simctl launch booted com.wrait.app

Runtime artifacts:
/private/tmp/wrait_us020_review_ios_validation_foreground.png
/private/tmp/A5A09BAB-CF88-405C-A1F1-129FABA7B1CF@3x.ktx.png
/private/tmp/wrait_us020_review_ios_during_recording.png
/private/tmp/wrait_us020_review_ios_record.mov
/private/tmp/wrait_us020_review_ios_record_frame.png
/private/tmp/wrait_us020_review_ios_after_safari_close.png
```

## Validation notes and limitations

- The approved validation exception was used: OS screenshot, screen-recording,
  and app-switch pixel contents were validated with runtime artifacts and
  documented limitations instead of direct Flutter `integration_test`
  assertions.
- Android validation must target the freshly installed debug/profile package
  `com.wrait.flutter.dev`. A stale release package `com.wrait.flutter` was
  initially inspected by mistake and did not represent this implementation.
- The standalone Android debug app showed the known splash-screen limitation
  from project guidance. The profile APK was used for final Android runtime
  capture evidence because it reached a live secure window and produced black
  foreground/recents capture artifacts.
- Review-driven Android evidence now also includes the resumed-window secure
  flag dump, a post-resume black screenshot, a decoded screen-recording frame,
  and a temporary automation-lockscreen-mode compatibility check.
- Normal iOS simulator bootstrap continued to show a system passcode prompt for
  Wrait even after `APP_LOCK_ENABLED=false`, so direct cover observation on the
  production bootstrap path remained blocked by protected startup dependencies.
- `CAPTURE_VALIDATION_MODE=true` renders non-sensitive placeholder content from
  `lib/main.dart` without touching the normal bootstrap path. This made the
  native privacy-cover behavior observable on simulator while keeping runtime
  evidence free of real diary content.
- Stored SplashBoard snapshot inspection provided direct app-switch/background
  evidence: the saved scene snapshot rendered the black `Private` cover instead
  of the visible placeholder content.
- `xcrun simctl io booted recordVideo` still did not toggle
  `UIScreen.main.isCaptured` in this environment. Both the live recording
  screenshot and the extracted recorded frame showed the underlying placeholder
  content, so active-capture hiding remains a simulator limitation and still
  needs physical-device validation for stronger evidence.

## Review status

The first external review pass has been remediated and the approved fixes are
implemented. Per the SDD workflow, the feature remains in progress until the
review loop is either accepted as complete or a new reviewer update arrives.
