# Implementation Plan: Dependency Constraint Refresh

> **Feature number:** 034
> **Spec:** [`spec.md`](spec.md)
> **Author:** Codex
> **Date:** 2026-06-24

---

## Approach summary

Refresh the project from the currently installed Flutter stable toolchain
`3.44.1` to the latest stable toolchain reported by
`flutter upgrade --verify-only` at planning time: Flutter `3.44.3` revision
`e1fd963c6f`. Then update app dependency constraints and the lockfile using a
best-effort freshest-compatible strategy. Direct dependencies that are already
reported as resolvable to latest should be moved to those versions. Remaining
transitive packages may stay behind when the solver cannot safely select their
latest versions under the selected Flutter SDK and direct dependency graph; any
such remainder will be documented in `implementation.md`.

No product behavior, backend contract, persistence schema, or UI behavior is
intended to change. Validation focuses on dependency resolution, analyzer/unit
health, existing integration flows, Android emulator runtime behavior, and iOS
simulator runtime behavior.

## Architecture decisions

| Decision | Choice | Rationale |
| --- | --- | --- |
| Flutter target | Upgrade local stable Flutter from `3.44.1` to latest stable `3.44.3`, then verify with `flutter --version` | This directly satisfies the approved latest-stable toolchain requirement while staying on the stable channel already used by the project. |
| Toolchain pinning | Add an explicit `environment.flutter` lower bound in `pubspec.yaml` matching the selected stable target | The repo does not currently contain `.fvmrc` or another version-manager file. A Flutter environment constraint makes the minimum app toolchain explicit without introducing a new version manager. |
| Dart SDK constraint | Keep `sdk: ^3.12.1` unless Flutter `3.44.3` reports a newer bundled Dart requirement | Current Flutter `3.44.1` uses Dart `3.12.1`; the constraint already matches that runtime family. The implementation will re-check after upgrade. |
| Dependency update strategy | Update direct constraints to the freshest compatible resolvable versions, then run solver-driven lockfile refresh | This minimizes manual graph manipulation while satisfying the best-effort freshness requirement. |
| `drift_dev` latest gap | Attempt the latest `drift_dev` first; if the solver rejects `2.34.1+1`, use the freshest resolvable version and document the gap | The current report shows `2.34.0` resolvable and `2.34.1+1` latest, so this is the known likely exception. |
| Transitive outdated packages | Do not force transitive versions with dependency overrides unless required to fix a concrete compatibility issue | Overrides can hide real package constraints and increase future maintenance risk. Remaining transitive lag is acceptable when documented. |
| Generated backend package | Do not edit generated backend client metadata unless dependency resolution or analysis fails because of it | App code depends on the stable bridge, and the generated package has broad SDK/dependency constraints. Avoid unnecessary generated-output churn. |
| Native build files | Do not edit Android/iOS native build files unless Flutter `3.44.3` validation exposes a required compatibility change | The current Android Gradle/Kotlin versions are already recent. Native churn should be driven by actual toolchain failures. |
| Validation scope | App validation checks only; no separate dependency audit/security report | This records the approved validation-scope clarification. |

## File changes

| File | Action | Description |
| --- | --- | --- |
| `specs/034-dependency-constraint-refresh/spec.md` | Modify | Mark approved and keep any scope clarifications aligned with implementation findings if needed. |
| `specs/034-dependency-constraint-refresh/plan.md` | Modify | Planning artifact for the approved spec. |
| `specs/034-dependency-constraint-refresh/tasks.md` | Modify later | Actionable task checklist after plan approval. |
| `specs/034-dependency-constraint-refresh/implementation.md` | Create later | Implementation notes, selected versions, remaining outdated packages, and validation evidence. |
| `pubspec.yaml` | Modify | Add/adjust Flutter toolchain constraint and update direct dependency constraints. |
| `pubspec.lock` | Modify | Refresh resolved dependency graph after toolchain and constraint updates. |
| `tool/openapi-generator/output/backend_api/pubspec.lock` | Modify only if needed | Refresh only if generated-client validation requires its local lockfile to move. |
| `README.md` | Modify only if needed | Update common Flutter command/version guidance only if the implementation changes durable local workflow expectations. |
| `android/**`, `ios/**` | Modify only if needed | Apply compatibility fixes only if Flutter `3.44.3` build/runtime validation requires them. |

