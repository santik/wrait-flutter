# Feature Specification: Screenshot and Screen Recording Prevention

> **Feature number:** 020
> **Status:** In Progress
> **Author:** Codex
> **Date:** 2026-06-23
> **Work item:** US-020

## Status history

| Date | Status | Author | Notes |
| --- | --- | --- | --- |
| 2026-06-23 | Draft | Codex | Initial spec created from `plan/us_020.md` and the project SDD workflow |
| 2026-06-23 | Draft | Codex | User approved draft spec for clarify phase |
| 2026-06-23 | Draft | Codex | User clarified simplest acceptable iOS capture behavior, all app surfaces in scope, lock capture output, capture feedback, and emulator/simulator validation baseline |
| 2026-06-23 | Approved | Codex | User approved finalized spec for implementation planning |
| 2026-06-23 | Approved | Codex | User approved the US-020 implementation plan, including the OS-capture validation exception, for task breakdown |
| 2026-06-23 | Approved | Codex | User approved the US-020 task list for analysis |
| 2026-06-23 | Approved | Codex | Analysis completed with no artifact corrections required |
| 2026-06-23 | In Progress | Codex | User approved analysis for implementation |
| 2026-06-23 | In Progress | Codex | Implementation completed and documented in `implementation.md`; waiting for external `review.md` unless review is explicitly skipped |
| 2026-06-23 | In Progress | Codex | External review read, remediation plan presented, and user approved the review-fix pass |
| 2026-06-23 | In Progress | Codex | Review fixes implemented: Android lifecycle workaround documented, iOS privacy cover made generic, and runtime validation evidence expanded |

---

## Overview

Wrait contains private diary content that should not be exposed through normal
device capture surfaces. The app should protect visible journal content from
screenshots, screen recordings, and app-switcher previews on supported mobile
platforms.

This story defines capture-prevention behavior for app launch and normal app
use. The protection must be active before sensitive diary content is shown, and
captured output should hide Wrait content even when the app itself remains
usable to the person holding the device.
The implementation may use the simplest platform-appropriate protected output
or content-hiding behavior as long as captured output does not reveal app
content.

> **Reminder:** This spec must be **purely functional and technology-agnostic**.
> Describe the problem and requirements, not the solution. Technology choices
> belong in `plan.md`.

## User stories

- As a user, I want Wrait to prevent screenshots from revealing my diary
  content so that accidental or malicious captures do not expose private
  entries.
- As a user, I want Wrait to prevent screen recordings from revealing my diary
  content so that my journal is protected during recording or mirroring.
- As a user, I want app-switcher previews to avoid showing my diary content so
  that someone glancing at my recent apps cannot read Wrait content.
- As a user, I want capture protection active before sensitive content appears
  so that startup, resume, and navigation transitions do not briefly leak
  journal content.

## Acceptance criteria

- [ ] Capture protection is active before any sensitive diary content is
      displayed during a cold launch.
- [ ] Capture protection remains active while Wrait is in the foreground on
      Android.
- [ ] Android screenshots of Wrait produce protected output that does not show
      journal content.
- [ ] Android screen recordings of Wrait produce protected output that does not
      show journal content.
- [ ] Android recent-apps previews of Wrait do not show journal content.
- [ ] Capture protection remains active while Wrait is in the foreground on iOS
      where platform capabilities allow it.
- [ ] iOS screen recordings, screen sharing, or other detectable screen-capture
      sessions hide Wrait content while capture is active.
- [ ] iOS captured output does not show journal content when the platform
      provides a supported way to protect screenshots or capture snapshots.
- [ ] Capture protection covers all Wrait surfaces that can show sensitive
      diary content, including the main screen, entry list, entry detail,
      draft-related content, and locked or backgrounded app views.
- [ ] Capture protection also covers non-diary app surfaces, including startup,
      loading, bootstrap retry, quota, settings, and error states.
- [ ] Capture protection does not delete, alter, retry, upload, or otherwise
      change journal entries, drafts, recordings, quota state, backend
      registration, local persistence data, or app-lock state.
- [ ] If the platform cannot fully prevent a specific capture type, Wrait uses
      the strongest available platform-supported hiding behavior and the
      limitation is documented in validation evidence.
- [ ] Protection state survives ordinary lifecycle transitions including app
      resume, backgrounding, app-switching, and return to foreground.
- [ ] Capture-prevention behavior works alongside app locking without exposing
      the content behind the lock surface.
