# Implementation: Spec-Driven Process Review & Validation

> **Feature number:** 005
> **Spec:** [`spec.md`](spec.md)
> **Plan:** [`plan.md`](plan.md)
> **Tasks:** [`tasks.md`](tasks.md)
> **Author:** Codex
> **Date:** 2026-06-09

## Summary

This feature updates the repository's canonical spec-driven workflow so future
non-trivial features follow `specify -> clarify -> plan -> tasks -> analyze ->
implement -> review -> fix`, with explicit handling for external review,
dual-platform validation defaults, planning-time validation exceptions, and a
final knowledge-capture approval gate.

## Key implementation points

- Rewrote [CONSTITUTION.md](/Users/alexander/projects/wrait/write-flutter/CONSTITUTION.md) so the governing rules now include the review/fix phases, the externally authored `review.md` artifact, stricter validation expectations, and the final documentation gate.
- Updated [AGENTS.md](/Users/alexander/projects/wrait/write-flutter/AGENTS.md) so future agent runs are instructed to wait for `review.md`, present a remediation plan before changing files, treat review findings case by case, and require explicit approval for long-lived documentation updates.
- Reworked [docs/spec-driven-workflow.md](/Users/alexander/projects/wrait/write-flutter/docs/spec-driven-workflow.md) into an eight-phase workflow with explicit review-loop behavior, validation-exception handling, and an updated definition of done.
- Updated [specs/README.md](/Users/alexander/projects/wrait/write-flutter/specs/README.md) plus the [plan template](/Users/alexander/projects/wrait/write-flutter/specs/_templates/plan.md) and [tasks template](/Users/alexander/projects/wrait/write-flutter/specs/_templates/tasks.md) so new feature folders inherit the revised process expectations by default.

## Validation

Approved validation exception for this feature:

- No `integration_test` coverage, because this story changes repository
  process documents only and introduces no mobile user flow.
- No Android emulator verification, because no app runtime behavior changed.
- No iOS simulator verification, because no app runtime behavior changed.

Validation performed:

- End-to-end artifact consistency review across:
  - `CONSTITUTION.md`
  - `AGENTS.md`
  - `docs/spec-driven-workflow.md`
  - `specs/README.md`
  - `specs/_templates/plan.md`
  - `specs/_templates/tasks.md`
- Keyword review to confirm the updated docs explicitly cover:
  - `review.md` as an external artifact
  - no file changes after reading review until the remediation plan is approved
  - case-by-case review triage with human escalation on uncertainty
  - repeated review rounds on the same `review.md`
  - skip-review still requiring the final knowledge-capture gate
  - completion being blocked until the knowledge-capture gate is handled

## Notes

- This process update applies only to future non-trivial features that start
  after adoption of the revised workflow.
- No additional long-lived documentation proposal step was required for this
  feature itself because the long-lived workflow documents were the primary
  implementation target of the approved scope.
