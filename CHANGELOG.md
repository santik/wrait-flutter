# Changelog

All notable changes to wrait are documented here.

## [1.0.0] - 2026-07-13

Initial public Flutter client release preparation.

### Added

- Flutter Android and iOS client foundation.
- One-button cloud-backed voice diary recording flow.
- Backend device registration, audio transcription, and transcript cleanup
  through the OpenAPI-generated backend client.
- Encrypted local entry database using `wrait_entries_v2.sqlite`.
- Retryable local draft handling for interrupted transcription and cleanup.
- Entry list and entry detail screens.
- Entry editing, sharing, and deletion.
- Manual CSV export and import from the entries screen.
- App-wide privacy lock using platform device authentication.
- Android screenshot, screen recording, and recent-app protection.
- iOS background and app-switch privacy cover.
- Android release/debug package split:
  - release: `com.wrait.flutter`
  - debug/profile: `com.wrait.flutter.dev`
- iOS app target with bundle ID `com.wrait.app`.
- Android debug and release deployment scripts.
- OpenAPI backend generation workflow via `npm run build`.

### Changed

- Replaced the old Android-only public documentation with Flutter-specific
  README, privacy policy, tester guide, changelog, and development notes.
- Moved developer deployment guidance out of the root README and into
  `docs/development.md`.

### Known limitations

- The Flutter client currently has no offline transcription mode.
- There is no account, sync, cloud backup, or search.
- CSV import tests validate app-side behavior but do not automate the native
  platform document picker UI.
- iOS active capture-hiding needs stronger physical-device validation; current
  simulator validation covers background and app-switch snapshot protection.