## API contract details

No backend HTTP endpoint is introduced or modified. Existing generated backend
API usage must continue to compile and resolve through
`lib/data/api/generated/backend_api_generated.dart`.

## Data model changes

No app data model, database schema, secure-storage format, draft file layout,
or generated backend DTO shape is planned to change.

### Before

```text
No schema or persisted type change.
```

### After

```text
No schema or persisted type change.
```

### Migration

No migration is planned. If dependency compatibility unexpectedly requires a
persistence-affecting change, implementation must stop and return to planning
for explicit approval.

## Test strategy

### Automated tests

| Test case | Type | File |
| --- | --- | --- |
| Verify selected Flutter stable version and Dart version | Toolchain | `/opt/homebrew/bin/flutter --version` |
| Verify project dependency graph resolves after updates | Dependency | `/opt/homebrew/bin/flutter pub get` |
| Verify remaining outdated packages are documented | Dependency | `/opt/homebrew/bin/flutter pub outdated` |
| Verify generated backend package remains resolvable | Dependency | `/opt/homebrew/bin/flutter pub get` from `tool/openapi-generator/output/backend_api`, if root validation exposes generated-client issues |
| Static analysis after dependency refresh | Static analysis | `/opt/homebrew/bin/flutter analyze` |
| Full unit and widget coverage | Unit/widget | `/opt/homebrew/bin/flutter test test` |
| Main startup and recording flow coverage | Integration | `integration_test/main_screen_flow_test.dart`, `integration_test/main_recording_controller_flow_test.dart`, `integration_test/audio_recording_service_flow_test.dart` |
| Permission and backend flow coverage | Integration | `integration_test/main_screen_permission_flow_test.dart`, `integration_test/backend_api_client_flow_test.dart`, `integration_test/cloud_transcription_service_flow_test.dart`, `integration_test/cleanup_transcript_use_case_flow_test.dart`, `integration_test/device_registration_launch_flow_test.dart` |
| Entry list/detail/share/delete coverage | Integration | `integration_test/entry_list_flow_test.dart`, `integration_test/entry_detail_flow_test.dart`, `integration_test/entry_detail_device_smoke_test.dart` |
| Draft retry and local data lifecycle coverage | Integration | `integration_test/draft_retry_launch_flow_test.dart`, `integration_test/local_data_lifecycle_flow_test.dart` |
| App lock, privacy, and keep-awake coverage | Integration | `integration_test/app_lock_flow_test.dart`, `integration_test/capture_prevention_flow_test.dart`, `integration_test/main_screen_display_awake_flow_test.dart` |
| Build-script safeguards still pass | Shell tests | `test/deploy_debug_script_test.sh`, `test/deploy_release_script_test.sh` |
| Android debug build still succeeds | Build | `/opt/homebrew/bin/flutter build apk --debug` |
| iOS simulator build still succeeds | Build | `/opt/homebrew/bin/flutter build ios --simulator --no-codesign` |

The implementation should prefer running the complete integration suite where
practical:

```sh
/opt/homebrew/bin/flutter test integration_test
```

If a specific integration test requires a device-only runtime, it should be run
under the Android/iOS runtime verification steps below or documented with the
reason it could not run headlessly.

### Android emulator verification

1. Start or select an Android emulator.
2. Verify the upgraded app launches with:
   `/opt/homebrew/bin/flutter run -d <android-emulator-id> --debug` or an
   equivalent build/install/launch command.
3. Run the integration suite or the approved app-validation subset on the
   emulator with `/opt/homebrew/bin/flutter test -d <android-emulator-id> integration_test`.
