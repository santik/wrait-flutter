# Feature Specification: Portrait-only App Orientation

> **Feature number:** 044
> **Status:** Complete
> **Author:** Codex
> **Date:** 2026-09-02
> **Work item:** Not assigned

## Status history

| Date       | Status | Author | Notes                |
| ---------- | ------ | ------ | -------------------- |
| 2026-09-02 | Draft  | Codex  | Initial spec created |
| 2026-09-02 | Approved | Codex | Draft approved; clarification completed with no scope changes |
| 2026-09-04 | In Progress | Codex | Implementation complete; iOS physical rotation evidence remains blocked by simulator automation permissions |
| 2026-09-04 | In Progress | Codex | Review remediation approved; route/dialog coverage expanded, unrelated worktree changes preserved, and the iOS rotation validation exception documented |
| 2026-09-04 | Complete | Codex | Finalization approved; no durable guidance updates were needed for this isolated native configuration change |

---

## Overview

Wrait should remain in a vertical portrait presentation when a user rotates a
phone. This keeps the app's layout, recording controls, and private content
consistent and usable without requiring the user to manually rotate the phone
back.

The behavior applies throughout the Wrait app, including when the app is
opened, resumed, or navigated between its screens. The requirement is to
prevent landscape presentation on supported phone-sized devices; reverse
portrait presentation may remain available where the platform supports it.

## User stories

- As a Wrait user, I want the app to stay in portrait orientation when I rotate
  my phone so that the interface remains consistent and readable.

## Acceptance criteria

- [x] On supported phone-sized devices, Wrait presents only in portrait
      orientation while the app is active.
- [x] Rotating the phone to either landscape direction does not change the
      Wrait app to a landscape presentation.
- [x] If Wrait is launched or resumed while the device is physically oriented
      in landscape, the app presents in portrait orientation.
- [x] The portrait-only behavior applies consistently across the app's screens,
      dialogs, and navigation routes.
- [x] Existing recording, navigation, privacy-lock, import/export, and entry
      interactions continue to work without requiring landscape orientation.
- [x] Orientation changes do not introduce visible startup errors, persistent
      layout overflow, or loss of the current screen state.
- [x] System-managed screens outside Wrait, such as the operating system's
      settings or document picker, are not required to be portrait-locked by
      this feature.

Validation note: the active iOS physical-rotation interaction is covered by
the approved environment-limited validation exception documented in `plan.md`;
no unverified runtime result is represented as passing evidence.

## API contract

No HTTP API endpoints are introduced or modified by this feature.

## Data model changes

No data model fields, persisted data, or migrations are required.

## Dependencies

- [x] The operating system's supported application-orientation controls.
- [x] Existing Wrait screens and lifecycle behavior.

## UX / design references

No external design reference is provided. The existing portrait layout and
visual style remain the source of truth.

## Non-functional requirements

- **Performance:** The portrait constraint should take effect at app launch and
  resume without a noticeable delay or repeated orientation oscillation.
- **Security:** No additional sensitive data is introduced or exposed.
- **Reliability:** The constraint remains active after navigation, background /
  foreground transitions, and privacy-lock authentication.
- **Scalability:** The behavior must remain stable across the supported
  phone-sized device range and common portrait aspect ratios.
- **Observability:** No new production logging is required; orientation failures
  must not expose platform diagnostics to users.

## Test strategy

- Automated coverage will verify the portrait-only behavior at launch, after a
  simulated device rotation, after resuming the app, and across the current
  navigation routes plus representative dialogs.
- Runtime validation will verify the behavior on an Android emulator and an
  iOS simulator, including launcher-style startup and an active rotation to
  both landscape directions where the platform automation permits it. The iOS
  physical-rotation check is explicitly documented as an environment-limited
  validation exception in the implementation plan.
- Existing recording, privacy-lock, and navigation checks will be run to detect
  regressions caused by the orientation constraint.

## Out of scope

- Redesigning Wrait layouts specifically for landscape orientation.
- Locking the orientation of other applications or system-managed screens.
- Adding a user setting to opt into landscape orientation.
- Defining a separate tablet, desktop, foldable, or multi-window layout
  strategy beyond the platform's supported orientation-lock behavior.

## Open questions

- [x] None. The intended behavior is portrait-only; normal and reverse portrait
      are both acceptable where supported by the platform.
