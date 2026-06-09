# Implementation Plan: [Feature Name]

> **Feature number:** NNN
> **Spec:** [`spec.md`](spec.md)
> **Author:** [name]
> **Date:** YYYY-MM-DD

---

## Approach summary

_One paragraph describing the chosen implementation strategy.
Reference the spec's acceptance criteria and explain how this plan satisfies them._

## Architecture decisions

_Document key technical choices and their rationale._

| Decision | Choice | Rationale |
| --- | --- | --- |
| [e.g., Validation approach] | [e.g., Riverpod state + repository] | [Why this is the simplest correct choice] |
| [e.g., Storage migration] | [e.g., None] | [Why no migration is required] |

## File changes

_List every file that will be created or modified._

| File | Action | Description |
| --- | --- | --- |
| `lib/example.dart` | Create | New feature logic |
| `test/example_test.dart` | Modify | Coverage for the new behavior |

## API contract details

_Expand on the spec's contract with implementation specifics:
validation rules, failure behavior, response structure, or internal contract
details as appropriate for the feature._

## Data model changes

_Show the before/after for any type changes.
Include migration steps when existing data is affected._

### Before

```text
// existing shape
```

### After

```text
// modified shape
```

### Migration

_Steps to migrate existing data (if applicable)._

## Test strategy

_Define how this feature will be validated._

### Automated tests

_List the planned test cases.
Every in-scope user flow should have `integration_test` coverage unless the
user explicitly approves an exception during planning._

| Test case | Type | File |
| --- | --- | --- |
| [e.g., Happy-path user flow] | Integration | `integration_test/example_flow_test.dart` |
| [e.g., Repository fallback behavior] | Unit | `test/data/example_repository_test.dart` |

### Android emulator verification

_Describe the Android emulator checks required before final approval._

1. [Launch or runtime step]
2. [User-flow verification step]
3. [Expected evidence]

### iOS simulator verification

_Describe the iOS simulator checks required before final approval._

1. [Launch or runtime step]
2. [User-flow verification step]
3. [Expected evidence]

### Validation exception request

_Leave this section empty if no exception is needed.
If this feature cannot reasonably satisfy the default `integration_test` or
dual-platform runtime-verification requirements, request the exception here
with a concrete rationale for explicit user approval._

## Review and finalization

_Describe any feature-specific expectations for the post-implementation review
loop and the final knowledge-capture decision._

- `review.md` will be externally authored if review occurs.
- After reading `review.md`, no files may be changed until the remediation plan
  is explicitly approved.
- Note whether the feature is likely to require durable updates to
  `AGENTS.md`, `docs/application-description.md`, or `docs/agent-findings.md`
  after final approval.

## Integration notes

_Describe any integration points with other services, systems, or modules.
Note any contract changes that affect downstream consumers._

## Rollout & migration

_How will this be deployed?
Any backward-compatibility concerns?
Feature flags needed?_

## Risks & mitigations

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| [e.g., Regression in an existing flow] | Medium | High | [How it will be contained or detected] |

## Open items from spec

_Carry forward any unresolved questions from `spec.md` that affect implementation._
