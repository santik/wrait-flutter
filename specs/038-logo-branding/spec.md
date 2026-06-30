# Feature Specification: Logo Branding

> **Feature number:** 038
> **Status:** In Progress
> **Author:** Codex
> **Date:** 2026-06-29
> **Work item:** US-038

## Status history

| Date | Status | Author | Notes |
| --- | --- | --- | --- |
| 2026-06-29 | Draft | Codex | Initial spec created from request to replace Flutter branding with Wrait branding |
| 2026-06-29 | Draft | Codex | Clarified protected surfaces and required Wrait wordmark usage |
| 2026-06-29 | Draft | Codex | Draft spec approved for clarification; no open questions remain |
| 2026-06-29 | Approved | User | Finalized spec approved for planning |
| 2026-06-29 | Approved | Codex | Analyze phase corrected release-branding wording from primary button color to the app's existing button treatment for artifact consistency |
| 2026-06-29 | In Progress | Codex | Implementation completed with generated release/debug assets, tests, and runtime validation evidence; awaiting external review |
| 2026-06-29 | In Progress | Codex | Applied approved review remediation: Android launcher icons now render as circle-only assets, branding tests/generator are hardened, and validation was rerun |
| 2026-06-29 | In Progress | Codex | Applied user-directed follow-up remediation: Android launcher branding now follows the `wrait-android` adaptive-icon resource pattern with only background color plus the `wrait` wordmark |
| 2026-06-29 | In Progress | Codex | Applied user-directed iPhone follow-up: iOS release/debug app icons now use full background color plus the `wrait` wordmark with no inner circle |

---

## Overview

Wrait should present its own visual identity anywhere the app shows a logo or
brand mark. Users should never see the default Flutter logo in normal app
surfaces, startup moments, lock or privacy states, or install/runtime surfaces
that are controlled by the app. The release identity should match Wrait's
existing in-app visual language by using the app's current button treatment and
the `wrait` word.

The debug app should remain clearly distinguishable from the release app. Its
logo should keep the same Wrait identity but use a red debug color so a tester
can quickly tell that they are looking at a debug build rather than the
release build.

> **Reminder:** This spec must be **purely functional and technology-agnostic**.
> Describe the problem and requirements, not the solution. Technology choices
> belong in `plan.md`.

## User stories

- As a user, I want Wrait to show its own logo instead of the default Flutter
  logo so that the app feels complete and product-specific.
- As a user, I want the release logo to match the app's existing button look
  and include the `wrait` word so that branding is consistent with the rest of
  the app.
- As a tester or developer, I want the debug app logo to be red so that I can
  immediately distinguish it from the release app.
- As a privacy-conscious user, I do not want a Flutter logo to appear on lock,
  privacy, or startup surfaces so that protected states do not expose generic
  development branding.
- As a maintainer, I want all app-controlled branding surfaces to use a single
  Wrait identity direction so future branding changes are easier to verify.

## Acceptance criteria

- [ ] The release app logo uses Wrait branding, includes the `wrait` word, and
      visually matches the app's existing button treatment.
- [ ] The release app does not show the default Flutter logo on any
      app-controlled user-visible surface.
- [ ] The debug app logo uses Wrait branding, includes the `wrait` word, and
      uses a red debug color that is clearly distinguishable from the release
      logo.
- [ ] The debug app does not show the default Flutter logo on any
      app-controlled user-visible surface.
- [ ] Lock, privacy, authentication, or protected-state surfaces controlled by
      Wrait do not show the default Flutter logo.
- [ ] Lock, privacy, authentication, or protected-state surfaces may keep their
      current neutral protected-state presentation as long as they do not
      expose the default Flutter logo or sensitive content.
- [ ] Startup and loading surfaces controlled by Wrait do not show the default
      Flutter logo.
- [ ] App launcher surfaces controlled by Wrait show the `wrait` word instead
      of Flutter branding.
- [ ] App-switcher surfaces controlled by Wrait show the `wrait` word when a
      branded app snapshot is appropriate, or a neutral protected state when
      privacy protection is active.
- [ ] Existing privacy behavior is preserved: protected lock or capture
      surfaces must not reveal sensitive user content while showing the updated
      branding or neutral protected state.
- [ ] The release and debug app identities remain visually distinguishable
      after installation, launch, app switching, and lock/protected-state
      transitions.
- [ ] The branding update does not intentionally change app navigation,
      authentication, recording, transcription, entry storage, sharing,
      backend communication, or capture-prevention behavior.
- [ ] Validation evidence includes automated checks where practical plus
      Android emulator and iOS simulator runtime verification of release
      branding, debug branding, startup behavior, lock/protected-state
      behavior, and absence of the default Flutter logo unless a
      planning-time validation exception is explicitly approved.

## API contract

This feature does not introduce or modify backend HTTP endpoints.

## Data model changes

This feature does not add, remove, or modify persisted user data models.

## Dependencies

- [ ] Existing Wrait visual identity and button treatment
- [ ] Existing release app branding surfaces
- [ ] Existing debug app branding surfaces
- [ ] Existing app startup and loading surfaces
- [ ] Existing lock, authentication, privacy, and protected-state surfaces
- [ ] Existing app-switcher and capture-privacy behavior
- [ ] Android emulator validation path
- [ ] iOS simulator validation path

## UX / design references

No external design file is provided. The requested design direction is:

- release logo: Wrait logo with the `wrait` word, using the app's current
  button treatment and matching the current app look
- debug logo: same Wrait identity, but red so the debug build is immediately
  recognizable
- app-controlled logo surfaces should always use the `wrait` word rather than
  a symbol-only mark
- protected lock/privacy surfaces may keep the current neutral presentation if
  that best preserves privacy, as long as the default Flutter logo is not
  exposed
- constrained app-controlled logo surfaces should still use the `wrait` word
  rather than falling back to a symbol-only mark
- no default Flutter logo on app-controlled user-visible surfaces

## Non-functional requirements

- **Performance:** Branding changes must not add noticeable delay to app
  startup, lock/protected-state transitions, app switching, or normal screen
  rendering.
- **Security:** Lock, authentication, privacy, and protected-state surfaces
  must continue to hide sensitive user content. Branding must not reveal local
  file paths, account identifiers, backend details, stored entry content, or
  diagnostics.
- **Reliability:** Release and debug branding must remain stable across cold
  launch, app switching, background/foreground transitions, and protected-state
  transitions.
- **Scalability:** The branding approach should support future logo color or
  wordmark refreshes without requiring unrelated app behavior changes.
- **Observability:** Validation evidence must document the checked branding
  surfaces and include Android emulator plus iOS simulator observations unless
  a planning-time validation exception is explicitly approved.

## Out of scope

- Redesigning the wider app theme, typography, navigation, recording
  interface, entry screens, or marketing content
- Changing the app name, package identifiers, bundle identifiers, signing
  identities, backend environment selection, or install coexistence behavior
- Adding a new onboarding, about, settings, or brand customization screen
- Changing lock, authentication, screenshot-prevention, screen-recording
  prevention, or privacy-cover behavior except where needed to remove Flutter
  branding from those surfaces
- Changing data storage, transcription, cleanup, sharing, or backend API
  behavior
- Updating long-lived documentation before the final SDD knowledge-capture gate

## Open questions

No open questions remain in the spec. Clarification answers recorded:

- Protected lock/privacy surfaces may keep their current presentation as long
  as the default Flutter logo is not exposed.
- App-controlled logo surfaces should always use `wrait`.
