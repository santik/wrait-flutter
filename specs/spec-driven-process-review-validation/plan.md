# Implementation Plan: Spec-Driven Process Review & Validation

> **Feature number:** 005
> **Spec:** [`spec.md`](spec.md)
> **Author:** Codex
> **Date:** 2026-06-09

---

## Approach summary

Implement this feature by updating the repository's canonical workflow sources
so they all describe and reinforce the same future-state process. The core
work will revise the governing workflow documents, agent instructions, and
spec artifact templates to encode the new phase order, explicit review wait
behavior, remediation-plan approval gate, repeated review-loop handling,
dual-platform validation expectations, planning-time exception handling for
validation, and the final knowledge-capture approval gate. Validation for this
story will focus on cross-document consistency because the feature changes
process documentation rather than app runtime behavior or product user flows.

## Architecture decisions

| Decision | Choice | Rationale |
| --- | --- | --- |
| Canonical workflow source | Update `docs/spec-driven-workflow.md` as the primary end-to-end process definition | This document already defines the lifecycle in detail, so it should remain the authoritative workflow reference rather than splitting the process across ad hoc notes. |
| Governing-principles update | Revise `CONSTITUTION.md` to reflect the new phase sequence and stronger validation expectations | The constitution is the project’s non-negotiable policy layer and must stay aligned with the workflow document. |
| Agent behavior enforcement | Update root `AGENTS.md` so future agent runs are instructed to stop for external review, seek approval before remediation changes, require emulator validation, and propose final durable doc updates | Workflow changes are only effective if the agent instructions that drive day-to-day execution encode the same gates and rules. |
| Template enforcement | Update `specs/_templates/plan.md` and `specs/_templates/tasks.md`, and adjust `specs/README.md` as needed to reflect review/fix and validation requirements | Future stories are created from these templates and onboarding docs, so they must nudge contributors toward the new process by default. |
| Review artifact handling | Treat `review.md` as an externally authored but first-class feature-folder artifact, described in docs rather than templated | The user explicitly does not want a `review.md` template, but the workflow still needs to recognize and govern that file. |
| Review-finding disposition | Document case-by-case triage with required human escalation on uncertainty rather than severity-based auto-fix rules | This matches the finalized spec and keeps review responses intentional. |
| Validation exception mechanism | Allow only human-approved planning-time exceptions for user-flow `integration_test` coverage; document process-story exception explicitly in this plan | The new default is strict, but the user allowed justified exceptions during planning. This documentation-only feature is the canonical example because it has no app user flow to automate or run on emulators. |
| Knowledge-capture handling | Encode a final proposal-and-approval step for updates to `AGENTS.md`, `docs/application-description.md`, and `docs/agent-findings.md` when durable learnings exist | The user wants long-lived guidance updates handled deliberately and only after the final approved implementation. |

## File changes

| File | Action | Description |
| --- | --- | --- |
| `CONSTITUTION.md` | Modify | Update the governing process loop, artifact responsibilities, and test-evidence requirements so they match the revised workflow |
| `AGENTS.md` | Modify | Update agent instructions to enforce the review gate, remediation-plan approval before file changes, emulator/simulator verification, planning-time validation exceptions, and final knowledge-capture approval step |
| `docs/spec-driven-workflow.md` | Modify | Expand the workflow from six phases to include review and fix, document repeated review loops, define skip-review behavior, and update the definition of done |
| `specs/README.md` | Modify | Refresh the specs directory overview, lifecycle notes, and starter guidance so future contributors see the revised process immediately |
| `specs/_templates/plan.md` | Modify | Add structure for documenting user-flow `integration_test` coverage expectations, Android/iOS emulator verification, and any requested exception rationale |
| `specs/_templates/tasks.md` | Modify | Add task-group expectations for post-implementation review handling, review-fix loops, final validation evidence, and knowledge-capture follow-up |
| `specs/005-spec-driven-process-review-validation/spec.md` | Modify | Update status history if needed during later phases of this process feature |
| `specs/005-spec-driven-process-review-validation/plan.md` | Modify | Record the approved implementation approach and the validation exception for this documentation-only process story |
| `specs/005-spec-driven-process-review-validation/tasks.md` | Modify | Capture the actionable implementation checklist in the next phase |
| `specs/005-spec-driven-process-review-validation/implementation.md` | Create | Record the final process-change summary, approved validation exception evidence, and implementation notes |

## API contract details

No HTTP or app-runtime API contract changes are part of this feature.

The implementation-specific contract is documentary:

- future non-trivial features follow the revised ordered workflow
- `review.md` is recognized as an external review artifact in the active
  feature folder
- the agent must not modify files in response to review findings until a
  remediation plan has been presented and explicitly approved
- review handling may repeat against the same `review.md` file
- user-flow validation defaults are stricter and must be documented at plan
  time, including any requested exception
- feature completion includes a final durable-knowledge proposal gate before
  the spec can be marked complete

## Data model changes

This feature changes repository process artifacts and expectations, not app
runtime data.

### Before

