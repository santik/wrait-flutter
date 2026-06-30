# Implementation Plan: Logo Branding

> **Feature number:** 038
> **Spec:** [`spec.md`](spec.md)
> **Author:** Codex
> **Date:** 2026-06-29

---

## Approach summary

Replace the current platform placeholder branding with generated Wrait wordmark
assets and pin the wiring with source-level tests plus runtime verification.
Release assets will use the app's main-button treatment: a Wrait button-colored
field with the `wrait` word in the matching on-button text color. In the
current app look, that maps to the cream button surface (`0xFFE8E4DD`) with
charcoal text (`0xFF1A1917`). Debug/profile development assets will use the
same wordmark with a red debug treatment so the `.dev` app is visually
distinct. Flutter-controlled startup and lock surfaces already use
Wrait/neutral text; this plan preserves those privacy-safe surfaces while
adding tests that guard against reintroducing the default Flutter logo.

## Architecture decisions

| Decision | Choice | Rationale |
| --- | --- | --- |
| Logo source | Deterministic local vector/PNG generation from checked-in Wrait branding sources | The required mark is simple text plus color. A deterministic source avoids opaque binary-only edits and makes future refreshes repeatable. |
| Release color | Use the current Wrait main-button treatment: cream button field `0xFFE8E4DD` with charcoal wordmark `0xFF1A1917` | This matches the app look shown by the existing main action button and the user's requested "button color with wrait word" direction. |
| Debug color | Use a saturated red button field with a high-contrast `wrait` wordmark for debug and profile/dev builds | Android debug and profile both use `com.wrait.flutter.dev`; profile is the final deploy artifact in the debug deploy flow, so both dev build types should be visibly red. |
| Android dev icons | Add source-set icon overlays for `debug` and `profile` | This keeps release resources untouched for release builds while making the `.dev` app red without changing package identity. |
| iOS debug icons | Add a separate debug asset catalog icon set and wire Debug/Profile build configurations to it | iOS does not currently have separate debug icon wiring. Build configuration asset selection is the smallest platform-native change that keeps Release on release branding. |
| Startup branding | Keep neutral/native startup backgrounds where already neutral, and replace any branded launch image assets with Wrait wordmark assets | The spec requires no Flutter logo and Wrait app branding, but does not require redesigning startup behavior. |
| Privacy surfaces | Preserve the current neutral protected-state presentation (`Private` on iOS native cover and text-only app lock) | The finalized spec explicitly allows neutral privacy surfaces as long as they do not expose Flutter branding or sensitive content. |
| Automated validation | Combine widget/integration tests for Flutter-controlled surfaces with source/config tests for native asset wiring | Flutter tests cannot reliably inspect OS launcher/app-switcher pixels. Source tests pin the wiring, and runtime screenshots verify the OS surfaces. |

## File changes

