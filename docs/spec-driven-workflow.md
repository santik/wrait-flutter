# Spec-Driven Development Workflow

This document describes the spec-driven development (SDD) process used in this
project.

## What is Spec-Driven Development?

SDD inverts the traditional development flow. Instead of jumping straight to
code, we start with a specification that defines _what_ we're building and
_why_. Code becomes the output of a structured plan, not the starting point.

**Key idea:** specifications are the source of truth. Code serves the spec.

## Why we use it

- **Prevents scope creep** — acceptance criteria are agreed before coding starts.
- **Enables AI-assisted development** — AI agents work better with structured
  specs than with vague instructions.
- **Improves traceability** — every task links back to a spec, which links back
  to the original requirements.
- **Reduces rework** — catching design issues in a spec is cheaper than fixing
  them in code, and external review catches issues before completion.

## The eight phases

```text
Specify -> Clarify -> Plan -> Tasks -> Analyze -> Implement -> Review -> Fix
```

The workflow may loop between **Review** and **Fix** multiple times until the
user accepts the result or explicitly skips further review.

### Phase 1: Specify

**Input:** an idea or feature request.  
**Output:** `spec.md` — a complete feature specification.

1. Create a new folder: `specs/NNN-feature-name/`
2. Copy the templates from `specs/_templates/` into it.
3. Fill in all required spec sections.
4. Mark status as **Draft** when complete.

**Gate:** present the draft spec to the user and obtain explicit approval
before proceeding to the Clarify phase.

### Phase 2: Clarify _(automatic)_

**Input:** a draft `spec.md`.  
**Output:** a refined, unambiguous `spec.md` ready for planning.

The agent reviews the spec for underspecified areas and asks targeted
questions before proceeding. This gate prevents planning against an incomplete
spec.

Typical questions:

- Are there acceptance criteria that are vague or untestable?
- Are there missing error cases or edge scenarios?
- Are there implicit assumptions about existing behavior?
- Are there unresolved open questions in the spec?

**Gate:** present the finalized spec summary to the user and obtain explicit
approval before proceeding to the Plan phase.

### Phase 3: Plan

**Input:** an approved `spec.md`.  
**Output:** `plan.md` — a detailed implementation plan.

1. Copy `specs/_templates/plan.md` into the feature folder.
2. Document architecture decisions with rationale.
3. List every file that will be created or modified.
4. Define the test strategy.
5. Document `integration_test` coverage for every in-scope user flow.
6. Document Android emulator and iOS simulator verification steps.
7. If a validation exception is needed, request it explicitly during planning
   and capture the rationale.
8. Assess risks and plan mitigations.

**Gate:** present the plan to the user and obtain explicit approval before
proceeding to the Tasks phase.

### Phase 4: Tasks

**Input:** an approved `plan.md`.  
**Output:** `tasks.md` — an actionable, ordered checklist.

1. Copy `specs/_templates/tasks.md` into the feature folder.
2. Break the plan into small, concrete tasks.
3. Group tasks into sequential phases.
4. Mark parallelizable tasks with `[P]`.
5. Include post-implementation review/fix handling and final knowledge-capture
   follow-up when applicable.
6. Note dependencies between groups.

**Gate:** present the task list to the user and obtain explicit approval before
proceeding to the Analyze phase.

### Phase 5: Analyze _(automatic)_

**Input:** `spec.md`, `plan.md`, and `tasks.md`.  
**Output:** a consistency report and, if needed, corrections to the artifacts.

The agent automatically cross-checks all three artifacts before any code is
written. This gate catches misalignments early.

The agent checks:

- Every acceptance criterion in `spec.md` is covered by at least one task.
- Every architectural decision in `plan.md` is reflected in the task list.
- Validation requirements and any requested exceptions are represented in the
  task list.
- No tasks contradict the spec or introduce unplanned scope.
- Dependencies between task groups are correctly ordered.

**Gate:** present the analysis results, including any corrections, to the user
and obtain explicit approval before proceeding to the Implement phase.

### Phase 6: Implement

**Input:** `tasks.md`.  
**Output:** working code, tests, validation evidence, and `implementation.md`.

1. Create a feature branch following the project's branching convention.
2. Work through tasks in order, checking them off.
3. Follow the project's commit conventions.
4. Record validation evidence in `tasks.md`.
5. Verify the planned automated tests and runtime checks succeed.
6. Create `implementation.md` with implementation details.

**Gate:** stop after implementation and wait for an external `review.md` file
unless the user explicitly tells you to skip review.

### Phase 7: Review _(external)_

