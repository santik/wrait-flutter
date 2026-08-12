# Application Description

Wrait is a mobile journaling application centered around voice-first diary
entry creation.

## Product summary

The user records a spoken entry, the app converts that recording into text, and
the result is stored as a diary entry. The current product is a single
cloud-backed voice flow with strong attention to privacy, local data
protection, and a simple interaction model.

## Primary experience

The core user flow is:

1. Open the app.
2. Start a voice recording.
3. Let the app transcribe the recording.
4. Optionally clean up the transcript.
5. Save and review the resulting entry.

The current product scope centers on one launch path: cloud-backed recording,
transcription, cleanup, and local entry persistence with retryable drafts when
backend work cannot fully complete in one attempt.

## Current implementation scope

At the moment, the Flutter app includes the shared project foundation, the core
visual shell, and the first encrypted local persistence layer needed for
upcoming feature work:

- app bootstrap
- immediate first-frame bootstrap shell with loading and retry states while
  launch dependencies finish asynchronously
- split Android install identities for release/update validation
  (`com.wrait.flutter`) versus debug/profile validation
  (`com.wrait.flutter.dev`)
- Wrait-only platform launcher/app-icon branding across Android and iOS, with
  release using the app button-color background and debug/profile using a red
  background, both showing the `wrait` wordmark and no Flutter logo
- Android manifest-level Impeller disablement for reliable real-device cold
  launch instead of hanging behind the splash screen on the current validation
  phone
- routing shell
- runtime configuration loading
- physical-phone release-signed Android deployment flow via
  `./deploy_release.sh`
- centralized light/dark theme and design tokens
- encrypted local entry database bootstrap through the app startup flow rather
  than a fully blocking pre-UI initialization step
- encrypted local entry persistence and stale-draft cleanup through the current
  type-based store in `wrait_entries_v2.sqlite`
- fresh-install rollout for the current entry-type store; legacy pre-US-037
  `wrait_entries.sqlite` entry data is not migrated or surfaced by the current
  app
- same-identity app-update preservation for the current encrypted database,
  linked
  app-private retained files, persisted device id, pending drafts, and
  first-recording state
- uninstall/reinstall and Android clear-data fresh-start behavior for local
  app-private state
- bootstrap failure handling that surfaces a simple retry/error shell instead
  of silently wiping local database artifacts
- Android backup/restore disabled for this app-private local data lifecycle
- shared preferences bootstrap
- persisted recording-state preference
- persisted stable app device identifier with native lookup/fallback
  resolution and backend-compatible anonymous hashing for newly resolved IDs
- app-wide privacy lock that starts locked on cold launch and relocks on
  return from true foreground exit states
- whole-app lock overlay with blur/scrim obscuring, explicit unlock action,
  automatic foreground auth prompt scheduling, and retryable unavailable states
- best-effort device-security settings recovery plus warning bypass when no
  supported device security is configured
- always-on native Android capture protection for screenshots, screen
  recordings, and recent-app previews through secure-window handling
- native iOS privacy-cover protection for app-switch/background snapshots
- generic non-sensitive protected output on iOS privacy-cover surfaces instead
  of branded or diary-specific content
- centralized backend API client for device registration, audio transcription,
  and transcript cleanup
- OpenAPI-driven backend contract consumption from `api/wrait-backend.yaml`
- backend request wiring through runtime config plus persisted device identity
- non-blocking launch-time backend device registration
- launch-only background draft retry after successful device registration
- session-only quota state populated from successful backend registration and
  refreshed by valid transcription responses in the same app session
- app-facing transcript cleanup use case for Best-mode flows, including fresh
  draft creation before cleanup, retry against existing text drafts, typed
  cleanup failures for invalid retry targets, and draft finalization only on
  usable cleanup success
- incremental Best-mode draft persistence across recording, transcription, and
  cleanup so partially completed work remains retryable until the full happy
  path succeeds
- launch retry for pending audio and text drafts in newest-first order, with
  one failed draft not blocking later drafts in the same launch pass
- automatic stale-draft cleanup for drafts older than seven days before launch
  retry begins
- malformed audio-draft deletion when the retained local audio file is blank,
  missing, unreadable, or empty