| File | Action | Description |
| --- | --- | --- |
| `specs/038-logo-branding/spec.md` | Modify | Mark spec approved and keep final requirements as source of truth |
| `specs/038-logo-branding/plan.md` | Modify | This implementation plan |
| `specs/038-logo-branding/tasks.md` | Modify later | Actionable task checklist after plan approval |
| `tool/branding/` | Create | Checked-in branding source files and generation script for platform PNG assets |
| `android/app/src/main/res/mipmap-*/ic_launcher.png` | Modify | Release launcher icon PNGs with Wrait button-treatment wordmark |
| `android/app/src/debug/res/mipmap-*/ic_launcher.png` | Create | Debug launcher icon PNG overrides with red Wrait wordmark |
| `android/app/src/profile/res/mipmap-*/ic_launcher.png` | Create | Profile/dev launcher icon PNG overrides with red Wrait wordmark |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png` | Modify | Release app icons with Wrait button-treatment wordmark |
| `ios/Runner/Assets.xcassets/AppIconDebug.appiconset/` | Create | Debug/profile app icons with red Wrait wordmark |
| `ios/Runner/Assets.xcassets/LaunchImage.imageset/*.png` | Modify | Replace placeholder launch images with Wrait-safe launch images |
| `ios/Runner.xcodeproj/project.pbxproj` | Modify | Wire iOS Debug/Profile app icon setting to `AppIconDebug` while keeping Release on `AppIcon` |
| `test/bootstrap_app_test.dart` | Modify | Assert Flutter-controlled startup screens expose Wrait copy and no `FlutterLogo` widgets |
| `test/presentation/app_lock/app_lock_screen_test.dart` | Create | Focused widget coverage for the lock surface copy and absence of `FlutterLogo` |
| `test/platform/branding_assets_test.dart` | Create | Source/config tests for Android/iOS icon resources, debug/profile overrides, and absence of known Flutter placeholder wiring |
| `integration_test/app_lock_flow_test.dart` | Modify | Add runtime integration assertion that the locked surface remains Wrait/neutral and does not expose Flutter branding |
| `integration_test/branding_surfaces_flow_test.dart` | Create | Runtime integration smoke coverage for Flutter-controlled startup/loaded surfaces where practical |
| `specs/038-logo-branding/implementation.md` | Create during implementation | Record implemented changes and validation evidence |

## API contract details

No backend or HTTP contract changes.

## Data model changes

No persisted data model changes and no migration.

## Test strategy

### Automated tests

| Test case | Type | File |
| --- | --- | --- |
| Startup loading and retry surfaces use Wrait copy and no `FlutterLogo` widget | Widget | `test/bootstrap_app_test.dart` |
| App lock surface remains Wrait/neutral and does not expose `FlutterLogo` | Widget | `test/presentation/app_lock/app_lock_screen_test.dart` |
| Android release launcher icon resources exist at all densities and Android debug/profile overlays exist at all densities | Source/config | `test/platform/branding_assets_test.dart` |
| iOS release and debug app icon asset catalogs exist and Debug/Profile build configs point at the debug catalog | Source/config | `test/platform/branding_assets_test.dart` |
| iOS native privacy cover keeps generic `Private` copy and does not introduce Flutter branding | Source/config | `test/platform/ios_capture_privacy_test.dart` |
| App lock integration flow remains Wrait/neutral when locked after resume | Integration | `integration_test/app_lock_flow_test.dart` |
| Flutter-controlled branding smoke flow shows Wrait surfaces and no `FlutterLogo` widget | Integration | `integration_test/branding_surfaces_flow_test.dart` |

### Android emulator verification

1. Build and install the debug/dev app on an Android emulator.
2. Verify the launcher icon is the red `wrait` wordmark for
   `com.wrait.flutter.dev`.
3. Cold-start the app with launcher-style `adb shell am start -W -n
   com.wrait.flutter.dev/com.wrait.flutter.MainActivity` and verify the startup
   path does not show the default Flutter logo.
4. Trigger or inspect the lock/protected-state surface and verify it remains
   Wrait/neutral with no Flutter logo.
5. Capture screenshots of launcher/app switcher/startup/lock surfaces for
   evidence.
6. When release signing inputs are available, also build/install the release
   app and verify the launcher icon uses the Wrait button-treatment wordmark
   for `com.wrait.flutter`.

### iOS simulator verification

1. Build and run the Debug configuration on an iOS simulator.
2. Verify the installed app icon uses the red `wrait` wordmark.
3. Launch the app and verify startup/app surfaces do not show the default
   Flutter logo.
4. Exercise app lock or privacy-cover transitions and verify protected surfaces
   remain Wrait/neutral with no Flutter logo.
5. Inspect app-switcher/SplashBoard snapshot evidence where direct app-switcher
   automation is unavailable, following the project capture-privacy guidance.
6. Verify Release branding by generated asset review/source tests and, if a
   release-capable device/build path is available, by release runtime evidence.

### Validation exception request

Requested exceptions for explicit approval with this plan:

- Native launcher icons, OS splash icons, and app-switcher thumbnails are OS
  surfaces outside reliable Flutter `integration_test` introspection. They will
  be covered by generated-asset/source tests plus Android emulator and iOS
  simulator visual evidence instead of pure `integration_test` assertions.
- iOS Release-mode runtime execution is not generally available on the iOS
  simulator through Flutter. Release iOS branding will be validated by source
  asset checks and generated asset review unless a release-capable device path
  is available during implementation.
- Android release runtime verification depends on release signing inputs. If
  those inputs are unavailable during implementation, release branding will be
  validated by source/config tests and generated asset review, with debug/dev
  branding verified on emulator runtime.

## Review and finalization

- `review.md` will be externally authored if review occurs.
- After reading `review.md`, no files may be changed until the remediation plan
  is explicitly approved.
- This feature is likely to produce durable branding guidance. After final
  approval, propose long-lived notes for `AGENTS.md` and
  `docs/agent-findings.md` covering generated branding assets and dev/release
  icon separation.

## Integration notes

The change integrates with Android resource source sets, iOS asset catalogs,
Xcode build configuration settings, Flutter startup widgets, and the existing
native privacy-cover behavior. There are no backend, database, router,
recording, transcription, or sharing integration changes.

## Rollout & migration

The change ships as static app resources and tests. No feature flag or data
migration is required. Existing app identities remain unchanged:

- Android release/update: `com.wrait.flutter`
- Android debug/profile dev: `com.wrait.flutter.dev`
- iOS bundle identifier remains unchanged by this story

## Risks & mitigations

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| Wordmark readability at very small icon sizes is limited | Medium | Medium | Use high-contrast color treatment, inspect all generated sizes, and keep the `wrait` word as required by the spec. |
| Debug/profile icon wiring misses one platform/build mode | Medium | High | Add source/config tests for Android debug/profile overlays and iOS Debug/Profile app icon settings. |
| Native splash or OS app switcher still shows old cached assets during validation | Medium | Medium | Reinstall/clean build artifacts before runtime screenshots and document device/simulator state in implementation evidence. |
| Privacy cover branding could expose more than intended | Low | High | Preserve current neutral privacy cover copy and test that no Flutter branding is introduced. |
| Release runtime verification is blocked by signing or simulator limits | Medium | Medium | Request explicit planning exception and cover release assets with source/config tests plus generated asset evidence. |
| Binary asset churn is hard to review | Medium | Medium | Commit deterministic source assets and generation script alongside generated PNGs. |

## Open items from spec

No unresolved spec questions remain. The approved clarifications are:

- Protected lock/privacy surfaces may keep their current neutral presentation
  as long as the default Flutter logo is not exposed.
- App-controlled logo surfaces should always use `wrait`.
