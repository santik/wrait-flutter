# Feature Specification: Theme, Design Tokens & Core UI Shell

> **Feature number:** 003
> **Status:** Complete
> **Author:** Codex
> **Date:** 2026-06-08
> **Work item:** US-002

## Status history

| Date       | Status | Author | Notes |
| ---------- | ------ | ------ | ----- |
| 2026-06-08 | Draft | Codex | Initial spec created from `plan/us_002.md`, existing Flutter foundation, and Android design references |
| 2026-06-08 | Draft | Codex | Clarifications incorporated: shared placeholder layout with different titles, any non-empty entry ID is sufficient, router-level/direct route coverage is enough, typography should target similar rather than exact cross-platform parity, and dark mode is now in scope pending final spec approval |
| 2026-06-08 | Approved | Codex | Finalized spec approved for planning with automatic system-following dark mode and no in-app theme override |
| 2026-06-08 | Complete | Codex | Implemented centralized Wrait theme/tokens, shell placeholders for `/`, `/entries`, and `/entry/:id`, automated validation, and Android/iOS light-dark manual verification |

---

## Overview

The current Flutter app proves launch, configuration, and basic routing readiness, but it does not yet provide the shared visual language and navigational shell that later user-facing stories can build on consistently. Without a common set of presentation rules, upcoming screens risk diverging in spacing, motion, sizing, and route structure, making the product feel inconsistent and increasing rework.

This feature establishes the baseline user-facing shell for the mobile app. It defines the shared visual rules needed for a familiar, minimal Wrait experience across both light and dark appearances and introduces placeholder destinations for the first core navigation surfaces. The result should give future stories a stable foundation for building real screens while keeping this story limited to reusable UI rules and shell behavior rather than feature-specific content.

> **Reminder:** This spec must be **purely functional and technology-agnostic**.
> Describe the problem and requirements, not the solution. Technology choices
> belong in `plan.md`.

## User stories

- As a mobile user, I want the app to feel visually consistent and familiar so that the Flutter version matches the established Wrait experience.
- As a mobile user, I want the app shell to support both light and dark appearances so that it feels coherent in different device display modes.
- As a mobile user, I want the app shell to support moving between the main destinations so that future entry-related screens have a predictable navigation structure.
- As a developer, I want shared presentation tokens for spacing, motion, gesture thresholds, sizing, and persistent layout reservations so that new screens can reuse the same rules instead of redefining them.
- As a developer, I want placeholder destinations for the home surface, entries surface, and individual entry surface so that later stories can add real content without restructuring the app shell.

## Acceptance criteria

- [ ] The app exposes a shared visual system for this phase of the product, including the spacing, timing, gesture-threshold, adaptive button-sizing, and reserved message-area values defined by the approved Wrait reference for this story.
- [ ] The app provides clean, minimal light and dark appearances that follow the device or system appearance automatically, with the required body, label, supporting-text, and medium-title text roles available for reuse across the shell, targeting similar look and feel to the approved reference rather than exact cross-platform typography parity.
- [ ] The app provides navigable destinations for the root surface, the entries surface, and an individual entry surface, even if those destinations only contain placeholder content in this story.
- [ ] The root surface and entries surface may share one placeholder layout as long as each destination is distinguishable by its own title.
- [ ] Navigation coverage for the shell destinations works on supported Android and iOS builds without requiring real entry data, and direct route accessibility is sufficient for this story.
- [ ] The individual entry destination is reachable for any non-empty entry identifier in this story.
- [ ] The primary adaptive button-sizing behavior respects the approved ratio and minimum/maximum bounds across different screen widths.
- [ ] Layout space for transient status messaging and quota messaging remains reserved so that showing or clearing those messages does not cause surrounding content to jump unexpectedly.
- [ ] This story does not introduce entry persistence, recording flows, transcription flows, or non-placeholder entry content.

## API contract

No HTTP endpoints are introduced or modified by this feature.

This story only defines client-side shell behavior and shared presentation rules for future screens.

## Data model changes

No persistent user data model is introduced or changed by this feature.

The feature does require a shared presentation configuration surface for:

- spacing values
- animation and timing values
- gesture-threshold values
- adaptive primary button-sizing rules
- reserved layout behavior for status and quota messaging

No migration is required because no stored user data changes.

## Dependencies

- [ ] Existing app bootstrap and routing foundation from [specs/002-flutter-project-foundation/spec.md](/Users/alexander/projects/wrait/write-flutter/specs/002-flutter-project-foundation/spec.md)
- [ ] Story requirements in [plan/us_002.md](/Users/alexander/projects/wrait/write-flutter/plan/us_002.md)
- [ ] Established Wrait visual references in [wrait-android/src/main/java/com/wrait/app/ui/theme/DesignTokens.kt](/Users/alexander/projects/wrait/write-flutter/wrait-android/src/main/java/com/wrait/app/ui/theme/DesignTokens.kt), [Theme.kt](/Users/alexander/projects/wrait/write-flutter/wrait-android/src/main/java/com/wrait/app/ui/theme/Theme.kt), [Color.kt](/Users/alexander/projects/wrait/write-flutter/wrait-android/src/main/java/com/wrait/app/ui/theme/Color.kt), and [Type.kt](/Users/alexander/projects/wrait/write-flutter/wrait-android/src/main/java/com/wrait/app/ui/theme/Type.kt)

## UX / design references

This story uses the existing Android implementation as the current design reference.

The Flutter shell should match the approved Wrait visual language closely enough that later feature stories inherit the same baseline look and feel.

## Non-functional requirements

- **Performance:** Shell navigation and placeholder rendering should feel immediate on supported mobile targets, and the shared shell must not introduce unnecessary startup or transition overhead.
- **Security:** No new secrets, permissions, authentication flows, or external network calls are introduced in this story.
- **Reliability:** The visual system and shell navigation should behave consistently on Android and iOS in both light and dark appearances, and placeholder destinations should remain usable even when no entry data exists.
- **Scalability:** The shared visual rules should be reusable by upcoming entry, recording, and settings screens without redefining the same constants in multiple places.
- **Observability:** Validation evidence should show that the shell renders, the routes are reachable, and the adaptive sizing behavior can be verified through automated checks.
- **Maintainability:** Presentation rules should have a single source of truth so future visual adjustments can be made centrally instead of screen by screen.

## Out of scope

- Implementing real entry lists, entry detail content, or entry editing behavior
- Implementing recording, transcription, backend communication, or persistence
- Adding an in-app theme override or theme selection control
- Adding alternative themes beyond the approved light and dark Wrait shell for this story, or introducing brand-new visual exploration unrelated to that reference
- Introducing non-placeholder business logic for quota, status, or deletion behavior beyond reserving the required layout space and defining reusable thresholds/timings
- Handling advanced navigation flows beyond the root surface, entries surface, and individual entry surface shell routes

## Open questions

None at this stage.
