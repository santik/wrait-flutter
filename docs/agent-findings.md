# Agent Findings

This document captures implementation findings from completed stories that are
worth keeping in mind during future feature work.

## US-020: Screenshot and Screen Recording Prevention

### Android secure-window contract

- Android capture privacy is implemented at the activity window level through
  `FLAG_SECURE` in
  `android/app/src/main/kotlin/com/wrait/flutter/MainActivity.kt`.
- Keep the protection unconditional across debug, profile, and release
  identities.
- Pre-`super.onCreate(...)` application is required for first-frame protection,
  but validation also showed that this alone was not enough to preserve the
  secure flag on the final live Flutter window.
- The current validated contract therefore includes reasserting `FLAG_SECURE`
  after `super.onCreate(...)`, on resume, and when focus returns.
- Do not remove those reassertion points casually. Revalidate with runtime
  window inspection first if a future story tries to simplify them.

### Android validation guidance

- For capture-privacy work, verify more than a single screenshot:
  - launcher-style cold start
  - `dumpsys window` secure-flag presence on the live activity window
  - black foreground screenshot output
  - black recents/task-preview output
  - a decoded frame from an Android `screenrecord` artifact
- Debug automation lockscreen mode remained compatible with `FLAG_SECURE`
  during validation. Preserve that interaction and restore the automation
  setting after temporary test changes.

### iOS scene-cover contract

- iOS capture privacy is implemented in `ios/Runner/SceneDelegate.swift` as a
  native scene-level privacy cover.
- Keep the iOS cover generic and non-sensitive. The current validated text is
  `Private`.
- The validated app-switch/background behavior is the inactive/background scene
  path, not a Flutter route-specific overlay.

### iOS simulator validation caveats

- In this environment, normal simulator startup can still surface a system
  passcode prompt for Wrait before ordinary Flutter UI appears, even when the
  app-lock provider is disabled.
- A compile-time `CAPTURE_VALIDATION_MODE=true` launch path in `lib/main.dart`
  is acceptable for validation-only placeholder content because it exercises
  the same native privacy-cover path without changing the production bootstrap
  flow or exposing diary content.
- `xcrun simctl io booted recordVideo` did not toggle
  `UIScreen.main.isCaptured` here. Do not over-claim simulator proof for
  active-capture hiding based on `recordVideo` alone.
- When direct app-switcher UI automation is unavailable, inspect the stored
  SplashBoard snapshot in the simulator app container. That gave direct runtime
  proof that the native `Private` cover replaced the visible foreground content
  during the background snapshot path.

## US-019: App Lock

### Root app-lock contract

- The privacy lock should stay implemented as a root app gate above the router
  content rather than as screen-specific logic.
- Current production wiring uses:
  - `lib/presentation/app_lock/app_lock_gate.dart`
  - `lib/presentation/app_lock/app_lock_controller.dart`
  - `lib/data/auth/app_lock_authenticator.dart`
  - `lib/data/auth/device_security_settings_opener.dart`
- Cold launch starts locked.
- Returning from a true foreground exit re-locks the app until authentication
  succeeds or the approved no-security bypass is used.

### Lifecycle caveat worth preserving

- Do not treat `AppLifecycleState.inactive` as a relock trigger for app lock.
- Real-device validation showed that native biometric UI can emit transient
  `inactive` transitions while the authentication sheet is on screen.
- If app lock re-locks on `inactive`, the biometric prompt can slide up and
  down continuously because auth is canceled and immediately restarted on the
  next `resumed`.
- The current contract is:
  - ignore `inactive`
  - relock only on true foreground exit states such as `paused`, `hidden`, and
    `detached`

### Native auth robustness

- App-lock auth now uses an explicit timeout with best-effort cancellation so a
  hung native prompt returns a retryable unavailable state instead of leaving
  the session permanently stuck in `authenticating`.
- Non-success auth and availability outcomes are logged through the shared
  app-lock warning logger.
- Device-security settings opening is single-flight to avoid repeated settings
  launches from rapid taps.

### Android platform contract

- Android app-lock production wiring depends on:
  - `MainActivity` remaining a `FlutterFragmentActivity`
  - `android.permission.USE_BIOMETRIC`
  - AppCompat-compatible launch/normal theme parents for `local_auth_android`
- The Android security-settings path should verify that the intent resolves
  before launching it.

### Testing guidance

- Tests that pump `WraitApp` but are not specifically validating app lock
  should override `appLockEnabledProvider` to `false`.
- Dedicated app-lock coverage should keep validating:
  - cold launch unlock
  - relock on foreground return
  - `inactive -> resumed` churn during an in-flight auth prompt
  - cancel/retry
  - no-security settings + bypass
  - temporary unavailable retry

### Validation note

- On the connected Android phone, the post-fix app-lock integration flow passed
  after iOS simulator and Android emulator validation were both green.
- A plain `adb shell am start -W` cold launch of the reinstalled debug build
  later reported `Status: timeout` while `dumpsys activity` still showed
  `com.wrait.flutter.dev/.MainActivity` as the resumed activity. Treat
  `dumpsys` as a useful secondary check when launcher-style timing output is
  ambiguous on this device.

## US-032: iOS Draft Audio Update Path Stability

### Shared retained-audio path contract

- Retryable draft audio paths should be stored the same way on iOS and Android:
  `app-cache://<relative-path>` under the current app temporary directory.
- Do not persist absolute app-cache paths for retryable draft audio. iOS app
  container paths can change across update or reinstall-style simulator flows
  even when logical app data remains continuous.
- Do not reintroduce basename fallback or legacy absolute-path recovery for
  retained draft audio. If a stored reference cannot be resolved safely, it
  should fail explicitly rather than binding a draft to the wrong file.
- When integration tests seed retryable audio drafts through the production
  repository/provider graph, create real files in the app temporary directory
  so tests exercise the same retained-audio contract as production code.

## US-015: Draft Retry System

### Launch sequencing contract

- Launch-time draft retry must stay sequenced after successful device
  registration.
- `startAppLaunchWork(...)` remains fire-and-forget from the UI's perspective:
  first paint and normal navigation must not wait for registration or retry to
  finish.
- Retry is launch-only. If launch registration fails and later recovers in the
  same app session, draft retry still waits for a future app launch.

### Draft retry behavior worth preserving

- Pending drafts are retried newest-first from local entries where
  `isDraft=true`.
- Stale drafts older than seven days are deleted before pending drafts are
  loaded for retry.
- Each pending draft is handled independently so one retry failure does not
  block later drafts in the same launch pass.
- Audio drafts with blank, missing, unreadable, or empty retained files should
  be deleted instead of retried indefinitely.
- Audio transcription failure preserves the audio draft and retained file.
- Audio transcription success followed by cleanup failure should preserve a
  text draft at the same entry id and delete the no-longer-needed retained
  audio file.
- Retry success should remain silent in the foreground; finalized entries
  simply appear through the existing list/detail/stats surfaces.

### Retry implementation boundaries

- `RegisterDeviceOnLaunchUseCase` owns launch registration result reporting and
  session-quota propagation.
- `AppLaunchWorkUseCase` owns launch-only sequencing of registration followed
  by draft retry.
- `RetryPendingDraftsUseCase` owns stale cleanup, pending-draft iteration,
  malformed-audio deletion, transcription retry, and retained-audio cleanup.
