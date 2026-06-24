# Feature Specification: Dependency Constraint Refresh

> **Feature number:** 034
> **Status:** Complete
> **Author:** Codex
> **Date:** 2026-06-23
> **Work item:** US-034

## Status history

| Date | Status | Author | Notes |
| --- | --- | --- | --- |
| 2026-06-23 | Draft | Codex | Initial spec created from dependency-resolution output showing newer versions blocked by constraints |
| 2026-06-24 | Draft | Codex | Expanded scope to include Flutter SDK/toolchain version update |
| 2026-06-24 | Draft | Codex | Recorded clarification answers for toolchain target, dependency freshness, and validation scope |
| 2026-06-24 | Approved | User | Finalized spec approved for planning |
| 2026-06-24 | In Progress | Codex | Implementation completed and validation evidence recorded; awaiting external review |
| 2026-06-24 | Complete | Codex | Review fixes, durable documentation updates, and final validation evidence completed |

---

## Overview

Wrait should keep its Flutter toolchain and third-party dependency set current
enough that routine dependency resolution does not report a large set of
packages with newer available versions blocked by the app's constraints. The
current dependency resolution output reports 32 packages with newer versions
that cannot be used under the existing constraints, including app-facing,
development, generated code, platform, analyzer, testing, storage, and
recording dependencies.

This maintenance story defines the expected outcome for refreshing dependency
constraints and the Flutter SDK/toolchain safely: the project should resolve
cleanly against supported current versions, existing Wrait behavior should
remain unchanged, and any package or toolchain update intentionally left behind
should have a clear, reviewable reason.

The target is the latest stable Flutter release/channel available when the
implementation plan is prepared. Package updates should make a best-effort
move toward the freshest compatible versions, while allowing documented
exceptions when a package cannot be safely or compatibly updated within this
maintenance story.

> **Reminder:** This spec must be **purely functional and technology-agnostic**.
> Describe the problem and requirements, not the solution. Technology choices
> belong in `plan.md`.

## User stories

- As a maintainer, I want dependency constraints to allow current supported
  package versions so that routine development starts from a healthy dependency
  baseline.
- As a maintainer, I want the Flutter SDK/toolchain target to be current and
  explicit so that Android, iOS, test, and build workflows use a supported
  foundation.
- As a maintainer, I want dependency updates to preserve existing app behavior
  so that maintenance work does not introduce product regressions.
- As a maintainer, I want any intentionally deferred package update to be
  documented so that future work can understand the remaining risk and reason.
- As a user, I want Wrait's recording, entry, privacy, and startup behavior to
  continue working after dependency maintenance so that the app remains
  reliable.

## Acceptance criteria

- [ ] Dependency resolution no longer reports the same 32-package set as newer
      versions blocked by project constraints.
- [ ] Each package reported in the triggering dependency output is either
      updated to a currently resolvable supported version or explicitly
      documented as intentionally deferred with a concrete reason.
- [ ] The Flutter SDK/toolchain target is updated to the latest stable release
      available when the implementation plan is prepared, or any intentional
      deferral is documented with a concrete reason.
- [ ] Dependency updates use a best-effort approach to keep the freshest
      compatible versions available within the selected Flutter SDK/toolchain
      target.
- [ ] The refreshed dependency graph remains compatible with the project's
      supported Android, iOS, and development workflows.
- [ ] The project's declared language/runtime constraints match the selected
      Flutter SDK/toolchain target.
- [ ] Existing user-facing flows for startup, recording, entry list, entry
      detail, sharing, deletion, app lock, screenshot/screen-recording
      protection, draft retry, and backend connectivity are not intentionally
      changed.
- [ ] Existing generated-backend API usage continues to resolve successfully
      after the dependency refresh.
- [ ] Existing local data, encrypted storage, secure storage, audio recording,
      permissions, and platform privacy behavior remain intact.
- [ ] Automated validation covers dependency resolution, static analysis, unit
      tests, and app validation checks approved in the plan.
- [ ] Runtime validation includes Android emulator and iOS simulator checks
      before final approval unless a planning-time validation exception is
      explicitly approved.
- [ ] No new user-visible feature, UI redesign, backend contract change, or
      data model change is introduced as part of this maintenance story.

## API contract

This feature does not introduce or modify backend HTTP endpoints.

## Data model changes

This feature does not intentionally add, remove, or modify persisted data
models. If a dependency update requires a persistence, schema, generated-code,
or platform-storage compatibility change, that change must be surfaced during
planning before implementation proceeds.

## Dependencies

- [ ] Current project dependency manifest and lockfile
- [ ] Current Flutter SDK/toolchain installation or version manager
- [ ] Package registry availability for dependency resolution
- [ ] Existing generated backend API package
- [ ] Existing Android and iOS build configurations
- [ ] Existing automated test and integration-test suites
- [ ] Android emulator validation path
- [ ] iOS simulator validation path

## UX / design references

No UX or design changes are intended. Any user-visible change discovered during
implementation should be treated as a potential regression unless explicitly
approved through the SDD process.

## Non-functional requirements

- **Performance:** Dependency maintenance must not introduce noticeable startup,
  recording, navigation, database, or entry-list performance regressions.
- **Security:** Security-sensitive dependency areas, including encrypted local
  storage, device authentication, platform privacy protections, networking, and
  generated API clients, must remain at least as protective as before.
- **Reliability:** Existing startup, retry, recording, persistence, deletion,
  sharing, and app-lock behavior must continue to work after the dependency
  refresh.
- **Scalability:** The refreshed Flutter toolchain and dependency set should
  support routine future package maintenance without requiring broad unrelated
  rewrites.
- **Observability:** Validation evidence must include dependency-resolution
  output, automated command output, and app validation evidence for the checks
  approved in the plan.

## Out of scope

- New product features or behavior changes
- UI redesigns, copy changes, or navigation changes
- Backend endpoint, authentication, quota, transcription, or cleanup contract
  changes
- Data model changes or migrations unless a dependency compatibility issue is
  explicitly approved during planning
- Replacing major app architecture patterns
- Adding new runtime dependencies that are not needed for the dependency
  refresh
- Dependency audit or security-report generation beyond app validation checks
- Updating unrelated long-lived documentation before the final SDD
  knowledge-capture gate

## Open questions

No open questions remain in the spec. Clarification answers recorded:

- Target the latest stable Flutter release/channel available when the plan is
  prepared.
- Make a best-effort move toward the freshest compatible dependency versions.
- It is acceptable for some dependencies to remain behind when a fully clean
  dependency-health report is not safely or compatibly achievable.
- Validation should cover app validation checks only; no separate dependency
  audit/security report is in scope.
