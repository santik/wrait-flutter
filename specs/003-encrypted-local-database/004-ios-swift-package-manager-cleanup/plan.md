# Implementation Plan: iOS Swift Package Manager Cleanup

> **Feature number:** 004
> **Spec:** [`spec.md`](spec.md)
> **Author:** Codex
> **Date:** 2026-06-08

---

## Approach summary

Remove the obsolete CocoaPods path from the iOS client project while preserving
the already-generated Swift Package Manager plugin path that Flutter is using
for the active iOS dependency set. The cleanup will remove Pod-specific
configuration includes, Pod-linked framework references, Pod-only Xcode build
phases, and Pod-specific project groups or lock artifacts that are no longer
part of the current plugin resolution flow. Validation will focus on confirming
that Flutter no longer reports leftover CocoaPods integration for iOS and that
the app still builds and launches on a supported iOS simulator through the SPM
path.

## Architecture decisions

| Decision | Choice | Rationale |
| --- | --- | --- |
| Native dependency path | Keep Flutter’s generated Swift package integration and remove obsolete CocoaPods wiring | Flutter already reports that all active iOS plugins are available as Swift Packages, so the cleanup should align the project with the dependency path actually in use. |
| Podfile handling | Remove the root `ios/Podfile` as part of the cleanup | Once Pod-specific project references are gone, retaining the Podfile would keep the project in a misleading half-migrated state. |
| Xcode project cleanup scope | Remove Pod framework references, Pod groups, and `[CP]` shell phases from `Runner.xcodeproj` while preserving Flutter build phases and Swift package references | The Pod-only nodes are what keep CocoaPods integrated into the project. The Flutter and Swift package wiring must remain intact for iOS builds to continue working. |
| xcconfig handling | Remove Pod support-file includes from iOS xcconfig files and keep the generated Flutter config include | The project should continue to inherit Flutter-generated build settings without attempting to load missing Pod xcconfig files. |
| Validation approach | Prefer real Flutter iOS analyze/build/launch verification over static file-only validation | This cleanup is native-project-configuration heavy, so the strongest evidence is that Flutter no longer emits the leftover-CocoaPods message and an iOS simulator launch still succeeds. |
| Non-iOS safety | Do not change Android or app-layer code during this cleanup | The spec is limited to iOS project/tooling cleanup, so non-iOS flows should remain unaffected. |

## File changes

| File | Action | Description |
| --- | --- | --- |
| `ios/Podfile` | Delete | Remove the obsolete CocoaPods entry point now that the active iOS plugin set resolves through Swift Package Manager |
| `ios/Podfile.lock` | Delete | Remove the stale Pod lockfile associated with the no-longer-used CocoaPods path |
| `ios/Pods/` | Delete if present locally | Remove stale local Pod support files and pod project artifacts so the workspace no longer carries a leftover CocoaPods tree |
| `ios/Flutter/Debug.xcconfig` | Modify | Remove the Pod support-file include while preserving the Flutter generated config include |
| `ios/Flutter/Release.xcconfig` | Modify | Remove the Pod support-file include while preserving the Flutter generated config include |
| `ios/Runner.xcodeproj/project.pbxproj` | Modify | Remove Pod framework references, Pod groups, Pod xcconfig file references, and `[CP]` shell phases while preserving Swift package integration and Flutter build phases |
| `specs/004-ios-swift-package-manager-cleanup/tasks.md` | Modify later during implementation | Record validation evidence once cleanup is complete |

## API contract details

No HTTP endpoints are implemented or changed in US-004.

The implementation-specific contract is internal to the iOS project:

- iOS build configuration must resolve through Flutter’s generated Swift package
  path for the active plugin set
- Pod-only project references and scripts must be absent after cleanup
- Flutter tooling must stop reporting that all plugins are Swift Packages while
  CocoaPods integration still remains

## Data model changes

No application data model, schema, or persisted user data changes are required.

### Before

```text
iOS project includes both:
- Swift Package Manager plugin integration
- obsolete CocoaPods references and shell phases
```

### After

```text
iOS project includes:
- Swift Package Manager plugin integration only
```

### Migration

No user-data migration is required.

This is a native project-configuration cleanup only.

## Test strategy

Validation will focus on proving that the CocoaPods path is no longer required
by the iOS project and that iOS launch still succeeds through the Swift package
path. Manual verification is the primary confidence source because the behavior
being changed lives in Flutter/Xcode tooling and native-project wiring rather
than app-layer business logic.

### Automated tests

| Test case | Type | File |
| --- | --- | --- |
| `flutter analyze` completes successfully after iOS project cleanup | Static analysis | N/A command evidence recorded in `tasks.md` |
| `flutter test` still passes after the native iOS project cleanup | Automated suite | N/A command evidence recorded in `tasks.md` |

### Manual verification

1. Complete the iOS project cleanup by removing Podfile artifacts, Pod xcconfig includes, and Pod-specific Xcode project references.
2. Run `flutter analyze` and confirm it succeeds.
3. Run `flutter test` and confirm existing tests still pass.
4. Run `flutter devices` and confirm the iOS simulator remains available.
5. Run `flutter run -d <ios-simulator-id>` and confirm the app launches successfully on a supported iOS simulator.
6. Confirm Flutter no longer prints the “all plugins found for ios are Swift Packages, but your project still has CocoaPods integration” message during the iOS command path used for validation.

## Integration notes

- Flutter’s generated iOS plugin package currently lives under `ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage` and already includes the active plugin set.
- The current Xcode project still references `libPods-Runner.a`, Pod xcconfig files, and `[CP]` shell phases even though the plugin package path exists.
- Generated Flutter files under `ios/Flutter/ephemeral/` should not be hand-edited; the cleanup should target the checked-in project wiring around them.
- If iOS launch fails after cleanup, the likely issue will be an incomplete Xcode project migration rather than app-layer code.

## Rollout & migration

This is a native-project maintenance cleanup.

- No feature flag is needed.
- No runtime behavior migration is required.
- The main compatibility risk is breaking iOS build/launch if an essential Pod-era reference is removed incorrectly.
- Validation should prioritize an actual iOS simulator run before closing the story.

## Risks & mitigations

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| Removing a Pod-era Xcode reference accidentally breaks iOS build or launch | Medium | High | Clean only the clearly Pod-specific nodes, preserve Flutter and Swift package references, and validate with a real simulator run |
| Flutter regenerates project files in a way that reintroduces Pod assumptions | Low | Medium | Limit edits to checked-in iOS project files and validate against the current Flutter-generated package path after `flutter pub get` |
| Deleting the Podfile hides a future dependency that might later require Pods again | Low | Medium | This cleanup is based on the current active plugin set; any future Pod-required dependency can reintroduce CocoaPods explicitly in a new story |
| Non-iOS developers become confused by stale documentation referencing Pod-based setup | Medium | Low | Follow up by updating validation notes and implementation artifacts to reflect that the current iOS path is SPM-only |

## Open items from spec

None.