- [ ] Captured output during a locked state may show a generic locked or
      privacy-protected screen, a blank screen, or other platform-appropriate
      protected output, provided it does not reveal app content behind the lock.
- [ ] Capture-prevention behavior remains accessible and does not block normal
      app interaction for the person using the device.
- [ ] When a platform requires in-app content hiding during active capture, the
      app may hide content with or without explanatory text, choosing the
      simplest behavior that avoids exposing app content.
- [ ] Validation evidence includes automated or runtime coverage for first-frame
      protection, Android screenshot protection, Android recent-apps preview
      protection, Android screen-recording protection where practical, iOS
      capture-hiding behavior where practical, plus Android emulator and iOS
      simulator verification unless a planning-time validation exception is
      explicitly approved. The implementation plan should preserve a practical
      path for physical-device validation when emulator or simulator coverage
      cannot fully demonstrate a capture behavior.

## API contract

This feature does not introduce or modify backend HTTP endpoints. It defines an
application-level privacy contract for operating-system capture surfaces.

### Capture-protection inputs

The app may receive or derive these privacy-related conditions:

- app cold launch
- first visible frame
- app foreground and background lifecycle transitions
- app-switcher preview generation
- screenshot attempt
- screen recording or screen sharing start
- screen recording or screen sharing end
- app-lock state changes

### Capture-protection outputs

The app can present or produce:

- normal app UI to the person using the device
- protected screenshot output
- protected screen-recording output
- protected recent-apps or app-switcher preview output
- temporary content-hiding state while detectable capture is active
- optional generic privacy or locked-state copy when it is the simplest
  platform-appropriate way to hide content

Functional expectations:

- Captured output must not reveal diary content when platform-supported
  protection is available.
- Captured output must not reveal non-diary app content either.
- Capture protection must apply before sensitive Wrait content is visible.
- Capture protection must not change persisted journal data or backend state.
- Capture protection should degrade to the strongest available hiding behavior
  when a platform cannot fully block a capture type.

## Data model changes

This feature does not require persisted journal data model changes.

Functional state needed by the app may include:

- whether screen capture or screen sharing is currently active where detectable
- whether a temporary privacy cover should be shown
- whether platform capture protection is currently enabled

## Dependencies

- [ ] Existing app launch and lifecycle behavior
- [ ] Existing app shell and navigation surfaces that can show diary content
- [ ] Existing app-lock behavior from US-019 where present
- [ ] Platform-supported capture-prevention or content-hiding capabilities on
      Android and iOS
- [ ] Android emulator validation path
- [ ] iOS simulator validation path

## UX / design references

No external design file is provided. The reference behavior is `plan/us_020.md`
and the legacy Android implementation named there:

- `wrait-android/src/main/java/com/wrait/app/MainActivity.kt`

The Flutter behavior should preserve Wrait's minimal voice-first UI while
ensuring operating-system capture surfaces cannot reveal diary content.

## Non-functional requirements

- **Performance:** Capture protection must not add noticeable delay to first
  frame, foreground resume, navigation, recording start, recording stop, or
  app-lock unlock.
- **Security:** Protected capture output must not expose journal text, draft
  content, recording details, quota data, startup state, settings values,
  backend data, local file paths, stack traces, secrets, or other sensitive
  implementation details.
- **Reliability:** Lifecycle transitions, capture start/end events, app
  switching, and app-lock transitions must not leave Wrait content exposed in
  protected capture surfaces or leave the in-app UI permanently hidden.
- **Scalability:** The protection should cover current and future sensitive app
  surfaces through shared app-level behavior where possible instead of
  screen-specific special cases.
- **Observability:** Validation evidence must document which capture types were
  verified on Android and iOS, which platform limitations remain, and whether
  any validation exception was approved during planning.

## Out of scope

- Adding a user preference to enable, disable, or configure capture prevention
- Adding custom watermarking, capture warnings, or capture audit logs
- Changing app-lock authentication behavior except to ensure captured output
  does not reveal content behind the lock surface
- Changing recording, transcription, cleanup, draft retry, quota, backend
  registration, entry list, entry detail, sharing, editing, deletion, or local
  persistence behavior
- Changing backend APIs, proxy authentication, account authentication, or
  backend request behavior
- Guaranteeing protection against external cameras, compromised devices,
  platform bugs, debug tooling, rooted or jailbroken devices, or attacks
  outside normal operating-system capture controls
- Guaranteeing identical behavior for every capture type on every iOS and
  Android version when the operating system exposes different capabilities

## Open questions

None.