- silent draft finalization through the existing entry list, entry detail, and
  stats surfaces instead of separate foreground success feedback
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
- listening-state pulse now starts at the main action button, expands to the
  visible safe-area edges and slightly beyond them, and stays behind the
  action button, countdown, quota, and status UI
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
- manual CSV export from the entries screen, covering saved and draft entries,
  excluding retained audio files, database ids, and duplicate timestamp
  fields, and writing to an automatic local platform destination
- manual CSV import from the entries screen for Wrait-produced CSV files only,
  adding new saved and draft entries without updating or deleting existing
  local rows
- imported CSV draft rows remain drafts, imported saved rows remain saved, CSV
  ids are ignored in favor of new local ids, retained audio files are not
  restored by import, and `created_at` round-trips as the raw stored integer
  value from the local database
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
- shared entry text now includes the localized entry date and time before the
  shared body text
- shared entry deletion confirmation behavior between entry list and entry
  detail
- safe redirect from invalid, missing, deleted, or unreadable detail routes
  back to `/entries`
- Android system back now matches the visible in-app back behavior on the
  entry list and entry detail routes
- platform setup for Android and iOS

Feature behavior such as network-preflight handling, richer retry UX, quota
presentation beyond the current session state, preferences persistence beyond
the current basic flags and identifiers, settings UI, and broader
entry-management UI still belongs to later user stories.

Current platform limitation to keep in mind:

- iOS simulator recording in this environment does not currently prove active
  screen-capture hiding because `UIScreen.main.isCaptured` did not toggle
  during `simctl recordVideo`; stronger evidence for that path still belongs to
  future physical-device validation.

## Feedback and privacy

The main screen includes one top-right feedback button for the first-version
user feedback flow. Users choose `Bug`, `Idea`, `Confusing`, or `Praise`, may
provide unrestricted plain-text reply contact information, and then submit a
free-text message through Wiredash without leaving the app.

Feedback is an external service boundary. The app disables Wiredash email and
screenshot prompts, does not use Wiredash analytics, and sends only an
explicitly allowlisted category, broad app area, platform, locale, and
trimmed non-blank contact value. When supplied, the contact is sent both as
custom `reply_contact` metadata and in Wiredash's standard `userId` field so it
survives the SDK's hidden-email submission path. The `userEmail` field is also
populated defensively, but is dropped by Wiredash 2.6.1 when the email prompt is
hidden. The contact is not auto-collected or email validated. Journal entries,
transcripts, audio, file paths, identifiers,
screenshots, proxy secrets, and raw diagnostics are not attached
automatically. The preparation form includes privacy guidance telling users
not to include private journal content unless they choose to type it.

Wiredash credentials are build-time configuration values, not Wrait backend
credentials. Missing values keep the app launchable and make feedback degrade
to a sanitized unavailable state. The integration is pinned to Wiredash
`2.6.1`; future SDK upgrades require dependency, analyzer, and Android/iOS
integration validation.

## Important product themes

- Voice-first capture
- Cross-platform mobile support on Android and iOS
- Privacy-aware handling of sensitive journal content
- App-level privacy lock with device-owner authentication
- Native operating-system capture privacy for supported Android and iOS surfaces
- Secure local storage
- Backend-assisted voice journaling with durable local retry

## Key planned technical capabilities

Planned future stories cover:

- expanded preferences and settings
- recording UI on top of the existing app-facing recording controller
- network preflight and richer retry UX on top of the existing
  recording/transcription controller surface
- retry UX on top of the existing transcription and cleanup use cases
- entry detail and broader entry-management screens
- additional privacy-oriented behavior if a future approved story introduces it

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
- release-signed Android deployments use `./deploy_release.sh`, read the
  current private config from `android/local.properties`, and keep signing
  passwords transient rather than persisting them into
  `android/local.properties`
- production Android backend connectivity depends on
  `android.permission.INTERNET` being declared in
  `android/app/src/main/AndroidManifest.xml` so release installs can complete
  launch registration and show quota
- Android developers can also build the debug APK manually with
  `flutter build apk --debug --dart-define=PROXY_SECRET=...` and install
  `build/app/outputs/flutter-apk/app-debug.apk` directly through `adb`
