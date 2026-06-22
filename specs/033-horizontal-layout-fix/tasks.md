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

_Tasks are organized into sequential groups.
Tasks within the same group marked `[P]` can be worked on in parallel._

### Group 1: Foundation

_Set up the files, contracts, and prerequisites needed for the feature._

- [ ] [P] Task description — `file/path.dart`
- [ ] [P] Task description — `file/path.dart`

### Group 2: Core implementation

_Implement the main feature behavior._

- [ ] Task description — `file/path.dart`
  - Depends on: Group 1
- [ ] [P] Task description — `file/path.dart`
- [ ] [P] Task description — `file/path.dart`

### Group 3: Validation

_Add automated coverage and runtime verification._

- [ ] Implement `integration_test` coverage for every in-scope user flow from the plan, or record the approved exception
- [ ] Add or update lower-level automated tests from the plan
- [ ] Verify the feature on an Android emulator, or record the approved exception
- [ ] Verify the feature on an iOS simulator, or record the approved exception
- [ ] Verify the project build succeeds with no errors

### Group 4: Review and fix

_Handle external review after implementation._

- [ ] Create `implementation.md` with implementation notes and validation evidence
- [ ] Stop and wait for external `review.md`, unless the user explicitly skips review
- [ ] Read `review.md` and prepare a remediation plan without changing files
- [ ] Present the remediation plan and wait for approval before making any changes
- [ ] Implement approved review fixes and update `spec.md`, `plan.md`, `tasks.md`, `implementation.md`, code, and tests when review changes scope, approach, or validation
- [ ] Repeat the review/fix loop if the same `review.md` file is updated for another pass

### Group 5: Finalization

_Handle durable documentation follow-up and closeout._

- [ ] Decide whether the feature produced durable learnings or long-lived product/architecture changes worth preserving
- [ ] If needed, propose updates to `AGENTS.md`, `docs/application-description.md`, and `docs/agent-findings.md`
- [ ] Wait for explicit approval before editing those long-lived guidance documents
- [ ] Record whether the knowledge-capture gate resulted in updates or an explicit no-update decision

## Completion criteria

All tasks checked, validation evidence documented, review handled or explicitly
skipped, and the final knowledge-capture gate handled.

## Validation evidence

_Record test results, screenshots, command output, approved exceptions, or
review-related notes here when complete._

```text
# Example:
$ flutter test
All tests passed.
```

## Notes

_Any observations, decisions, or deviations from the plan during implementation._
