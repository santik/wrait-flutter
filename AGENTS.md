---

## Instructions for Codex

Act as a senior flutter engineer. You know everything around flutter development for android and ios. You have deep knowledge about software architecture, testing and software development best practices.

## Spec-driven development workflow

This project follows a **specify → clarify → plan → tasks → analyze → implement** loop.
All artifact responsibilities and phase gate rules are defined in
[`constitution.md`](CONSTITUTION.md). Read it before starting any feature work.

Before starting any non-trivial feature:

1. Copy templates from `specs/_templates/` into a new `specs/NNN-feature-name/` folder.
2. Fill in `spec.md` — what and why.
3. **STOP. Present the draft spec and wait for explicit user approval.**
4. Clarify the spec — resolve ambiguities through agent questions.
5. **STOP. Present the finalised spec and wait for explicit user approval.**
6. Fill in `plan.md` — how (architecture, contracts, test strategy).
7. **STOP. Present the plan and wait for explicit user approval.**
8. Fill in `tasks.md` — actionable checklist.
9. **STOP. Present the tasks and wait for explicit user approval.**
10. Analyze — verify cross-artifact consistency before coding.
11. **STOP. Present the analysis and wait for explicit user approval.**
12. Implement against the tasks, updating status as you go.

> **Hard rule:** After completing any phase output, you MUST stop and wait for
> the user to respond. Do not continue to the next phase, even if you believe
> approval is implied. Silence is not approval.

Full process: see [`docs/spec-driven-workflow.md`](docs/spec-driven-workflow.md).

## Additional project references

- Application description: [`docs/application-description.md`](docs/application-description.md)
- Agent-relevant implementation findings: [`docs/agent-findings.md`](docs/agent-findings.md)
