# Feature Specification: Flutter Project Foundation

> **Feature number:** 002
> **Status:** Complete
> **Author:** Codex
> **Date:** 2026-06-03
> **Work item:** US-001

## Status history

| Date       | Status | Author | Notes |
| ---------- | ------ | ------ | ----- |
| 2026-06-03 | Draft | Codex | Initial spec created from `plan/us_001.md` and Flutter platform setup requirements |
| 2026-06-03 | Approved | Codex | Clarifications accepted: privacy mode deferred, single placeholder screen is sufficient, scope limited to structure and configuration only, no extra runtime flags |
| 2026-06-03 | In Progress | Codex | Flutter foundation scaffolded and validated with analyze, tests, and Android debug build; Android/iOS launch verification remains blocked by local device/tooling setup |
| 2026-06-04 | Complete | Codex | Android emulator and iOS simulator launch validation completed with runtime config values visible on both platforms |

---

## Overview

The product currently has Android-specific implementation references and a set of upcoming mobile stories, but it does not yet have a shared Flutter application foundation that those stories can build on consistently. Without that foundation, each future story would need to make its own assumptions about app structure, platform setup, runtime configuration, and development quality gates, increasing rework and inconsistency.

This feature establishes the baseline cross-platform mobile application shell for the new client so later stories can be implemented on top of a stable foundation. The baseline must support development on current Android and iOS targets, expose the runtime configuration needed by later recording and backend-connected flows, and include the device capability declarations required for recording-related experiences to work when those features are added.

> **Reminder:** This spec must be **purely functional and technology-agnostic**.
> Describe the problem and requirements, not the solution. Technology choices
> belong in `plan.md`.

## User stories

- As a developer, I want a shared mobile app foundation so that future stories can be added without reworking the project structure each time.
- As a developer, I want environment-specific runtime settings to be supplied without source changes so that development, test, and production builds can target the correct services and limits.
- As a developer, I want clear separation between app foundation, business logic, data access, and presentation concerns so that the codebase stays maintainable as more stories are implemented.
- As a mobile user, I want the app to declare the recording- and speech-related device capabilities it needs so that future features can request access correctly on supported devices.

## Acceptance criteria

- [ ] A baseline mobile app can be launched in development on supported Android and iOS targets from this repository.
- [ ] The baseline app exposes a clear top-level structure that separates shared foundation concerns, data concerns, domain concerns, and presentation concerns for future stories.
- [ ] Runtime configuration for backend connectivity, proxy authentication, and recording duration limits can be supplied per build and read by the app at runtime without source edits.
- [ ] Required platform permission and privacy declarations for microphone access and speech recognition are present so future recording flows can request access correctly on both platforms.
- [ ] The baseline app includes the supporting foundation needed for upcoming stories without introducing build-time dependency or configuration conflicts.
- [ ] Static analysis for the baseline project completes with zero warnings.
- [ ] A single placeholder screen is sufficient to verify the app shell launches; no additional user-facing flows are required in this story.

## API contract

No HTTP endpoints are introduced or modified by this feature.

The feature only establishes the client application's ability to receive and expose runtime configuration required by future backend-connected features.

## Data model changes

No persistent user data model is introduced or changed by this feature.

The feature does require a defined runtime configuration surface for later stories. At minimum, that surface must cover:

- backend service base URL
- proxy authentication secret
- recording hard-cap duration

No migration is required because this is initial project foundation work.

## Dependencies

- [ ] Product requirements in [plan/functionality.md](/Users/alexander/projects/wrait/write-flutter/plan/functionality.md)
- [ ] Existing Android reference values and platform requirements in [wrait-android/build.gradle.kts](/Users/alexander/projects/wrait/write-flutter/wrait-android/build.gradle.kts) and [wrait-android/local.properties](/Users/alexander/projects/wrait/write-flutter/wrait-android/local.properties)
- [ ] Supported mobile development targets for Android and iOS

## UX / design references

No dedicated design artifact was provided for this setup story.

The app shell only needs to be sufficient to validate launch, structure, and configuration readiness for future stories.

## Non-functional requirements

- **Performance:** The baseline app startup path should remain lightweight and should not do unnecessary work before any feature-specific flows are added.
- **Security:** Environment-specific secrets and service addresses must be supplied through runtime/build configuration rather than hardcoded in source, and sensitive configuration must not be exposed in logs unnecessarily.
- **Reliability:** Missing or invalid runtime configuration must fail clearly enough for developers to diagnose during setup, and platform capability declarations must be consistent with the intended recording-related flows.
- **Scalability:** The project foundation must support adding the Phase 1 Flutter stories without requiring a top-level structural rewrite.
- **Observability:** Implementation must produce validation evidence that launch, configuration access, and static analysis succeed for the baseline project.
- **Maintainability:** The initial project structure should make ownership boundaries obvious so future features can be added with minimal cross-layer coupling.
- **Scope control:** This story is limited to project structure, platform configuration, dependency readiness, and runtime configuration access. It must not introduce placeholder domain/service implementations beyond what is strictly needed to prove the app shell and configuration work.

## Out of scope

- Implementing actual recording, transcription, sharing, persistence, or biometric flows
- Reproducing the full Android feature set in Flutter
- Final product UI design beyond a minimal shell needed for launch validation
- Adding starter navigation flows or multiple screens beyond the single placeholder launch screen
- Defining placeholder service interfaces for future storage, networking, recording, permission, or secure-storage features unless a minimal interface is strictly required by the chosen app bootstrap
- Privacy mode behavior and any related runtime configuration
- Production release hardening such as store assets, signing workflows, or CI/CD automation unless later approved
- Analytics, experimentation, or additional runtime flags not required for this foundation story

## Open questions
None at this stage.
