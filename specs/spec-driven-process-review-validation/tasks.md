# Tasks: Spec-Driven Process Review & Validation

> **Feature number:** 005
> **Plan:** [`plan.md`](plan.md)
> **Author:** Codex
> **Date:** 2026-06-09

---

## Legend

- `[ ]` — not started
- `[x]` — complete
- `[P]` — can be parallelized with other `[P]` tasks in the same group
- `[B]` — blocked (note the blocker)

## Task groups

_Tasks are organized into sequential groups.
Tasks within the same group marked `[P]` can be worked on in parallel._

### Group 1: Canonical workflow updates

_Update the core process definitions that future work relies on._

- [x] Revise the workflow loop, review/fix phases, and definition of done in `docs/spec-driven-workflow.md`
- [x] Update governing principles and validation expectations in `CONSTITUTION.md`
- [x] Update agent execution rules in `AGENTS.md`

### Group 2: Future-feature scaffolding updates

_Make the revised process visible in starter guidance and templates._

- [x] Update `specs/README.md` so future contributors see the new lifecycle and artifact expectations
  - Depends on: Group 1
- [x] [P] Update `specs/_templates/plan.md` to require documentation of user-flow `integration_test` coverage, Android/iOS emulator verification, and any requested validation exception
  - Depends on: Group 1
- [x] [P] Update `specs/_templates/tasks.md` to reflect review/fix handling, validation evidence expectations, and the final knowledge-capture gate
  - Depends on: Group 1

### Group 3: Feature artifact alignment

_Keep this process feature’s own artifacts accurate as the implementation lands._

- [x] Update `specs/005-spec-driven-process-review-validation/plan.md` if implementation details or the approved validation exception need to be reflected more precisely
  - Depends on: Group 2
- [x] Update `specs/005-spec-driven-process-review-validation/implementation.md` with the final process-change summary after implementation is complete
  - Depends on: Group 4

### Group 4: Validation

_Validate the documentation changes and record the approved exception path._

- [x] Record the approved validation exception for this documentation-only feature in the implementation evidence
  - Depends on: Group 3
- [x] Perform an end-to-end consistency pass across `docs/spec-driven-workflow.md`, `CONSTITUTION.md`, `AGENTS.md`, `specs/README.md`, `specs/_templates/plan.md`, and `specs/_templates/tasks.md`
  - Depends on: Group 3
- [x] Confirm the updated docs state that `review.md` is externally authored and that no files may change after reading it until the remediation plan is approved
  - Depends on: Group 3
- [x] Confirm the updated docs state that review findings are judged case by case, with human escalation when the correct response is unclear, and that repeated review rounds reuse the same `review.md` file
  - Depends on: Group 3
- [x] Confirm the updated docs state that explicitly skipping review still requires the final knowledge-capture proposal stage
  - Depends on: Group 3
- [x] Confirm the updated docs state that final knowledge-capture proposals require explicit approval before editing long-lived guidance docs
  - Depends on: Group 3
- [x] Confirm the updated docs state that a feature cannot be marked complete until the knowledge-capture gate has been handled, including the case where no durable doc update is needed
  - Depends on: Group 3

## Completion criteria

All tasks checked, workflow documents/templates aligned, approved validation
exception documented for this feature, and validation evidence recorded in
this file or linked from here.

## Validation evidence

_Record test results, screenshots, or curl output here when complete._

```text
Approved validation exception for this feature:
- Skip `integration_test` coverage because this is a documentation-only process
  update with no mobile user flow.
- Skip Android emulator verification because no app runtime behavior changed.
- Skip iOS simulator verification because no app runtime behavior changed.

Consistency review performed against:
- `CONSTITUTION.md`
- `AGENTS.md`
- `docs/spec-driven-workflow.md`
- `specs/README.md`
- `specs/_templates/plan.md`
- `specs/_templates/tasks.md`

Verification notes:
- Confirmed the new ordered workflow appears in the canonical docs.
- Confirmed `review.md` is described as externally authored.
- Confirmed no-files-changed-before-remediation-approval wording is present.
- Confirmed repeated review rounds reuse the same `review.md` file.
- Confirmed skip-review still leads to the final knowledge-capture gate.
- Confirmed final completion depends on handling the knowledge-capture gate.
```

## Notes

- The approved validation exception remained appropriate throughout implementation.
- No additional plan changes were needed beyond the approved exception and file inventory updates completed during analysis.