- `CleanupTranscriptUseCase` continues to own text-draft persistence, language
  canonicalization, and final entry creation after usable cleanup success.

### Validation guidance

- Android emulator validation for this story succeeded on `emulator-5554`, but
  the reliable bring-up path in this repo was the direct emulator binary:
  `/Users/alexander/Library/Android/sdk/emulator/emulator -avd Pixel_8_emulator -no-snapshot-load`
- If `flutter emulators --launch Pixel_8_emulator` does not surface a
  connected device, launch the AVD directly, wait for
  `adb -s emulator-5554 shell getprop sys.boot_completed` to return `1`, and
  then run Flutter integration tests against `emulator-5554`.

## US-001: Flutter Project Foundation

### Established app foundation

- The Flutter application now lives at the repository root.
- The app bootstrap already exists and should be reused:
  - `lib/main.dart`
  - `lib/app.dart`
  - `lib/core/config/app_config.dart`
  - `lib/core/router/app_router.dart`
- The intended top-level layer split is in place:
  - `lib/core`
  - `lib/data`
  - `lib/domain`
  - `lib/presentation`

### Runtime configuration contract

Future stories should reuse the existing runtime config surface instead of
creating a second environment-loading path.

Supported defines:

- `BACKEND_URL`
- `PROXY_SECRET`
- `RECORDING_HARD_CAP_MS`

Current implementation details:

- Config is loaded through `AppConfig.fromEnvironment()`.
- `BACKEND_URL` defaults to `https://wrait-backend.vercel.app`.
- `PROXY_SECRET` defaults to an empty string.
- `RECORDING_HARD_CAP_MS` defaults to `120000`.
- Config parsing is validated in `test/core/config/app_config_test.dart`.

### Platform baseline

Android baseline:

- Release/update package/application ID: `com.wrait.flutter`
- Debug/profile package/application ID: `com.wrait.flutter.dev`
- `minSdk = 26`
- `RECORD_AUDIO` permission is already declared
- `INTERNET` must remain declared in `android/app/src/main/AndroidManifest.xml`
  so production Android builds can reach the backend

Older notes or external materials may still mention `com.wrait.app`. Treat
that as historical context and verify the installed package name before
debugging device state or uninstalling builds.

iOS baseline:

- Deployment target: `14.0`
- `NSMicrophoneUsageDescription` is already declared
- `NSSpeechRecognitionUsageDescription` is already declared

### Historical iOS integration caveat

Early Flutter setup encountered an iOS dependency mismatch: Flutter 3.44
generated a Swift Package Manager-first project, while `sqflite_sqlcipher`
still depended on CocoaPods.

This is now historical context only:

- `sqflite_sqlcipher` has been removed from the Flutter dependency graph.
- The checked-in iOS project has been cleaned up to use Swift Package Manager
  only for the current plugin set.
- Do not reintroduce CocoaPods wiring casually unless a future dependency
  explicitly requires it and a new story approves that change.

### Dependency warnings worth tracking

The current project builds and runs, but these warnings appeared during setup:

- These plugins emit Kotlin Gradle Plugin migration warnings on Android:
  - `package_info_plus`
  - `share_plus`
  - `speech_to_text`
  - `wakelock_plus`

These are not blockers right now, but future dependency upgrades should be done
carefully.

### Validation knowledge

US-001 was validated successfully on both platforms:

- Android emulator launch succeeded.
- iOS simulator launch succeeded.
- The placeholder shell displayed the expected config-derived values on both:
  - `Foundation ready`
  - `wrait-backend.vercel.app`
  - `120 seconds`
  - `Configured`

### Guidance for future stories

- Reuse `AppConfig` for backend, proxy, and recording-cap settings.
- Keep plugin-specific code in `data`.
- Add business contracts only when a story actually needs them.
- Prefer unit tests around config/service logic before wiring UI.
- Treat iOS dependency changes carefully because the current project is now
  SPM-only and future Pod-required plugins would need an explicit re-migration.

## US-027: Android Deploy Script and App Namespace Isolation

### Android debug deployment contract

- Prefer `./deploy_debug.sh` for real-device Android debug deployment when the
  story depends on backend registration, transcription, or proxy-authenticated
  traffic.
- The Flutter Android debug/profile package/application ID is
  `com.wrait.flutter.dev`.
- The release/update Flutter Android package/application ID remains
  `com.wrait.flutter`.
- The native Android app remains `com.wrait.app`; treat that package as a
  separate install that must be preserved.

### Deploy-script behavior worth preserving

- `./deploy_debug.sh` intentionally ignores emulators and requires one
  connected physical Android phone in `device` state.
- The script builds the debug APK, runs
  `flutter test --no-pub -d <phone-serial> integration_test`, and only then
  performs the final APK install.
- When the deploy script is not the right validation tool, the manual debug APK
  fallback is:
  - `PROXY_SECRET=... /opt/homebrew/bin/flutter build apk --debug --dart-define=PROXY_SECRET=...`
  - install `build/app/outputs/flutter-apk/app-debug.apk` with `adb`
- The script verifies `com.wrait.flutter.dev` exists after install.
- If `com.wrait.app` existed before deployment, the script verifies it still
  exists after install.
- The script must never uninstall `com.wrait.app`.
- Shell regression coverage for this behavior lives in
  `test/deploy_debug_script_test.sh`.

### Current validation state

- The most recent real-device run confirmed that `./deploy_debug.sh` uses the
  connected physical Android phone and stops before final install when
  integration tests fail.
- That same run confirmed `com.wrait.app` remained installed after the aborted
  deploy attempt.
- Two current real-device integration failures are tracked as follow-up work in
  `plan/us_028.md`:
  - `launch registration is non-blocking and updates session quota on success`
  - `transient launch registration failure is non-blocking and preserves quota`

## US-029: Connected Device Tests With Screen Off

### Locked-screen deploy behavior

- `./deploy_debug.sh` now supports starting from a connected physical Android
  phone whose screen is off and whose keyguard is still active.
- The script wakes the phone, attempts best-effort keyguard dismissal, and
  uses an automation-gated debug Android activity path so the test flow can
  proceed without manual interaction on an ordinarily locked phone.

### Deploy artifact split worth preserving

- The deploy script still uses the debug/integration channel for
  `flutter test --no-pub -d <phone-serial> integration_test`.
- On the current physical validation phone, the final standalone debug install
  can remain stuck on the Flutter splash screen even though the debug test
  phase succeeds.
- Because of that validated device behavior, `./deploy_debug.sh` now builds
  and installs the profile APK as the final deployed app artifact after the
  debug test phase passes.
- When reproducing or manually validating the same final deployed app state,
  prefer the profile artifact instead of assuming the final install is debug.

### Automation-state contract

- The temporary Android automation switch for locked-screen launch is the
  namespaced global setting
  `com.wrait.flutter.debug.automation_lockscreen_mode`.
- `MainActivity` should only enable show-over-lock-screen, turn-screen-on, and
  keep-screen-on behavior when both of these are true:
  - the process is debuggable
  - that automation setting is set to `1`
- Keep the setting namespaced, validate readback after writes, and restore the
  previous value when the script exits.

### Permission and cleanup guidance

- The deploy script must keep `android.permission.RECORD_AUDIO` granted during
  the Flutter test session because `flutter test` can reinstall both
  `com.wrait.flutter.dev` and `com.wrait.flutter.dev.test`, which can
  otherwise bring back the system recording prompt on a locked phone.
