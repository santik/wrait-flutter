# Tasks: Screenshot and Screen Recording Prevention

> **Feature number:** 020
> **Plan:** [`plan.md`](plan.md)
> **Author:** Codex
> **Date:** 2026-06-23

---

## Legend

- `[ ]` — not started
- `[x]` — complete
- `[P]` — can be parallelized with other `[P]` tasks in the same group
- `[B]` — blocked (note the blocker)

## Task groups

Tasks are organized into sequential groups. Tasks within the same group marked
`[P]` can be worked on in parallel.

### Group 1: Native Contract Regression Tests

Pin the platform contracts before changing native code.

- [x] [P] Add Android source regression coverage that `FLAG_SECURE` is applied
      in `MainActivity.onCreate` before `super.onCreate(...)` —
      `test/platform/android_capture_prevention_test.dart`
- [x] [P] Add Android source regression coverage that secure-window protection
      is unconditional and not limited to debug automation mode —
      `test/platform/android_capture_prevention_test.dart`
- [x] [P] Add iOS source regression coverage for screen-capture observation and
      privacy-cover lifecycle methods —
      `test/platform/ios_capture_privacy_test.dart`
- [x] [P] Add iOS source regression coverage that inactive/background scene
      states show the privacy cover and active non-captured state hides it —
      `test/platform/ios_capture_privacy_test.dart`

### Group 2: Android Native Protection

Apply Android capture prevention at the earliest app-owned launch point.

- [x] Add secure-window protection before any existing launch automation and
      before `super.onCreate(...)` —
      `android/app/src/main/kotlin/com/wrait/flutter/MainActivity.kt`
  - Depends on: Group 1
- [x] Preserve existing app-lock automation lockscreen flags, device-id method
      channel, security-settings method channel, and activity superclass —
      `android/app/src/main/kotlin/com/wrait/flutter/MainActivity.kt`
  - Depends on: Android secure-window task
- [x] Confirm Android implementation keeps debug/profile package
      `com.wrait.flutter.dev` and release package `com.wrait.flutter`
      behavior unchanged —
      `android/app/src/main/kotlin/com/wrait/flutter/MainActivity.kt`
  - Depends on: Android secure-window task

### Group 3: iOS Native Privacy Cover

Implement all-surface iOS hiding for screen capture and app-switch snapshots.

- [x] Create a full-window native privacy cover with generic non-sensitive
      protected output — `ios/Runner/SceneDelegate.swift`
  - Depends on: Group 1
- [x] Show the privacy cover when the scene is inactive or backgrounded so
      app-switcher snapshots do not expose Wrait content —
      `ios/Runner/SceneDelegate.swift`
  - Depends on: privacy-cover creation
- [x] Observe main `UIScreen` capture changes and show the privacy cover while
      active screen capture is detected — `ios/Runner/SceneDelegate.swift`
  - Depends on: privacy-cover creation
- [x] Hide the privacy cover when the scene is active and screen capture is not
      detected — `ios/Runner/SceneDelegate.swift`
  - Depends on: lifecycle and capture handling
- [x] Remove screen-capture observers during scene teardown to avoid stale
      callbacks — `ios/Runner/SceneDelegate.swift`
  - Depends on: capture observation

### Group 4: Integration Smoke Coverage

Prove the native privacy changes do not break normal Flutter app use.

- [x] Create a capture-prevention integration harness with app-lock disabled
      and existing provider overrides matching smoke-test patterns —
      `integration_test/capture_prevention_flow_test.dart`
  - Depends on: Groups 2 and 3
- [x] Add integration coverage that Wrait launches to the main screen and the
      primary action remains reachable with normal capture state —
      `integration_test/capture_prevention_flow_test.dart`
  - Depends on: integration harness
- [x] Add integration coverage that basic navigation to entries or stats
      surfaces still works with capture prevention present —
      `integration_test/capture_prevention_flow_test.dart`
  - Depends on: integration harness

### Group 5: Automated Validation

Run focused and adjacent checks, recording evidence as implementation proceeds.

- [x] Run focused source and smoke tests:
      `/opt/homebrew/bin/flutter test test/platform/android_capture_prevention_test.dart test/platform/ios_capture_privacy_test.dart test/app_smoke_test.dart test/core/router/app_router_test.dart`
  - Depends on: Groups 1-4