```text
Workflow:
specify -> clarify -> plan -> tasks -> analyze -> implement

Validation guidance:
- test strategy required
- validation evidence required
- emulator/simulator verification is encouraged but not consistently mandated

Review handling:
- external review may happen informally
- no formal post-implementation wait state or remediation-plan approval gate

Knowledge capture:
- durable updates to long-lived docs are discretionary and not part of the
  formal completion flow
```

### After

```text
Workflow:
specify -> clarify -> plan -> tasks -> analyze -> implement -> review -> fix

Validation guidance:
- every in-scope user flow requires `integration_test` coverage by default
- Android emulator and iOS simulator verification are required before final
  approval
- exceptions must be proposed during planning and explicitly approved

Review handling:
- the agent stops after implementation and waits for external `review.md`
  unless explicitly told to skip review
- the agent reads `review.md`, proposes a remediation plan, and waits for
  approval before changing files
- the same `review.md` file may be updated for repeated review/fix cycles

Knowledge capture:
- after final approved implementation, the agent proposes durable updates to
  long-lived guidance docs when warranted and waits for approval before
  editing them
- the feature is not complete until this final gate has been handled
```

### Migration

No runtime data migration is required.

Process migration rules:

- the revised workflow applies only to future non-trivial features that start
  after this process change is adopted
- already in-flight features are not required to restart under the new flow

## Test strategy

Validation for this story is documentation-focused because no product behavior
or app user flow changes. The main goal is to prove the canonical workflow
documents, templates, and agent instructions are aligned and reflect every
approved rule from the spec. This plan explicitly requests a human-approved
exception to the usual integration-test and emulator/simulator requirements
because the feature has no mobile user flow to automate or execute on-device.

### Automated tests

| Test case | Type | File |
| --- | --- | --- |
| Verify every revised workflow rule is represented in the canonical docs and templates during implementation review | Documentation consistency review | N/A manual artifact check recorded in `tasks.md` |
| Verify no repository template or workflow doc still instructs future features to stop at implementation without the new review/fix and knowledge-capture behavior | Documentation consistency review | N/A manual artifact check recorded in `tasks.md` |

### Manual verification

1. Complete the documentation and template updates in the approved task order.
2. Read the updated `CONSTITUTION.md`, `AGENTS.md`, `docs/spec-driven-workflow.md`, `specs/README.md`, and modified templates end to end.
3. Confirm they all describe the same phase order, review wait behavior, remediation-plan approval gate, repeated review-loop behavior, validation expectations, exception handling, and final knowledge-capture gate.
4. Confirm the templates now prompt future stories to document user-flow integration coverage, dual-platform emulator verification, and any justified exception request during planning.
5. Confirm no updated document requires the agent to create `review.md`, since that artifact remains externally authored.

### Validation exception request

Request approval for this feature to skip:

- `integration_test` coverage, because this story changes repository process
  documents only and introduces no mobile user flow
- Android emulator verification, because no app behavior changes
- iOS simulator verification, because no app behavior changes

If approved, validation evidence will consist of artifact review and document
consistency checks only.

## Integration notes

- This feature integrates primarily with repository governance artifacts rather
  than app modules.
- `docs/spec-driven-workflow.md` should remain the detailed source of truth,
  while `CONSTITUTION.md` and `AGENTS.md` enforce the rules at principle and
  execution levels.
- The templates and `specs/README.md` must align with those canonical docs so
  newly created feature folders start from the revised process automatically.
- Because `review.md` remains externally authored, the implementation should
  describe how the agent reacts to that file rather than introducing a new
  generated template for it.
- The final knowledge-capture gate should be reflected in workflow guidance
  without forcing long-lived doc updates when no durable learnings exist.

## Rollout & migration

This is a documentation and process-governance rollout.

- No feature flags are needed.
- The new rules apply only to future non-trivial features that begin after
  this process change is adopted.
- In-flight work can continue under its existing approved process unless a
  human explicitly decides to opt it into the new one.
- Backward-compatibility risk is primarily documentary drift: one workflow file
  being updated while another still describes the old process.
- The rollout is complete when all canonical docs and templates agree on the
  revised process and future feature work can start from them without needing
  extra verbal instructions.

## Risks & mitigations

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| One workflow source is updated while another still describes the old process | High | High | Treat `docs/spec-driven-workflow.md`, `CONSTITUTION.md`, `AGENTS.md`, `specs/README.md`, and templates as a coordinated edit set and review them together before completion |
| The new review gate is documented ambiguously, causing agents to edit files before remediation-plan approval | Medium | High | Use explicit wording in every governing document that no files may be changed after reading `review.md` until the plan is approved |
| Strict validation expectations are interpreted as applying to documentation-only stories with no user flow | Medium | Medium | Record the planning-time exception mechanism clearly and document this process feature as an approved exception example |
| The workflow accidentally implies the agent should author `review.md` | Medium | Medium | State in multiple places that `review.md` is externally authored and only consumed by the agent |
| The final knowledge-capture gate becomes confused with ordinary implementation documentation | Medium | Medium | Separate implementation artifacts from long-lived guidance docs and document the explicit approval step before editing the latter |

## Open items from spec

None.
