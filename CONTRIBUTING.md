# Contributing

Thanks for considering a contribution to wrait.

This project uses a spec-driven workflow. Before non-trivial feature work, read:

- [CONSTITUTION.md](CONSTITUTION.md)
- [docs/spec-driven-workflow.md](docs/spec-driven-workflow.md)
- [AGENTS.md](AGENTS.md)

## Development Setup

```sh
npm install
npm run build
flutter pub get
```

Run checks before opening a pull request:

```sh
flutter analyze
flutter test
```

If `api/wrait-backend.yaml` changes, run `npm run build` before analysis or
tests.

## Pull Requests

- Keep changes focused.
- Include tests for behavior changes.
- Document Android emulator and iOS simulator validation for user-facing
  flows, or explain the validation gap.
- Do not commit secrets, local signing files, generated backend output, or build
  artifacts.
- Use conventional commit-style titles where practical, for example
  `docs(readme): update public release notes`.

## Reporting Issues

When reporting a bug, include:

- platform and OS version
- app build type and version
- expected behavior
- actual behavior
- reproduction steps
- relevant logs, with private diary content removed