- [x] Run capture-prevention integration smoke:
      `/opt/homebrew/bin/flutter test integration_test/capture_prevention_flow_test.dart`
  - Depends on: Group 4
- [x] Run app-lock integration regression:
      `/opt/homebrew/bin/flutter test integration_test/app_lock_flow_test.dart`
  - Depends on: Groups 2-4
- [x] Run static analysis:
      `/opt/homebrew/bin/flutter analyze`
  - Depends on: Groups 1-4
- [x] Run Android compile validation with the repo-approved Gradle command or
      equivalent Flutter Android build check —
      `./gradlew --no-daemon compileDebugKotlin` from `android/`
  - Depends on: Android native changes
- [x] If generated backend API output is missing, run `npm run build` before
      Flutter tests and record that prerequisite in validation evidence.

### Group 6: Runtime Platform Verification

Collect required emulator/simulator evidence and the approved OS-capture
validation-exception notes.

- [x] Verify Android emulator cold launch with launcher-style command:
      `adb shell am start -W -n com.wrait.flutter.dev/com.wrait.flutter.MainActivity`
  - Depends on: Group 5
- [x] Verify Android emulator screenshot output with `adb exec-out screencap -p`
      while Wrait is foregrounded and record whether app content is hidden —
      runtime evidence
  - Depends on: Android cold-launch verification
- [x] Verify Android emulator recent-apps preview by opening app switcher,
      capturing the emulator screen, and recording whether Wrait content is
      hidden — runtime evidence
  - Depends on: Android cold-launch verification
- [x] Verify Android emulator screen-recording behavior with
      `adb shell screenrecord` where practical, or document emulator
      limitations — runtime evidence
  - Depends on: Android cold-launch verification
- [x] Verify iOS simulator launch and normal foreground usability —
      runtime evidence
  - Depends on: Group 5
- [x] Verify iOS simulator app-switch/background snapshot behavior shows the
      native privacy cover instead of app content, or document simulator
      control limitations with source/build coverage and a manual validation
      path preserved — runtime evidence
  - Depends on: iOS simulator launch verification
- [x] Attempt iOS simulator video capture with
      `xcrun simctl io booted recordVideo` where practical, and document
      whether simulator capture toggles the native capture state —
      runtime evidence
  - Depends on: iOS simulator launch verification
- [x] Record the approved validation exception: OS screenshot, video, and
      app-switch pixels are validated with runtime evidence rather than direct
      `integration_test` assertions; iOS simulator capture limitations may be
      documented with a physical-device path preserved.

### Group 7: Implementation Evidence

Capture what changed and prepare the feature for external review.

- [x] Update task statuses as implementation progresses —
      `specs/020-screenshot-screen-recording-prevention/tasks.md`
- [x] Record automated test commands, runtime capture evidence, and approved
      validation exception notes in the validation evidence section —
      `specs/020-screenshot-screen-recording-prevention/tasks.md`
- [x] Confirm `spec.md` and `plan.md` still match implemented behavior —
      `specs/020-screenshot-screen-recording-prevention/spec.md`,
      `specs/020-screenshot-screen-recording-prevention/plan.md`
- [x] Create `implementation.md` with implementation summary, changed files,
      validation commands, capture artifacts/notes, platform limitations, and
      approved deviations —
      `specs/020-screenshot-screen-recording-prevention/implementation.md`
- [x] Stop and wait for external `review.md`, unless the user explicitly skips
      review — `specs/020-screenshot-screen-recording-prevention/review.md`

### Group 8: Review And Fix

Handle the external review loop without changing files before approval.

- [x] Read externally provided `review.md` when available —
      `specs/020-screenshot-screen-recording-prevention/review.md`
- [x] Prepare a remediation plan for each review finding without updating files
      — `specs/020-screenshot-screen-recording-prevention/review.md`
- [x] Present the remediation plan and wait for explicit approval before making
      any changes
- [x] Implement approved review fixes and update `spec.md`, `plan.md`,
      `tasks.md`, `implementation.md`, code, and tests when review changes
      scope, approach, or validation
- [ ] Repeat the review/fix loop if the same `review.md` file is updated for
      another pass

### Group 9: Finalization

Close the feature only after durable documentation follow-up is handled.

- [ ] Decide whether US-020 produced durable learnings or long-lived
      product/architecture changes worth preserving
