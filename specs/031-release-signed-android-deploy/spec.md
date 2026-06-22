# Feature Specification: Release-Signed Android Deploy Flow

> **Feature number:** 031
> **Status:** In Progress
> **Author:** Codex
> **Date:** 2026-06-22
> **Work item:** US-031

## Status history

| Date | Status | Author | Notes |
| --- | --- | --- | --- |
| 2026-06-22 | Draft | Codex | Initial spec created from the request for a release deployment flow that uses a stable real signing identity |
| 2026-06-22 | Draft | Codex | Incorporated requested Android identity split and debug-flow preservation constraint |
| 2026-06-22 | Draft | Codex | Clarified signing source, device targeting, release-flow scope, and runtime configuration discovery |
| 2026-06-22 | Draft | Codex | Added requirement to copy private release-signing settings into the Flutter app's private Android configuration location |
| 2026-06-22 | Approved | User | Approved finalized spec and authorized planning |
| 2026-06-22 | In Progress | Codex | Implemented code and automated validation; physical-phone verification and external review still pending |
| 2026-06-22 | In Progress | Codex | Completed physical-phone validation; external review still pending |
| 2026-06-22 | In Progress | Codex | Applied approved review fixes for transient signing-secret handling, keystore preflight, atomic config sync, and release connectivity documentation |

---

## Overview

Wrait currently has an Android debug deployment flow for local real-device
validation, but that flow does not represent a true production-style install
identity. For update validation, release-like installs, and future operator use,
the project also needs a reliable way to build and deploy an Android app
package that uses the app's stable real signing identity instead of temporary
debug signing.

The goal of this feature is to let an operator deploy the Android app to a
connected device through a simple repeatable release deployment flow that keeps
the app update-compatible with prior installs signed by the same real identity.
That flow must fail clearly when required signing inputs are unavailable and
must avoid exposing signing secrets in source control.

The release deployment flow also needs clear separation from the existing debug
deployment flow. Debug deployment should no longer target the same installed
Android app identity that real update validation depends on, so that routine
debug installs and integration-test deploys do not overwrite or reset the app
state being validated through the release path.

The real release/update-validation Android app identity is
`com.wrait.flutter`. The debug-only Android app identity is
`com.wrait.flutter.dev`. Existing debug deployment behavior should remain the
same from an operator perspective except where identity separation is necessary
to protect the release/update app state.

The release deployment flow should use the project's existing private Android
deployment configuration as the canonical source for release-signing inputs.
That private configuration is not tracked source material and must remain
outside versioned code. The Flutter Android project should receive those
release-signing settings in the private app-local configuration location that
its build uses for signing, without committing or logging secret values.
Non-secret signing settings may be synchronized into that private app-local
configuration, while secret passwords may be supplied only for the active
deployment/build process. The
release deployment flow should target the same kind of connected physical
Android phone used by the existing debug deployment flow. It should focus on
producing and installing the real release-signed app package; integration tests
are not part of the release deployment flow itself.

> **Reminder:** This spec must be **purely functional and technology-agnostic**.
> Describe the problem and requirements, not the solution. Technology choices
> belong in `plan.md`.

## User stories

- As a developer or operator, I want one repeatable Android release deployment
  flow so that I can install a production-identity build without manual signing
  steps.
- As a developer validating update behavior, I want the deployed Android build
  to use the stable real app signing identity so that in-place updates behave
  like real user installs.
- As a developer using the debug deployment flow, I want debug installs to use
  the `com.wrait.flutter.dev` Android app identity so that debug deployment does
  not overwrite the locally stored state of the real update-validation install.
- As a developer or operator, I want signing prerequisites to fail with clear
  guidance so that missing or incorrect release-signing setup does not produce
  confusing deployment failures.
- As a project maintainer, I want signing secrets kept out of versioned source
  files so that release deployment does not weaken the project's security
  posture.

## Acceptance criteria

- [ ] The project provides one documented Android release deployment flow that
      can be run locally without manually invoking multiple build and signing
      steps.
- [ ] The deployment flow installs the Flutter Android app using the stable real
      app signing identity rather than a debug-only signing identity.
- [ ] The Android release deployment flow targets the existing real Flutter app
      identity used for update-compatible installs: `com.wrait.flutter`.
- [ ] The Android debug deployment flow targets a separate debug-only app
      identity, `com.wrait.flutter.dev`, rather than the real release/update app
      identity.
- [ ] Existing debug deployment behavior remains functionally unchanged except
      for the minimum changes required to target the debug-only app identity and
      preserve release/update app state.
- [ ] The deployed app remains update-compatible with prior installs that use
      the same app identity and same stable signing identity.
