# Implementation Plan: Screenshot and Screen Recording Prevention

> **Feature number:** 020
> **Spec:** [`spec.md`](spec.md)
> **Author:** Codex
> **Date:** 2026-06-23

---

## Approach summary

Implement capture prevention at the native shell layer so protection is active
before Flutter content can render. Android will mark the main activity window
secure at the beginning of launch and reassert that flag if the live Flutter
window is recreated or retargeted during startup, resume, or focus changes.
iOS will keep a native privacy cover available at the scene/window level and
show it while screen capture is active or while the scene is being snapshotted
for app switching. This covers every Wrait surface without adding per-screen
conditions, preserves normal in-app interaction when no capture is active, and
leaves journal data, drafts, backend state, app-lock state, and local
persistence untouched.

## Architecture decisions

| Decision | Choice | Rationale |
| --- | --- | --- |
| Android protection location | Add the secure-window flag in `MainActivity.onCreate` before `super.onCreate(...)`, then reassert it after `super.onCreate(...)`, on resume, and when focus returns | Pre-`super` application is still the earliest app-owned launch point. Emulator validation showed Flutter can retarget the live activity window later in startup and lifecycle transitions, so the flag is reasserted at those app-owned points to preserve the same whole-window contract. |
| Android scope | Enable secure-window protection unconditionally for debug, profile, and release Flutter identities | The spec requires privacy protection across app surfaces, not a user preference or release-only behavior. Keeping all build variants aligned also makes emulator validation meaningful. |
| iOS protection location | Add a scene-level native privacy cover in `SceneDelegate.swift` | This is simpler than wrapping each Flutter screen and can cover startup, app-switch snapshots, screen-capture changes, app-lock overlays, and all current/future Flutter routes from outside the Flutter widget tree. |
| iOS screen capture behavior | Show a generic native privacy cover when `UIScreen.main.isCaptured` is true | This uses platform-supported capture detection for screen recording, mirroring, and sharing. It accepts the clarified requirement to use the simplest platform-appropriate hiding behavior. |
| iOS app-switcher behavior | Show the same privacy cover while the scene is inactive/backgrounded, then remove it only when active and not captured | App-switcher snapshots happen during scene lifecycle transitions. A native cover avoids exposing Flutter content in snapshots and does not affect app data. |
| One-shot iOS screenshots | Do not implement the secure-text-field screenshot-prevention technique in the initial plan | One-shot screenshot prevention on iOS does not have the same direct public app-window flag as Android. The secure-text-field approach is more fragile and less maintainable than the requested simplest behavior. The implementation will document this platform limitation in validation evidence. |
| Flutter widget changes | Avoid Flutter capture-prevention UI unless implementation proves native coverage insufficient | Native coverage satisfies first-frame and all-surface requirements with fewer moving pieces and avoids coupling capture privacy to app routing or app-lock state. |
| New dependencies | None | The native APIs and existing test harness are sufficient. Avoiding a plugin reduces dependency and platform-integration risk. |
| Validation style | Combine source/ordering tests, compile checks, integration smoke, and runtime OS capture evidence | Flutter integration tests cannot inspect OS screenshot/video/app-switch artifacts. Runtime emulator/simulator commands and saved artifacts are needed for the actual capture surfaces. |

## File changes

| File | Action | Description |
| --- | --- | --- |
| `android/app/src/main/kotlin/com/wrait/flutter/MainActivity.kt` | Modify | Add secure-window protection before `super.onCreate(...)` while preserving existing app-lock automation and method channels. |
| `ios/Runner/SceneDelegate.swift` | Modify | Add a native privacy cover, screen-capture observer, and scene lifecycle handling for app-switch snapshots. |
| `lib/main.dart` | Modify | Add a compile-time validation-only launch mode that shows non-sensitive placeholder content when simulator bootstrap is blocked by a system passcode prompt, so native iOS privacy-cover behavior can still be validated directly. |
| `test/platform/android_capture_prevention_test.dart` | Create | Source-level regression coverage that Android sets `FLAG_SECURE` and does it before `super.onCreate(...)`. |
| `test/platform/ios_capture_privacy_test.dart` | Create | Source-level regression coverage that iOS observes capture changes and protects inactive/background scene snapshots. |
| `integration_test/capture_prevention_flow_test.dart` | Create | Integration smoke proving the protected app still launches to the main flow and remains usable with normal capture state. |
| `specs/020-screenshot-screen-recording-prevention/tasks.md` | Modify later | Task checklist derived from the approved plan. |
| `specs/020-screenshot-screen-recording-prevention/implementation.md` | Create later | Implementation notes and validation evidence. |

