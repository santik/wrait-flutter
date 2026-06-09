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

### Guidance for future stories

- Reuse the existing `EntryRepository` contract instead of adding parallel local
  storage paths.
- Reuse `resolveSupportedLanguageCode()` from
  `lib/domain/model/supported_language.dart` anywhere a persisted or
  user-selected language must be canonicalized.
- Keep encrypted database bootstrap explicit through
  `bootstrapLocalEntryDatabase()` rather than creating ad hoc provider
  containers.
- If a future story changes the SQLite runtime or iOS dependency surface,
  revalidate both encrypted-store startup and the iOS SPM-only build path.

## US-004: iOS Swift Package Manager Cleanup

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
