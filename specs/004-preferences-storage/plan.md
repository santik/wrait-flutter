# Implementation Plan: Preferences Storage

> **Feature number:** 004
> **Spec:** [`spec.md`](spec.md)
> **Author:** Codex
> **Date:** 2026-06-09

---

## Approach summary

Implement US-004 as a small persistence slice with one domain-facing
`PreferencesRepository`, backed by ordinary local preferences for
`hasEverRecorded` and one persisted opaque app device ID. The repository will
resolve that device ID once by attempting a platform lookup first and falling
back to generated local ID creation when the platform value is unavailable,
then persist the resolved value so later calls and later launches return the
same identifier without exposing its origin. The repository will be
bootstrapped at app startup alongside the existing local database bootstrap,
then exposed through a Riverpod provider for future consumers. Validation will
rely primarily on unit tests because this story introduces infrastructure, not
UI.

## Architecture decisions

| Decision | Choice | Rationale |
| --- | --- | --- |
| Preferences contract shape | Add a small domain repository with async read/write methods for `hasEverRecorded` plus `getDeviceId()` | The finalized spec only requires persistence and retrieval. Async methods are simpler than introducing reactive streams before any UI consumes them. |
| Local persistence | Use `shared_preferences` for both `hasEverRecorded` and the resolved app device ID | The story now requires one persisted opaque app-level ID and does not require that callers know its source. Reusing one simple persistence mechanism keeps the implementation small. |
| Device-ID source priority | Resolve device ID from storage first, otherwise attempt platform lookup, otherwise generate fallback | This matches the revised spec exactly and guarantees the rest of the app sees one stable value regardless of origin. |
| Platform bridge contract | Make the Flutter `MethodChannel` return a nullable platform value instead of treating absence as a fatal app-level error | The repository now owns fallback generation, so the platform source should report availability rather than terminate the flow. |
| Android identifier | Use `Settings.Secure.ANDROID_ID` in the Android host | This is the platform-provided identifier appropriate to the revised scope and gives the desired stability on Android. |
| iOS identifier | Use `UIDevice.current.identifierForVendor` in the iOS host | This is the platform-provided identifier appropriate to the revised scope and gives vendor-scoped stability on iOS. |
| Fallback ID generation | Generate a random opaque identifier in Dart when no platform value is available | This keeps fallback generation cross-platform, avoids another native branch, and satisfies the “do not interrupt the user” requirement. |
| Device-ID contract ownership | Keep the repository as the only public device-ID contract and hide platform-vs-generated origin completely | Later stories should depend on one application contract, not repeat platform-conditional logic or branch on source. |
| Caching strategy | Cache the resolved device ID in memory after the first successful resolution | Once the repository has resolved and persisted the ID, repeated reads should not keep hitting the method channel or preferences. |
| App bootstrap integration | Bootstrap shared preferences and the repository in `main.dart`, then inject through provider overrides | This matches the existing pattern used for `AppConfig` and the local entry database, and keeps runtime dependencies explicit at startup. |
| Migration behavior | No legacy-key migration | The finalized spec explicitly removes migration from scope. |
| Validation approach | Unit-test repository resolution, fallback generation, caching, and Dart-side platform behavior with fakes plus standard `flutter analyze` and `flutter test` | This story is infrastructure-only, so focused automated tests provide the strongest evidence without needing temporary UI. |

## File changes

| File | Action | Description |
| --- | --- | --- |
| `pubspec.yaml` | Modify | Add `shared_preferences` as the non-sensitive preference dependency for this story |
| `lib/domain/repository/preferences_repository.dart` | Modify | Keep the public contract stable while revising the underlying device-ID resolution semantics |
| `lib/data/preferences/platform_device_id_provider.dart` | Modify | Encapsulate the Flutter `MethodChannel` contract as a best-effort platform ID source instead of a fatal error boundary |
| `lib/data/preferences/preferences_repository_impl.dart` | Modify | Resolve, cache, persist, and return one opaque app device ID using stored value, platform source, or generated fallback |
| `lib/data/preferences/preferences_providers.dart` | Modify | Keep the provider surface stable while wiring the revised repository behavior |
| `lib/main.dart` | Modify | Bootstrap `SharedPreferences`, construct the repository, and override its provider at app startup |
| `android/app/src/main/kotlin/com/wrait/app/MainActivity.kt` | Modify | Register the Android side of the `MethodChannel` and return `ANDROID_ID` |
| `ios/Runner/AppDelegate.swift` | Modify | Register the iOS side of the `MethodChannel` and return `identifierForVendor` |
| `test/data/preferences/platform_device_id_provider_test.dart` | Modify | Verify Dart-side channel behavior, including successful platform values and unavailable bridge/value cases |
| `test/data/preferences/preferences_repository_impl_test.dart` | Modify | Verify stored-value precedence, platform-value persistence, fallback generation persistence, write-failure handling, and no source leakage |

## API contract details

No HTTP endpoints are implemented or changed in US-004.

The implementation-specific contract is internal:

- `PreferencesRepository.getHasEverRecorded()` returns `false` when the flag is
  absent.
- `PreferencesRepository.setHasEverRecorded(bool value)` persists either
  boolean value without special write-once behavior.
- `PreferencesRepository.getDeviceId()` first returns the already-stored app
  device ID when present.
- When no stored device ID exists yet, `getDeviceId()` attempts to read a
  platform device ID and persists it if available.
- When no stored device ID exists yet and no platform value is available,
  `getDeviceId()` generates an opaque fallback ID, persists it, and returns it.
- The rest of the app receives only the resolved stored device ID and is not
  told whether it came from the platform or fallback generation.

## Data model changes

