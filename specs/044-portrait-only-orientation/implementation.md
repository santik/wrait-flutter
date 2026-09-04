# Implementation: Portrait-only App Orientation

> **Feature number:** 044
> **Spec:** [`spec.md`](spec.md)
> **Plan:** [`plan.md`](plan.md)
> **Branch:** `codex/feat/portrait-only-orientation`
> **Date:** 2026-09-04
> **Status:** Complete with approved iOS rotation validation exception; no durable guidance updates needed

## Summary

Wrait now requests portrait-only presentation at the native Android and iOS
application boundaries. Android uses sensor-based portrait orientation so
normal and reverse portrait remain possible; iOS retains its existing portrait
allowlist values and no longer advertises landscape. The review remediation
expanded integration coverage across the current routes and representative
dialogs, improved source-contract diagnostics, and documented the existing
Android configuration-change handling. No Flutter startup, persistence, API,
or user-data behavior changed.

## Files changed

- `android/app/src/main/AndroidManifest.xml`
  - Added `android:screenOrientation="sensorPortrait"` to `MainActivity` and
    documented why the existing `orientation` configuration-change entry is
    retained.
- `ios/Runner/Info.plist`
  - Removed landscape values from the iPhone and iPad supported-orientation
    arrays while preserving portrait values.
- `test/platform/orientation_configuration_test.dart`
  - Added source-contract checks for the Android activity and iOS orientation
    allowlists, with assertion-specific failure reasons and reverse-portrait
    documentation.
- `integration_test/orientation_lock_flow_test.dart`
  - Added launch, portrait-window, lifecycle-resume, main/entries/detail route,
    delete-dialog, feedback-dialog, and continued-interaction coverage with
    app lock disabled.
- `specs/044-portrait-only-orientation/spec.md`
- `specs/044-portrait-only-orientation/plan.md`
- `specs/044-portrait-only-orientation/tasks.md`

## Validation evidence

### Automated validation

- `flutter test test/platform/orientation_configuration_test.dart` — passed,
  2 tests.
- `flutter analyze` — passed, no issues found.
- `flutter test --no-pub` — passed, 443 tests. The existing suite emitted one
  non-fatal hit-test warning in the app-lock gate test; it did not fail the run.
- `flutter test --no-pub -d emulator-5554 integration_test/orientation_lock_flow_test.dart` — passed, including the expanded route/dialog flow.
- `flutter test --no-pub -d 4A181FDJH0030G integration_test/orientation_lock_flow_test.dart` — passed, including the expanded route/dialog flow.
- `flutter test --no-pub -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test/orientation_lock_flow_test.dart` — passed, including the expanded route/dialog flow.

### Build validation

- `flutter build apk --debug --no-pub` — passed; produced
  `build/app/outputs/flutter-apk/app-debug.apk`.
- `flutter build ios --simulator --no-pub` — passed; produced
  `build/ios/iphonesimulator/Runner.app`.
- The packaged Android APK contains `screenOrientation` value `0x7`, the
  Android `sensorPortrait` value.
- The packaged iOS plist contains only `UIInterfaceOrientationPortrait` for
  iPhone and `UIInterfaceOrientationPortrait` plus
  `UIInterfaceOrientationPortraitUpsideDown` for iPad.

### Android runtime validation

- Android emulator (`emulator-5554`, Android 17/API 37): after installing the
  freshly built `.dev` artifact, forced landscape-left and landscape-right cold
  launches produced portrait screenshots at `1080x2400`. The focused Wrait
  activity reported `port`, `ROTATION_0`, and a `1080x2400` task/window after
  both attempts. The same state remained after background/resume.
- Connected Android phone (`4A181FDJH0030G`, Android 17): the forced
  landscape-left cold launch produced a focused Wrait window reporting `port`,
  `ROTATION_0`, and `1080x2400`. The screenshot was black because the phone
  was in its secure/locked automation state; the full integration flow passed
  independently on the phone.
- Temporary rotation settings were restored: emulator
  `accelerometer_rotation=1`, `user_rotation=0`; phone
  `accelerometer_rotation=0`, `user_rotation=0`.

Evidence artifacts:

- `/private/tmp/wrait_orientation_android_emulator_debug_landscape_left.png`
- `/private/tmp/wrait_orientation_android_emulator_debug_landscape_right.png`
- `/private/tmp/wrait_orientation_android_emulator_debug_resume.txt`
- `/private/tmp/wrait_orientation_android_phone_landscape_left.png`
- `/private/tmp/wrait_orientation_android_phone_landscape_left.txt`

### iOS simulator validation

- iPhone 17 simulator (`491CD949-D3C0-4C4C-A6B9-15BAB1859156`, iOS 26.5):
  the feature integration flow passed, the normal app build passed, and the
  existing non-sensitive `CAPTURE_VALIDATION_MODE=true` run displayed the
  portrait validation surface in a `1206x2622` screenshot.
- Physical landscape-left/right rotation and post-rotation resume could not be
  driven automatically. macOS denied the Simulator keyboard shortcut through
  System Events, and `xcrun simctl` exposes screenshot/UI controls but no
  orientation command. The user explicitly approved a validation exception for
  this environment-limited interaction; it remains unverified rather than
  being reported as a passing result.

Evidence artifact:

- `/private/tmp/wrait_orientation_ios_validation_portrait.png`

## Review status

The external `review.md` artifact was read in full. Review remediation was
approved and applied as follows:

- Existing unrelated deployment, documentation, and tester changes were left
  untouched per the user's direction and may remain in the same changeset.
- Route/dialog integration coverage was expanded through the entry-detail route,
  delete confirmation, and feedback preparation dialog.
- Source-contract diagnostics and reverse-portrait documentation were improved.
- Android `orientation` configuration-change handling was retained and
  documented.
- The iOS physical-rotation validation exception was recorded in `plan.md`,
  `tasks.md`, and this implementation record.

Finalization is complete. The user approved the no-update knowledge-capture
decision for `AGENTS.md`, `docs/application-description.md`, and
`docs/agent-findings.md`. No unverified iOS physical-rotation result is
claimed.
