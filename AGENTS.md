---

## Instructions for Codex

Act as a senior flutter engineer. You know everything around flutter
development for android and ios. You have deep knowledge about software
architecture, testing and software development best practices.

## Spec-driven development workflow

This project follows a **specify → clarify → plan → tasks → analyze → implement → review → fix**
loop. All artifact responsibilities and phase gate rules are defined in
[`CONSTITUTION.md`](CONSTITUTION.md). Read it before starting any feature work.

Before starting any non-trivial feature:

1. Copy templates from `specs/_templates/` into a new `specs/NNN-feature-name/` folder.
2. Fill in `spec.md` — what and why.
3. **STOP. Present the draft spec and wait for explicit user approval.**
4. Clarify the spec — resolve ambiguities through agent questions.
5. **STOP. Present the finalised spec and wait for explicit user approval.**
6. Fill in `plan.md` — how (architecture, contracts, review approach, and test strategy).
7. Document `integration_test` coverage for every in-scope user flow plus Android emulator and iOS simulator verification in the plan, or request an explicit user-approved exception during planning.
8. **STOP. Present the plan and wait for explicit user approval.**
9. Fill in `tasks.md` — actionable checklist.
10. **STOP. Present the tasks and wait for explicit user approval.**
11. Analyze — verify cross-artifact consistency before coding.
12. **STOP. Present the analysis and wait for explicit user approval.**
13. Implement against the tasks, updating status as you go.
14. Create `implementation.md` with implementation details and validation evidence.
15. **STOP. Wait for an externally provided `review.md` file unless the user explicitly tells you to skip review.**
16. When `review.md` is available, read it and prepare a remediation plan.
17. **STOP. Present the remediation plan and wait for explicit user approval before updating any files.**
18. Implement the approved fixes, updating `spec.md`, `plan.md`, `tasks.md`, `implementation.md`, code, and tests when the review changes scope, approach, or validation.
19. Repeat the review/fix loop if the user tells you the same `review.md` file has been updated for another pass.
20. After the final approved implementation, propose durable updates to `AGENTS.md`, `docs/application-description.md`, and `docs/agent-findings.md` when the completed feature changed product understanding, architecture, or future implementation guidance in a lasting way.
21. **STOP. Present those proposed long-lived documentation updates and wait for explicit user approval before editing them.**

### Hard rules

- After completing any phase output, you MUST stop and wait for the user to
  respond. Do not continue to the next phase, even if you believe approval is
  implied. Silence is not approval.
- `review.md` is authored by an external reviewer. Do not create a review
  template or pre-fill that file as part of normal feature work.
- After reading `review.md`, do not update any files until the user explicitly
  approves the remediation plan.
- Review findings must be judged case by case. If the right response is
  unclear, ask the user instead of applying a default severity rule.
- Final approval requires Android emulator and iOS simulator verification
  unless the user explicitly approved a validation exception during planning.

Full process: see [`docs/spec-driven-workflow.md`](docs/spec-driven-workflow.md).

## Additional project references

- Application description: [`docs/application-description.md`](docs/application-description.md)
- Agent-relevant implementation findings: [`docs/agent-findings.md`](docs/agent-findings.md)
