# Feature Specification: App Lock

> **Feature number:** 019
> **Status:** Approved
> **Author:** Codex
> **Date:** 2026-06-22
> **Work item:** US-019

## Status history

| Date | Status | Author | Notes |
| --- | --- | --- | --- |
| 2026-06-22 | Draft | Codex | Initial spec created from `plan/us_019.md` and the project SDD workflow |
| 2026-06-22 | Draft | Codex | User clarified lock timing, cold-launch behavior, automatic prompts, whole-app obscuring, warning bypass, best-effort settings, and message proposal |
| 2026-06-22 | Draft | Codex | User approved draft spec for clarify phase; clarify pass finalized accepted copy and moved implementation feasibility checks to planning |
| 2026-06-22 | Approved | Codex | User approved finalized spec for implementation planning |
| 2026-06-22 | Approved | Codex | Planning chose to preserve current in-progress work while locked unless implementation reveals a specific instability requiring approval |
| 2026-06-22 | Approved | Codex | User approved the US-019 implementation plan for task breakdown |
| 2026-06-22 | Approved | Codex | User approved the US-019 task list for analysis; analysis completed with no artifact corrections required |

---

## Overview

Wrait contains private diary content that can remain visible when the user
switches away from the app and later returns. The app should protect that
content by entering a locked state when it leaves active use, obscuring journal
content while locked, and requiring the user to prove device ownership before
normal app interaction resumes.

This story defines the user-facing privacy lock behavior for cold launch and
returning from the background. When the lock is active, the whole app should be
blocked from casual viewing, the user should have a clear unlock action, and
authentication failures should leave the app protected while still offering an
understandable recovery path.

> **Reminder:** This spec must be **purely functional and technology-agnostic**.
> Describe the problem and requirements, not the solution. Technology choices
> belong in `plan.md`.

## User stories

- As a user, I want Wrait to hide my diary content after I leave the app so
  that someone looking at my device cannot casually read my entries.
- As a user, I want to unlock Wrait with the security method already configured
  on my device so that returning to journaling is quick and familiar.
- As a user, I want canceled or failed unlock attempts to keep my diary hidden
  so that privacy is preserved until I successfully unlock.
- As a user without usable device security configured, I want Wrait to explain
  what needs to be set up and offer a path to device settings so that I can
  enable the lock requirement.
- As a user, I want the lock screen to avoid repeated or poorly timed system
  prompts so that background and foreground transitions feel stable.

## Acceptance criteria

- [ ] When Wrait leaves active foreground use, the app records that sensitive
      content must be locked before normal interaction can resume.
- [ ] Wrait also starts locked on cold launch before normal app interaction is
      available.
- [ ] When Wrait is locked, the entire app behind the lock surface is visually
      obscured before the user can continue interacting with the app.
- [ ] When the user returns to a locked Wrait session and device-owner
      authentication is available, the app shows a lock screen over the
      obscured app content.
- [ ] The lock screen provides an explicit unlock action.
- [ ] On cold launch or return to foreground, Wrait automatically starts the
      authentication prompt when device-owner authentication is available and
      the app is fully active in the foreground.
- [ ] The app starts the device-owner authentication prompt only while the app
      is fully active in the foreground.
- [ ] The app does not repeatedly launch overlapping authentication prompts
      during lifecycle transitions, cancellation, or prompt dismissal.
- [ ] Successful authentication removes the obscuring layer, dismisses the lock
      screen, and restores normal app interaction.
- [ ] If the user cancels authentication, Wrait remains locked and the user can
      try the unlock action again.
- [ ] If authentication cannot continue because the device has no supported
      security method configured, Wrait keeps sensitive content obscured and
      shows a clear message prompting the user to set up device security.
- [ ] When device security setup is required, Wrait provides an actionable path
      to the relevant system settings where the platform supports it, using a
      best-effort platform-appropriate destination when direct security settings
      are unavailable.
- [ ] When device security is not configured, Wrait also provides an explicit
      warning bypass action that lets the user continue into the app after
      acknowledging reduced protection.
- [ ] If authentication is temporarily unavailable, Wrait keeps sensitive
      content obscured and shows an understandable message that the user can
      recover from without exposing diary content.
- [ ] The locked state survives ordinary background and foreground transitions
      until authentication succeeds.
- [ ] The lock experience works on both Android and iOS using the security
      methods available on each platform.
- [ ] App-lock feedback remains accessible to assistive technologies, including
      the lock state, unlock action, and security-setup recovery action.
- [ ] App locking does not delete, alter, retry, upload, or otherwise change
      journal entries, drafts, recordings, quota state, backend registration, or
      local persistence data.
- [ ] Existing recording, upload, cleanup, registration, and draft-retry work
      may continue while Wrait is locked when it can do so without exposing app
      content, requiring unlocked foreground interaction, or destabilizing the
      in-progress operation.