## API contract details

No backend HTTP endpoints are introduced or modified.

### Native capture-protection contract

Android:

- The main Flutter activity must mark the whole activity window as secure.
- The flag must be applied before Flutter content is attached or rendered.
- The flag must not be cleared during ordinary lifecycle transitions.
- Existing debug lockscreen automation may continue to add its own flags, but
  it must not remove secure-window protection.

iOS:

- The scene must create or reuse a full-window privacy cover.
- The cover must be visible when the scene is inactive/backgrounded so
  app-switcher snapshots do not show app content.
- The cover must be visible when the main `UIScreen` reports active capture.
- The cover must be removed when the scene is active and no screen capture is
  active.
- The cover must contain no diary content, backend data, local paths, stack
  traces, secrets, or user-specific app data.

## Data model changes

No persisted data model changes are planned.

### Before

```text
No capture-prevention state is persisted in app data.
```

### After

```text
No capture-prevention state is persisted in app data.
Android secure-window state is native window configuration.
iOS capture/app-switch privacy state is transient native scene state.
```

### Migration

No migration is required.

## Test strategy

### Automated tests

| Test case | Type | File |
| --- | --- | --- |
| Android secure flag is applied in `MainActivity.onCreate` before `super.onCreate(...)` | Unit/source regression | `test/platform/android_capture_prevention_test.dart` |
| Android secure flag is not limited to debug automation mode | Unit/source regression | `test/platform/android_capture_prevention_test.dart` |
| iOS scene installs capture-change observation | Unit/source regression | `test/platform/ios_capture_privacy_test.dart` |
| iOS scene shows privacy cover for inactive/background snapshots and removes it only when active and not captured | Unit/source regression | `test/platform/ios_capture_privacy_test.dart` |
| Wrait launches normally with capture prevention present and main UI remains usable | Integration | `integration_test/capture_prevention_flow_test.dart` |
| Existing app-lock integration still launches and overlays correctly | Integration regression | `integration_test/app_lock_flow_test.dart` |
| Existing app smoke and routing tests continue to pass | Widget/unit regression | `test/app_smoke_test.dart`, `test/core/router/app_router_test.dart` |

Planned command set:

```sh
/opt/homebrew/bin/flutter test test/platform/android_capture_prevention_test.dart test/platform/ios_capture_privacy_test.dart test/app_smoke_test.dart test/core/router/app_router_test.dart
/opt/homebrew/bin/flutter test integration_test/capture_prevention_flow_test.dart
```

If the generated backend API package is missing locally, run `npm run build`
before Flutter tests as required by the backend generation guidance.

### Android emulator verification

1. Build and install a debug or profile Flutter app on an Android emulator
   using package identity `com.wrait.flutter.dev`.
2. Launch cold with:
   `adb shell am start -W -n com.wrait.flutter.dev/com.wrait.flutter.MainActivity`.
3. Verify the app reaches the expected Wrait UI and remains usable.
4. Capture an emulator screenshot with `adb exec-out screencap -p` while Wrait
   is foregrounded; expected evidence: the captured image does not show Wrait
   app content.
5. Open recent apps with `adb shell input keyevent KEYCODE_APP_SWITCH`, capture
   the emulator screen, and verify the Wrait task preview does not expose app
   content.
6. Run a short emulator screen recording with `adb shell screenrecord` where
   practical; expected evidence: the resulting video does not expose Wrait app
   content, or the emulator blocks/protects the capture.
7. Preserve screenshots/video notes in `implementation.md`.

### iOS simulator verification

1. Build and run Wrait on an iOS simulator.
2. Verify the app reaches the expected Wrait UI and remains usable when no
   capture is active.
3. Send Wrait to the app switcher/background and verify the app-switcher
   snapshot shows the native privacy cover instead of app content.
4. Attempt simulator video capture with `xcrun simctl io booted recordVideo`
   where practical; expected evidence: the privacy cover appears if the
   simulator reports active screen capture, or the simulator limitation is
   documented.
5. Return Wrait to foreground after capture/background transitions and verify
   normal UI returns when no capture is active.
6. Preserve simulator screenshots/video notes in `implementation.md`.

### Validation exception request

Request approval for this validation exception as part of plan approval:

- Flutter `integration_test` cannot directly assert the pixel contents of
  operating-system screenshot output, screen-recording video, or app-switcher
  task snapshots. Those checks will be validated with Android emulator and iOS
  simulator runtime commands plus saved evidence instead of full
  `integration_test` assertions.
