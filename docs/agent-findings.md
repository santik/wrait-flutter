# Agent Findings

This file is the compact, active guidance index for future coding sessions.
Keep it focused on durable implementation constraints that should affect new
work.

When a detail here conflicts with `AGENTS.md`, `CONSTITUTION.md`, or an
approved story artifact, treat the formal workflow artifact as the gate and use
this file as supporting implementation memory.

## Startup, Bootstrap, and App Lock

- Keep startup non-blocking: `runApp()` should happen before heavier launch
  initialization, and bootstrap loading/retry UI stays owned by `lib/main.dart`.
- Preserve single-flight bootstrap retry behavior. Retry actions must not
  create overlapping launch work.
- Start app-wide launch side effects from the bootstrapped `ProviderContainer`
  in `main.dart`, not route builders or widgets.
- Backend device registration is non-blocking and launch-scoped. Failures are
  logging-only unless a future story explicitly changes the user-visible
  contract.
- Draft retry runs only after successful launch registration, and it waits for
  a future app launch if registration fails and later recovers in-session.
- Keep app lock at the root through `AppLockGate` in `lib/app.dart`; do not add
  screen-specific privacy locks for ordinary sensitive routes.
- Do not relock on `AppLifecycleState.inactive`. Native biometric UI can emit
  transient inactive transitions and trigger prompt restart loops.
- App-lock auth and device-security settings opening are single-flight and
  timeout/retry aware. Preserve those guards when touching lock flow code.

## Capture Privacy

- Android capture protection lives in
  `android/app/src/main/kotlin/com/wrait/flutter/MainActivity.kt` through
  `FLAG_SECURE`.
- Keep `FLAG_SECURE` applied before `super.onCreate(...)` and reasserted after
  `super.onCreate(...)`, on resume, and on focus return unless a future story
  revalidates a simpler lifecycle.
- Android app-lock production wiring depends on `MainActivity` remaining a
  `FlutterFragmentActivity`, `android.permission.USE_BIOMETRIC`, and
  AppCompat-compatible launch/normal theme parents.
- iOS capture privacy lives in `ios/Runner/SceneDelegate.swift` as a native
  scene-level cover. Keep privacy changes at that scene boundary by default.
- The iOS privacy cover copy should stay generic and non-sensitive. Current
  validated copy is `Private`.
- For Android capture work, prefer evidence from cold start, `dumpsys window`
  secure-flag inspection, black foreground/recents screenshots, and a decoded
  frame from `screenrecord`.
- For iOS simulator validation, `xcrun simctl io booted recordVideo` did not
  toggle `UIScreen.main.isCaptured` in this environment. Use SplashBoard
  snapshot inspection for app-switch/background cover validation when direct
  app-switcher automation is unavailable.

## Android Identities and Deployment

- Release/update Android package ID: `com.wrait.flutter`.
- Debug/profile Android package ID: `com.wrait.flutter.dev`.
- Historical or external notes may mention `com.wrait.app`; verify actual
  installed package names before debugging, uninstalling, or scraping logs.
- Production backend connectivity on Android depends on
  `android.permission.INTERNET` in
  `android/app/src/main/AndroidManifest.xml`.
- The Android manifest intentionally disables Impeller with
  `io.flutter.embedding.android.EnableImpeller=false` because physical-device
  cold launches could hang behind the splash screen while Vulkan/Impeller was
  active.
- Prefer `./deploy_debug.sh` for real-device Android debug deployment when a
  story depends on backend registration, transcription, or proxy-authenticated
  traffic.
- `./deploy_debug.sh` requires exactly one connected physical Android phone,
  ignores emulators, runs `flutter test --no-pub -d <phone> integration_test`,
  then installs the profile APK as the final deployed debug/profile artifact.
- Set `PROXY_SECRET` before running `./deploy_debug.sh`; the app must send the
  backend `X-Proxy-Secret` header from runtime config.
- The debug deploy script temporarily enables the namespaced global setting
  `com.wrait.flutter.debug.automation_lockscreen_mode` and USB stay-awake, then
  restores both on success and failure.
- The debug deploy script must never uninstall `com.wrait.app`; it should also
  preserve any pre-existing release install.
- Prefer `./deploy_release.sh` for physical-phone release deployment when the
  stable release identity or update-compatible installs matter.
- Canonical private release config lives in `wrait-android/local.properties`;
  only non-secret release keys should be synchronized to
  `android/local.properties`.
- Release signing passwords stay transient in
  `WRAIT_RELEASE_KEYSTORE_PASSWORD` and `WRAIT_RELEASE_KEY_PASSWORD`.
- `./deploy_release.sh` should validate the configured keystore with `keytool`
  before building and must preserve pre-existing debug/profile installs.

