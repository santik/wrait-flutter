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

At the moment, the Flutter app includes the shared project foundation, the core
visual shell, and the first encrypted local persistence layer needed for
upcoming feature work:

- app bootstrap
- routing shell
- runtime configuration loading
- centralized light/dark theme and design tokens
- encrypted local entry database bootstrap
- encrypted local entry persistence and stale-draft cleanup
- shared preferences bootstrap
- persisted recording-state preference
- persisted stable app device identifier with native lookup/fallback
  resolution and backend-compatible anonymous hashing for newly resolved IDs
- centralized backend API client for device registration, audio transcription,
  and transcript cleanup
- OpenAPI-driven backend contract consumption from `api/wrait-backend.yaml`
- backend request wiring through runtime config plus persisted device identity
- non-blocking launch-time backend device registration
- session-only quota state populated from successful backend registration
- explicit backend failure categories for timeout, no internet,
  request-too-large, quota-exceeded, proxy-auth failure,
  backend-unavailable, and generic API error
- placeholder shell routes for `/`, `/entries`, and `/entry/:id`
- platform setup for Android and iOS
- placeholder screens used to validate launch, theming, and route coverage

Feature behavior such as real recording UI, full transcription/cleanup
orchestration, quota presentation beyond the current session state,
preferences persistence beyond the current basic flags and identifiers, and
entry-management UI still belongs to later user stories.

## Important product themes

- Voice-first capture
- Cross-platform mobile support on Android and iOS
- Privacy-aware handling of sensitive journal content
- Secure local storage
- Support for both backend-assisted and offline-oriented flows

## Key planned technical capabilities

Planned future stories cover:

- expanded preferences and settings
- audio recording services
- transcription and cleanup flows
- entry browsing and detail screens
- privacy mode and offline behavior

## Backend integration note

The backend client is generated at build time from the checked-in OpenAPI
contract.

- Source of truth: `api/wrait-backend.yaml`
- Build/bootstrap command: `npm run build`
- Generated package output: `tool/openapi-generator/output/backend_api/`
- App-facing compatibility bridge:
  `lib/data/api/generated/backend_api_generated.dart`

Current runtime behavior on top of that generated client:

- app launch triggers backend device registration without blocking initial UI
  rendering
- successful registration can seed the current in-memory quota state for later
  quota-aware flows in the same app session

## Reference

For the current story breakdown and broader functionality roadmap, see:

- `plan/functionality.md`
- `plan/us_001.md` through `plan/us_026.md`