4. Confirm startup, main recording UI, permission handling with fakes where
   applicable, entry list/detail navigation, app lock, capture prevention, and
   keep-awake flows still pass.
5. Record command output and, when runtime UI is launched manually, screenshots
   or launch evidence in `implementation.md`.

### iOS simulator verification

1. Start or select an iOS simulator.
2. Verify the upgraded app launches with:
   `/opt/homebrew/bin/flutter run -d <ios-simulator-id> --debug` or an
   equivalent build/install/launch command.
3. Run the integration suite or the approved app-validation subset on the
   simulator with `/opt/homebrew/bin/flutter test -d <ios-simulator-id> integration_test`.
4. Confirm startup, main recording UI, entry list/detail navigation, app lock,
   capture privacy, generated backend usage, and keep-awake-adjacent flows still
   pass where supported by simulator APIs.
5. Record command output and, when runtime UI is launched manually, screenshots
   or launch evidence in `implementation.md`.

### Validation exception request

No exception is requested for Android emulator or iOS simulator verification.
The approved dependency-audit/security-report exclusion is recorded as out of
scope rather than as a validation exception.

## Review and finalization

- `review.md` will be externally authored if review occurs.
- After implementation, stop and wait for external `review.md` unless the user
  explicitly skips review.
- After reading `review.md`, no files may be changed until the remediation plan
  is explicitly approved.
- This feature may produce durable updates to `docs/agent-findings.md` if the
  Flutter/toolchain update reveals new project-specific dependency maintenance
  guidance. It is unlikely to require `docs/application-description.md` changes
  because no product behavior is planned to change.

## Integration notes

- Root app dependency resolution depends on the local generated
  `wrait_backend_api` package under `tool/openapi-generator/output/backend_api`.
- The backend OpenAPI source is not in scope. If `api/wrait-backend.yaml`
  changes unexpectedly, stop and re-plan before running regeneration as part of
  this story.
- Android and iOS plugin behavior most likely affected by this refresh includes
  `record`, `path_provider`, `sqlite3`, `permission_handler`,
  `flutter_secure_storage`, `local_auth`, and Riverpod-driven state wiring.

## Rollout & migration

This is a source-level maintenance update. No feature flag, backend rollout,
or data migration is planned. App store or physical-device release deployment
is not required by this story, but debug/profile/release deployment scripts
must remain valid.

## Risks & mitigations

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| Flutter stable upgrade changes analyzer, generated code, or build behavior | Medium | Medium | Upgrade toolchain first, run `flutter pub get`, `flutter analyze`, and build checks before code fixes. |
| `record` plugin update changes audio capture behavior | Medium | High | Run audio service unit tests, main recording integration tests, Android emulator validation, and iOS simulator validation. |
| Drift or sqlite update affects encrypted database opening | Medium | High | Run database/repository tests, local-data lifecycle integration tests, and launch runtime checks. |
| Riverpod update changes provider lifecycle behavior | Low | High | Run full unit/widget suite plus main, app-lock, entry, and launch integration flows. |
| Analyzer/test-family transitive packages remain outdated | High | Low | Document remaining solver-constrained transitive packages in `implementation.md`; avoid unsafe overrides. |
| Native plugin/platform update requires Android or iOS project adjustments | Medium | Medium | Keep native edits scoped to build/runtime failures, then re-run platform builds and runtime checks. |
| Existing dirty worktree contains unrelated changes | High | Medium | Touch only files listed in this plan unless an approved compatibility issue requires more. Do not revert unrelated user changes. |

## Open items from spec

No open spec questions remain. Planning records these resolved decisions:

- Flutter target: latest stable at planning time, currently Flutter `3.44.3`.
- Dependency target: best effort toward freshest compatible versions.
- Dependency-health report: remaining outdated packages are acceptable when
  documented with concrete reasons.
- Validation scope: app validation checks only; no separate dependency audit or
  security report.
