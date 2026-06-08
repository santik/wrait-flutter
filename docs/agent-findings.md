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

### iOS integration caveat

Flutter 3.44 generated a Swift Package Manager-first iOS project, but
`sqflite_sqlcipher` still requires CocoaPods.

Important implications:

- Keep the root `ios/Podfile`.
- Be careful changing Podfile structure casually.
- The working Podfile is intentionally simple and avoids extra configuration
  mapping.

Specific issue encountered:

- CocoaPods `1.16.2` crashed against a more complex Podfile shape.
- The stable workaround was to remove explicit Xcode configuration mapping and
  test-target nesting from `ios/Podfile`.

### Dependency warnings worth tracking

The current project builds and runs, but these warnings appeared during setup:

- `sqflite_sqlcipher` does not support Swift Package Manager.
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
- Treat iOS dependency changes carefully because CocoaPods and plugin
  compatibility are the most fragile part of the current setup.