- [ ] A debug deployment does not overwrite, replace, or clear the locally
      stored state of an installed release/update app that uses the real app
      identity.
- [ ] The release deployment flow targets the same single connected physical
      Android phone class as the existing debug deployment flow.
- [ ] The release deployment flow produces and installs the release-signed app
      package only; it does not run integration tests as part of the release
      deployment flow.
- [ ] If the required release-signing inputs are missing, blank, unreadable, or
      invalid, the deployment flow stops before installation and reports a
      simple actionable error.
- [ ] The Flutter Android project consumes the release-signing settings from an
      app-local private configuration location populated from the canonical
      private Android deployment configuration.
- [ ] Secret signing passwords are not persisted into the Flutter app-local
      private configuration file beyond the active deployment/build process.
- [ ] If required runtime configuration inputs cannot be determined from the
      existing private Android deployment configuration, the deployment flow
      stops before installation and reports a simple actionable error.
- [ ] The release deployment flow does not require committing signing secrets,
      passwords, or private key material into tracked project files.
- [ ] The deployment flow does not uninstall or remove the older native Android
      Wrait app when that separate app identity is already present on the
      device.
- [ ] The deployment flow verifies that the intended Flutter Android app
      identity is installed after deployment.
- [ ] The deployment flow is validated on a connected Android device using a
      real release-signed install path.
- [ ] The feature does not change iOS deployment behavior.

## API contract

This feature does not introduce or modify backend HTTP endpoints.

## Data model changes

This feature does not change the diary data model or backend contract.

It may introduce new local deployment configuration inputs for signing, but
those are operational inputs rather than product data-model changes.

It may also introduce a separate Android debug application identity to isolate
debug installs from release/update installs, but that is an app-packaging and
deployment concern rather than a diary data-model change.

## Dependencies

- [ ] Existing Flutter Android application identity and build configuration
- [ ] Existing Android debug deployment workflow and package-identity checks
- [ ] Existing Android real-device deployment workflow expectations
- [ ] Existing local/private Android deployment configuration that stores
      release-signing material references and associated secrets outside tracked
      source
- [ ] Flutter Android app-local private configuration location used by the build
      to consume release-signing settings
- [ ] Existing runtime configuration needed for backend access during deployed
      app use

## UX / design references

No in-app UX changes are expected. This is an operator/developer deployment
workflow feature.

## Non-functional requirements

- **Performance:** The deployment flow should remain practical for ordinary
  local operator use and should not add unnecessary build/install steps beyond
  what is needed for a real signed install.
- **Security:** Private signing material, passwords, and other secrets must not
  be committed to source control or printed unnecessarily in logs.
- **Reliability:** The deployment flow should fail early on invalid setup and
  should consistently produce an installable production-identity Android app.
- **Isolation:** Debug and release deployment flows must not contend for the
  same installed Android app identity when that would risk overwriting local
  state needed for update validation.
- **Compatibility:** The existing debug deployment flow should retain its
  current operator-facing behavior with minimal changes, apart from the required
  move to the debug-only Android app identity.
- **Scalability:** The flow should support repeated local deployments and
  future update-validation runs without requiring ad hoc manual reconfiguration.
- **Observability:** Validation evidence should show the build/deploy path used,
  the target Android app identity, the device targeting path, and whether the
  install succeeded.

## Out of scope

- iOS release deployment
- Play Store submission, Play Console upload, staged rollout, or store review
- App Bundle publishing workflows unless later planning proves they are
  required for the local deployment goal
- Rotating or replacing the existing production signing identity
- Migrating installs between different Android app identities
- Preserving shared local app data between the separate debug and release app
  identities
- Changing backend APIs, diary behavior, or local database structure

## Open questions

None.

## Clarification notes

- Canonical release-signing inputs come from the existing private Android
  deployment configuration under `wrait-android/local.properties`; tracked
  project files must not contain signing secrets or private key material.
- The release-signing settings should be copied or synchronized into the Flutter
  Android app's private build configuration location during implementation, not
  into tracked source files. Secret passwords may remain transient inputs
  rather than persisted file values in that target location.
- Release deployment should use the same connected physical-phone targeting
  model as the existing debug deployment flow.
- Release deployment should only build and install the release-signed artifact;
  integration tests are outside the release deployment flow.
- Runtime configuration inputs are not separately known at the specification
  level. Planning and implementation should discover the required values from
  existing private deployment configuration and fail clearly before installation
  when required values are unavailable.
- Release deployment must preserve backend connectivity for the production app
  identity, including any Android manifest permissions needed for production
  backend calls.