**Input:** `implementation.md`, validation evidence, and external `review.md`.  
**Output:** an approved remediation plan or an explicit decision to make no
changes.

`review.md` is written by an external reviewer, not by the agent.

When `review.md` becomes available:

1. Read the same `review.md` file in the active feature folder.
2. Judge each finding case by case.
3. Ask the user whenever the correct response to a finding is unclear.
4. Prepare a remediation plan.

**Hard rule:** after reading `review.md`, the agent must not update any files
until the user explicitly approves the remediation plan.

**Gate:** present the remediation plan and obtain explicit approval before
proceeding to the Fix phase.

### Phase 8: Fix

**Input:** an approved remediation plan.  
**Output:** approved review fixes, updated artifacts, and refreshed validation
evidence when needed.

1. Implement the approved review fixes.
2. Update `spec.md`, `plan.md`, `tasks.md`, and `implementation.md` when the
   review changes scope, approach, or validation.
3. Refresh code, tests, and validation evidence as needed.
4. If the user indicates that the same `review.md` file has been updated,
   return to the Review phase and repeat the loop.

## Validation expectations

For future non-trivial features started under this process:

- Every in-scope user flow requires `integration_test` coverage by default.
- Final approval requires verification on both an Android emulator and an iOS
  simulator.
- Validation exceptions are allowed only when proposed during planning and
  explicitly approved by the user.
- If required emulator or simulator verification is unavailable, final approval
  is blocked until that gap is resolved or the user explicitly changes the plan.

## Final knowledge capture

After the final approved implementation and after any review/fix loop is
complete, the agent must decide whether the feature produced durable learnings
or long-lived product or architecture changes worth preserving.

If yes:

1. Propose updates to the relevant long-lived guidance documents such as
   `AGENTS.md`, `docs/application-description.md`, and
   `docs/agent-findings.md`.
2. Present those proposed updates to the user.
3. Wait for explicit approval before editing those documents.

If no:

1. Record that no long-lived documentation update is needed.
2. Treat that decision as part of the completion gate.

## Integration with git conventions

| SDD artifact | Git artifact |
| --- | --- |
| Feature folder name | Maps to the branch description |
| Work item in spec | Must match branch and commit work-item IDs |
| Spec status | Tracks alongside the PR lifecycle |
| Validation evidence | Included in PR description or linked |
| `review.md` | Records external review findings for the current feature |

Branch format: `<type>/<description>[-#<work-item>]`  
Commit format: `type(scope): summary #<work-item>`

## Working with AI agents

Given a feature description, the agent should follow this sequence:

1. Write `spec.md`.
2. **Wait for user approval** of the draft spec.
3. Run Clarify and update `spec.md`.
4. **Wait for user approval** of the finalized spec.
5. Write `plan.md`, including validation coverage and any requested exception.
6. **Wait for user approval** of the plan.
7. Write `tasks.md`.
8. **Wait for user approval** of the task list.
9. Run Analyze and correct any gaps.
10. **Wait for user approval** of the analysis results.
11. Implement the approved tasks and write `implementation.md`.
12. **Wait for external `review.md`** unless the user explicitly skips review.
13. Read `review.md` and prepare a remediation plan.
14. **Wait for user approval** of the remediation plan before changing files.
15. Implement approved review fixes.
16. Repeat the review/fix loop if the same `review.md` is updated.
17. Propose any durable updates to long-lived guidance docs.
18. **Wait for user approval** before editing those long-lived docs.

**Every phase transition requires explicit user approval.** The agent must
never automatically advance to the next phase without a clear confirmation
from the user.

## Definition of Done

A feature is complete when:

- [ ] All acceptance criteria in `spec.md` are met.
- [ ] All tasks in `tasks.md` are checked off.
- [ ] Validation evidence is recorded in `tasks.md`.
- [ ] The planned automated tests and runtime verification have passed, or an
      approved validation exception has been documented.
- [ ] The review phase has been handled, or the user explicitly skipped review.
- [ ] The final knowledge-capture gate has been handled, including the case
      where no long-lived documentation update is needed.
- [ ] Spec status is updated to **Complete**.
- [ ] Implementation details are recorded in `implementation.md`.

## Quick reference

| What | Where |
| --- | --- |
| Start a new feature | `specs/README.md` |
| Spec template | `specs/_templates/spec.md` |
| Plan template | `specs/_templates/plan.md` |
| Tasks template | `specs/_templates/tasks.md` |
| Project principles | `CONSTITUTION.md` |
| Agent instructions | `AGENTS.md` |
