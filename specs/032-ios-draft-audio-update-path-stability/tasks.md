# Tasks: [Feature Name]

> **Feature number:** NNN
> **Plan:** [`plan.md`](plan.md)
> **Author:** [name]
> **Date:** YYYY-MM-DD

---

## Legend

- `[ ]` — not started
- `[x]` — complete
- `[P]` — can be parallelized with other `[P]` tasks in the same group
- `[B]` — blocked (note the blocker)

## Task groups

Tasks are organized into sequential groups. Tasks within the same group marked
`[P]` can be worked on in parallel after their group prerequisites are met.

### Group 1: [Foundational work]

- [ ] [Concrete task]
- [ ] [Concrete task]

### Group 2: [Main implementation]

- [ ] [Concrete task]
- [ ] [Concrete task]

### Group 3: [Validation]

- [ ] Run [specific test / command]
- [ ] Verify [runtime behavior]

### Group 4: Review and Fix

- [ ] Stop and wait for external `review.md`, unless the user explicitly
      skips review
- [ ] Read `review.md` and prepare a remediation plan without changing files
- [ ] Present the remediation plan and wait for approval before making any
      changes
- [ ] Implement approved review fixes and update `spec.md`, `plan.md`,
      `tasks.md`, `implementation.md`, code, and tests when review changes
      scope, approach, or validation
- [ ] Repeat the review/fix loop if the same `review.md` file is updated for
      another pass

### Group 5: Finalization

- [ ] Decide whether this feature produced durable learnings or long-lived
      product/architecture changes worth preserving
- [ ] If needed, propose updates to `AGENTS.md`
- [ ] If needed, propose updates to `docs/application-description.md`
- [ ] If needed, propose updates to `docs/agent-findings.md`
- [ ] Wait for explicit approval before editing long-lived guidance documents
- [ ] Record whether the knowledge-capture gate resulted in updates or an
      explicit no-update decision
- [ ] Mark `spec.md` status as `Complete` only after implementation, review,
      validation, and final knowledge-capture gates are handled

## Completion criteria

All tasks checked, validation evidence documented, review handled or explicitly
skipped, and the final knowledge-capture gate handled.

## Validation evidence

Record test results, screenshots, command output, approved exceptions, or
review-related notes here when complete.

```text
Pending implementation.
```