## Data, Drafts, and Persistence

- The encrypted local entry store uses Drift plus the `sqlite3mc` runtime
  selected through `hooks.user_defines.sqlite3.source: sqlite3mc`.
- Database open must verify cipher availability with `PRAGMA cipher;` and fail
  startup explicitly if encryption support is missing.
- Keep database opening behind the first-frame bootstrap shell. Do not move it
  back to a fully blocking pre-UI startup path without an approved story.
- `LocalEntryDatabase.open()` should fail closed on corruption or open errors
  and leave database artifacts untouched.
- `deleteDatabaseArtifacts()` is destructive and should stay reserved for
  explicit reset flows, not automatic bootstrap recovery.
- Same-identity Android and iOS app updates should preserve the encrypted
  database and linked app-private retained files.
- Uninstall/reinstall and Android `pm clear` should start from fresh local
  state. Android backup/restore is intentionally disabled for this lifecycle.
- Retryable draft audio paths should be stored as
  `app-cache://<relative-path>` under the current app temporary directory, not
  absolute iOS container paths.
- Do not reintroduce basename fallback or legacy absolute-path recovery for
  retained draft audio. Unsafe references should fail explicitly.
- Stale drafts older than seven days are deleted before pending drafts are
  loaded for retry.
- Pending drafts retry newest-first, and one failed draft must not block later
  drafts in the same launch pass.
- Audio drafts with blank, missing, unreadable, or empty retained files should
  be deleted instead of retried indefinitely.
- Audio transcription failure preserves the audio draft and retained file.
- Audio transcription success followed by cleanup failure should preserve a
  text draft at the same entry id and delete no-longer-needed retained audio.

## Backend and Generation

- Backend contract source of truth: `api/wrait-backend.yaml`.
- If that file changes, run `npm run build` before `flutter pub get`,
  `flutter analyze`, or `flutter test`.
- Generated backend output lives under
  `tool/openapi-generator/output/backend_api/` and is local build output, not
  committed source.
- App code should depend on
  `lib/data/api/generated/backend_api_generated.dart`, the compatibility bridge
  over the generated package.
- Backend base URL comes from `AppConfig.backendUrl`.
- Proxy authentication comes from `AppConfig.proxySecret` through
  `X-Proxy-Secret`.
- Device identity comes from `PreferencesRepository.getDeviceId()` through
  `X-Device-Id`.
- Keep app-specific backend policy in the handwritten adapter layer; do not
  leak generated package types into feature code.
- Current app-facing backend failures are intentionally narrower than transport
  errors: proxy auth failed, request too large, quota exceeded, backend
  unavailable, no internet, timeout, and generic API error.
- Shared session quota has one owner: `sessionRecordQuotaStateProvider`.
  Quota-aware work should update or read that provider instead of adding a
  parallel cache.

## Recording, Transcription, and Cleanup

- Recording service contract stays narrow: `startRecording(outputPath)`,
  `stopRecording()`, `isRecording`, and `hardCapDeadlineElapsedRealtime`.
- Recording output is file-based AAC Low Complexity in an M4A container,
  16 kHz, mono.
- The 5-second minimum recording rule is enforced in the service, and too-short
  output files are deleted before returning control to callers.
- The service owns recorder lifecycle, active-session bookkeeping, and cleanup
  of invalid or aborted partial output.
- The controller/orchestrator owns hard-cap stopping and successful returned
  file cleanup policy.
- When microphone access disappears while listening, use cancel semantics
  instead of normal stop/upload so revoked audio is not uploaded or saved.
- `CloudTranscriptionService` is the app-facing Best-mode transcription
  boundary. UI should not coordinate recorder and backend calls directly.
- Live transcription is sequential: start recording, stop valid recording,
  upload, then return a narrowed app-facing success or failure.
- The transcription service rejects overlapping live or draft operations.
- `detectedLanguage` is optional. A usable transcript can succeed when backend
  language detection is blank or unsupported.
- Language normalization should reuse `resolveSupportedLanguageCode()` from
  `lib/domain/model/supported_language.dart`.
- `CleanupTranscriptUseCase` is the app-facing Best-mode cleanup boundary.
- Fresh cleanup persists a text draft before the backend request and finalizes
  that same entry only after usable cleaned text is returned.
- Retry cleanup targets an existing draft entry and must fail safely if the
  entry is missing or already finalized.
- Cleanup request truncation is request-only: submit at most 10,000 characters
  while preserving the full stored `rawTranscript`.

## Preferences and Device ID

- Shared preferences are injected once during app bootstrap in `lib/main.dart`.
- Reuse `sharedPreferencesProvider`, `platformDeviceIdProvider`, and
  `preferencesRepositoryProvider`.
