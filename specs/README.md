# specs/

This directory holds feature specifications following the
**Spec-Driven Development** workflow.

## Workflow summary

Future non-trivial features in this repository follow:

```text
specify -> clarify -> plan -> tasks -> analyze -> implement -> review -> fix
```

After implementation:

- the agent waits for an externally authored `review.md` file unless the user
  explicitly skips review
- the agent reads `review.md`, proposes a remediation plan, and waits for
  approval before changing any files
- the same `review.md` file may be updated for repeated review/fix rounds
- the feature still requires the final knowledge-capture decision before it
  can be marked complete

## Directory structure

```text
specs/
├── _templates/                  # Copy these to start a new feature
│   ├── spec.md                  # Feature specification (what & why)
│   ├── plan.md                  # Implementation plan (how)
│   └── tasks.md                 # Task breakdown (actionable checklist)
├── 001-feature-name/
│   ├── spec.md
│   ├── plan.md
│   ├── tasks.md
│   ├── implementation.md        # Created during implementation
│   └── review.md                # External review input, if provided
└── README.md
```

`review.md` is externally authored. It is recognized by the workflow but is
not copied from `_templates/`.

## Starting a new feature

1. Determine the next feature number by checking existing folders.
2. Create a folder: `specs/NNN-short-description/`
   — use lowercase, hyphens, no spaces.
3. Copy the templates from `_templates/` into your new folder.
4. Fill them in order: `spec.md` → `plan.md` → `tasks.md`.
5. Create a feature branch: `feat/short-description` (append `-#<work-item>`
   if one exists).
6. During planning, document `integration_test` coverage for every in-scope
   user flow plus Android emulator and iOS simulator verification, or request
   an explicit user-approved exception.

## Naming conventions

| Element | Format | Example |
| --- | --- | --- |
| Folder name | `NNN-kebab-case-description` | `001-crud-api` |
| Feature number | Zero-padded, incrementing | `001`, `002`, ..., `1000` |
| Branch | `<type>/<description>[-#<work-item>]` | `feat/crud-api` or `feat/crud-api-#42` |
| Spec file | Always `spec.md` | |
| Plan file | Always `plan.md` | |
| Tasks file | Always `tasks.md` | |
| Implementation file | Always `implementation.md` | |
| Review file | Always `review.md` when supplied | |

## Lifecycle

- **Draft** — the spec is being written or clarified.
- **Approved** — the spec has been reviewed and accepted for planning or
  implementation.
- **In progress** — tasks are being implemented or review/fix work is underway.
- **Complete** — implementation, review handling, validation, and the final
  knowledge-capture gate are all done.
- **Superseded** — replaced by a newer spec.

Track the current status at the top of each `spec.md`.
