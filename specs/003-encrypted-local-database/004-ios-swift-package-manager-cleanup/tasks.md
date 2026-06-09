# Tasks: iOS Swift Package Manager Cleanup

> **Feature number:** 004
> **Plan:** [`plan.md`](plan.md)
> **Author:** Codex
> **Date:** 2026-06-08

---

## Legend

- `[ ]` — not started
- `[x]` — complete
- `[P]` — can be parallelized with other `[P]` tasks in the same group
- `[B]` — blocked (note the blocker)

## Task groups

_Tasks are organized into sequential groups.
Tasks within the same group marked `[P]` can be worked on in parallel._

### Group 1: Remove obsolete CocoaPods entry points

_Delete the checked-in Pod artifacts that should no longer exist once iOS uses
only Swift Package Manager for the current plugin set._

- [x] Delete the obsolete CocoaPods entry point from the iOS project — `ios/Podfile`
- [x] Delete the stale Pod lockfile associated with the removed Pod path — `ios/Podfile.lock`
- [x] Delete the leftover local `ios/Pods/` directory if it is still present so stale Pod support files are removed from the workspace

### Group 2: Clean the checked-in iOS build configuration

_Remove Pod-era config includes and Pod-only Xcode project references while
preserving Flutter and Swift package wiring._

- [x] Remove the Pod support-file include from the debug iOS xcconfig while keeping the Flutter generated config include — `ios/Flutter/Debug.xcconfig`
- [x] Remove the Pod support-file include from the release iOS xcconfig while keeping the Flutter generated config include — `ios/Flutter/Release.xcconfig`
- [x] Remove Pod-only framework references, Pod xcconfig file references, the Pods group, and `[CP]` shell phases from the checked-in Xcode project while preserving Flutter build phases and the generated Swift package reference — `ios/Runner.xcodeproj/project.pbxproj`
  - Depends on: Group 2 xcconfig cleanup tasks

### Group 3: Validate the SPM-only iOS path after implementation

_Confirm the warning is gone and that the app still launches on iOS through the
Swift package path._

- [x] Run `flutter analyze` and record successful results as validation evidence
  - Depends on: Groups 1 and 2
- [x] Run `flutter test` and record successful results as validation evidence
  - Depends on: Groups 1 and 2
- [x] Run `flutter devices` and confirm the target iOS simulator remains available after the cleanup
  - Depends on: Groups 1 and 2
- [x] Run `flutter run -d <ios-simulator-id>` and confirm the app launches successfully through the Swift package path
  - Depends on: Groups 1 and 2
- [x] Confirm the leftover-CocoaPods warning no longer appears during the iOS Flutter command path used for validation
  - Depends on: Groups 1 and 2
- [x] Record validation evidence and implementation notes directly in this file — `specs/004-ios-swift-package-manager-cleanup/tasks.md`
  - Depends on: All groups

## Completion criteria

All tasks checked, Pod-era project wiring removed from the checked-in iOS
project, Flutter no longer reports leftover CocoaPods integration for iOS, iOS
simulator launch still succeeds, and validation evidence is documented in this
file.

## Validation evidence

_Record test results, screenshots, or command output here when complete._

```text
2026-06-08
- `flutter analyze` -> passed with "No issues found!"
- `flutter test` -> passed; suite completed with "All tests passed!"
- `flutter devices` -> confirmed available iOS simulators including:
  - `iPhone 17 Pro` (`0140EF83-0B3E-4517-B669-FDBE5E3B0BBA`)
  - `iPhone 17` (`491CD949-D3C0-4C4C-A6B9-15BAB1859156`)
- `flutter run -d 0140EF83-0B3E-4517-B669-FDBE5E3B0BBA` -> Xcode build completed and the app launched successfully on `iPhone 17 Pro`
- No Flutter warning about leftover CocoaPods integration appeared on the validated iOS run path after the cleanup
- Static verification: `rg -n "Pods|Podfile|CocoaPods|libPods-Runner|\[CP\]" ios -S` returned no remaining checked-in Pod-era matches
```

## Notes

- This story is limited to removing obsolete CocoaPods integration from the iOS
  project for the current plugin set.
- Flutter’s generated Swift package artifacts under `ios/Flutter/ephemeral/`
  should be treated as generated inputs, not hand-edited cleanup targets.
