# Implementation Plan: App Lock

> **Feature number:** 019
> **Spec:** [`spec.md`](spec.md)
> **Author:** Codex
> **Date:** 2026-06-22

---

## Approach summary

Implement app locking as an app-level privacy gate around `MaterialApp.router`'s
router content. A new Riverpod app-lock controller will observe cold launch and
app lifecycle transitions, mark the session locked whenever Wrait launches or
leaves the foreground, and auto-start authentication only after the app is
fully resumed. The router stays mounted behind a blur-and-blocking overlay so
existing recording, registration, cleanup, and draft-retry work can continue
when already in progress, while all visible app surfaces remain obscured until
authentication succeeds or the no-security warning bypass is explicitly used.

## Architecture decisions

| Decision | Choice | Rationale |
| --- | --- | --- |
| Lock placement | Wrap `MaterialApp.router` content with a root `AppLockGate` via `MaterialApp.router(builder: ...)` | Covers `/`, `/entries`, and `/entry/:id` consistently without screen-specific logic or router changes. Keeps bootstrap loading/retry screens outside this story's scope and preserves startup sequencing. |
| State ownership | Add a Riverpod `AppLockController` with immutable `AppLockState` | Matches the app's provider architecture and gives widget/integration tests deterministic state control through provider overrides. |
| Lifecycle source | Let `AppLockGate` own `WidgetsBindingObserver` for cold launch, background lock, and foreground prompt scheduling | Whole-app lifecycle behavior belongs at the app shell, not inside `MainScreen`. Existing `MainScreen` resume handling for microphone permission remains unchanged. |
| Authentication boundary | Introduce an injectable `AppLockAuthenticator` abstraction backed by `local_auth` | Keeps native plugin behavior isolated and makes locked, canceled, no-security, unavailable, and success paths testable without real biometric dialogs. |
| Authentication method | Use device-owner authentication with biometrics when available and device credentials as fallback | Satisfies the story's biometric/device credential requirement and follows the current `local_auth` behavior where `authenticate()` allows platform credential fallback unless biometric-only mode is requested. |
| Prompt timing | Controller tracks a single pending prompt and `AppLockGate` triggers it only after resumed-frame scheduling | Prevents overlapping prompts during lifecycle churn and avoids launching native prompts while Flutter is inactive. |
| Visual privacy | Use a root `Stack` with a 20dp blur/filter over the child plus an opaque scrim and lock controls | Provides immediate whole-app obscuring while preserving the underlying widget tree and background work. |
| No-security recovery | Show `Open settings` and `Continue without lock` only for the no-security state | Keeps normal auth failures private by default while honoring the approved bypass only when no supported device security is configured. |
| Settings recovery | Use best-effort platform settings: Android security settings via native channel where practical, iOS/app fallback through existing platform settings support | Android can target security settings more directly; iOS does not expose a reliable public deep link to Face ID/passcode setup, so app/settings fallback satisfies the spec's best-effort requirement. |
| Native dependency setup | Keep existing `local_auth: ^3.0.1`; update Android/iOS platform setup required by the plugin | `local_auth` is already present. Current docs require Android `FragmentActivity`, `USE_BIOMETRIC`, and compatible theme setup, plus iOS `NSFaceIDUsageDescription`. Sources: [local_auth](https://pub.dev/packages/local_auth), [local_auth_android](https://pub.dev/packages/local_auth_android), [local_auth_darwin](https://pub.dev/packages/local_auth_darwin). |
| In-progress work while locked | Preserve current controller/use-case behavior; do not pause or cancel work solely because app lock activates | This is the simplest way to allow recording/upload/cleanup/registration/draft retry to continue where platform lifecycle already permits it. If native auth/background behavior exposes a specific instability during implementation, bring a focused exception back for approval. |

## File changes

| File | Action | Description |
| --- | --- | --- |
| `lib/app.dart` | Modify | Wrap router content with `AppLockGate`; keep theme, localization, and router ownership unchanged. |
| `lib/data/auth/app_lock_authenticator.dart` | Create | Define `AppLockAuthenticator`, availability/result enums, and `LocalAuthAppLockAuthenticator` backed by `local_auth`. |
| `lib/data/auth/app_lock_providers.dart` | Create | Provide the production authenticator and settings-opener services for app-lock controller injection. |
| `lib/data/auth/device_security_settings_opener.dart` | Create | Define best-effort settings opening abstraction; use method channel or platform fallback for production. |
| `lib/presentation/app_lock/app_lock_controller.dart` | Create | Riverpod controller and immutable state for cold launch, lock-on-background, resumed prompting, success, cancel, no-security, temporary-unavailable, settings, and bypass handling. |
| `lib/presentation/app_lock/app_lock_gate.dart` | Create | Root lifecycle observer and overlay composition. |
| `lib/presentation/app_lock/app_lock_screen.dart` | Create | Lock UI, approved copy, accessibility labels/hints, unlock/settings/bypass actions. |
| `lib/presentation/app_lock/app_lock_test_keys.dart` | Create | Stable test keys for overlay, blur, messages, unlock/settings/bypass actions. |
| `android/app/src/main/kotlin/com/wrait/flutter/MainActivity.kt` | Modify | Switch to `FlutterFragmentActivity` for `local_auth`; add or reuse a method-channel method for Android security settings if selected during implementation. |
| `android/app/src/main/AndroidManifest.xml` | Modify | Add `android.permission.USE_BIOMETRIC`. |
| `android/app/src/main/res/values/styles.xml` | Modify | Adjust launch/normal theme parents only as needed for `local_auth_android` compatibility while preserving launch appearance. |
| `android/app/src/main/res/values-night/styles.xml` | Modify | Mirror Android theme compatibility changes for dark mode. |
| `android/app/build.gradle.kts` | Modify if needed | Add an explicit AndroidX AppCompat dependency only if required for AppCompat theme resolution after platform setup. |
| `ios/Runner/Info.plist` | Modify | Add `NSFaceIDUsageDescription` with Wrait-specific privacy-lock copy. |
| `test/data/auth/app_lock_authenticator_test.dart` | Create | Unit coverage for native-result mapping and exception categorization through fake clients. |
| `test/data/auth/device_security_settings_opener_test.dart` | Create | Unit coverage for settings-opening success/failure fallback behavior where feasible. |
| `test/presentation/app_lock/app_lock_controller_test.dart` | Create | Controller coverage for cold launch lock, background lock, auto-prompt, single-flight prompt, success, cancel, no-security, temporary-unavailable, settings, and bypass. |
| `test/presentation/app_lock/app_lock_gate_test.dart` | Create | Widget coverage for whole-app overlay, blur presence, interaction blocking, accessibility, and lifecycle-triggered prompts. |
| `test/app_smoke_test.dart` | Modify | Override app lock for existing smoke tests or assert unlocked baseline explicitly so unrelated tests remain focused. |
| `test/bootstrap_app_test.dart` | Modify | Override app lock for post-bootstrap app rendering or verify the lock gate is present after runtime bootstrap. |
| Existing `test/presentation/...` app-shell tests | Modify as needed | Add app-lock provider overrides where tests pump `WraitApp` and need the underlying screen accessible. |
| `integration_test/app_lock_flow_test.dart` | Create | Integration coverage using fake authenticator/provider overrides for cold launch, foreground return, success, cancel, no-security bypass, and temporary unavailable states. |
| Existing `integration_test/...` app-shell flows | Modify as needed | Override app lock to unlocked for flows unrelated to US-019 so the new cold-launch lock does not obscure their test targets. |
| `specs/019-app-lock/tasks.md` | Modify later | Filled in during the next SDD phase after plan approval. |
| `specs/019-app-lock/implementation.md` | Create later | Implementation details and validation evidence during the implement phase. |

## API contract details

No backend API changes are required.

Internal app-lock contract:

```text
AppLockAvailability
- available
- noSecurityConfigured
- temporarilyUnavailable
- unsupportedOrUnavailable

AppLockAuthResult
- success
- canceled
- noSecurityConfigured
- temporarilyUnavailable
- unsupportedOrUnavailable

AppLockState
- isLocked: bool
- isPromptPending: bool
- status: locked | authenticating | canceled | noSecurity | temporarilyUnavailable | unlocked
- canBypass: bool
- message: approved user-facing copy
```

The production authenticator will:

- check device-owner authentication availability before prompting
- call `authenticate(localizedReason: 'Unlock Wrait to continue.')`
- time out and cancel a hung native authentication attempt before returning a
  retryable unavailable state
- treat `false` authentication returns as canceled
- map no-passcode/no-enrollment/no-supported-security failures to
  `noSecurityConfigured`
- map lockout or transient platform failures to `temporarilyUnavailable`
- preserve a generic unavailable category for unsupported plugin/platform errors

The controller will:

- start locked on cold launch
- mark locked on every non-resumed foreground exit
- start authentication automatically only from resumed state
- ignore new prompt requests while `isPromptPending` is true
- ignore transient `inactive` lifecycle churn from native auth UI so the app
  does not re-lock and restart the same prompt
- unlock only on auth success or no-security warning bypass
- keep content obscured for cancel, temporary unavailable, and generic
  unavailable states

## Data model changes

No persisted journal data model changes are required.

### Before

```text
No app-lock domain state.
Root app renders router content directly after bootstrap.
MainScreen observes resume only for microphone-permission refresh.
```

### After

```text
Ephemeral AppLockState exists in memory for the current process/session.
Root app renders router content behind AppLockGate.
MainScreen keeps its existing resume behavior.
```

### Migration

No data migration is required.

## Test strategy

### Automated tests

| Test case | Type | File |
| --- | --- | --- |
| `LocalAuthAppLockAuthenticator` reports available when device authentication is supported | Unit | `test/data/auth/app_lock_authenticator_test.dart` |
| Auth success, cancel, no-security, temporary-unavailable, and generic unavailable results map to app-lock results | Unit | `test/data/auth/app_lock_authenticator_test.dart` |
| Hung native auth is canceled after an explicit timeout and returns a retryable unavailable result | Unit | `test/data/auth/app_lock_authenticator_test.dart` |
| Settings opener returns success/failure without throwing user-visible implementation details | Unit | `test/data/auth/device_security_settings_opener_test.dart` |
| Cold launch initializes locked and schedules an automatic resumed prompt | Unit | `test/presentation/app_lock/app_lock_controller_test.dart` |
| Background transition marks locked every time | Unit | `test/presentation/app_lock/app_lock_controller_test.dart` |
| Prompt single-flight prevents overlapping authentication | Unit | `test/presentation/app_lock/app_lock_controller_test.dart` |
| Successful auth unlocks and clears the overlay state | Unit | `test/presentation/app_lock/app_lock_controller_test.dart` |
| Canceled auth remains locked and allows another unlock attempt | Unit | `test/presentation/app_lock/app_lock_controller_test.dart` |
| No-security state shows settings and warning bypass; bypass unlocks only for this state | Unit | `test/presentation/app_lock/app_lock_controller_test.dart` |
| Security settings opening is single-flight while already in progress | Unit | `test/presentation/app_lock/app_lock_controller_test.dart` |
| Temporary unavailable remains locked and exposes retry copy | Unit | `test/presentation/app_lock/app_lock_controller_test.dart` |
| Locked gate blurs/blocks the whole app and exposes approved lock copy | Widget | `test/presentation/app_lock/app_lock_gate_test.dart` |
| Lock screen accessibility includes state, unlock action, settings action, and bypass action where relevant | Widget | `test/presentation/app_lock/app_lock_gate_test.dart` |
| Lifecycle resume from widget binding triggers auto-prompt only after resumed | Widget | `test/presentation/app_lock/app_lock_gate_test.dart` |
| `inactive -> resumed` churn during an in-flight auth prompt does not cancel and restart the prompt | Widget | `test/presentation/app_lock/app_lock_gate_test.dart` |
| Existing app smoke/bootstrap tests continue to render intended targets with an unlocked override or explicit lock assertion | Widget | `test/app_smoke_test.dart`, `test/bootstrap_app_test.dart` |
| Cold launch starts locked, fake success unlocks, and underlying main screen becomes interactable | Integration | `integration_test/app_lock_flow_test.dart` |
| Background/foreground relocks and auto-prompts with fake authenticator | Integration | `integration_test/app_lock_flow_test.dart` |
| Fake cancel keeps locked until retry succeeds | Integration | `integration_test/app_lock_flow_test.dart` |
| Fake no-security state exposes settings plus warning bypass and bypass reveals app | Integration | `integration_test/app_lock_flow_test.dart` |
| Fake temporary-unavailable state keeps app locked and allows retry | Integration | `integration_test/app_lock_flow_test.dart` |
| `inactive -> resumed` churn during in-flight fake auth does not restart the prompt | Integration | `integration_test/app_lock_flow_test.dart` |

Existing integration tests that pump `WraitApp` for unrelated flows should
override app lock to the unlocked state. US-019 coverage belongs in the new
dedicated integration flow so native prompt behavior and unrelated product
flows do not blur each other together in tests.

### Android emulator verification

1. Run focused automated tests:
   `flutter test test/data/auth test/presentation/app_lock test/app_smoke_test.dart test/bootstrap_app_test.dart`.
2. Run the app-lock integration test on an Android emulator:
   `flutter test -d <android-emulator-id> integration_test/app_lock_flow_test.dart`.
3. Run a launcher-style cold start for the debug/profile or release package
   under validation and confirm the lock screen appears before app content is
   usable.
4. Configure emulator device security/biometric enrollment if available, return
   Wrait from background, and verify the native authentication prompt appears
   automatically and success unlocks the app.
5. Remove or avoid device security where practical and verify no-security copy,
   best-effort settings action, and `Continue without lock` warning bypass.

### iOS simulator verification

1. Run focused automated tests:
   `flutter test test/data/auth test/presentation/app_lock test/app_smoke_test.dart test/bootstrap_app_test.dart`.
2. Run the app-lock integration test on an iOS simulator:
   `flutter test -d <ios-simulator-id> integration_test/app_lock_flow_test.dart`.
3. Launch Wrait cold on the simulator and confirm the lock screen appears before
   app content is usable.
4. Use simulator biometric enrollment/features where available to verify the
   native Face ID/Touch ID prompt, automatic foreground prompt, cancel, retry,
   and success unlock paths.
5. Verify the no-security/best-effort settings behavior on iOS. If iOS cannot
   deep-link to passcode/Face ID setup, document the observed best-effort
   destination as validation evidence.

### Validation exception request

None. The plan includes dedicated `integration_test` coverage for every
in-scope user flow using fake authenticator injection, plus Android emulator
and iOS simulator runtime verification for the native prompt paths.

## Review and finalization

- `review.md` will be externally authored if review occurs.
- After implementation, stop and wait for `review.md` unless the user explicitly
  skips review.
- After reading `review.md`, no files may be changed until the remediation plan
  is explicitly approved.
- This feature is likely to require durable updates after final approval:
  `docs/application-description.md` should mention app-lock privacy behavior,
  and `docs/agent-findings.md` may need platform/local-auth setup guidance if
  implementation uncovers important Android or iOS caveats.

## Integration notes

- `local_auth` is already declared in `pubspec.yaml` as `^3.0.1`; implementation
  should run `flutter pub get` only if platform transitive resolution changes.
- Android `MainActivity` currently extends `FlutterActivity`; it must move to
  `FlutterFragmentActivity` for `local_auth_android`.
- Android must add `android.permission.USE_BIOMETRIC`.
- Android theme compatibility must be verified against current
  `local_auth_android` guidance before final validation.
- iOS must add `NSFaceIDUsageDescription`; existing microphone/speech usage
  descriptions remain unchanged.
- The app-lock wrapper should not move encrypted database opening back into a
  blocking pre-UI path and should not interfere with bootstrap retry behavior.
- `MainScreen`'s existing resume hook for microphone permission refresh remains
  in place; root app-lock lifecycle handling is additive.

## Rollout & migration

No feature flag or data migration is planned. App lock becomes the default
behavior on cold launch and every background/foreground return. Users without
configured device security receive the approved warning bypass path, so the
feature remains recoverable on simulators and devices without passcode or
biometrics.

## Risks & mitigations

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| Native auth prompt fires during an unstable lifecycle transition | Medium | High | Gate prompting on resumed lifecycle state, schedule after frame, and use controller single-flight state. |
| Android platform setup breaks launch or existing automation lockscreen mode | Medium | High | Keep `MainActivity` changes minimal, preserve existing automation-lockscreen code, and validate cold start with `adb shell am start -W`. |
| AppCompat theme change alters splash/launch appearance | Medium | Medium | Change only required theme parents/items, preserve launch background, and visually verify Android cold launch. |
| Existing tests fail because the app now starts locked | High | Medium | Add provider overrides for unrelated tests and isolate US-019 assertions in dedicated tests. |
| Native biometric prompts are hard to automate consistently | High | Medium | Use fake authenticator for automated integration tests; perform explicit emulator/simulator runtime checks for native prompt evidence. |
| iOS cannot open direct Face ID/passcode settings | High | Low | Treat settings action as best effort per approved spec and document the actual destination during validation. |
| Backgrounding while recording behaves differently across platforms | Medium | Medium | Preserve current recording/controller behavior and validate that lock activation does not expose content or force unintended data mutation; request a focused exception if a platform-specific instability appears. |

## Open items from spec

None.

Planning follow-up: during implementation, verify whether preserving active
recording, upload, cleanup, registration, and draft-retry work while locked is
stable on both platforms. If a specific operation cannot safely continue while
locked, pause before changing behavior and request explicit approval for that
exception.
