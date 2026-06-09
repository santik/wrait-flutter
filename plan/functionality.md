# wrait — Functional Description for Flutter Rewrite

## Application Overview

**wrait** is a minimal voice diary application. The user opens the app, taps a
single button, speaks, taps again, and the entry is transcribed, optionally
cleaned up by AI, and stored encrypted on-device.

**Tagline**: *One button. Your voice. Your words. Stays on your phone.*

**Target platforms (Flutter rewrite)**: Android and iOS.

---

## Core Features

### F1 — Primary Recording Flow

1. Main screen shows a large circular action button with label "tap to write".
2. User taps the button → app requests microphone permission if needed.
3. App enters **Listening** state — button label changes to "listening…", a
   pulsing ring animation plays around the button.
4. A countdown ring appears when approaching the hard cap (default 120 s).
5. User taps button again → recording stops.
6. If recording < 5 s → error "too short · keep talking", shake animation.
7. In **Best** mode: audio uploaded to backend `/api/transcribe`; then raw
   transcript sent to `/api/cleanup`; cleaned text saved.
8. In **Offline** mode: on-device speech recognition; raw transcript saved
   directly (no cleanup).
9. On success → state becomes **Saved**, status line shows "tap to read".
10. After 4 s, auto-reset to Idle.

### F2 — Entry List

1. Accessible via swipe-up on main screen or tap on stats line.
2. Entries displayed in reverse chronological order.
3. Each row shows: formatted date/time, first line of content (truncated),
   language tag (if non-default).
4. Swipe-right on a row reveals a delete button.
5. Empty state: "no entries yet".
6. Back navigation: swipe-down or back button.

### F3 — Entry Detail

1. Shows full cleaned text (or raw transcript if no cleanup).
2. Header: date, day of week, word count.
3. Actions: share (native share sheet), delete (with confirmation dialog).
4. Swipe-down triggers back navigation.
5. Text is selectable.
6. (Future) Text editing with auto-save.

### F4 — Entry Deletion

- From list: swipe-right → delete button → confirmation dialog → delete.
- From detail: delete icon → confirmation dialog → navigate back to list.
- Deleted entries trigger a "Deleted" state on main screen (auto-clears 3 s).

### F5 — Entry Sharing

- From detail screen, share button opens native share sheet with entry text.

### F6 — Language Selection

- Only available in **Offline** mode.
- Tap language label in settings panel → bottom sheet with supported languages.
- Supported: en-US, nl-NL, ru-RU, uk-UA, de-DE, es-ES, fr-FR, it-IT, pl-PL,
  pt-PT, tr-TR.
- In **Best** mode, language is auto-detected by backend.

### F7 — Privacy Mode Toggle

- Settings panel accessible via settings icon (top-right) or swipe-down.
- Panel slides in from top.
- Toggle switch: "Offline" (on) / "Best" (off).
- **Best**: cloud transcription + AI cleanup. Requires network.
- **Offline**: on-device transcription, no cleanup. No network required.
- Dismiss: tap scrim, swipe-up on panel, or tap outside.

### F8 — Statistics

- Displayed on main screen below the button: "X entries · Y days".
- Entry count and unique active days calculated from stored entries.
- Tapping stats navigates to entry list.

### F9 — Draft & Retry System

- If transcription or cleanup fails (network error, timeout, backend
  unavailable), entry saved as draft.
- Audio drafts: audio file kept on disk.
- Text drafts: raw transcript stored, pending cleanup.
- On app launch, pending drafts retried automatically (Best mode only).
- Stale drafts (> 7 days) deleted automatically.

### F10 — Quota Display

- In Best mode, backend returns recording quota (limit, count, remaining,
  resetAt).
- Displayed above the action button: "X total · Y left".
- Hidden in Offline mode.

### F11 — Device Registration

- On app launch, anonymous device ID sent to backend `/api/register`.
- Used for beta access gating and quota tracking.
- Device ID stored encrypted on-device.

### F12 — Microphone Permission Handling

- First tap: system permission dialog.
- If denied: error state, can retry.
- If permanently denied: shows "mic blocked · tap to open settings" with link
  to app settings.
- Permission revocation during recording: stops recording, shows error.

### F13 — Security & Privacy

- Database encrypted (equivalent to SQLCipher — use flutter_secure_storage +
  encrypted SQLite or similar).
- Screenshot/screen recording blocked (FLAG_SECURE on Android,
  UIScreen.isCaptured on iOS).
