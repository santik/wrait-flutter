# Feature Specification: Connected Device Tests With Screen Off

> **Feature number:** 029
> **Status:** Approved
> **Author:** Codex
> **Date:** 2026-06-17
> **Work item:** US-029

## Status history

| Date | Status | Author | Notes |
| --- | --- | --- | --- |
| 2026-06-17 | Draft | Codex | Initial spec created from the developer request to run connected-device tests, especially `deploy_debug.sh`, when the phone screen starts switched off |
| 2026-06-17 | Draft | Codex | Clarify phase resolved wake behavior, post-run power-state handling, command scope, and locked-phone expectations |
| 2026-06-17 | Draft | Codex | Clarified that ordinary locked-phone state is in scope and must work without phone interaction |
| 2026-06-17 | Approved | Codex | User approved the finalized US-029 spec for implementation planning |
| 2026-06-17 | Approved | Codex | Clarified during planning that the workflow may keep the phone awake if needed |
| 2026-06-18 | Approved | Codex | Review remediation aligned the deploy contract with physical-device evidence that the debug test artifact and final installed artifact may differ when the validation phone cannot reliably cold-launch a standalone debug install |

---

## Overview

Developers need the connected Android phone test and deployment workflow to be
reliable even when the phone display is switched off and the phone is locked
before the command starts. The current workflow is intended to be a repeatable
local validation command, but it can still depend on manual device attention if
the phone is asleep, locked, or otherwise not ready to show and exercise the app
under test.

This feature makes the developer-facing connected-device workflow work from a
screen-off, locked starting state without requiring physical interaction with
the phone during the run. The workflow may wake the phone automatically. It does
not need to restore the previous screen or power state after completion. The
workflow may also keep the phone awake when needed to complete the automated
test, install, and launch sequence. The real-device test phase still uses the
debug/integration channel. If the validation phone cannot reliably cold-launch
the final standalone debug install, the workflow may deploy a different
non-release developer build artifact after the tests pass, as long as that
artifact choice is documented and the final launch is still verified.

> **Reminder:** This spec must be **purely functional and technology-agnostic**.
> Describe the problem and requirements, not the solution. Technology choices
> belong in `plan.md`.

## User stories

- As a developer, I want connected Android device tests to run successfully
  when the phone screen is switched off and the phone is locked before the
  command starts so that I do not have to manually wake or touch the phone
  before every validation run.
- As a developer, I want `./deploy_debug.sh` to handle a screen-off connected
  phone before it runs real-device tests so that debug deployment remains a
  single reliable command.
- As a developer, I want clear failure messages when the phone cannot be made
  test-ready so that I know whether to unlock, authorize, reconnect, or change
  device settings.
- As a developer, I want the workflow to preserve the phone's user data and
  avoid weakening existing test and deployment safeguards so that convenience
  does not hide real failures.

## Acceptance criteria

- [ ] A developer can start the real-device test workflow while the single
      connected Android phone's screen is switched off and the phone is locked.
- [ ] `./deploy_debug.sh` prepares the connected phone for its real-device test
      phase without requiring the developer to manually wake, unlock, or touch
      the phone.
- [ ] An ordinary locked-phone state is supported; the developer must not need
      to unlock the phone by hand for the script to proceed.
- [ ] `./deploy_debug.sh` is the only required entry point for this feature; no
      standalone connected-device test command is required.
- [ ] The workflow may wake the phone automatically when preparing it for
      testing.
- [ ] The workflow may keep the phone awake during the deploy/test run when
      needed to avoid screen-off interruptions.
- [ ] The workflow does not need to restore the phone's previous screen,
      locked, or power state after completion.
- [ ] `./deploy_debug.sh` still builds the debug test app, runs the integration
      test suite on the connected phone, installs the final developer app only
      after tests pass, and verifies the installed app launch.
- [ ] If the connected validation phone cannot reliably cold-launch the final
      standalone debug install, the workflow may install a different non-release
      developer build artifact after the debug test phase, but the chosen final
      artifact type must be documented and the launch verification must still
      pass.
- [ ] If the phone is connected but cannot be made ready for automated testing,
      the workflow exits non-success and prints a clear, actionable message.
- [ ] The failure message distinguishes screen/lock/readiness problems from
      missing phone, unauthorized phone, build failure, test failure, install
      failure, and launch failure where practical.