- The permission watchdog should stay bounded and should clean up stale PID
  state at startup.
- The deploy script should continue restoring temporary stay-awake and
  automation-setting state on both success and failure paths.
- Shell regression coverage for this behavior lives in
  `test/deploy_debug_script_test.sh`.

## US-031: Release-Signed Android Deploy Flow

### Android release deployment contract

- Prefer `./deploy_release.sh` for physical-phone Android release deployment
  when a story depends on the stable release signing identity or on
  update-compatible installs under `com.wrait.flutter`.
- `./deploy_release.sh` is separate from `./deploy_debug.sh` and must preserve
  any pre-existing `com.wrait.flutter.dev` install.
- The native Android app `com.wrait.app` remains a separate install that must
  not be removed by the Flutter release flow.

### Private config and signing contract

- Canonical private release config lives in `wrait-android/local.properties`.
- The Flutter-local consumed config remains `android/local.properties`, but
  only non-secret release keys should be synchronized there:
  - `KEYSTORE_PATH`
  - `KEY_ALIAS`
  - `BACKEND_URL`
  - `PROXY_SECRET`
  - `RECORDING_HARD_CAP_MS`
- Do not persist `KEYSTORE_PASSWORD` or `KEY_PASSWORD` into
  `android/local.properties`.
- Release signing passwords should stay transient through the environment:
  - `WRAIT_RELEASE_KEYSTORE_PASSWORD`
  - `WRAIT_RELEASE_KEY_PASSWORD`
- `deploy_release.sh` should validate the configured keystore with `keytool`
  before building:
  - `keytool -list` confirms keystore access and alias availability
  - `keytool -certreq` confirms private-key access with the configured key
    password

### Release-build behavior worth preserving

- The release Gradle configuration should fail closed for release tasks when
  required signing inputs are absent.
- `android/local.properties` synchronization should be atomic and should remove
  stale persisted signing-password entries from older local files.
- `deploy_release.sh` intentionally does not run `integration_test`, does not
  enable debug lock-screen automation settings, and does not install the debug
  identity.
- If `com.wrait.flutter.dev` existed before release deployment, the script
  should verify it still exists afterward.
- Shell regression coverage for this behavior lives in
  `test/deploy_release_script_test.sh`.

### Production backend-connectivity note

- Production Android backend registration and quota visibility depend on
  `android.permission.INTERNET` being declared in
  `android/app/src/main/AndroidManifest.xml`.
- Do not move that permission back to debug/profile-only manifests, or release
  installs can silently stop reaching `/api/register`.

## US-012: Microphone Permission Handling

### Main-screen permission behavior

- The main recording flow now distinguishes retryable microphone denial from
  blocked microphone access.
- `MicrophoneAccessState.denied` maps to retryable UI with
  `mic needed · tap again`.
- `MicrophoneAccessState.permanentlyDenied` and
  `MicrophoneAccessState.restricted` map to blocked UI with
  `mic blocked · tap settings`.
- Blocked state recovery is driven by app resume: granting permission in
  system settings and returning to the app clears the blocked state without a
  restart.

### iOS-specific permission nuance

- Keep the first unseen iOS microphone `denied` state retryable so the initial
  tap can still show the native prompt.
- After the app has already attempted a microphone permission request in the
  current session, iOS `denied` should be treated as blocked rather than
  retryable because the platform may stop re-presenting the prompt.
- This behavior is covered in
  `test/data/audio/microphone_permission_service_test.dart`.

### Resume-path guidance

- `MainRecordingController.onAppResumed()` should keep its single-flight guard.
- Resume-time permission checks should stay timeout-bounded so a hung platform
  permission query does not wedge the foreground recovery path.
- Current controller coverage for that behavior lives in
  `test/presentation/main/main_recording_controller_test.dart`.

### Recording revocation guidance

- When microphone access disappears while the app is already listening, use
  cancel semantics rather than the normal stop/upload flow.
- The cancel path exists to avoid uploading or saving audio captured after the
  permission loss event.
- `CloudTranscriptionService.cancelLiveTranscription()` should preserve state
  honestly if recorder cancellation throws: log the failure and reflect
  whether the recorder still reports an active session.

### Accessibility guidance

- Retryable and blocked permission statuses now carry explicit semantics
  labels and hints instead of the generic status-message wording.
- Future changes to permission-related status copy should update both the
  visible text and the accessibility strings together.

### Real-device test caveat

- Keep `integration_test/main_screen_flow_test.dart` focused on behavioral
  assertions when validating against the locked physical Android phone.
- Screenshot capture in that suite caused the real-device run to hang on a
  locked screen, even though the behavioral checks themselves were valid.
- The focused permission suite
  `integration_test/main_screen_permission_flow_test.dart` remains safe for
  real-device and simulator coverage of the microphone permission flows.

## US-002: Theme, Design Tokens & Core UI Shell

### Established presentation foundation

- The Flutter app now has a centralized presentation-theme surface under:
  - `lib/presentation/theme/design_tokens.dart`
  - `lib/presentation/theme/wrait_colors.dart`
  - `lib/presentation/theme/wrait_typography.dart`
  - `lib/presentation/theme/wrait_theme.dart`
- The app shell now uses explicit Wrait light and dark Material 3 themes
  through `ThemeMode.system`.
- The placeholder shell implementation now lives in:
  - `lib/presentation/shell/shell_placeholder_screen.dart`
  - `lib/presentation/home/home_placeholder_screen.dart`

### Token and theme guidance

Future UI stories should reuse the existing token and theme surface instead of
adding screen-local constants.

Important implementation details:

- Spacing, animation, gesture, button-sizing, app-lock, and reserved-layout
  values are centralized in `design_tokens.dart`.
- Semantic status colors now exist as a `ThemeExtension`:
  - `WraitSemanticColors`
- Future status, warning, error, info, and success UI should read semantic
  colors from `Theme.of(context).extension<WraitSemanticColors>()` instead of
  inventing local palettes.
- The typography surface now includes:
  - `bodyLarge`
  - `labelLarge`
  - `labelSmall`
  - `bodySmall`
  - `titleMedium`

### Routing and shell behavior

- The router now supports:
  - `/`
  - `/entries`
  - `/entry/:id`
- `lib/core/router/app_router.dart` now honors Flutter startup routes when no
  explicit `initialLocation` is injected.

Important implications:

- Manual direct-route verification can use `flutter run --route=/entries` or
  `flutter run --route=/entry/<id>`.
- Empty entry IDs should not be treated as valid input:
  - `/entry/:id` redirects to `/entries` when the resolved ID is blank.

### Accessibility guidance

- Decorative shell visuals should not be exposed blindly to assistive
  technologies.
- The placeholder shell now uses explicit semantics for:
  - reserved status and quota message regions
  - entry ID badge content
  - adaptive button preview summary
- Future shell-like UI should preserve this pattern:
  - expose meaningful labels for content regions
  - use `ExcludeSemantics` for purely decorative visuals when needed

### Validation knowledge

US-002 was validated successfully with both automated and manual checks:

- `flutter analyze` completed with no issues.
- `flutter test` passed, including:
  - route coverage for `/`, `/entries`, and `/entry/:id`
  - empty-ID redirect behavior
  - dark-theme rendering checks
  - adaptive button-sizing edge cases