- iOS simulator screen-recording APIs may not reliably toggle
  `UIScreen.main.isCaptured`. If simulator capture cannot trigger the native
  capture state, final validation may document that simulator limitation and
  use source regression coverage plus app-switcher simulator evidence. A
  physical-device path remains available for a later or manual validation pass.
- If simulator bootstrap is blocked by a system passcode prompt from secure
  storage or other protected startup dependencies, a compile-time
  `CAPTURE_VALIDATION_MODE=true` launch may be used to render non-sensitive
  placeholder content and exercise the same native privacy-cover behavior
  without changing production behavior.

No exception is requested for Android emulator verification, iOS simulator
launch/app-switch verification, compile checks, or the integration smoke test.

## Review and finalization

- `review.md` will be externally authored if review occurs.
- After reading `review.md`, no files may be changed until the remediation plan
  is explicitly approved.
- This feature is likely to require durable updates after final approval:
  - `docs/application-description.md` should mention native screenshot,
    recording, and app-switcher privacy protection.
  - `docs/agent-findings.md` should capture platform validation limitations,
    especially iOS one-shot screenshot limitations if confirmed.
  - `AGENTS.md` may need capture-validation guidance if the final emulator or
    simulator commands are useful for future privacy stories.

## Integration notes

- US-020 works alongside US-019 app lock. Android secure-window protection
  wraps the whole activity, including the app-lock surface. iOS native privacy
  cover sits above Flutter content during capture/app-switch states, so it can
  cover the app-lock screen too when needed.
- Existing startup behavior remains non-blocking. Android protection is a
  native window flag before Flutter render; iOS privacy cover is native scene
  state and does not move database/bootstrap work into a blocking path.
- The validation-only launch mode in `lib/main.dart` is compile-time gated and
  only intended for simulator evidence when secure startup dependencies block
  direct observation of the native cover. Production launches continue through
  the normal bootstrap path.
- Existing Android debug automation lockscreen flags must remain intact and
  restore behavior in deploy scripts must not change.
- Existing backend, quota, draft retry, local persistence, recording,
  transcription, cleanup, entry list/detail, sharing, editing, and deletion
  flows are not changed.

## Rollout & migration

This is an always-on app privacy behavior for Android and iOS. It requires no
feature flag, data migration, backend migration, or user setting.

Existing installs receive the protection on app update. No local data is read,
rewritten, or deleted as part of rollout.

## Risks & mitigations

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| Android secure-window flag is applied too late and the first frame can leak | Low | High | Apply the flag before `super.onCreate(...)`; add source-order regression test and launcher-style cold-start validation. |
| Flutter retargets the live Android activity window after the initial flag application | Medium | High | Reassert `FLAG_SECURE` after `super.onCreate(...)`, on resume, and when focus returns; validate secure flags before and after app-switch/resume transitions. |
| Android emulator capture behavior differs from physical devices or OEM builds | Medium | Medium | Validate on emulator for the required gate, document behavior, and preserve a physical-device validation path when stronger evidence is needed. |
| iOS simulator does not toggle active capture state during `simctl` recording | Medium | Medium | Validate app-switcher cover on simulator, keep source regression coverage for capture observer logic, document simulator limitation, and leave physical-device validation path available. |
| iOS simulator startup is blocked by a system passcode prompt before normal Wrait UI appears | Medium | Medium | Use a compile-time validation-only placeholder screen to exercise the same native cover behavior, while keeping the production bootstrap path unchanged. |
| iOS native privacy cover remains stuck after returning foreground | Low | High | Centralize visibility in one `updatePrivacyCover()` path keyed by scene activity and screen capture state; test source behavior and verify foreground return manually. |
| iOS one-shot screenshots still capture content | Medium | Medium | Document as a platform limitation of the simplest supported behavior. Revisit only if the user later approves a more complex secure-container approach. |
| Native cover conflicts with app lock or blocks accessibility unexpectedly | Low | Medium | Keep cover generic and only active during capture/app-switch states; verify app-lock integration and foreground usability. |
| Source-level tests become brittle after native refactors | Medium | Low | Keep tests focused on required observable contracts: secure flag order and lifecycle/capture observer presence. Runtime validation remains the stronger evidence. |

## Open items from spec

None. The plan carries forward the clarified choices:

- simplest acceptable iOS capture behavior
- all app surfaces in scope
- generic or blank protected output acceptable during locked state
- iOS capture feedback optional
- emulator/simulator validation baseline with real-device path available
