# Feature Specification: Release-Signed Android Deploy Flow

> **Feature number:** 031
> **Status:** Draft
> **Author:** Codex
> **Date:** 2026-06-22
> **Work item:** US-031

## Status history

| Date | Status | Author | Notes |
| --- | --- | --- | --- |
| 2026-06-22 | Draft | Codex | Initial spec created from the request for a release deployment flow that uses a stable real signing identity |

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
  a separate Android app identity so that debug deployment does not overwrite
  the locally stored state of the real update-validation install.
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
      identity used for update-compatible installs.
- [ ] The Android debug deployment flow targets a separate debug-only app
      identity rather than the real release/update app identity.
- [ ] The deployed app remains update-compatible with prior installs that use
      the same app identity and same stable signing identity.
- [ ] A debug deployment does not overwrite, replace, or clear the locally
      stored state of an installed release/update app that uses the real app
      identity.
- [ ] If the required release-signing inputs are missing, blank, unreadable, or
      invalid, the deployment flow stops before installation and reports a
      simple actionable error.
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
- [ ] Existing local/private release-signing material and associated secrets
- [ ] Existing proxy-authenticated runtime configuration needed for backend
      access during deployed app use

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
- **Scalability:** The flow should support repeated local deployments and
  future update-validation runs without requiring ad hoc manual reconfiguration.
- **Observability:** Validation evidence should show the build/deploy path used,
  the target Android app identity, and whether the install succeeded.

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

- [ ] What signing material source should be treated as canonical for this
      project's real Android signing identity?
- [ ] Should the release deployment flow keep the same physical-phone-only
      targeting rules as `deploy_debug.sh`, or may it also support emulators?
- [ ] Should the release deployment flow run integration tests before final
      install, or should it focus only on producing and installing the
      production-identity artifact?
- [ ] What runtime configuration inputs, if any, must remain mandatory for the
      deployed release-signed app to function in the current environment?
- [ ] What exact debug-only Android app identity should replace the current
      shared debug/release identity for `deploy_debug.sh`?
