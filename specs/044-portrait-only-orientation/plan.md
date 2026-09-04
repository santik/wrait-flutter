# Implementation Plan: Portrait-only App Orientation

> **Feature number:** 044
> **Spec:** [`spec.md`](spec.md)
> **Author:** Codex
> **Date:** 2026-09-02

---

## Approach summary

Declare portrait-only orientation at each native application boundary: the
Android Flutter activity will request sensor-based portrait orientation, and
the iOS application orientation allowlists will retain portrait values while
removing landscape values. Native declarations are applied before Flutter
renders and cover every Wrait route, dialog, and lifecycle transition without
adding asynchronous startup work or a new orientation state layer. A source
contract test will protect both declarations, an integration flow will verify
that the app remains usable across every current route and representative
dialogs, and Android/iOS runtime checks will verify actual rotation and resume
behavior where platform automation is available.

## Architecture decisions

| Decision | Choice | Rationale |
| --- | --- | --- |
| Orientation enforcement boundary | Native application configuration | It applies before Flutter startup and remains in force for all Flutter routes and dialogs. This is simpler and more reliable for the requirement than introducing a Dart lifecycle controller or an asynchronous startup call. |
| Android portrait policy | `sensorPortrait` on `MainActivity` | Landscape is excluded while normal and reverse portrait remain available where the device supports them, matching the finalized spec. |
| iOS portrait policy | Keep portrait entries in both supported-orientation arrays and remove landscape entries | The existing iPhone portrait behavior is preserved, iPad reverse portrait remains available, and both iOS device families stop advertising landscape support. |
| Runtime state and persistence | None | Orientation is an OS-level presentation policy; it does not require app state, storage, API changes, or a feature flag. |
| Startup integration | No change to `lib/main.dart` | Native declarations avoid delaying `runApp()` and preserve the project's non-blocking bootstrap behavior. |

## File changes

| File | Action | Description |
| --- | --- | --- |
| `android/app/src/main/AndroidManifest.xml` | Modify | Request sensor-based portrait orientation for `MainActivity`; retain and document the existing configuration-change handling. |
| `ios/Runner/Info.plist` | Modify | Remove landscape values from `UISupportedInterfaceOrientations` and `UISupportedInterfaceOrientations~ipad`, preserving the existing portrait values. |
| `test/platform/orientation_configuration_test.dart` | Create | Verify the Android activity orientation contract and the iOS portrait-only allowlists, with targeted failure diagnostics and reverse-portrait documentation. |
| `integration_test/orientation_lock_flow_test.dart` | Create | Exercise launch, portrait-window assertions, all current route transitions, lifecycle resume, the delete confirmation and feedback preparation dialogs, and continued interaction with app lock disabled. |

## API contract details

No HTTP API contract is introduced or modified. Orientation configuration is a
local application presentation policy and has no request, response, or error
payload.

## Data model changes

No data model or persisted state changes are planned.

### Before

```text
Android activity: no explicit orientation request.
iOS: portrait plus landscape values are advertised for iPhone and iPad.
```

### After

```text
Android activity: sensor-based portrait orientation is requested.
iOS: only existing portrait values remain advertised for each device family.
```

### Migration

None. The setting takes effect on the next app launch/update and does not
alter user data.

## Test strategy

The feature has one in-scope user flow: a user launches or resumes Wrait,
rotates the phone toward landscape, and continues using the app while it
remains in portrait. The integration test covers the app-side launch,
portrait-window assertion, resume, and route-navigation portions of this flow;
platform runtime verification covers the physical rotation portion that cannot
be driven reliably by a Flutter test alone.

### Automated tests

| Test case | Type | File |
| --- | --- | --- |
| Android manifest requests sensor-based portrait orientation | Source contract | `test/platform/orientation_configuration_test.dart` |
| iOS iPhone and iPad allowlists contain portrait values and no landscape values | Source contract | `test/platform/orientation_configuration_test.dart` |
| Launch Wrait, verify a portrait window, simulate resume, navigate through main → entries → entry detail → main, open representative delete and feedback dialogs, and verify portrait presentation remains usable | Integration | `integration_test/orientation_lock_flow_test.dart` |
| Existing app smoke, recording, privacy-lock, and navigation suites remain green | Regression | Existing `test/` and `integration_test/` suites selected during implementation |

### Android emulator verification

1. Build/install the intended Flutter Android artifact on a phone-sized Android
   emulator and record the emulator's existing rotation settings.
