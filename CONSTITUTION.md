# Constitution

> Governing principles for this project.
> All development — human or AI-assisted — must align with these principles.

## 1. Spec-first development

Every non-trivial change starts with a specification, not with code.
Follow the **specify → clarify → plan → tasks → analyze → implement → review → fix**
loop documented in [`docs/spec-driven-workflow.md`](docs/spec-driven-workflow.md).

Code is the output of the plan, not the starting point.

### Artifact responsibilities

- **`spec.md`** — defines _what_ and _why_. Specs must be **purely functional
  and technology-agnostic**. They describe the problem, user needs,
  acceptance criteria, and constraints — never the solution. Do not prescribe
  frameworks, libraries, or implementation approaches. If a user mentions a
  specific technology, capture the underlying need, not the technology itself.
- **`plan.md`** — defines _how_. This is where technology choices are made,
  evaluated, and justified with rationale. Every significant decision must
  include why it was chosen over alternatives. Plans must document validation
  coverage for user flows, Android/iOS runtime verification, and any requested
  validation exception that needs human approval.
- **`tasks.md`** — defines _what to do, in what order_. Actionable,
  ordered implementation steps derived from the plan. Each task must be
  concrete enough to implement without further clarification.
- **`implementation.md`** — records what was implemented, how it was validated,
  and any implementation-specific notes that matter for review or future work.
- **`review.md`** — an externally authored review artifact that the agent
  consumes after implementation. The agent must not create this file as part of
  the normal workflow.

### Phase gates

Every phase transition requires **explicit user approval**. Never advance
to the next phase without clear confirmation from the user. Present your
output, then stop and wait.

Additional gate rules:

- After implementation, stop and wait for `review.md` unless the user
  explicitly skips the review step.
- After reading `review.md`, present a remediation plan and wait for approval
  before changing any files.
- After final approved implementation, present any proposed long-lived
  documentation updates and wait for approval before editing those documents.

## 2. Simplicity over cleverness

Choose the simplest solution that correctly satisfies the spec.
Avoid over-engineering, premature abstractions, and unnecessary dependencies.
If the simple approach works, ship it.

## 3. Reuse over rebuild

Before building, check if an existing module, library, or pattern already
solves the problem. Before creating a new utility, check if an existing one
can be extended. Duplication is a defect.

## 4. Validate at the boundary

- Validate all inputs at system boundaries — never trust external data.
- Return clear, structured error responses.
- Error messages must never leak implementation details or stack traces.

## 5. Security by default

- Apply rate limiting on all public endpoints.
- Restrict CORS to known origins in production.
- Never commit secrets — use environment variables.
- Keep dependencies up to date and audit regularly.

## 6. Version control conventions

- Use the conventional commits format: `type(scope): summary`.
- Branch names should be descriptive: `<type>/<short-description>`.
- Reference work item numbers in commits and branches when applicable.

## 7. Data model evolution

- Schema changes must be documented in the plan before implementation.
- Show before/after for any type or schema change.
- Include migration steps when existing data is affected.
- Prefer backward-compatible changes over breaking ones.

## 8. Test evidence required

- Every feature spec must include a **test strategy** section.
- Every in-scope user flow must have planned `integration_test` coverage unless
  the user explicitly approves a justified exception during planning.
- Final approval requires validation on both an Android emulator and an iOS
  simulator unless the user explicitly approves a planning-time exception.
- If required emulator or simulator verification is unavailable, final approval
  is blocked until that gap is resolved or a new explicit user decision changes
  the plan.
- Implementation is not “done” until validation evidence exists and the review
  and final knowledge-capture gates have been handled.

## 9. Clarity over ambiguity

- Ask targeted clarifying questions when requirements, review findings, or
  validation expectations are ambiguous.
- Judge review findings case by case; do not apply an automatic severity-based
  fix rule.
- Escalate to the user when you are unsure whether a review finding should be
  addressed or how a validation exception should be handled.
