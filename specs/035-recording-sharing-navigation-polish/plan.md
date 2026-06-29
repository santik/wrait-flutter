# Implementation Plan: Recording, Sharing, and Navigation Polish

> **Feature number:** 035
> **Spec:** [`spec.md`](spec.md)
> **Author:** Codex
> **Date:** 2026-06-24

---

## Status history

| Date | Status | Author | Notes |
| --- | --- | --- | --- |
| 2026-06-24 | Draft | Codex | Initial implementation plan created from approved spec |
| 2026-06-24 | Approved | User | Plan approved for task breakdown |
| 2026-06-25 | In Progress | Codex | Implementation completed with validation evidence; awaiting external review |
| 2026-06-25 | In Progress | Codex | Review remediation implemented; pulse sizing now uses measured button position and validation reran on split simulator/emulator commands |

---

## Approach summary

Implement the three approved polish changes through the existing presentation
layers. The recording pulse will be resized from the active recording layout,
using the measured button position against the visible safe-area bounds instead
of changing recording state or audio behavior. Entry sharing will build the
shared text from the current displayed entry text plus the existing localized
in-app date/time format derived from the entry metadata. Android system back
behavior will reuse the same detail-screen back handler that the visible back
button already uses, while the entry list will prefer a normal route pop and
only fall back to the main screen when no prior route exists.

## Architecture decisions

| Decision | Choice | Rationale |
| --- | --- | --- |
| Recording pulse sizing | Compute the listening pulse from the measured button center to the furthest visible safe-area corner, then keep it behind the action button | This satisfies the full-screen visual requirement on off-center layouts and different phone orientations without changing recording controller state, countdown behavior, or audio logic. |
| Pulse rendering surface | Keep pulse rendering in the main recording presentation components (`MainScreen`, `ButtonArea`, `PulseRing`) | These files already own the action button and active listening visual feedback, so the change remains localized. |
| Shared date/time format | Reuse the entry-detail screen's full weekday and long-date style, plus localized time and the existing locale fallback behavior | The spec requires the existing in-app display format; reusing the detail-date presentation avoids introducing a second date/time convention. |
| Share text assembly | Pass entry metadata into the entry-detail share path and compose the final text before invoking the platform share service | The share service should remain a platform boundary that shares a string; presentation/controller logic already knows which entry text is visible. |
| Android back handling | Route platform pop/back events through the same entry-detail handler used by the visible back button, and let the entry list pop real stack history before falling back to `/` | This preserves edit flushing, dialog behavior, and navigation history while making Android system back consistent with in-app back. |
| Data model | No schema or model changes | Entries already expose `createdAt`, which is sufficient for sharing date and time. |
| Backend/API | No backend or generated API changes | The feature is presentation/navigation only. |

## File changes

| File | Action | Description |
| --- | --- | --- |
| `lib/presentation/main/main_screen.dart` | Modify | Provide the available recording viewport/layout size to the button/pulse area so the active pulse can reach the screen bounds. |
| `lib/presentation/main/button_area.dart` | Modify | Accept full-screen pulse sizing input, keep action/countdown controls centered, and render the enlarged listening pulse behind them. |
| `lib/presentation/main/pulse_ring.dart` | Modify | Support the larger pulse diameter while preserving existing animation, opacity, and semantics-neutral behavior. |
| `lib/presentation/entries/entry_detail_formatters.dart` | Modify | Add or expose a formatter for the existing in-app date/time share label using the current locale fallback approach. |
| `lib/presentation/entries/entry_detail_controller.dart` | Modify | Update the share method contract to accept or build the final share payload that includes date/time plus displayed text. |
| `lib/presentation/entries/entry_detail_screen.dart` | Modify | Pass the entry created timestamp and locale into sharing, and ensure platform back uses the existing back flow. |
| `lib/presentation/entries/entry_list_screen.dart` | Modify | Make Android system back match the visible list back button and return to the main screen. |
| `test/presentation/main/button_area_test.dart` | Modify | Cover enlarged pulse sizing, layering, and listening-only rendering. |
| `test/presentation/entries/entry_detail_formatters_test.dart` | Modify | Cover the share date/time label in the existing in-app format and locale fallback. |
| `test/presentation/entries/entry_detail_controller_test.dart` | Modify | Cover sharing with date/time and body text while preserving share failure behavior. |
| `test/presentation/entries/entry_detail_screen_test.dart` | Modify | Cover share payload composition from readable and edited detail text, and platform pop/back parity where practical in widget tests. |
| `test/presentation/entries/entry_list_screen_test.dart` | Modify | Cover system back parity with the visible list back button. |
| `integration_test/main_screen_flow_test.dart` | Modify | Add active-recording pulse geometry coverage on a real app surface. |
| `integration_test/entry_detail_flow_test.dart` | Modify | Extend existing edit/share/back flow to assert shared date/time content and platform pop-route back navigation. |
| `integration_test/entry_list_flow_test.dart` | Modify | Cover Android system back from the entry list returning to the main screen. |
| `specs/035-recording-sharing-navigation-polish/tasks.md` | Modify later | Fill during the Tasks phase after plan approval. |
| `specs/035-recording-sharing-navigation-polish/implementation.md` | Create later | Record implementation details and validation evidence during implementation. |

## API contract details

No HTTP endpoints, generated backend clients, request bodies, response shapes,
or backend error contracts are introduced or modified.

Internal presentation contracts will change only where needed:

- `ButtonArea` may receive a pulse diameter or available bounds in addition to
  the existing recording state, shake key, button label, countdown progress,
  and press callback.