- Manual verification succeeded on:
  - Android emulator in light and dark mode
  - iOS simulator in light and dark mode
  - Android direct-route launches for `/entries` and `/entry/day-001`

### Guidance for future stories

- Reuse the centralized Wrait theme/token files for all future UI constants.
- Prefer adding missing design-system values to the shared theme surface rather
  than introducing feature-local colors or spacing.
- Use `flutter run --route=...` for manual route verification before adding any
  temporary debug navigation UI.
- Validate dark-mode changes with both widget tests and manual device/simulator
  checks; theme-object assertions alone are not enough.
- Use `dart format` for Dart/Flutter formatting. `flutter format` is not the
  correct formatter command in this toolchain.

## US-003: Encrypted Local Entry Store

### Established persistence foundation

- The Flutter app now has an encrypted local entry store under:
  - `lib/data/entries/`
  - `lib/domain/model/entry.dart`
  - `lib/domain/model/supported_language.dart`
  - `lib/domain/repository/entry_repository.dart`
- App startup now renders first and completes launch/bootstrap work behind a
  first-frame loading shell in:
  - `lib/main.dart`
  - `lib/data/entries/entry_providers.dart`

### Encryption and database guidance

- The project uses Drift plus the `sqlite3mc` runtime selected through
  `hooks.user_defines.sqlite3.source: sqlite3mc` in `pubspec.yaml`.
- The code is intentionally using `package:sqlite3` with the
  SQLite3MultipleCiphers build selected by hooks, not a separate long-term
  `sqflite_sqlcipher` architecture.
- Database open now performs a runtime cipher-availability check:
  - `PRAGMA cipher;` must succeed during setup
  - missing cipher support should fail startup explicitly instead of silently
    proceeding
- The encrypted database file path is still:
  - app documents directory + `wrait_entries.sqlite`

### Entry and language contract

- Persisted entries use canonical supported BCP-47 language codes only.
- Flutter now mirrors the Android supported-language canonicalization behavior:
  - exact supported tags are preserved canonically
  - `_` is normalized to `-`
  - base-language inputs like `en` and `fr` resolve to supported canonical tags
  - unsupported values are rejected before persistence
- Current supported language codes are:
  - `en-US`
  - `nl-NL`
  - `ru-RU`
  - `uk-UA`
  - `de-DE`
  - `es-ES`
  - `fr-FR`
  - `it-IT`
  - `pl-PL`
  - `pt-PT`
  - `tr-TR`

### Repository behavior worth preserving

- `updateDraftTranscript()` intentionally clears `audioPath`; this matches the
  Android reference behavior and existing expectations for audio-draft
  progression.
- Stale draft cleanup runs during startup before normal app use continues.
- Audio-file cleanup is best-effort and intentionally does not block database
  correctness.
- Preserve the non-blocking launch pattern: bootstrap failures should surface
  through the startup retry UI instead of preventing the Flutter app from
  rendering a first frame.
- The current Drift setup uses direct `NativeDatabase(...)` opening rather than
  `NativeDatabase.createInBackground(...)`.
- Recent host validation reopened a seeded database with 1,000 entries in about
  20 ms, which was acceptable for the current startup path. Re-measure before
  revisiting a more complex background-open design.

### Validation knowledge

- Shared persistence validation now includes:
  - `flutter analyze`
  - `flutter test`
  - targeted entry-store tests under `test/data/entries/`
- Native validation that has already succeeded:
  - Android debug build: `flutter build apk --debug`
  - iOS simulator debug build: `flutter build ios --simulator --debug --no-codesign`

## US-030: Update Preserves Local Data

### Data lifecycle contract

- Same-identity app updates on Android and iOS should preserve the encrypted
  database and linked app-private retained files.
- Uninstall/reinstall should remove app-private local state and reopen as a
  fresh install.
- Android `pm clear` should remove app-private local state and reopen as a
  fresh install.
- Android backup/restore is intentionally disabled for this local-data
  lifecycle so uninstall stays aligned with a true fresh start.

### Database failure handling worth preserving

- `LocalEntryDatabase.open()` should fail closed on corruption or open errors
  and leave database artifacts untouched.
- `deleteDatabaseArtifacts()` is destructive and should stay reserved for
  explicit reset flows only, not automatic recovery during bootstrap.
- Preserve the existing startup UX contract: database-open failures should
  surface through the bootstrap retry/error shell instead of silently wiping
  persisted data.

### Validation guidance

- `flutter test -d ... integration_test/...` is not a trustworthy harness for
  same-identity update-preservation checks because it can reinstall the app
  container and reset local state as part of the test flow.
- `flutter drive --keep-app-running` is the validated harness for seed/update
  verification when persistence across installs matters.
- Recent cross-platform validation succeeded for:
  - Android same-package update preserving local state
  - iOS same-bundle update preserving local state
  - uninstall/reinstall reopening with fresh local state
  - Android `pm clear` reopening with fresh local state
- Absolute iOS cache-path portability for retained draft audio remains a
  separate follow-up tracked in US-032 rather than a solved part of US-030.

## US-028: Device Registration Launch Hardening

### Startup and retry behavior

- The first visible app state should come from the Flutter bootstrap shell, not
  the launcher icon. When launch work fails, the user should land in an
  explicit retryable failure state instead of appearing stuck during startup.
- Bootstrap retry is intentionally single-flight. Keep retry actions from
  issuing overlapping launch requests.

### Deployment and backend registration guidance

- Prefer `./deploy_debug.sh` for Android real-device validation when a story
  depends on backend registration or proxy-authenticated traffic.
- `PROXY_SECRET` must be set for those debug deployments so runtime config can
  populate the expected `X-Proxy-Secret` header.
- The deploy script now guards against a few easy-to-miss failure modes:
  - no connected target device
  - missing or zero-byte APK output
  - reinstalling stale build artifacts

### Recording and permission behavior

- Recording startup now relies on richer microphone permission interpretation in
  the service layer:
  - granted
  - denied
  - permanently denied
  - restricted
- UI currently collapses blocked permission outcomes into the existing
  microphone-blocked feedback state. Keep that mapping in mind before adding
  more granular copy or settings deep links.
- Native Android recording-start failures are surfaced back through the Flutter
  controller path and should remain user-visible instead of failing silently.

### Test guidance

- Main-screen flow tests should use stable selectors from
  `lib/presentation/main/main_screen_test_keys.dart` instead of depending on
  display text.

## US-028: Android Cold-Launch Rendering Fix

### Rendering and startup finding

- Some physical-device Android launches could reach `MainActivity` but remain
  stuck behind the Android splash screen with no completed first frame.
- The failing launches showed:
  - `adb shell am start -W ...` returning `Status: timeout`
  - repeated `FlutterRenderer: Width is zero. 0,0`
  - the splash window still layered above `com.wrait.flutter/.MainActivity`
- On the current validation phone, that behavior correlated with
  Impeller/Vulkan startup.

### Current mitigation

- `android/app/src/main/AndroidManifest.xml` now sets:
  - `io.flutter.embedding.android.EnableImpeller=false`
- Treat that manifest setting as intentional until a future story re-validates
  Android startup stability with Impeller enabled.

### Validation knowledge

- The failing cold-launch path reproduced after plain `adb install -r` followed
  by launcher-style app start.