- [ ] Propose updates to `AGENTS.md`, `docs/application-description.md`, and
      `docs/agent-findings.md` if capture-prevention behavior, platform
      limitations, or validation commands should become long-lived guidance
- [ ] Wait for explicit approval before editing those long-lived guidance
      documents
- [ ] Apply approved long-lived documentation updates, or record the explicit
      no-update decision
- [ ] Mark `spec.md` status `Complete` only after implementation, validation,
      review handling, and final knowledge-capture gates are done

## Completion criteria

All tasks checked, validation evidence documented, approved OS-capture
validation exception recorded, Android emulator and iOS simulator verification
completed or explicitly documented under the approved exception, review handled
or explicitly skipped, final knowledge-capture gate handled, and `spec.md`
marked `Complete`.

## Validation evidence

Record test results, screenshots, videos, command output, approved exceptions,
or review-related notes here when complete.

```text
Approved validation exception:
- User approved the plan on 2026-06-23, including the exception that OS
  screenshot, screen-recording, and app-switch pixel contents will be validated
  with emulator/simulator runtime evidence instead of direct Flutter
  integration-test assertions.
- User also approved documenting iOS simulator screen-capture limitations if
  `UIScreen.isCaptured` cannot be triggered by simulator recording, while
  preserving a practical physical-device validation path.

Automated checks:
- PASS `dart format test/platform/android_capture_prevention_test.dart test/platform/ios_capture_privacy_test.dart integration_test/capture_prevention_flow_test.dart`
- PASS `dart format lib/data/auth/app_lock_providers.dart lib/main.dart test/platform/android_capture_prevention_test.dart test/platform/ios_capture_privacy_test.dart`
- PASS `/opt/homebrew/bin/flutter test test/platform/android_capture_prevention_test.dart test/platform/ios_capture_privacy_test.dart test/app_smoke_test.dart test/core/router/app_router_test.dart`
- PASS `/opt/homebrew/bin/flutter test test/platform/android_capture_prevention_test.dart test/platform/ios_capture_privacy_test.dart test/app_smoke_test.dart test/bootstrap_app_test.dart`
- PASS `/opt/homebrew/bin/flutter test -d emulator-5554 integration_test/capture_prevention_flow_test.dart`
- PASS `/opt/homebrew/bin/flutter test -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/capture_prevention_flow_test.dart`
- PASS `/opt/homebrew/bin/flutter test -d emulator-5554 integration_test/app_lock_flow_test.dart`
- PASS `/opt/homebrew/bin/flutter analyze`
- PASS `./gradlew --no-daemon compileDebugKotlin` from `android/`
- PASS `/opt/homebrew/bin/flutter build apk --profile`
- PASS `/opt/homebrew/bin/flutter build ios --simulator`

Non-blocking command notes:
- Initial untargeted `/opt/homebrew/bin/flutter test integration_test/capture_prevention_flow_test.dart`
  failed because multiple devices were connected. The test passed when targeted
  to Android emulator `emulator-5554` and iOS simulator
  `491CD949-D3C0-4C4C-A6B9-15BAB1859156`.
- One parallel Flutter test/analyze attempt failed because concurrent Flutter
  commands contended on `ios/Flutter/ephemeral/Packages/.packages`. The same
  focused test command passed when rerun serially, and `flutter analyze` passed.
- One parallel `flutter build ios --simulator` attempt hit the same Flutter
  ephemeral file contention and passed when rerun serially.
- Android app-lock integration initially hit
  `INSTALL_FAILED_INSUFFICIENT_STORAGE`; Flutter uninstalled the old version,
  retried, and the test then passed.

Android emulator runtime evidence:
- PASS profile APK cold launch:
  `adb -s emulator-5554 shell am start -W -n com.wrait.flutter.dev/com.wrait.flutter.MainActivity`
  returned `Status: ok`, `LaunchState: COLD`, `Activity:
  com.wrait.flutter.dev/com.wrait.flutter.MainActivity`, `TotalTime: 1044`.
- PASS live profile window flags from `dumpsys window` included:
  `fl=LAYOUT_IN_SCREEN SECURE LAYOUT_INSET_DECOR SPLIT_TOUCH HARDWARE_ACCELERATED DRAWS_SYSTEM_BAR_BACKGROUNDS`.
- PASS foreground screenshot artifact:
  `/private/tmp/wrait_us020_review_android_foreground.png`; visually inspected as fully
  black, no Wrait content exposed.
- PASS recent-apps artifact:
  `/private/tmp/wrait_us020_review_android_recents.png`; visually inspected as
  black during the app-switch validation path.
- PASS secure-window persistence after app-switch/foreground return:
  `/private/tmp/us020_android_window_after_resume.txt` still showed
  `fl=LAYOUT_IN_SCREEN SECURE ...` on the live
  `com.wrait.flutter.dev/com.wrait.flutter.MainActivity` window after
  app-switching away and returning.
- PASS post-return foreground screenshot artifact:
  `/private/tmp/wrait_us020_review_android_after_resume.png`; visually
  inspected as fully black after the resume path.
- PASS debug automation lockscreen interaction:
  temporary setting
  `com.wrait.flutter.debug.automation_lockscreen_mode=1` remained compatible
  with the secure flag during the resumed-window validation, then was restored
  to `0`.
- PASS screenrecord artifact inspection:
  `/private/tmp/wrait_us020_review_android_screenrecord.mp4`; extracted frame
  `/private/tmp/wrait_us020_review_android_screenrecord_frame.png` was visually
  inspected as fully black.
- Important repeatability note: a stale release package `com.wrait.flutter`
  was initially inspected by mistake and did not contain the current debug/profile
  secure-window build. Correct validation target was the freshly installed
  debug/profile identity `com.wrait.flutter.dev`.

iOS simulator runtime evidence:
- PASS `/opt/homebrew/bin/flutter test -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/capture_prevention_flow_test.dart`
  verified normal Wrait launch and basic navigation with app lock disabled by
  provider override.
- PASS `/opt/homebrew/bin/flutter build ios --simulator` compiled the native
  `SceneDelegate.swift` privacy-cover implementation.
- PASS installed and launched `build/ios/iphonesimulator/Runner.app` on booted
  iPhone 17 simulator with bundle id `com.wrait.app`.
- Initial normal-bootstrap simulator launches still showed a system passcode
  prompt for Wrait even after `APP_LOCK_ENABLED=false`, so direct cover
  observation on the production bootstrap path remained blocked by protected
  startup dependencies.
- PASS validation-only simulator foreground:
  `/private/tmp/wrait_us020_review_ios_validation_foreground.png`; a
  non-sensitive `CAPTURE_VALIDATION_MODE=true` placeholder screen rendered
  successfully, proving the scene could be observed directly once secure
  startup dependencies were bypassed for validation.
- PASS app-switch/background snapshot privacy cover:
  backgrounding Wrait into Safari created a stored SplashBoard snapshot at
  `/Users/alexander/Library/Developer/CoreSimulator/Devices/491CD949-D3C0-4C4C-A6B9-15BAB1859156/data/Containers/Data/Application/67529076-BF55-4EA6-8BF8-A61BFED7136A/Library/SplashBoard/Snapshots/sceneID:com.wrait.app-default/A5A09BAB-CF88-405C-A1F1-129FABA7B1CF@3x.ktx`;
  thumbnail `/private/tmp/A5A09BAB-CF88-405C-A1F1-129FABA7B1CF@3x.ktx.png` was
  visually inspected and showed the native black `Private` cover instead of the
  foreground placeholder content.
- PASS foreground return after background snapshot:
  after closing Safari, `/private/tmp/wrait_us020_review_ios_after_safari_close.png`
  showed Wrait's visible placeholder content again, with the privacy cover
  cleared.
- PASS simulator screen-recording limitation confirmed:
  `xcrun simctl io booted recordVideo` produced
  `/private/tmp/wrait_us020_review_ios_record.mov`; both
  `/private/tmp/wrait_us020_review_ios_during_recording.png` and extracted frame
  `/private/tmp/wrait_us020_review_ios_record_frame.png` still showed the
  underlying placeholder content, confirming this simulator path did not toggle
  `UIScreen.main.isCaptured` and therefore did not trigger the native cover.
- iOS app-switcher limitation update: `simctl` still exposes no direct
  app-switcher UI command here, but stored SplashBoard snapshot inspection
  provided runtime evidence for the same inactive/background privacy-cover path.
```

## Notes

- iOS one-shot screenshot prevention with a secure text-field/container
  technique is intentionally not part of the approved initial plan.
- No persisted data, backend contract, recording, draft retry, quota, entry,
  sharing, editing, deletion, or app-lock authentication behavior should change
  for US-020.
