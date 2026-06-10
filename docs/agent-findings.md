# Agent Findings

This document captures implementation findings from completed stories that are
worth keeping in mind during future feature work.

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

- Package/application ID: `com.wrait.app`
- `minSdk = 26`
- `RECORD_AUDIO` permission is already declared

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
- App startup now bootstraps the local database before `runApp` in:
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

### Validation knowledge

- Shared persistence validation now includes:
  - `flutter analyze`
  - `flutter test`
  - targeted entry-store tests under `test/data/entries/`
- Native validation that has already succeeded:
  - Android debug build: `flutter build apk --debug`
  - iOS simulator debug build: `flutter build ios --simulator --debug --no-codesign`

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
  - `registrationQuotaStateProvider`
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
  storage paths.
- Reuse `resolveSupportedLanguageCode()` from
  `lib/domain/model/supported_language.dart` anywhere a persisted or
  user-selected language must be canonicalized.
- Keep encrypted database bootstrap explicit through
  `bootstrapLocalEntryDatabase()` rather than creating ad hoc provider
  containers.
- If a future story changes the SQLite runtime or iOS dependency surface,
  revalidate both encrypted-store startup and the iOS SPM-only build path.

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