- Entry-detail sharing may accept the entry timestamp and locale, or a
  preformatted date/time label, before calling `EntryShareService.shareText`.
- `EntryShareService` remains responsible only for invoking the platform share
  API with the final text.

## Data model changes

No data model changes are planned.

### Before

```text
Entry {
  id
  rawTranscript
  cleanedText
  language
  createdAt
  ...
}
```

### After

```text
Entry {
  id
  rawTranscript
  cleanedText
  language
  createdAt
  ...
}
```

### Migration

No migration is required. Existing `createdAt` metadata will supply the shared
date and time.

## Test strategy

### Automated tests

| Test case | Type | File |
| --- | --- | --- |
| Active recording renders an enlarged pulse that reaches beyond the app viewport while leaving controls present | Integration | `integration_test/main_screen_flow_test.dart` |
| Pulse ring remains absent outside listening state and countdown/action button remain centered in listening state | Widget | `test/presentation/main/button_area_test.dart` |
| Share date/time label uses the existing in-app format and locale fallback behavior | Unit | `test/presentation/entries/entry_detail_formatters_test.dart` |
| Sharing delegates text containing date/time plus the displayed entry body | Unit | `test/presentation/entries/entry_detail_controller_test.dart` |
| Share failure still reports a generic error and does not expose internal details | Widget/Unit | `test/presentation/entries/entry_detail_screen_test.dart`, `test/presentation/entries/entry_detail_controller_test.dart` |
| Sharing readable short, long, and draft-like detail text where sharing is already available includes date/time and body content | Integration | `integration_test/entry_detail_flow_test.dart` |
| Sharing edited detail text includes date/time and edited body content | Integration | `integration_test/entry_detail_flow_test.dart` |
| Platform pop/back from entry detail flushes pending edits and returns to the entry list like the visible back button | Integration | `integration_test/entry_detail_flow_test.dart` |
| Platform pop/back from the entry list returns to the main screen like the visible back button | Integration | `integration_test/entry_list_flow_test.dart` |
| Dialog, delete, and edit behavior remain compatible with back/share changes | Widget/Integration regression coverage | Existing `entry_detail_screen_test.dart` and `entry_detail_flow_test.dart` cases, extended if needed |

### Android emulator verification

1. Run focused automated tests on the Android emulator for main recording and
   entry detail flows.
2. Start recording from the main screen and capture evidence that the pulse
   reaches all screen edges and slightly beyond while the action button, quota,
   and status remain usable.
3. Share an entry and verify the platform share payload includes date/time plus
   the entry body.
4. Navigate to entry detail, press the Android system back button, and verify
   the app returns to the entry list after flushing edits when applicable.
5. Verify root/main-screen back behavior remains the simplest
   platform-appropriate behavior and does not introduce a navigation loop.

### iOS simulator verification

1. Run focused automated tests on the iOS simulator for main recording and
   entry detail flows.
2. Start recording from the main screen and capture evidence that the pulse
   reaches all screen edges and slightly beyond while controls remain usable.
3. Share an entry and verify the platform share payload includes date/time plus
   the entry body.
4. Confirm entry detail navigation, visible back, edit, share failure, and
   delete dialog behavior were not regressed by the Android back changes.

### Validation exception request

No validation exception is requested. The plan includes `integration_test`
coverage for every in-scope user flow and runtime verification on both Android
emulator and iOS simulator.

## Review and finalization

- `review.md` will be externally authored if review occurs.
- After implementation, stop and wait for `review.md` unless the user
  explicitly skips review.
- After reading `review.md`, no files may be changed until the remediation plan
  is explicitly approved.
- This story is unlikely to require durable updates to `AGENTS.md` because it
  does not introduce a new architecture rule. A small update to
  `docs/application-description.md` or `docs/agent-findings.md` may be proposed
  after final approval only if implementation reveals lasting product or
  validation guidance.

## Integration notes

- The platform share integration remains through `share_plus` via
  `EntryShareService`.
- Existing app-lock and capture-privacy layers remain outside the planned code
  path.
- Existing route paths remain `/`, `/entries`, and `/entry/:id`.
- Existing local entry storage and generated backend API code remain untouched.

## Rollout & migration

No feature flag, data migration, or backend rollout is required. The changes are
backward-compatible presentation and navigation refinements included in the next
app build.

## Risks & mitigations

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| Enlarged pulse could intercept touches or obscure UI | Medium | Medium | Render it behind controls, keep it non-interactive, and verify controls remain tappable in tests. |
| Pulse sizing could fail on unusual viewports or orientations | Medium | Medium | Derive size from layout bounds and test representative phone-size surfaces. |
| Share payload format could duplicate or mismatch existing date display | Low | Medium | Reuse existing formatter patterns and assert expected payloads in tests. |
| Edited text sharing could use stale persisted text instead of current draft | Medium | Medium | Keep current displayed-text selection behavior and add tests for edited sharing. |
| Android back handling could conflict with dialogs, text editing, or app lock | Medium | High | Reuse existing back handler where possible and keep dialog/app-lock behavior covered by regression tests. |
| Integration tests may be sensitive to platform share UI | Medium | Medium | Keep share assertions at the injected `EntryShareService` boundary in automated tests, then manually verify the platform sheet payload during runtime checks. |

## Open items from spec

No open questions remain. Recorded decisions:

- Shared output includes date and time.
- Shared date and time use the existing in-app display format.
- Android root back behavior should use the simplest implementation that
  preserves current platform expectations.