This story adds a new internal persistence contract but does not change any
existing entry schema or backend API shape.

### Before

```dart
// A Flutter preferences repository already exists, but it delegates device-ID
// lookup directly to the platform bridge and fails when no platform ID is
// available. It does not yet persist one resolved opaque app device ID.
```

### After

```dart
abstract interface class PreferencesRepository {
  Future<bool> getHasEverRecorded();
  Future<void> setHasEverRecorded(bool value);
  Future<String> getDeviceId();
}
```

### Migration

No migration is required.

## Test strategy

Validation will focus on persistence contracts, restart-equivalent behavior,
and startup safety. Because this story does not expose UI, unit tests provide
the primary evidence. Implementation should be completed first, then
post-implementation validation should prove fresh-install defaults, boolean
round-trips, stored-value precedence, stable resolved device-ID reuse, fallback
generation when no platform ID is available, and app startup compatibility.

### Automated tests

| Test case | Type | File |
| --- | --- | --- |
| `hasEverRecorded` defaults to `false` when no preference has been stored | Unit | `test/data/preferences/preferences_repository_impl_test.dart` |
| `hasEverRecorded` persists `true` across a repository re-creation using the same shared-preferences state | Unit | `test/data/preferences/preferences_repository_impl_test.dart` |
| `hasEverRecorded` persists `false` after being reset from `true` | Unit | `test/data/preferences/preferences_repository_impl_test.dart` |
| `setHasEverRecorded` throws when persistence reports a failed write | Unit | `test/data/preferences/preferences_repository_impl_test.dart` |
| Platform device-ID provider returns the value supplied by the Flutter method channel | Unit | `test/data/preferences/platform_device_id_provider_test.dart` |
| Platform device-ID provider reports unavailable value when the method channel returns `null`, blank, or a missing plugin path | Unit | `test/data/preferences/platform_device_id_provider_test.dart` |
| Repository-level `getDeviceId()` returns the already-stored value without re-querying the platform source | Unit | `test/data/preferences/preferences_repository_impl_test.dart` |
| Repository-level `getDeviceId()` stores and reuses the platform value when one is available on first resolution | Unit | `test/data/preferences/preferences_repository_impl_test.dart` |
| Repository-level `getDeviceId()` generates, stores, and reuses a fallback value when no platform value is available | Unit | `test/data/preferences/preferences_repository_impl_test.dart` |
| Repository-level `getDeviceId()` hides whether the stored value came from platform or fallback by returning the same opaque contract in both paths | Unit | `test/data/preferences/preferences_repository_impl_test.dart` |
| `flutter analyze` completes cleanly after startup and provider wiring changes | Static analysis | N/A command evidence recorded in `tasks.md` |
| `flutter test` passes after the new repository and storage tests are added | Test suite | N/A command evidence recorded in `tasks.md` |

### Manual verification

1. Complete the implementation tasks for repository resolution, fallback generation, platform ID bridge, and startup wiring.
2. Run `flutter analyze` and confirm there are no warnings or errors.
3. Run `flutter test` and confirm the new persistence tests and existing regression tests pass.
4. Launch the app on Android and verify startup still succeeds after adding preferences bootstrap.
5. Launch the app on iOS and verify startup still succeeds after adding preferences bootstrap.

## Integration notes

- The new repository will integrate with the existing app bootstrap in
  [lib/main.dart](/Users/alexander/projects/wrait/write-flutter/lib/main.dart)
  alongside `AppConfig` and the local database override pattern already used
  today.
- The platform device-ID provider will introduce one explicit Flutter
  `MethodChannel` contract whose native implementations live in
  [android/app/src/main/kotlin/com/wrait/app/MainActivity.kt](/Users/alexander/projects/wrait/write-flutter/android/app/src/main/kotlin/com/wrait/app/MainActivity.kt)
  and [ios/Runner/AppDelegate.swift](/Users/alexander/projects/wrait/write-flutter/ios/Runner/AppDelegate.swift).
- The repository, not the platform provider, owns fallback generation and
  persisted device-ID storage. This keeps platform availability concerns
  encapsulated away from feature code.
- No current UI consumes the repository yet, so this story should stop at
  infrastructure and test coverage instead of introducing temporary screens.
- Later recording, analytics, and registration stories can depend on the new
  repository/provider rather than implementing their own local persistence.

## Rollout & migration

This is an additive infrastructure story.

- No feature flags are needed.
- No migration is required.
- Backward-compatibility risk is low because no Flutter code currently depends
  on a preferences repository contract.
- Startup wiring, native channel registration, and fallback persistence are the
  main rollout concerns; verification must show app launch still succeeds on
  both platforms after the additional bootstrap step.

## Risks & mitigations

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| Startup regressions from adding shared-preferences bootstrap to `main.dart` | Medium | High | Keep the bootstrap additive, mirror the existing override pattern, and validate with app launch plus smoke tests |
| Native Android and iOS implementations diverge behind the shared Dart contract | Medium | High | Keep the channel surface minimal, document one method name and return shape, and validate both platforms with launch checks |
| Platform identifier is temporarily unavailable or blank on one platform edge case | Medium | High | Treat the platform source as best-effort only and verify the repository generates and persists fallback IDs without interrupting callers |
| Fallback ID regeneration bug causes identity churn across launches | Low | High | Persist the first resolved device ID and verify stored-value precedence before platform lookup in repository tests |
| Tests accidentally depend on plugin internals instead of app behavior | Medium | Medium | Mock method-channel responses and shared-preference state so tests stay deterministic and fast |
| Later consumers assume they can infer whether the stored ID came from platform or fallback | Medium | Medium | Keep origin hidden in the repository contract and test only the opaque returned value |

## Open items from spec

None.