- After disabling Impeller, explicit cold start validation succeeded with:
  - `Status: ok`
  - `LaunchState: COLD`
  - `WaitTime` around `1743 ms`
- Launcher-intent validation also succeeded afterward, and Android reported:
  - `Displayed com.wrait.flutter/.MainActivity`
  - `Fully drawn com.wrait.flutter/.MainActivity`

## US-011: Main Screen UI

### Established main-screen presentation surface

- The app root route `/` now renders the real recording-focused main screen:
  - `lib/presentation/main/main_screen.dart`
- The reusable main-screen presentation pieces now live under:
  - `lib/presentation/main/button_area.dart`
  - `lib/presentation/main/pulse_ring.dart`
  - `lib/presentation/main/countdown_ring.dart`
  - `lib/presentation/main/main_screen_status.dart`
  - `lib/presentation/main/main_screen_stats.dart`

### Main-screen behavior worth preserving

- The root experience is now a voice-first single-button flow:
  - first-time idle status: `tap button to write`
  - returning idle button/status text: `wrait`
  - listening button text: `stop`
  - status text lives under the button, not inside it
- Saved feedback is intentionally UI-owned and auto-clears from the screen
  after the configured saved display window.
- Error and Deleted feedback remain controller-owned auto-clear behavior.
- Main-screen stats use fixed wording:
  - `{count} entries - {days} days`
- Stats count all stored entries, including drafts.
- Day counts use unique local calendar dates derived from entry timestamps.
- The saved status line navigates to `/entry/:id`.
- The stats line navigates to `/entries`.

### State-contract guidance

- `RecordingListening` now carries:
  - `hardCapDeadlineElapsedRealtime`
- `RecordingErrorState` now carries:
  - `preservedDraft`

Future stories should reuse these fields rather than reaching back into
transcription services or inferring draft preservation from generic error
categories in the UI.

### Presentation-logic guidance

- Status copy and status tap behavior are intentionally centralized in:
  - `lib/presentation/main/main_screen_status.dart`
- Entry-stat derivation is intentionally centralized in:
  - `lib/presentation/main/main_screen_stats.dart`

Future UI work on the main screen should extend those helpers instead of
duplicating status text or entry-stat formatting in widgets.

### Countdown and repaint guidance

- Countdown progress is intentionally updated through a local
  `ValueNotifier<double?>` in `MainScreen`.
- The button/countdown region is rebuilt through `ValueListenableBuilder`
  rather than whole-screen `setState()` ticks.

Future work should preserve that localized repaint pattern unless a story
explicitly introduces a different timing architecture.

### Token and test guidance

- Button shake and countdown sizing/timing values now belong in:
  - `lib/presentation/theme/design_tokens.dart`
- Do not reintroduce feature-local magic values for button/countdown tuning.
- When testing listening-state UI, be careful with `pumpAndSettle()` because
  active countdown refreshes keep scheduling frames.

### Validation knowledge

- Main-screen integration coverage now runs on both:
  - Android emulator
  - iOS simulator
- `integration_test/main_screen_flow_test.dart` is the primary end-to-end
  coverage surface for:
  - first-time idle
  - listening
  - saved feedback
  - entry-detail navigation
  - stats display/navigation
  - quota visibility
  - microphone-blocked feedback

## US-005: Backend API Client

### Established backend API foundation

- The Flutter app now has a centralized backend API layer under:
  - `lib/data/api/backend_client.dart`
  - `lib/data/api/backend_results.dart`
  - `lib/data/api/backend_providers.dart`
  - `lib/data/api/record_quota_state.dart`
  - `lib/data/api/generated/backend_api_generated.dart`

### OpenAPI contract and generation guidance

- The backend contract source of truth in this repo is:
  - `api/wrait-backend.yaml`
- Backend client generation now uses the official OpenAPI Generator CLI with
  the `dart-dio` generator.
- The checked-in generation entrypoints are:
  - `package.json`
  - `openapitools.json`
  - `tool/openapi-generator/backend-api-config.yaml`
- The generated package output lives at:
  - `tool/openapi-generator/output/backend_api/`

Important workflow implication:

- The generated package output is not tracked in git.
- On a fresh clone, run `npm run build` before `flutter pub get`,
  `flutter analyze`, or `flutter test`.
- App code should continue to depend on the compatibility bridge in
  `lib/data/api/generated/backend_api_generated.dart` rather than importing the
  generated package surface directly in feature code.

### Request wiring contract

- Backend base URL comes from `AppConfig.backendUrl`.
- Proxy authentication comes from `AppConfig.proxySecret` via the
  `X-Proxy-Secret` header.
- Device identity comes from `PreferencesRepository.getDeviceId()` via the
  `X-Device-Id` header.
- Shared Dio timeout configuration currently uses:
  - connect timeout: `15s`
  - send timeout: `60s`
  - receive timeout: `60s`

### Current behavior conventions

- Registration retries with bounded exponential backoff.
- Retry is intentionally scoped to registration only.
- Quota payloads are validated before being surfaced to callers.
- Current backend failure mapping is:
  - `401` -> proxy auth failed
  - `413` -> request too large
  - `429` -> quota exceeded, while still surfacing valid quota data when
    present
  - `502`, `504`, and other `5xx` -> backend unavailable
  - connection errors -> no internet
  - timeout errors -> timeout

### Validation knowledge

- Shared backend validation now includes:
  - `flutter analyze --no-pub`
  - `flutter test`
  - targeted API tests under `test/data/api/`
  - Android emulator integration pass for
    `integration_test/backend_api_client_flow_test.dart`
  - iOS simulator integration pass for
    `integration_test/backend_api_client_flow_test.dart`

### Guidance for future stories

- If the backend contract changes, update `api/wrait-backend.yaml` first and
  regenerate with `npm run build`.
- Keep app-specific policy in the handwritten adapter layer and avoid leaking
  generated package types into unrelated feature code.
- Extend backend failure reasons cautiously; the app-facing surface is
  intentionally narrower than the full transport/OpenAPI error space.

## US-006: Audio Recording Service

### Established recording foundation

- The Flutter app now has a shared recording layer under:
  - `lib/data/audio/audio_recording_service.dart`
  - `lib/data/audio/record_audio_recording_service.dart`
  - `lib/data/audio/audio_recording_providers.dart`
  - `lib/core/time/monotonic_clock.dart`

### Recording contract guidance

- The current recording service contract intentionally stays narrow:
  - `startRecording(outputPath)`
  - `stopRecording()`
  - `isRecording`
  - `hardCapDeadlineElapsedRealtime`
- The service is file-based and currently targets:
  - AAC Low Complexity in an M4A container
  - 16 kHz sample rate
  - mono capture
- The 5-second minimum recording rule is enforced in the service itself:
  - shorter captures throw `RecordingTooShortFailure`
  - too-short output files are deleted before control returns to callers
- Successful recordings return only when the produced file exists and is
  non-empty:
  - unusable or missing output now throws
    `RecordingOutputUnavailableFailure`

### Ownership boundaries worth preserving

- The service owns recorder lifecycle and active-session bookkeeping.
- The service does not own the hard-cap timer:
  - later orchestration should observe
    `hardCapDeadlineElapsedRealtime`
  - the orchestrator should call `stopRecording()` on user stop or cap expiry
