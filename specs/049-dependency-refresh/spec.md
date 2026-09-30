# Feature Specification: Dependency refresh

> **Feature number:** 049
> **Status:** Complete
> **Author:** Codex
> **Date:** 2026-09-24
> **Work item:** US-049 (local feature identifier)

## Status history

| Date | Status | Author | Notes |
| --- | --- | --- | --- |
| 2026-09-24 | Draft | Codex | Awaiting draft approval before clarification |
| 2026-09-24 | Draft | Codex | User approved initial draft; clarification in progress, finalized approval pending |
| 2026-09-24 | Draft | Codex | Clarification completed; finalized spec awaiting explicit approval |
| 2026-09-24 | Approved | Codex | User approved finalized spec; planning authorized |
| 2026-09-29 | Implemented | Codex | Approved Android validation complete; iOS exception recorded; awaiting external review |
| 2026-09-29 | Review fixes implemented | Codex | User approved all six finding dispositions; documentation/comment remediation applied; finalization and durable documentation approval pending |
| 2026-09-29 | Complete | Codex | User approved durable guidance; updates applied; approved review dispositions and validation reconciled |

## Overview

The development environment reports 89 packages with newer versions outside
current dependency constraints. Refresh the application's dependency baseline
to current stable, mutually compatible releases while preserving the existing
Android and iOS experience.

A read-only audit on 2026-09-24 found 69 dependencies that can advance within
existing constraints and six constrained below a resolvable release. These are
separate audit categories, not a reconstruction of the original warning count.
Some latest releases remain mutually incompatible. Resolve avoidable version
lag and explain verified remaining blockers instead of hiding the warning.

## User stories

- As a maintainer, I want current, reproducible dependencies so development
  benefits from supported fixes and improvements.
- As a maintainer, I want remaining outdated dependencies explained so I can
  distinguish actionable maintenance from upstream compatibility limits.
- As a user, I want updates to preserve my data, privacy, and existing workflows.

## Acceptance criteria

- [x] **AC-01 — Audit:** Record dated before-and-after audits of direct,
  development, and indirect dependencies, distinguishing lock-held versions
  from constraint-blocked versions.
- [x] **AC-02 — Refresh:** Adopt the newest stable, mutually compatible
  dependency set that passes approved validation. Reassess existing constraints
  and historical exceptions instead of assuming they remain valid. The supported
  development toolchain may advance to its latest stable release when needed
  to remove blockers, subject to the same compatibility and platform validation.
- [x] **AC-03 — Blockers:** Account for every remaining dependency below its
  latest stable release with its blocking dependency or environment requirement,
  evidence, and a condition for reconsideration. Group entries only when their
  common blocker is established. Zero outdated packages is the target where
  compatibility and validation permit it; no unexplained warning remains.
  Completion with evidence-backed upstream blockers is acceptable when zero
  outdated packages cannot be achieved safely and each remaining dependency
  is accounted for as required above.
- [x] **AC-04 — Development:** Dependency resolution, builds, analysis,
  automated tests, and generated backend-client checks succeed. Distinguish
  pre-existing failures from upgrade-induced failures in the evidence.
- [x] **AC-05 — Behavior:** Preserve startup and retry, recording and microphone
  permissions, transcription and cleanup, recoverable drafts, entry browsing,
  searching, editing, deletion, sharing, CSV import/export, and feedback.
- [x] **AC-06 — Data and privacy:** Same-identity updates preserve the current
  entry store, retained draft audio, preferences, and device identity. Preserve
  encrypted storage, app lock, capture privacy, sanitized failures, and feedback
  data restrictions.
- [x] **AC-07 — Platforms:** Fully verify affected Android emulator flows with
  recorded evidence. Retain completed iOS results; remaining iOS validation is
  explicitly waived by the user on 2026-09-28 because there are no iOS users.
