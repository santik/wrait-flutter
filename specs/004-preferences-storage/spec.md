# Feature Specification: Preferences Storage

> **Feature number:** 004
> **Status:** Complete
> **Author:** Codex
> **Date:** 2026-06-08
> **Work item:** US-004

## Status history

| Date       | Status | Author | Notes |
| ---------- | ------ | ------ | ----- |
| 2026-06-08 | Draft | Codex | Initial spec created from `plan/us_004.md`, project workflow documents, and Android behavior references |
| 2026-06-09 | Draft | Codex | Refined against current Flutter code and user clarifications: no legacy migration, no privacy-mode persistence in this story, reinstall resets identifier and app data, unsupported user-set language codes should be rejected |
| 2026-06-09 | Draft | Codex | Further narrowed per user clarification: language persistence is also out of scope because language selection belongs to a later privacy-mode story |
| 2026-06-09 | Draft | Codex | Clarify phase finalized: `hasEverRecorded` is treated as a normal persisted boolean, not a write-once flag |
| 2026-06-09 | Draft | Codex | Revised after finalized-spec approval: device identifier should come from platform device-ID facilities for greater stability, and uninstall/reinstall reset behavior is no longer required |
| 2026-06-09 | Complete | Codex | Implemented `hasEverRecorded` persistence with `shared_preferences`, centralized platform device-ID retrieval through native bridges, automated validation, and Android/iOS build verification |
| 2026-06-09 | Draft | Codex | Reopened after review clarification: resolve and persist one opaque app device ID, preferring a platform ID when available and generating a fallback when not |
| 2026-06-09 | Complete | Codex | Revised implementation completed: repository now resolves, persists, and caches one opaque app device ID using stored value, platform value, or generated fallback with updated validation |

---

## Overview

The app needs a persistent preferences capability so users do not lose core
settings whenever the app is closed and reopened. For this story, the immediate
needs are limited to a flag indicating whether the user has ever successfully
recorded and one stable stored device identifier that the app can reuse when
needed. Without this feature, later recording, analytics, and registration
stories would either behave inconsistently or need to reintroduce their own ad
hoc persistence rules.

This feature defines the expected user-facing behavior for storing and
retrieving those values across launches. It also establishes the required
fresh-install defaults, how sensitive and non-sensitive values should be
treated differently, and what fallback behavior is required when no valid
stored value exists. Privacy-mode choice and language selection are
intentionally not part of this story because the product remains single-mode
until a later dedicated implementation introduces multiple privacy modes and
the language behavior tied to them.

> **Reminder:** This spec must be **purely functional and technology-agnostic**.
> Describe the problem and requirements, not the solution. Technology choices
> belong in `plan.md`.

## User stories

- As a user, I want the app to remember whether I have ever recorded before so that later onboarding or status behavior can react appropriately.
- As the app, I want one stable stored device identifier so that downstream features can reuse one identifier without caring whether it originated from the platform or from fallback generation.

## Acceptance criteria

- [ ] The app exposes whether the user has ever recorded before, defaults that value to `false` for a fresh install, and preserves explicit updates to either `true` or `false` across app restart.
- [ ] When no stored device identifier exists yet and a platform-provided device identifier is available, the app stores that identifier and returns it.
- [ ] When no stored device identifier exists yet and no platform-provided device identifier is available, the app generates a fallback identifier, stores it, and returns it instead of interrupting the user with a non-recoverable error.
- [ ] After the app has stored a device identifier, later reads and later launches return that same stored identifier without requiring callers to know whether it originated from the platform or from fallback generation.
- [ ] The app exposes the resolved device identifier through one centralized application contract so later features do not need platform-specific identifier logic or source-awareness of their own.
- [ ] If the app encounters missing, invalid, or unsupported stored values for these preferences, it falls back to safe defaults rather than crashing.
- [ ] The app documents that the stored device identifier may originate either from a platform-provided value or from generated fallback, but that distinction is intentionally hidden from the rest of the application.

## API contract

No HTTP endpoints are introduced or modified by this feature.

This story defines local app behavior for persisted preferences and a stored
application device identifier only.

## Data model changes

This feature introduces local application state for:

- has-ever-recorded flag
- device identifier

Functional expectations for these values:

- The has-ever-recorded flag must behave as a normal boolean with a defined fresh-install default.
- The device identifier must resolve once to either an available platform-provided value or a generated fallback value and then remain stable through persisted local storage.

No legacy locally stored keys need to be migrated for this story.

## Dependencies

- [ ] Existing Flutter application foundation and platform setup from earlier stories
- [ ] Platform-specific device-identifier facilities available on Android and iOS targets
- [ ] Local persistence capability for storing the resolved device identifier across launches

## UX / design references

No new visual design is required for this story.

This feature exists to support later UI and behavior, not to introduce a new
settings screen in this phase.

## Non-functional requirements

- **Performance:** Reading current preference values should be fast enough to support app startup and ordinary UI state observation without noticeable delay.
- **Security:** The app should prefer the most restrictive platform identifier that satisfies this use case and only fall back to local generation when the platform identifier is unavailable. No secrets or journal content are part of this story.
- **Reliability:** Fresh installs, app restarts, and invalid stored values must all resolve to predictable defaults without crashing the app.
- **Scalability:** The persistence behavior should support additional preference consumers in future stories without duplicating storage rules in multiple places.
- **Observability:** Validation evidence should demonstrate restart persistence, default resolution, stable device-identifier reuse, and successful fallback generation when no platform identifier is available.
- **Maintainability:** Preference rules should be centrally defined so later recording, settings, and registration features rely on one source of truth.

## Out of scope

- Building or polishing a settings UI beyond whatever internal plumbing later stories need
- Implementing backend device registration or analytics behavior that may later consume the device identifier
- Persisting diary entry content, transcripts, or other non-preference domain data
- Introducing privacy-mode choice or persistence before a later story explicitly adds multiple privacy modes
- Introducing language selection or persistence before the privacy-mode story that needs it
- Cross-device sync or cloud backup of user preferences
- Exposing to feature code whether the stored device identifier originated from the platform or from fallback generation

## Open questions

None at this stage.