- [ ] The workflow does not uninstall apps, clear app data, delete diary data,
      or otherwise mutate user content as part of preparing the phone.
- [ ] The workflow preserves the existing single connected physical phone
      targeting behavior and continues to ignore Android emulators for
      `./deploy_debug.sh`.
- [ ] The workflow preserves the existing requirement that `PROXY_SECRET` be
      present and valid before deploy-time backend-authenticated testing.
- [ ] Existing test assertions are not weakened to make screen-off runs pass.
- [ ] The behavior is documented for developers, including any device
      preconditions that cannot be handled automatically.

## API contract

This feature does not introduce or modify backend HTTP endpoints. It defines a
developer-facing connected-device readiness contract for local Android test and
debug deployment flows.

### Connected-device readiness inputs

The workflow accepts:

- one connected physical Android phone
- the current Flutter app source tree
- required runtime configuration for debug deployment
- an initial phone state where the display may be off and the phone may be
  locked

### Connected-device readiness outputs

The workflow produces:

- a phone state suitable for running the existing real-device integration tests
- the existing test, install, and launch outcomes when the phone becomes ready
- a final installed developer app artifact that is launchable on the validated
  physical phone after the test phase
- a clear non-success failure when the phone is unavailable, unauthorized, not
  test-ready, or cannot run the automated flow

Functional expectations:

- The workflow must not require network access beyond dependencies already
  required by the local build, test, backend-registration, and deployment path.
- The workflow must not hide or convert real test failures into success.
- The workflow may change transient screen or lock presentation state as needed
  to run tests, but it does not need to restore that state afterward.
- The workflow may keep the phone awake during the command when needed to make
  the automated run reliable.
- The workflow may use one non-release build artifact for the connected-phone
  test phase and another non-release build artifact for the final installed app
  when the validation phone requires that split for reliable launch behavior.
- The workflow must make device-readiness failures understandable from command
  output alone.

## Data model changes

This story does not require a persistent user-data schema change.

Functional state affected by this feature:

- transient connected-phone readiness for automated local testing
- developer-visible command status and failure messages

Functional expectations:

- User diary entries, preferences, device identifiers, quotas, and drafts are
  not migrated or modified by this feature.
- Existing app package identity remains unchanged.
- Previous screen, lock, or power presentation state is not treated as
  persistent application data and does not need restoration.

## Dependencies

- [ ] Existing connected physical Android phone deployment workflow
- [ ] Existing Flutter integration tests used by the Android real-device flow
- [ ] Existing debug runtime configuration requirements for backend
      registration and proxy-authenticated traffic
- [ ] Android phone configured for local development and USB debugging
- [ ] Android phone lock configuration that allows the app and test runner to
      be launched through the existing local development channel without
      entering private credentials by hand

## UX / design references

- `deploy_debug.sh`
- `plan/us_027.md`
- `plan/us_028.md`
- `docs/agent-findings.md` deployment guidance for US-027 and US-028

## Non-functional requirements

- **Performance:** Device-readiness handling should add only the time required
  to make the connected phone test-ready and should avoid unnecessary waiting
  once the phone is ready.
- **Security:** The workflow must not print secrets, weaken `PROXY_SECRET`
  validation, bypass USB debugging authorization requirements, or expose user
  diary content.
- **Reliability:** Screen-off and not-ready device states must result in
  deterministic success or clear failure rather than flaky timeouts.
- **Scalability:** The behavior should be expressed as a reusable deploy/test
  workflow expectation so future real-device checks can rely on the same
  readiness contract.
- **Observability:** Command output must show when the workflow is preparing the
  connected phone and whether readiness succeeded or failed.

## Out of scope

- iOS simulator or iOS physical-device automation
- Android emulator deployment behavior for `./deploy_debug.sh`
- Release signing, release distribution, or app store deployment
- Backend API changes
- Product UI changes inside the Wrait app
- Changing the app's recording keep-screen-on behavior
- Restoring the phone's previous screen, locked, or power state after the run
- Automatically uninstalling apps or clearing app data from the phone
- Creating a standalone connected-device test command separate from
  `./deploy_debug.sh`
- Supporting multiple simultaneously connected Android targets
- Guaranteeing execution on devices whose security policy blocks app or test
  runner launch through the local development channel until private credentials
  are entered by hand

## Open questions

- [ ] None at this stage.
