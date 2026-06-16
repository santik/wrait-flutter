# Feature Specification: Android Deploy Script and App Namespace Isolation

> **Feature number:** 027
> **Status:** Approved
> **Author:** Codex
> **Date:** 2026-06-15
> **Work item:** US-027

## Status history

| Date | Status | Author | Notes |
| --- | --- | --- | --- |
| 2026-06-15 | Draft | Codex | Initial spec created from `plan/us_027.md`, `plan/README.md`, and the project SDD workflow |
| 2026-06-15 | Draft | Codex | Clarify phase resolved single-phone deployment, `com.wrait.flutter` identity, and debug-only scope |
| 2026-06-15 | Approved | Codex | User approved the finalized US-027 spec for implementation planning |

---

## Overview

Developers need a simple, repeatable way to deploy the Flutter Android app to a
single connected Android phone during local development. The command should be
easy to run from this repository, should fail clearly when no usable phone is
available, and should support the normal debug development flow.

The deployed Flutter app must coexist with the existing native Wrait Android
app on the same device. Installing a Flutter build must not replace, upgrade,
or otherwise collide with the existing Wrait Android app identity.

> **Reminder:** This spec must be **purely functional and technology-agnostic**.
> Describe the problem and requirements, not the solution. Technology choices
> belong in `plan.md`.

## User stories

- As a developer, I want one clear command to deploy the Flutter Android app so
  that I can test it quickly on the connected Android phone.
- As a developer, I want the deploy command to run the real-device test suite
  on the connected Android phone so that deployment catches device-only
  regressions before installing the app for manual testing.
- As a developer, I want the Flutter Android app to install alongside the
  existing Wrait Android app so that I can compare both apps on the same
  device without losing either installation.
- As a developer, I want deployment to fail with a clear message when no
  Android phone is available so that setup problems are obvious.
- As a developer, I want the Flutter app identity to be consistent across
  build, install, and runtime metadata so that future Android work does not
  depend on stale identity values.

## Acceptance criteria

- [ ] A single documented developer command deploys a debug build of the
      Flutter app to the connected Android phone.
- [ ] The deployment command can be run from the repository without requiring
      developers to remember a long sequence of lower-level commands.
- [ ] Deployment targets the single connected Android phone.
- [ ] The deployment command runs the Flutter integration test suite on the
      connected Android phone before the final debug app install.
- [ ] If real-device tests fail, deployment exits non-success and does not
      attempt the final debug app install.
- [ ] When no Android phone is available, deployment exits without attempting
      an install and prints a clear, actionable error message.
- [ ] The Flutter Android app has a distinct Android application identity from
      the existing Wrait Android app: `com.wrait.flutter`.
- [ ] Installing the Flutter Android app does not replace, upgrade, uninstall,
      or otherwise overwrite the existing Wrait Android app.
- [ ] The Android identity used for build, manifest/runtime metadata, and
      deployment is updated consistently wherever required.
- [ ] No remaining project-owned Android source, manifest, build, test, or
      deployment reference still uses the old Wrait Android app identity for
      the Flutter app.
- [ ] The app remains buildable and launchable on Android after the identity
      change.
- [ ] Existing non-Android app behavior is not intentionally changed by this
      feature.

## API contract

This feature does not introduce or modify backend HTTP endpoints. It defines a
developer-facing deployment contract for Android local builds.

### Deployment inputs

The deployment flow accepts:

- one connected Android phone
- the current Flutter app source tree

### Deployment outputs

The deployment flow produces:

- real-device test execution on the connected Android phone
- a debug Android app installed on the connected Android phone when deployment
  and tests succeed
- a clear failure message and non-success exit when no deployable Android phone
  can be determined or when real-device tests fail
- a distinct installed Flutter app that coexists with the existing native Wrait
  Android app

Functional expectations:

- Deployment must not require network access beyond any dependencies already
  required by the local build environment.
- Deployment must not mutate user diary data on the connected Android phone.
- Failure messages must help the developer identify whether the issue is a
  missing phone, test failure, or build/install failure.

## Data model changes

This story does not require a persistent user-data schema change.

Functional identity data affected by this feature:

- Android application identity for the Flutter app
- Android package/namespace metadata used by source, manifest, build, tests,
  and installation
- Any project-owned deployment metadata that identifies the app to install or
  launch

Functional expectations:

- The Flutter app identity is stable after this feature and does not collide
  with the existing native Wrait Android app.
- The Flutter app Android application identity is `com.wrait.flutter`.
- Existing locally stored diary entries are not migrated or modified as part of
  deployment identity changes.

## Dependencies

- [ ] Existing Flutter Android project configuration
- [ ] Existing Android build and install tooling available in the developer
      environment
- [ ] A connected Android phone for runtime verification
- [ ] Reference deployment workflows from the sibling native Android project
      for command ergonomics and failure behavior

## UX / design references

- `plan/us_027.md`
- Reference workflows in sibling `wrait-android` project, used for design
  reference only:
  - `deploy_debug.sh`
  - `deploy.sh`

## Non-functional requirements

- **Performance:** The deployment command should add no unnecessary steps beyond
  building and installing the debug Android app for local development.
- **Security:** The deployment flow must not expose secrets in command output,
  source-controlled files, or failure messages.
- **Reliability:** Missing, unauthorized, or unavailable Android phones must
  produce deterministic failures with clear messages.
- **Scalability:** The identity change should be applied in a way that future
  Android source, test, and deployment additions naturally use the Flutter app
  identity.
- **Observability:** Success and failure outcomes must be visible through
  command output and verifiable installed-app state on the connected Android
  phone.

## Out of scope

- Release signing, release distribution, or app store deployment
- Non-debug Android deployment automation
- iOS deployment automation
- Backend API changes
- User-facing app feature changes
- Data migration for existing installed Flutter builds that used the old
  Android identity
- Changing the existing native Wrait Android app
- Automatically uninstalling any app from developer devices
- Creating a full multi-environment deployment system
- Supporting multiple simultaneously connected Android targets
- Android emulator-specific deployment behavior
- Renaming product branding visible to end users unless required by Android
  install coexistence

## Open questions

- [ ] None at this stage.