- The service does not own successful file cleanup policy:
  - later transcription/draft flows decide whether to delete or retain the
    valid returned file
- The service does own cleanup for invalid or aborted partial output:
  - too-short recordings are deleted
  - dispose during active recording cancels the recorder and deletes the
    partial file

### Failure-handling guidance

- `startRecording()` now validates the caller-supplied output path:
  - blank paths are rejected
  - parent directories are created when needed
  - non-directory parents or unwritable targets fail fast
- Recorder start/stop failures now clean up consistently before rethrowing.
- Temporary-file cleanup remains best-effort, but cleanup failures are now
  logged through `dart:developer` instead of being swallowed silently.

### Testing and validation knowledge

- Deterministic tests should prefer the shared fake monotonic clock:
  - `test/test_doubles/fake_monotonic_clock.dart`
- Current automated coverage for the recording layer lives in:
  - `test/data/audio/audio_recording_service_test.dart`
  - `integration_test/audio_recording_service_flow_test.dart`
- Real recorder validation succeeded on both:
  - Android emulator `emulator-5554`
  - iOS simulator `iPhone 17`
- In this environment, `flutter test --no-pub` was more reliable than a plain
  `flutter test` because the latter tried to refresh generated iOS ephemeral
  package state.

## US-007: Cloud Transcription Service

### Established transcription foundation

- The Flutter app now has an app-facing cloud transcription layer under:
  - `lib/data/transcription/transcription_service.dart`
  - `lib/data/transcription/cloud_transcription_service.dart`
  - `lib/data/transcription/transcription_providers.dart`

### Service contract and flow guidance

- The current cloud transcription contract intentionally stays sequential:
  - `startLiveTranscription(onStatus)`
  - `stopLiveTranscription(onStatus)`
  - `transcribeAudioDraft(audioPath)`
- Live Best-mode transcription currently follows one linear flow:
  - start recording
  - stop a valid recording
  - emit `Uploading`
  - upload the captured file
  - return a narrowed app-facing success or failure result
- The service rejects overlapping live or draft transcription operations.
- `detectedLanguage` is optional at the app-facing boundary:
  - usable transcript text still succeeds when backend language detection is
    blank, unsupported, or otherwise unresolvable
  - future language-aware features should treat `null` as a valid outcome

### Shared-language and quota guidance

- Transcription language normalization should reuse
  `resolveSupportedLanguageCode()` from
  `lib/domain/model/supported_language.dart`.
- If future stories need locale-shape preprocessing, keep it in the same
  supported-language module instead of creating a second normalization path in
  feature code.
- Shared session quota now has one generalized owner:
  - `sessionRecordQuotaStateProvider`
- Later quota-aware stories should update or read that provider rather than
  introducing a second in-memory quota cache for transcription-specific state.
- Valid quota from transcription is surfaced on both success and supported
  failure results, but malformed success payloads rejected by the app should
  not mutate shared quota state.

### Audio-file ownership boundaries

- Live transcription owns its temporary recording file lifecycle:
  - successful live transcription deletes the temp audio immediately after a
    usable transcription result is available
  - failed live transcription preserves the audio path as retryable draft input
- Draft transcription does not own caller-supplied file cleanup:
  - successful draft transcription leaves the original file untouched
  - failed draft transcription also leaves the original file untouched
- Invalid draft files are rejected locally before upload:
  - blank, missing, unreadable, or zero-byte files fail fast with warning logs

### Validation knowledge

- Shared transcription validation now includes:
  - `flutter analyze`
  - `flutter test --no-pub`
  - unit coverage in `test/data/transcription/cloud_transcription_service_test.dart`
  - provider-graph coverage in
    `integration_test/cloud_transcription_service_flow_test.dart`
  - Android emulator pass for
    `integration_test/cloud_transcription_service_flow_test.dart`
  - iOS simulator pass for
    `integration_test/cloud_transcription_service_flow_test.dart`
- Real recorder runtime verification on the Android emulator may require
  explicitly granting microphone permission to the installed app:
  - `adb -s emulator-5554 shell pm grant com.wrait.app android.permission.RECORD_AUDIO`
- In this environment, post-review reruns were more reliable with
  `flutter test --no-pub` because plain `flutter test` attempted iOS ephemeral
  package cleanup before executing the Dart tests.

### Guidance for future stories

- Reuse `TranscriptionService` as the app-facing boundary for Best-mode
  transcription instead of coordinating recorder and backend client calls
  separately in UI code.
- Keep the narrowed app-facing failure surface intentional unless a future
  story explicitly expands it.
- Treat cancellation, retry policy, telemetry, and user-visible quota/cleanup
  UX as separate scope unless a future story explicitly absorbs them.

## US-008: Transcript Cleanup Use Case

### Established cleanup foundation

- The Flutter app now has an app-facing cleanup boundary under:
  - `lib/domain/usecase/cleanup_transcript_use_case.dart`
- Provider wiring for that boundary already exists under:
  - `lib/data/api/backend_providers.dart`

### Cleanup contract and persistence guidance

- `CleanupTranscriptUseCase` should remain the app-facing boundary for
  Best-mode transcript cleanup flows instead of coordinating repository and
  backend cleanup calls directly in UI/controller code.
- Fresh cleanup persists a text draft before the backend request and finalizes
  that same entry only after usable cleaned text is returned.
- Retry cleanup should target an existing draft entry and must fail safely when
  the supplied `entryId` is missing or already finalized.
- The broader Best-mode flow now assumes incremental draft persistence across:
  - recording
  - transcription
  - cleanup
- An entry should remain `isDraft == true` until the full happy path succeeds.

### Backend and repository behavior worth preserving

- Malformed nominal cleanup success with blank `cleanedText` is intentionally
  downgraded in `WraitBackendClient` instead of the use case:
  - valid quota from that malformed response must still survive the downgrade
- Retry-path draft rewrites should use
  `updateDraftTranscriptAndLanguage()`:
  - transcript
  - canonical language
  - word count
  - `audioPath` cleanup
  should update atomically before the backend cleanup call
- Cleanup request truncation is request-only:
  - the submitted transcript is capped at `10000` characters
  - the stored `rawTranscript` remains full-length
- Cleanup uses transcript-associated language when usable and falls back to
  `en-US` only when a supported non-null language is required.
- Repository load, draft-persistence, and finalization problems should surface
  as typed cleanup failures instead of leaking exceptions into higher layers.

### Testing and validation knowledge

- Cleanup use-case coverage now lives in:
  - `test/domain/usecase/cleanup_transcript_use_case_test.dart`
  - `integration_test/cleanup_transcript_use_case_flow_test.dart`
- Repository regression coverage for atomic retry-path updates lives in:
  - `test/data/entries/entry_repository_impl_test.dart`
- Full emulator validation that has already succeeded for this story includes:
  - Android emulator `emulator-5554`:
    - `flutter test --no-pub -d emulator-5554`
    - `flutter test --no-pub -d emulator-5554 integration_test`
  - iOS simulator `491CD949-D3C0-4C4C-A6B9-15BAB1859156`:
    - `flutter test --no-pub -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156`
    - `flutter test --no-pub -d 491CD949-D3C0-4C4C-A6B9-15BAB1859156 integration_test`
- Integration tests that rely on the real local entry database are more stable
  when each test harness uses an isolated temporary database path instead of
  the default persistent app database location.