- `PreferencesRepository` owns `hasEverRecorded` and `deviceId`.
- Failed writes are hard failures inside the repository.
- Treat `getDeviceId()` as returning one opaque stable app identifier. Feature
  code should not care whether it came from the platform or generated fallback.
- Current resolution order is in-memory cache, stored `app_device_id`,
  platform-provided device ID, then generated fallback ID.
- Newly resolved device IDs are normalized to 64-character lowercase SHA-256
  hex using the app-scoped salt `wrait-v1` before first persistence.
- Preexisting stored values are intentionally returned unchanged; legacy
  migration is explicit future scope.

## Main Screen and Entry UI

- The root `/` route renders the recording-focused main screen under
  `lib/presentation/main/`.
- Build recording UI on `mainRecordingControllerProvider` rather than
  recreating state in widgets.
- `RecordingControllerState.isActive` is true only for Listening, Uploading,
  and Processing.
- `RecordingSaved` requires a positive `entryId`; invalid cleanup results must
  degrade to `RecordingError.apiFailed` and must not set `hasEverRecorded`.
- Error and Deleted auto-clear timers belong to the controller. Saved feedback
  is UI-owned and clears through `clearSaved()` or a new recording start.
- Preserve `_buttonActionInFlight` style guarding against rapid repeated taps
  while start/stop work is in flight.
- Status copy and status tap behavior are centralized in
  `lib/presentation/main/main_screen_status.dart`.
- Entry-stat derivation is centralized in
  `lib/presentation/main/main_screen_stats.dart`.
- Countdown progress is localized through a `ValueNotifier<double?>` and
  `ValueListenableBuilder`; avoid whole-screen ticking rebuilds.
- Use stable main-screen selectors from
  `lib/presentation/main/main_screen_test_keys.dart` in widget and integration
  tests wherever practical.
- The `/entries` route includes finalized and draft entries, ordered newest
  first in the presentation/controller layer.
- Audio-only draft rows remain visible as pending retry state and should not
  navigate to `/entry/:id`.
- Keep row preview, timestamp, and language-label derivation in
  `entry_list_formatters.dart`.
- Delete failures should remain non-destructive in list/detail UI: log and
  leave visible state intact instead of showing false optimistic removal.
- The `/entry/:id` route accepts only positive integer IDs; invalid, missing,
  deleted, or unreadable entries redirect to `/entries`.
- Entry edits update `cleanedText` and `wordCount` only. They do not mutate
  `rawTranscript`.
- Entry-detail auto-save is revision-based and single-flight. Preserve that
  shape when expanding editing.

## Testing and Validation Gotchas

- Tests that pump `WraitApp` but are not specifically about app lock should
  override `appLockEnabledProvider` to `false`.
- Use `dart format` for Dart/Flutter formatting. `flutter format` is not the
  correct formatter command in this toolchain.
- For Android startup or rendering work, verify launcher-style cold start with
  `adb shell am start -W -n com.wrait.flutter/com.wrait.flutter.MainActivity`
  in addition to ordinary `flutter run` checks.
- For update-versus-uninstall persistence, prefer explicit install/update flows
  or `flutter drive --keep-app-running`; `flutter test -d ... integration_test`
  can reinstall or reset app state.
- `./deploy_debug.sh` is not a reliable validator for same-identity
  update-preservation behavior on `com.wrait.flutter`.
- For local-data lifecycle work, validate same-identity update preservation and
  uninstall/fresh-state behavior as separate flows.
- For dependency refreshes, validate generated backend package compatibility
  with at least `flutter pub get` and `flutter analyze` under
  `tool/openapi-generator/output/backend_api`.
- Current dependency exceptions:
  - `record` is pinned to `7.0.0`; `7.1.0` pulled `record_android 2.1.2`,
    which failed Android Kotlin compilation with unresolved `AdtsContainer`
    references.
  - `drift_dev` stays on `2.34.0`; `2.34.1+1` requires `analyzer ^13.0.0`,
    conflicting with the Flutter `3.44.3` test/analyzer family.
- Android emulator recording validation has a known split:
  `integration_test/main_recording_controller_flow_test.dart` passes on
  `emulator-5554`, while
  `integration_test/audio_recording_service_flow_test.dart` can stall on a
  provider-graph start/stop case and report `did not complete`.
- Screenshot-heavy integration coverage works well on emulator/simulator, but
  physical Android verification may need screenshot-free smoke tests for
  timing-sensitive entry detail flows.
- Direct emulator bring-up is often more reliable than `flutter emulators`:
  `/Users/alexander/Library/Android/sdk/emulator/emulator -avd Pixel_8_emulator -no-snapshot-load`.