- [ ] Validation evidence includes automated coverage for locked, unlocked,
      canceled, unavailable, no-security, warning-bypass, automatic-prompt, and
      cold-launch states plus Android emulator and iOS simulator verification
      unless a planning-time validation exception is explicitly approved.

## API contract

This feature does not introduce or modify backend HTTP endpoints.

### App-lock state contract

The app may derive these app-lock inputs:

- app cold launches
- app leaves active foreground use
- app returns to active foreground use
- device-owner authentication availability
- authentication succeeds
- authentication is canceled by the user or system
- authentication is unavailable because no supported device security is
  configured
- authentication is temporarily unavailable

The app can present these app-lock outputs:

- sensitive content obscuring layer
- lock screen overlay
- unlock action
- security-setup message
- security-settings recovery action where supported
- warning bypass action when no supported device security is configured
- temporary-unavailable message
- accessibility labels and hints for locked-state controls

Functional expectations:

- Sensitive content remains blocked while the app-lock state is locked.
- Unlock success leaves the locked state when authentication is available.
- The explicit warning bypass may leave the locked state only when no supported
  device security is configured.
- Canceled, failed, or temporarily unavailable authentication must not expose
  sensitive content.
- Authentication prompts should be user-comprehensible and should not appear
  when the app is not fully foregrounded.

## Data model changes

This feature does not require persisted journal data model changes.

Functional state needed by the app may include:

- whether the current app session is locked
- whether an unlock prompt is already pending
- the current authentication availability or failure reason

## Dependencies

- [ ] Existing app lifecycle awareness for foreground and background
      transitions
- [ ] Existing main app shell and navigation surfaces that can be obscured while
      locked
- [ ] Existing accessibility conventions for buttons, overlays, and status text
- [ ] Platform-provided device-owner authentication on Android and iOS
- [ ] Platform settings access for security setup where supported
- [ ] Android emulator validation path
- [ ] iOS simulator validation path

## UX / design references

No external design file is provided. The reference behavior is `plan/us_019.md`
and the legacy Android implementation named there:

- `wrait-android/src/main/java/com/wrait/app/lock/AppLockAuthenticator.kt`
- `wrait-android/src/main/java/com/wrait/app/lock/AppLockViewModel.kt`
- `wrait-android/src/main/java/com/wrait/app/MainActivity.kt`

The Flutter behavior should preserve Wrait's minimal voice-first UI while
making the locked state unmistakable and keeping sensitive content visually
blocked until authentication succeeds.

Approved user-facing copy:

- Locked: `wrait is locked`
- Unlock action: `Unlock`
- Authentication prompt reason: `Unlock Wrait to continue.`
- Authentication canceled: `still locked`
- No device security: `set up device security to protect Wrait`
- Open settings action: `Open settings`
- Warning bypass action: `Continue without lock`
- Warning bypass confirmation: `Your diary will be visible until you set up
  device security.`
- Temporarily unavailable: `unlock unavailable · try again`

## Non-functional requirements

- **Performance:** Entering the locked visual state and returning from
  background or cold launch must not add noticeable delay to first visible
  privacy protection, app resume, or unlock completion.
- **Security:** Locked-state UI must not expose journal text, draft content,
  recording details, backend data, local file paths, stack traces, secrets, or
  other sensitive implementation details.
- **Reliability:** Lifecycle transitions, prompt cancellation, prompt errors,
  and repeated foreground/background changes must not leave Wrait partially
  unlocked or stuck behind an unrecoverable prompt.
- **Scalability:** The lock state should cover existing and future sensitive app
  surfaces through a shared app-level behavior rather than screen-specific
  special cases.
- **Observability:** Validation evidence must show state transitions for
  background lock, foreground unlock, cancellation, unavailable authentication,
  no-security recovery, and platform runtime checks on Android and iOS.

## Out of scope

- Adding a user preference to enable, disable, or configure app locking
- Changing account authentication, backend authentication, proxy
  authentication, or backend request behavior
- Encrypting, migrating, deleting, or changing the local journal data model
- Changing recording, transcription, cleanup, draft retry, quota, entry list,
  entry detail, sharing, editing, or deletion behavior except to keep those
  surfaces obscured while locked and preserve in-progress work where feasible
- Designing a new settings screen inside Wrait for app-lock configuration
- Requiring a custom Wrait PIN, password, passphrase, or recovery code
- Locking individual entries separately from the app-level lock
- Guaranteeing protection from operating-system screenshots, external cameras,
  compromised devices, or platform-level attacks outside normal app control

## Open questions

None.

## Planning notes

- The implementation plan preserves current active recording, upload, cleanup,
  registration, and draft-retry behavior while locked. If implementation
  reveals a specific platform instability, pause and request explicit approval
  for that exception before changing the behavior.