## US-004: Preferences Storage

### Established preferences foundation

- The app now has a shared preferences layer under:
  - `lib/data/preferences/`
  - `lib/domain/repository/preferences_repository.dart`
- App startup now injects `SharedPreferences` once in:
  - `lib/main.dart`
- Riverpod access already exists and should be reused:
  - `sharedPreferencesProvider`
  - `platformDeviceIdProvider`
  - `preferencesRepositoryProvider`

### Preferences contract worth preserving

- `PreferencesRepository` currently owns two persisted concerns:
  - `hasEverRecorded`
  - `deviceId`
- `hasEverRecorded` defaults to `false` when unset.
- Failed writes are treated as hard failures inside the repository:
  - `setHasEverRecorded()` throws when persistence reports `false`
  - `getDeviceId()` throws when persisting the resolved ID reports `false`

### Device ID behavior worth preserving

- The rest of the app should treat `getDeviceId()` as returning one opaque
  stable app identifier.
- Feature code should not know or care whether that value came from the
  platform or from generated fallback.
- Current resolution order is:
  - in-memory cached value
  - stored `app_device_id` from shared preferences
  - platform-provided device ID
  - generated fallback ID
- Newly resolved values from either the platform path or generated fallback are
  normalized into a backend-compatible 64-character lowercase SHA-256 hex
  string with the app-scoped salt `wrait-v1` before first persistence.
- Preexisting stored values are intentionally returned unchanged, even if they
  predate the backend-compatible format; US-016 explicitly chose not to
  migrate legacy stored IDs.
- The first non-empty resolved value is persisted and then reused on later
  launches.

### Platform bridge guidance

- Android currently supplies the platform value from
  `Settings.Secure.ANDROID_ID` in
  `android/app/src/main/kotlin/com/wrait/app/MainActivity.kt`.
- iOS currently supplies the platform value from
  `UIDevice.current.identifierForVendor?.uuidString` in
  `ios/Runner/AppDelegate.swift`.
- The Flutter-side bridge is intentionally best-effort:
  - `PlatformException` returns `null`
  - `MissingPluginException` returns `null`
- Non-recoverable platform lookup failures should degrade to fallback
  generation instead of interrupting the user.

### Testing guidance

- `PreferencesStore` exists as a seam for deterministic repository tests and
  write-failure coverage.
- Future preference work should preserve test coverage for:
  - unset defaults
  - persistence across repository recreation
  - write-failure behavior
  - stored-value precedence over platform lookup
  - generated fallback reuse after persistence
  - source opacity of `getDeviceId()`

### Validation and caveats

- Validation that has already succeeded:
  - `flutter analyze`
  - `flutter test`
  - `flutter build apk --debug`
  - `flutter build ios --simulator --debug --no-codesign`
- Native builds verified the bridge compiles on both platforms, but live
  device/simulator retrieval of the actual platform IDs was not exercised in
  this environment.
- `SharedPreferences.getInstance()` is still part of app bootstrap in
  `lib/main.dart`; if that call starts failing in the future, the app will fail
  before `runApp`.

### Guidance for future stories

- Reuse the existing `EntryRepository` contract instead of adding parallel local
  persistence entry paths.
- Do not assume `getDeviceId()` returns a raw platform identifier; treat it as
  an opaque app-scoped identifier that may already be hashed.

## US-016: Device Registration

### Established launch registration foundation

- App launch now triggers device registration from the bootstrapped
  `ProviderContainer` in:
  - `lib/main.dart`
- The launch orchestration now lives in:
  - `lib/domain/usecase/register_device_on_launch_use_case.dart`
- Shared backend/session registration state now lives in:
  - `lib/data/api/backend_providers.dart`
  - `sessionRecordQuotaStateProvider`
  - `registerDeviceOnLaunchUseCaseProvider`

### Launch behavior worth preserving

- Registration is intentionally non-blocking:
  - startup triggers the work once per app launch
  - initial UI rendering does not wait for the backend response
- Registration continues to use `WraitBackendClient.register()` as the only
  network path, so retry policy stays centralized in the backend client.
- Successful registration updates session quota only when valid quota data is
  present.
- Successful registration without quota is silent and preserves the current
  in-memory quota value.
- Registration failure is logging-only in this story and does not surface a
  user-visible error.

### Quota-state guidance

- Registration quota is session-scoped only:
  - it is stored in memory
  - it does not persist across app relaunches
- Later quota-aware stories should read the shared backend-provider quota state
  instead of caching launch results independently or adding a second quota
  owner.

### Validation knowledge

- Shared launch-registration validation now includes:
  - `flutter analyze --no-pub`
  - targeted unit tests in `test/data/api/register_device_on_launch_use_case_test.dart`
  - updated preferences tests in
    `test/data/preferences/preferences_repository_impl_test.dart`
  - integration coverage in
    `integration_test/device_registration_launch_flow_test.dart`
  - Android emulator pass for the launch-registration integration test
  - iOS simulator pass for the launch-registration integration test

### Guidance for future stories

- Start app-wide launch side effects from the bootstrapped
  `ProviderContainer` in `main.dart` rather than from route builders or
  placeholder widgets.
- Reuse the existing launch registration use case/provider path instead of
  adding a second registration trigger in UI code.
- If a future story needs legacy stored device-ID migration, treat that as
  explicit new scope; US-016 intentionally left legacy values untouched.
- Keep user-visible registration messaging separate from launch orchestration
  unless a future story explicitly expands the scope beyond logging-only
  failure handling.

## US-009: Recording State Machine and Controller

### Established recording-controller foundation

- The app-facing recording state boundary now lives under:
  - `lib/presentation/main/recording_state.dart`
  - `lib/presentation/main/main_recording_controller.dart`
- The main controller is exposed through:
  - `mainRecordingControllerProvider`
  - `RecordingControllerState`
  - `RecordingState`
  - `RecordingError`

### Controller behavior worth preserving

- `RecordingControllerState.isActive` is intentionally true only for:
  - `Listening`
  - `Uploading`
  - `Processing`
- `RecordingSaved` requires a positive `entryId`.
- Cleanup results with a missing or non-positive `entryId` must degrade to
  `RecordingError.apiFailed`; they must not publish `Saved` and must not set
  `hasEverRecorded`.
- Error and Deleted auto-clear timers belong to the controller.
- Saved clearing is intentionally UI-owned through `clearSaved()` or a new
  recording start; the controller does not run a Saved timer.
- `_buttonActionInFlight` is an important guard against rapid repeated taps
  while start/stop work is still in flight.
- Timer cancellation on new transitions is required so stale Error/Deleted
  timers cannot reset a newer state.

### Retryable draft guidance

- Retryable audio-draft persistence now validates that the trimmed
  `audioDraftPath` points to an existing file before saving a draft record.
- Invalid or missing retryable audio paths should be logged and ignored
  without masking the original transcription failure.
- Integration or controller tests that validate audio-draft persistence should
  create a real temp audio file; nonexistent paths are intentionally ignored by
  the controller.

### Validation knowledge

- Shared controller validation now includes:
  - `flutter analyze`
  - `flutter test`
  - unit coverage in
    `test/presentation/main/main_recording_controller_test.dart`
  - integration coverage in
    `integration_test/main_recording_controller_flow_test.dart`
  - Android emulator pass for the main-recording-controller integration flow
  - iOS simulator pass for the main-recording-controller integration flow

