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
- immediate first-frame bootstrap shell with loading and retry states while
  launch dependencies finish asynchronously
- Android manifest-level Impeller disablement for reliable real-device cold
  launch instead of hanging behind the splash screen on the current validation
  phone
- routing shell
- runtime configuration loading
- centralized light/dark theme and design tokens
- encrypted local entry database bootstrap through the app startup flow rather
  than a fully blocking pre-UI initialization step
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
- session-only quota state populated from successful backend registration and
  refreshed by valid transcription responses in the same app session
- app-facing transcript cleanup use case for Best-mode flows, including fresh
  draft creation before cleanup, retry against existing text drafts, typed
  cleanup failures for invalid retry targets, and draft finalization only on
  usable cleanup success
- incremental Best-mode draft persistence across recording, transcription, and
  cleanup so partially completed work remains retryable until the full happy
  path succeeds
- cleanup request truncation to 10,000 characters while preserving the full
  stored raw transcript, transcript-language reuse with `en-US` fallback only
  when required, and session quota refresh from valid cleanup responses on
  success or supported failure
- explicit backend failure categories for timeout, no internet,
  request-too-large, quota-exceeded, proxy-auth failure,
  backend-unavailable, and generic API error
- cross-platform file-based audio recording service with mono 16 kHz AAC/M4A
  capture, monotonic hard-cap deadline exposure, too-short invalidation, and
  caller-owned post-recording file lifecycle
- runtime microphone permission interpretation for granted, denied,
  permanently denied, and restricted states before recording begins
- app-facing cloud transcription service for the Best-mode flow, including
  sequential live record-stop-upload orchestration, optional detected-language
  normalization, retryable failed-live audio retention, and immediate cleanup
  of successful live temporary audio files
- app-facing main recording controller for the Best-mode flow under
  `lib/presentation/main/`, including `Idle`, `Listening`, `Uploading`,
  `Processing`, `Saved`, `Error`, and `Deleted` states plus derived
  active-state behavior
- single-button Best-mode orchestration from live recording start/stop through
  cloud transcription, transcript cleanup, Saved-state publication, retryable
  audio-draft persistence, and `hasEverRecorded` updates
- controller-owned three-second auto-clear behavior for Error and Deleted
  feedback, with Saved feedback intentionally left UI-owned
- real root main screen at `/` with a voice-first circular recording button,
  under-button status line, entry stats line, and session quota line when
  quota data exists
- approved main-screen status behavior including first-time
  `tap button to write`, idle `wrait`, listening `stop`, uploading,
  processing, saved, draft-preserved, retryable microphone-denied, and
  microphone-blocked feedback states
- retryable microphone denial now surfaces `mic needed · tap again` and lets
  the next user-initiated tap request microphone access again
- blocked microphone access, permanently denied access, and restricted access
  now surface `mic blocked · tap settings` from both the status line and the
  primary main button
- the main screen refreshes microphone permission state on app resume so
  granting permission in system settings clears the blocked state without an
  app restart
- active live recording is canceled instead of uploaded or saved if microphone
  access is revoked while the app is listening
- native Android recording start failures are surfaced back into Flutter as
  controller-visible errors instead of leaving the app stuck on the launcher
  icon or a silent no-op path
- listening-state pulse/countdown presentation driven by the configured
  recording hard cap
- main-screen navigation from saved feedback to `/entry/:id` and from entry
  stats to `/entries`
- active entry stats using fixed `{count} entries - {days} days` wording,
  counting every stored entry including drafts and unique local calendar days
- real entry-list screen at `/entries` backed by the local entry repository
- entry-list newest-first ordering with draft rows included and visibly marked
- always-visible language labels and localized weekday/date/time metadata for
  each entry row
- entry-list previews derived from cleaned text first, then raw transcript,
  with audio-only drafts shown as `pending · will retry`
- right-swipe row deletion on `/entries` with immediate confirmation, cancel
  reset, and stay-on-list behavior after confirmed deletion
- real entry-detail screen at `/entry/:id` backed by the local entry
  repository
- entry detail text display derived from cleaned text first, then raw
  transcript fallback
- entry detail metadata showing localized weekday/date plus stored word count
- selectable entry-detail read mode and explicit edit mode
- automatic entry-detail edit persistence to `cleanedText` and `wordCount`
  without mutating the original `rawTranscript`
- entry-detail share action through the platform share surface
- shared entry deletion confirmation behavior between entry list and entry
  detail
- safe redirect from invalid, missing, deleted, or unreadable detail routes
  back to `/entries`
- platform setup for Android and iOS

Feature behavior such as network-preflight handling for Best mode, offline-mode
routing, retry UX, quota presentation beyond the current session state,
preferences persistence beyond the current basic flags and identifiers,
settings UI, and richer entry-management UI still belongs to later user
stories.

## Important product themes

- Voice-first capture
- Cross-platform mobile support on Android and iOS
- Privacy-aware handling of sensitive journal content
- Secure local storage
- Support for both backend-assisted and offline-oriented flows

## Key planned technical capabilities

Planned future stories cover:

- expanded preferences and settings
- recording UI on top of the existing app-facing recording controller
- Best-mode network preflight and offline-mode routing on top of the existing
  recording/transcription controller surface
- retry UX on top of the existing transcription and cleanup use cases
- entry detail and broader entry-management screens
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
- proxy-authenticated debug deployments require `PROXY_SECRET` to be present so
  the app can send the expected `X-Proxy-Secret` request header during launch
  registration and later backend calls
- Android developers can also build the debug APK manually with
  `flutter build apk --debug --dart-define=PROXY_SECRET=...` and install
  `build/app/outputs/flutter-apk/app-debug.apk` directly through `adb`

## Reference

For the current story breakdown and broader functionality roadmap, see:

- `plan/functionality.md`
- `plan/us_001.md` through `plan/us_026.md`