- [x] **AC-08 — Reproducibility:** Record the supported development baseline and
  upgrade results so another maintainer can reproduce resolution and validation.

## API contract

No product-facing backend contract changes. Preserve existing requests,
responses, authentication, quota handling, and error behavior.

## Data model changes

No intentional entry schema or stored-data semantic changes. Preserve current
local data during normal updates. Historical entry-store migration is excluded.

## Dependencies

- Availability and compatibility of stable upstream releases.
- Existing app, platform, privacy, and backend-client contracts.
- Existing test coverage and Android/iOS validation environments.
- Coordination with unrelated entry-editing and transcription-language work
  already present in the workspace.

## UX / design references

No new interface or intended behavior changes.

## Non-functional requirements

- **Performance:** Preserve responsive, non-blocking startup and recording UI.
- **Security:** Preserve encryption and privacy boundaries. Do not bypass
  compatibility requirements or expose sensitive information to pass validation.
- **Reliability:** Keep builds reproducible and workflows functional.
- **Scalability:** Preserve existing entry-processing and import limits.
- **Observability:** Record versions, blockers, and outcomes without credentials,
  journal content, or retained audio.

## Test strategy

Reuse existing lower-level and integration coverage, adapting tests where
upgrades require meaningful compatibility checks. Planning must map every
in-scope user flow in AC-05 and AC-06 to integration coverage and Android
emulator/iOS simulator verification. Include native recording, launcher cold
start, privacy behavior, and feedback contract checks where affected.

Verify normal update preservation separately from test runners that reset or
reinstall app state. Validate the generated backend client as well as the app.
Document known recording-runner and system-picker limitations explicitly; these
do not automatically constitute approved exceptions. The explicit 2026-09-28
Android-only validation amendment below governs the remaining iOS checks.

## Out of scope

- New product features, UX redesigns, or backend service changes.
- Completing unrelated in-progress features.
- Prerelease dependencies or bypassing compatibility rules to force zero warnings.
- Shipping a release or deploying to a physical phone.
- Unrelated build-tool ecosystem upgrades unless required for this refresh.

## Clarification decisions

Confirmed by the user on 2026-09-24:

1. The development toolchain may advance to its latest stable release when
   needed to remove dependency blockers, with Android and iOS validation.
2. Verified upstream blockers may remain at completion if every remaining
   outdated dependency has evidence and an explicit explanation under AC-03.

These decisions do not waive validation requirements. Exact versions and
technical upgrade choices belong in the implementation plan.

## Open questions

None. Finalized spec, implementation plan and task checklist approved.
Implementation approved on 2026-09-25; approved validation completed on
2026-09-29. External review received and approved remediation applied. Durable guidance
was explicitly approved and applied on 2026-09-29; all SDD gates are complete.

## Approved scope amendment — 2026-09-28

The user approved dropping iOS 14 support. Wrait supports iOS 15 and newer
for this refresh; Android minimum support is unchanged. This does not waive
any platform validation requirements.

## Approved validation amendment — 2026-09-28

The user explicitly requested "fully verify android only" because there are no
iOS users yet. Full Android verification remains required. Outstanding iOS
native recording, system permission/picker/share/authentication and active-capture
checks are waived for this refresh. Retain completed iOS compile, 80-test suite,
10-test main-screen suite, and old-to-new key/data/audio preservation evidence.
The known 28-byte iOS simulator recording outcome also reproduces under the old
SDK/dependencies; record it as an unverified iOS behavior, not a passing check.
Minimum iOS 15 remains approved. This exception does not waive external review.

## Review clarification — 2026-09-29

The validation waiver is limited to this maintenance work, not a permanent
waiver for shipping iOS. Before an iOS release, verify the final dependency set
and complete the outstanding native recording, permission, file-picker, sharing,
authentication, feedback layout and capture-privacy checks. The recording
limitation must be resolved and verified before release. Durable project guidance
was updated after explicit approval on 2026-09-29.