### Guidance for future stories

- Build main-screen recording UI on top of
  `mainRecordingControllerProvider` rather than recreating recording state in
  widgets.
- Reuse the existing controller failure mapping unless a future story
  explicitly changes the product contract.
- Keep retryable draft preservation and `hasEverRecorded` updates inside the
  controller/orchestration layer instead of scattering them across UI code.
- Reuse `resolveSupportedLanguageCode()` from
  `lib/domain/model/supported_language.dart` anywhere a persisted or
  user-selected language must be canonicalized.
- Keep encrypted database bootstrap explicit through
  `bootstrapLocalEntryDatabase()` rather than creating ad hoc provider
  containers.
- If a future story changes the SQLite runtime or iOS dependency surface,
  revalidate both encrypted-store startup and the iOS SPM-only build path.

## US-013: Entry List Screen

### Established entry-list surface

- The `/entries` route now renders the real entry-list screen through:
  - `lib/presentation/entries/entry_list_screen.dart`
- Reusable entry-list presentation pieces now live under:
  - `lib/presentation/entries/entry_list_row.dart`
  - `lib/presentation/entries/entry_list_controller.dart`
  - `lib/presentation/entries/entry_list_formatters.dart`

### Entry-list behavior worth preserving

- The `/entries` screen is repository-backed and includes both finalized and
  draft entries.
- Entry-list ordering is newest first by `createdAt`.
- Draft rows are visibly marked with `draft`.
- Language labels are intentionally always visible on every row.
- Row previews prefer cleaned text, then fall back to raw transcript.
- Audio-only drafts remain visible on the list as `pending · will retry`.
- Audio-only draft rows do not navigate to `/entry/:id` on tap.
- Row swipe-to-delete is intentionally scoped to a right-swipe reveal with an
  80dp red affordance, followed immediately by the confirmation dialog.
- Cancel and Delete both close the revealed row state.
- Confirmed deletion removes the row reactively while keeping the user on
  `/entries`.

### Architecture guidance

- Keep entry ordering in the presentation/controller layer instead of moving
  newest-first sorting into the repository contract.
- Keep row preview, localized timestamp, and language-label derivation in
  `entry_list_formatters.dart` so display rules stay unit-testable.
- Delete failures should remain non-destructive in the UI: log them from the
  controller and leave the row visible rather than showing a false optimistic
  removal state.
- Guard each row reveal/delete flow against duplicate in-flight triggers so
  repeated gestures or semantics actions cannot start multiple delete flows.

### Accessibility and localization guidance

- Preserve the row-level custom semantics delete action so assistive
  technologies can invoke deletion without performing the swipe gesture.
- Preserve explicit semantics labels and hints on the delete-confirmation
  dialog actions so destructive and cancel actions stay clearly distinguishable.
- Flutter localization delegates plus the direct `intl` dependency are now
  part of the app surface for entry-list weekday/date/time formatting.
- Timestamp formatting should keep its locale fallback path so unsupported
  locale inputs still render usable labels.

### Validation knowledge

- Shared US-013 validation includes:
  - `flutter analyze`
  - `flutter test`
  - widget coverage in:
    - `test/presentation/entries/entry_list_row_test.dart`
    - `test/presentation/entries/entry_list_screen_test.dart`
  - unit/provider coverage in:
    - `test/presentation/entries/entry_list_controller_test.dart`
    - `test/presentation/entries/entry_list_formatters_test.dart`
  - integration coverage in:
    - `integration_test/entry_list_flow_test.dart`
    - `integration_test/main_screen_flow_test.dart`
  - Android emulator pass for the entry-list integration flows
  - iOS simulator pass for the entry-list integration flows

### Guidance for future stories

- Prefer row-level widget coverage for swipe/reveal behavior instead of trying
  to prove every gesture detail only through the parent `ListView`.
- Keep integration coverage on both Android and iOS for real `/entries`
  navigation and delete flows.
- If a future story expands entry detail, editing, or bulk management, treat
  audio-only drafts as a distinct state instead of assuming every listed entry
  is immediately readable.

## US-014: Entry Detail Screen

### Established entry-detail surface

- The `/entry/:id` route now renders the real entry-detail screen through:
  - `lib/presentation/entries/entry_detail_screen.dart`
- Entry-detail presentation and orchestration now live under:
  - `lib/presentation/entries/entry_detail_controller.dart`
  - `lib/presentation/entries/entry_detail_formatters.dart`
  - `lib/presentation/entries/entry_share_service.dart`
- Shared entry-deletion behavior now lives under:
  - `lib/presentation/entries/entry_delete_confirmation.dart`
  - `lib/presentation/entries/entry_deletion_controller.dart`

### Entry-detail behavior worth preserving

- `/entry/:id` accepts only positive integer ids. Invalid ids redirect to
  `/entries`.
- Missing, deleted, and unreadable entries redirect to `/entries` instead of
  rendering a fallback detail shell.
- Readable detail text prefers `cleanedText` and falls back to
  `rawTranscript`.
- Entry edits update `cleanedText` and `wordCount` only. They do not mutate
  `rawTranscript`.
- Back navigation flushes the latest pending edit before returning to
  `/entries`.
- Entry list previews react to edited `cleanedText` because previews already
  prefer cleaned text.
- Entry detail and entry list intentionally reuse the same delete
  confirmation copy, semantics, and non-destructive failure handling.

### Architecture guidance

- Keep entry-detail persistence orchestration in
  `EntryDetailController` rather than pushing edit timing into widgets.
- The current auto-save path is revision-based and single-flight. Preserve that
  shape if future stories expand editing; it avoids stale completion races and
  keeps save draining finite.
- Keep route-id parsing shared between router redirect and builder logic so a
  validation change in one place does not reopen a runtime parse crash in the
  other.
- Programmatic editor sync should suspend the text-controller listener during
  controller writes instead of relying on a mutable boolean guard.
- Share-service injection already works through provider overrides. Do not add
  bootstrap complexity in `lib/main.dart` unless a future story actually needs
  a broader runtime seam.

### Accessibility and validation guidance

- Preserve explicit semantics labels for back, edit, share, delete, delete
  confirmation actions, and the multiline editor.
- Screenshot-heavy integration coverage works well on emulator and simulator,
  but physical Android verification is more stable with a screenshot-free smoke
  test:
  - `integration_test/entry_detail_device_smoke_test.dart`
- Keep Android/iOS integration coverage for the real `/entry/:id` route, and
  use the device smoke path when physical-device timing makes screenshot flows
  unreliable.

## Cross-cutting: iOS Swift Package Manager Cleanup

### Current iOS dependency state

- The checked-in iOS project is now Swift Package Manager only for the current
  Flutter plugin set.
- CocoaPods entry points and Pod-era Xcode wiring have been removed:
  - no checked-in `ios/Podfile`
  - no checked-in `ios/Podfile.lock`
  - no `Pods/Pods.xcodeproj` workspace reference
  - no Pod-only `[CP]` shell phases in `Runner.xcodeproj`

### Guidance for future stories

- Treat reintroducing CocoaPods as an architectural change, not a casual plugin
  add.
- If a future Flutter plugin requires Pods, capture that in a new story and
  validate the iOS project wiring deliberately instead of mixing Pod changes
  into unrelated feature work.
