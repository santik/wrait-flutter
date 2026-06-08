# Application Description

Wrait is a mobile journaling application centered around voice-first diary
entry creation.

## Product summary

The user records a spoken entry, the app converts that recording into text, and
the result is stored as a diary entry. The product is designed to support both
cloud-backed and offline-oriented behaviors, with strong attention to privacy,
local data protection, and a simple interaction model.

## Primary experience

The core user flow is:

1. Open the app.
2. Start a voice recording.
3. Let the app transcribe the recording.
4. Optionally clean up the transcript.
5. Save and review the resulting entry.

The early product roadmap prioritizes the "best mode" cloud-backed recording
and transcription flow first, then offline capabilities, and then polish work.

## Current implementation scope

At the moment, the Flutter app includes only the shared project foundation:

- app bootstrap
- routing shell
- runtime configuration loading
- platform setup for Android and iOS
- a placeholder screen used to validate launch and config visibility

Feature behavior such as real recording, transcription, local database storage,
preferences persistence, and entry management belongs to later user stories.

## Important product themes

- Voice-first capture
- Cross-platform mobile support on Android and iOS
- Privacy-aware handling of sensitive journal content
- Secure local storage
- Support for both backend-assisted and offline-oriented flows

## Key planned technical capabilities

Planned future stories cover:

- theme and design tokens
- encrypted local database storage
- persisted user preferences
- backend API integration
- audio recording services
- transcription and cleanup flows
- entry browsing and detail screens
- privacy mode and offline behavior

## Reference

For the current story breakdown and broader functionality roadmap, see:

- `plan/functionality.md`
- `plan/us_001.md` through `plan/us_026.md`