- Recent apps thumbnail hidden.
- No cloud backup of data.
- No account system.

### F14 — App Lock (Biometric/Device Credential)

- On app backgrounding, content is blurred.
- On returning to foreground, biometric/device credential prompt shown.
- If authentication succeeds, blur removed.
- If cancelled, remains locked.
- If no security configured, prompts user to set up device security.

### F15 — Keep Screen On During Recording

- While in Listening/Processing/Uploading state, screen stays on.
- Cleared when returning to Idle.

### F16 — Adaptive Button Sizing

- Button diameter = screen width × 0.56, clamped between 160dp and 280dp.
- Works correctly in split-screen and landscape.

---

## Navigation Structure

```
main (MainScreen)
  ├── swipe-up / tap stats → entries (EntryListScreen)
  │     └── tap entry → entry/:id (EntryDetailScreen)
  └── swipe-down / settings icon → SettingsPanel (overlay)
        └── tap language → LanguagePickerSheet (bottom sheet, Offline only)
```

---

## UI Design Tokens

| Token | Value |
|-------|-------|
| Fade duration | 300 ms |
| Pulse duration | 1800 ms |
| Button alpha (disabled) | 0.3 |
| Button alpha (reduced) | 0.5 |
| Swipe threshold | 80 dp |
| Status clear delay | 4000 ms |
| Min recording | 5000 ms |
| Max recording (hard cap) | configurable, default 120 s |
| Countdown window | 10 s before hard cap |

---

## Backend API (unchanged)

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/register` | POST | Device registration |
| `/api/transcribe` | POST | Audio transcription (multipart) |
| `/api/cleanup` | POST | Transcript cleanup |

All endpoints require `X-Device-Id` header and proxy secret auth.

---

## Data Model

### Entry
| Field | Type | Description |
|-------|------|-------------|
| id | int (auto) | Primary key |
| rawTranscript | String | Original transcription |
| cleanedText | String? | AI-cleaned text |
| isDraft | bool | Pending cleanup |
| language | String | Language code |
| createdAt | int (epoch ms) | Creation timestamp |
| wordCount | int | Word count |
| audioPath | String? | Path to audio draft file |

### Preferences
- selectedLanguage: String
- privacyMode: MODE_BEST | MODE_OFFLINE
- hasEverRecorded: bool
- deviceId: String (encrypted)

---

## Error States

| Error | Status Text | Behavior |
|-------|-------------|----------|
| TooShort | "too short · keep talking" | Shake, immediate retry |
| NoMatch | "nothing caught · too quiet?" | Shake, immediate retry |
| InsufficientPermissions | "mic blocked · tap to open settings" | Open settings |
| ConnectionRequired | "best mode needs connection" | No draft saved |
| NotAvailable | "no offline model for {lang}" | Offline only |
| NoInternet/Network/Timeout | "no connection · saved as draft" | Draft saved |
| BackendUnavailable | "service unavailable · saved as draft" | Draft saved |
| ProxyAuthFailed | "server config error · saved as draft" | Draft saved |

---

## Implementation Priority

**Phase 1 — Best Mode (US-001 to US-021):**
Core recording flow with cloud transcription and AI cleanup. All UI screens,
navigation, permissions, security, draft retry, device registration. This
delivers the primary user experience.

Detailed implementation order is tracked in `plan/README.md`. The current plan
intentionally schedules US-016 before US-006.

**Phase 2 — Offline Mode (US-024, US-025):**
On-device speech recognition and language selection. Lower priority because it
requires platform-specific speech APIs with more complexity and less
transcription quality.

**Phase 3 — Polish (US-022, US-023, US-026):**
Analytics, accessibility refinements, and comprehensive testing.

---

## Platform-Specific Considerations (Flutter)

### Audio Recording
- Use `record` or `flutter_sound` package for cross-platform audio capture.
- iOS: AVAudioSession configuration for recording.
- Android: MediaRecorder or AudioRecord.

### Speech Recognition
- **Offline mode**: `speech_to_text` package (on-device models).
- **Best mode**: Record audio file → upload to backend.

### Encryption
- `flutter_secure_storage` for keys.
- `sqflite_sqlcipher` or `drift` with encryption for database.
- iOS Keychain / Android Keystore for key protection.

### Biometric Auth
- `local_auth` package for biometric/device credential.

### Screenshot Prevention
- Android: FLAG_SECURE via platform channel.
- iOS: UITextField secure trick or notification-based approach.

### Permissions
- `permission_handler` package.
