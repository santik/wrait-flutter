# Feature Specification: Spec-Driven Process Review & Validation

> **Feature number:** 005
> **Status:** Complete
> **Author:** Codex
> **Date:** 2026-06-09
> **Work item:** PROCESS-005

## Status history

| Date       | Status | Author | Notes |
| ---------- | ------ | ------ | ----- |
| 2026-06-09 | Draft | Codex | Initial spec created from current repository workflow documents and user-approved process clarifications |
| 2026-06-09 | Draft | Codex | Clarify phase resolved rollout scope, review-skip behavior, planning-time validation exceptions, final knowledge-capture ordering, and in-place review artifact updates |
| 2026-06-09 | Complete | Codex | Updated the canonical workflow docs and templates to enforce review/fix, dual-platform validation defaults, planning-time exceptions, and the final knowledge-capture gate for future non-trivial features |

---

## Overview

The repository needs a stricter spec-driven delivery workflow so future
feature work consistently includes external review, real device-environment
verification, and deliberate knowledge capture after implementation. Today the
workflow stops after implementation and does not formally define how external
review feedback should be incorporated, when emulator-based validation is
required, or how durable implementation learnings should be preserved for
future agent and human work.

This feature defines the expected workflow behavior for future non-trivial
changes that start after this process update is adopted. It formalizes a
post-implementation review phase, establishes minimum validation expectations
for Android and iOS through emulators/simulators and integration tests, and
adds a final documentation-capture step so durable product and implementation
knowledge can be proposed and approved before being recorded in long-lived
project references.

> **Reminder:** This spec must be **purely functional and technology-agnostic**.
> Describe the problem and requirements, not the solution. Technology choices
> belong in `plan.md`.

## User stories

- As a project maintainer, I want the development workflow to pause for external review after implementation so independent feedback can shape the final result before completion.
- As a reviewer, I want review findings to be considered explicitly and transparently so fixes are planned intentionally rather than applied implicitly.
- As a product owner, I want every user flow validated on both supported mobile platforms so approval is based on evidence from realistic runtime environments.
- As a future human or AI contributor, I want durable learnings captured in project guidance documents so later work can reuse proven decisions and avoid repeating mistakes.

## Acceptance criteria

- [ ] The defined workflow for non-trivial feature work includes the ordered phases `specify -> clarify -> plan -> tasks -> analyze -> implement -> review -> fix`.
- [ ] After implementation is complete, the workflow requires the agent to stop and wait for an externally provided `review.md` artifact in the active feature folder unless a human explicitly instructs the agent to skip the review step.
- [ ] When `review.md` becomes available, the agent reads it, prepares a remediation plan, presents that plan to a human, and waits for explicit approval before updating any files.
- [ ] Review findings are evaluated case by case rather than by an automatic severity-based fix rule, and the workflow instructs the agent to ask a human when the correct response to a finding is uncertain.
- [ ] The workflow supports repeated review and fix cycles when a human indicates that the same `review.md` file has been updated for another pass.
- [ ] Every feature's validation expectations include automated integration-test coverage for every user flow in scope, unless a justified exception is proposed during planning and explicitly approved by a human.
- [ ] Every feature's validation expectations include verification on both an Android emulator and an iOS simulator before final approval.
- [ ] If required emulator or simulator verification is unavailable, the workflow prevents final approval until that verification gap is resolved rather than allowing the feature to complete with only partial evidence.
- [ ] If a human explicitly skips the review step, the workflow still requires the final knowledge-capture proposal stage before the feature can be completed.
- [ ] After the final approved implementation and after any review/fix loop is complete, the workflow requires the agent to propose durable updates to long-lived project guidance documents when the feature changed product understanding, architecture, or future implementation guidance in a way later work should know about.
- [ ] The workflow requires the agent to present those proposed long-lived documentation updates and wait for explicit human approval before editing those documents.
- [ ] The feature is not marked complete until the approved knowledge-capture step has been handled, including the case where no long-lived documentation update is needed.

## API contract

No HTTP endpoints are introduced or modified by this feature.

This feature defines repository workflow behavior, artifact expectations, and
approval gates only.

## Data model changes

This feature changes the expected lifecycle and meaning of project workflow
artifacts for future non-trivial features started under the revised process:

- feature specs gain a required post-implementation review/fix stage
- `review.md` becomes a recognized external review input artifact for feature
  folders
- validation evidence must reflect both integration-test coverage and
  dual-platform emulator/simulator verification for in-scope user flows,
  except where a human-approved planning exception exists
- long-lived project guidance documents may require a final approved update
  step when durable learnings emerge from a completed feature
- feature completion now includes an explicit post-review knowledge-capture
  decision before the spec can be marked complete

No application runtime data model changes are in scope.

## Dependencies

- [ ] Existing repository workflow documents and artifact conventions
- [ ] Feature-folder-based spec artifacts
- [ ] Availability of Android emulator and iOS simulator validation paths
- [ ] Human participation for review delivery, approval gates, and uncertainty resolution

## UX / design references

No product UI changes are introduced by this feature.

This feature governs delivery process and repository documentation only.

## Non-functional requirements

- **Performance:** Workflow updates should keep required gates explicit without adding ambiguous or duplicative steps that slow feature delivery unnecessarily.
- **Security:** Process documentation must not encourage agents to bypass review, approval gates, or required runtime validation.
- **Reliability:** Future contributors should be able to follow the workflow consistently without needing unstated tribal knowledge about review handling, validation expectations, or the final knowledge-capture gate.
- **Scalability:** The process should scale across future stories with multiple review cycles, multiple user flows, multiple contributors, and occasional human-approved validation exceptions.
- **Observability:** Feature artifacts must make it clear whether review is pending, what remediation is proposed, what validation evidence exists, whether an exception was approved, and whether long-lived documentation updates were proposed and approved.
- **Maintainability:** Durable workflow guidance should live in canonical project documents so future process changes can be made in one place and reused broadly.

## Out of scope

- Changing the functional behavior of the mobile application itself
- Requiring the agent to create `review.md`; that artifact remains externally authored
- Defining a mandatory severity-to-action mapping that automatically determines which review findings must be fixed
- Retroactively forcing already in-flight features to restart under the revised process
- Requiring long-lived documentation updates when a completed feature produced no durable learnings or future-facing changes worth preserving
- Changing the project's product roadmap outside the workflow and documentation updates needed to enforce this new process

## Open questions

None at this stage.