2. Force the emulator toward both landscape rotations, cold-launch the release
   identity with `adb shell am start -W -n
   com.wrait.flutter/com.wrait.flutter.MainActivity`, and verify through a
   screenshot and window/display inspection that Wrait remains taller than it
   is wide.
3. While the device is in the forced landscape state, background and resume
   Wrait, then exercise the main-to-entries navigation covered by the
   integration flow; verify the app remains portrait and retains the current
   screen state.
4. Restore every rotation setting changed for validation, even if a command or
   test fails.

Expected evidence: passing automated tests, a launcher-style cold-start result,
portrait screenshots for both landscape requests, and a post-resume window
inspection. Validation will use a phone-sized emulator because Android 16 and
later may ignore orientation locks on large-screen windows.

### iOS simulator verification

1. Build/install the app on the booted iOS simulator and launch it while the
   Simulator is rotated to each landscape direction using the Simulator's
   supported rotation controls.
2. Verify that the app returns to and remains in portrait at cold launch, after
   rotating while active, and after background/resume. Exercise the main-to-
   entries navigation and confirm that the screen remains usable.
3. Capture screenshots before and after rotation/resume, and inspect the built
   app's orientation allowlist if runtime behavior is ambiguous.

Expected evidence: passing automated tests and simulator screenshots showing
portrait presentation after supported rotation attempts and after resume. In
this environment, the active iOS landscape-rotation portion is not
automatable: macOS denied Simulator keyboard automation and `xcrun simctl`
does not expose an orientation command. The remaining iOS evidence consists of
the portrait baseline, expanded integration flow, built-app orientation
allowlist, and successful iOS build; the unverified physical-rotation portion
is recorded below as an approved exception.

### Validation exception request

Approved on 2026-09-04 during review remediation. The iOS simulator's active
landscape rotation and post-rotation resume cannot be driven in this
environment because macOS denied the Simulator keyboard automation and
`xcrun simctl` has no orientation-control command. The exception is limited to
that physical-rotation interaction; iOS build, portrait baseline,
orientation-allowlist inspection, expanded integration coverage, and Android
emulator/phone runtime checks remain required and are recorded as evidence.

## Review remediation disposition

| Finding | Disposition |
| --- | --- |
| P0-1 unrelated worktree changes | No file removal. The user directed that the existing deployment, documentation, and tester changes remain untouched and may share the changeset. |
| P1-1 incomplete iOS physical rotation evidence | Approved validation exception documented above; no unverified runtime result is claimed. |
| P1-2 limited route/dialog coverage | Addressed by expanding the integration flow through the entry-detail route and delete/feedback dialogs. |
| P2-1 Android `configChanges` clarity | Existing `orientation` handling retained and documented inline because the Flutter activity configuration contract remains intentional. |
| P2-2 test diagnostics | Addressed with assertion-specific failure reasons. |
| P3-1 reverse portrait documentation | Addressed with a source-contract test comment explaining `sensorPortrait`. |
| P3-2 test doubles | No change; minimal doubles remain appropriate for an orientation-focused flow. |

## Review and finalization

- `review.md` will be externally authored if review occurs.
- After reading `review.md`, no files may be changed until the remediation plan
  is explicitly approved.
- The final knowledge-capture decision will determine whether the orientation
  policy belongs in `AGENTS.md`, `docs/application-description.md`, or
  `docs/agent-findings.md`. The initial expectation is no durable documentation
  change because this is an isolated platform configuration change, but that
  decision will be presented after review and final validation.

## Integration notes

The Android activity and iOS scene/application orientation declarations are the
only runtime integration points. The existing Flutter bootstrap, router,
privacy lock, recording flows, and native import/export bridges require no
orientation-specific changes. System-owned screens opened from Wrait remain
outside the app orientation policy.

## Rollout & migration

Ship with the next normal Android and iOS app build. No migration, remote
configuration, feature flag, or backend rollout is needed. Existing installs
adopt the setting on update; user data and app identity remain unchanged.

## Risks & mitigations

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| A platform or large-screen policy ignores the requested orientation | Low on phones; higher on tablets/foldables | Medium | Validate on phone-sized Android and iOS targets; document the large-screen limitation and keep the app usable in its existing layouts. |
| A manifest or plist change affects startup or native screen behavior | Low | High | Keep the change declarative and minimal; add source-contract tests and perform launcher-style cold-start checks on both platforms. |
| Existing flows rely on an unintended landscape size | Low | Medium | Run the selected recording, privacy-lock, navigation, and import/export regression coverage and inspect the main and entries screens during runtime verification. |

## Open items from spec

None. Reverse portrait is permitted where supported, and system-owned screens
and separate large-screen layout strategy remain out of scope.
