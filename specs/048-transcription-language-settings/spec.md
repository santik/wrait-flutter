# Feature Specification: Transcription language settings

> **Feature number:** 048
> **Status:** Complete
> **Author:** Codex
> **Date:** 2026-09-23
> **Work item:** US-048 (local feature identifier)

## Status history

| Date | Status | Author | Notes |
| --- | --- | --- | --- |
| 2026-09-23 | Draft | Codex | Initial draft presented |
| 2026-09-23 | Draft | Codex | User supplied clarification decisions; finalized spec awaiting approval |
| 2026-09-23 | Approved | Codex | User approved finalized spec; planning authorized |
| 2026-10-02 | Implemented | Codex | App implementation and Android/iOS simulator validation complete; awaiting external review |
| 2026-10-02 | Change request draft | Codex | User requested capitalized labels, a compact dropdown, and main-indicator navigation to the language setting |
| 2026-10-02 | Change request clarified | Codex | Draft approved; interaction and capitalization details finalized |
| 2026-10-02 | Change request approved | Codex | Revised spec, plan, tasks, and analysis approved for implementation |
| 2026-10-02 | Implemented | Codex | Presentation revision and Android/iOS simulator validation complete; awaiting external review |
| 2026-10-03 | Reviewed and remediated | Codex | User-provided combined-run failure treated as review feedback; approved test-only timing remediation passed Android and iOS validation |
| 2026-10-03 | Change request draft | Codex | User requested dropdown typography and row spacing consistent with the rest of the interface |
| 2026-10-03 | Change request clarified | Codex | Draft approved; uniform typography, compact visual rhythm, and accessibility constraints finalized |
| 2026-10-03 | Change request approved | Codex | Finalized dropdown typography specification approved for planning |
| 2026-10-04 | Reviewed and remediated | Codex | User-provided app-lock lifecycle failure was corrected in the integration fixture and passed Android/iOS validation |
| 2026-10-04 | Implemented | Codex | Dropdown typography revision completed with host, Android, and iOS validation; awaiting external review |
| 2026-10-06 | Reviewed | Codex | Code review produced 10 findings; all 10 remediated |
| 2026-10-06 | Updated | Codex | Language catalogue expanded from 35 to 61 entries covering full backend enum; documentation phase |
| 2026-10-06 | Complete | Codex | Long-lived documentation applied; all tasks complete |

## Overview

Automatic language detection is unreliable for some spoken languages. Add a
Settings page where users can select their spoken language so the transcription
service can use that choice. Show an explicit selection on the main screen so
users can check it before recording, and remember the preference across sessions.

Preserve automatic detection for users who do not choose a language. This
preference controls speech transcription, not interface language or translation.
Clarification decisions are incorporated below. The user approved this finalized
spec for planning on 2026-09-23.

## User stories

- As a user whose language is detected poorly, I want to choose my spoken
  language so transcription can use my choice.
- As a user, I want my choice remembered so I do not repeat it every session.
- As a user, I want to see my selected language on the main screen so I can
  check it before recording.
- As a user who changes languages, I want to change my selection or restore
  automatic detection.

## Acceptance criteria

- [ ] **AC-01 — Navigation:** The main screen has an identifiable Settings
  entry point. Users can open Settings and return. Existing feedback access
  remains available.
- [ ] **AC-02 — Selection:** Settings includes a clearly labelled, compact
  dropdown for transcription language with automatic detection and all base
  languages from the backend transcription enum. Language codes remain unchanged. Every language label
  starts with a capital letter where its writing system has letter case; labels
  in scripts without letter case remain unchanged. The current choice is clearly
  distinguishable from other options, and the full catalogue does not occupy the
  Settings page when the control is closed.
- [ ] **AC-03 — Default and reset:** Users without a saved preference use
  automatic detection. Selecting automatic detection removes the explicit
  override for subsequent operations.
- [ ] **AC-04 — Persistence:** A successfully saved choice survives navigation,
  restart, and normal app updates. Saving works offline. Selection
  saves immediately without a separate Save action.
- [ ] **AC-05 — Main-screen indicator:** An explicit selection is displayed by
  human-readable language name before and during recording/transcription,
  without obscuring controls or status. The indicator is an accessible control:
  tapping it opens Settings at the transcription-language control. Returning
  from Settings reflects the saved choice. Hide the indicator in automatic mode;
  use the capitalized language display labels for explicit selections.
- [ ] **AC-06 — Submission:** Applicable audio submissions supply the explicit
  language code in the transcription API call. Automatic mode supplies no explicit
  override. Backend handling will be implemented separately later; this feature
  must send the code without requiring that later implementation to exist.
- [ ] **AC-07 — Operation consistency:** An in-progress operation keeps a stable
  language choice. New recordings use the preference active
  at recording start, and Settings is unavailable during recording/transcription.
  Later preference changes affect subsequent operations.
- [ ] **AC-08 — Audio retry:** Retained-audio retries follow a defined language
  policy: use the current preference at retry start, allowing
  users to correct their choice before retrying. An in-progress retry keeps its
  starting choice.
- [ ] **AC-09 — Existing content:** Preference changes do not rewrite existing
  entries, re-transcribe saved text, or change stored entry-language values.
  Existing entry surfaces use the newly capitalized shared display labels without
  changing their underlying language metadata.
  For new transcripts, use the returned language for entry metadata and
  subsequent text cleanup, even if it differs from the selected language. If
  no usable language is returned, preserve existing missing-language behavior
  (including the existing cleanup fallback); do not substitute the preference.
- [ ] **AC-10 — Failures:** Failed saves show a clear, non-technical error and do
  not falsely present the new value as saved. Missing or unsupported saved
  preferences resolve to automatic detection without blocking app use.
  Transcription failures preserve existing recoverable-draft behavior; an
  explicit-language request is not silently retried in automatic mode.
- [ ] **AC-11 — Usability and privacy:** Controls and indicators have meaningful
  accessibility labels and remain usable at larger text sizes on supported phone
  screens. Settings stays protected by the existing app privacy lock.

## API contract

Functional requirement: audio transcription requests carry an optional spoken
language code from the selected catalogue entry. Omit the override in automatic
mode. Preserve existing response, quota, and recoverable-error handling. Returned
language remains authoritative for entry metadata and text cleanup.

The user supplied an updated backend contract on 2026-10-01; it is now the
contract reference for this feature. Synchronize the app-side contract and call
with that reference during implementation. Backend implementation remains outside
this repository task; supplying the contract does not establish deployment status. Actual backend use of the hint and resulting
accuracy improvements are not completion requirements for this app-side story.

## Data model changes

Add one device-local preference: automatic detection or one supported spoken
language. Existing installations without a value retain automatic detection.
The preference is separate from each entry's language. No rewriting of existing
entry data is proposed. No recording-specific language history is required:
audio retries use the current preference at retry start.

## Dependencies

- The existing app language catalogue and its language codes/display labels.
- Existing recording, retained-audio retry, text cleanup, local preferences,
  navigation, and privacy-lock behavior.
- Later backend work will consume the optional language code. That work is
  outside this feature and does not block app-side implementation or validation.

## UX / design references

No external design supplied. Functional design:

- A Settings entry point on the main screen and a dedicated Settings page.
- A compact dropdown labelled “Transcription language”, with “Automatic
  detection” and the existing language catalogue using capitalized labels.
- A compact, tappable “Language: <selected language>” control near the recording
  area that opens Settings at the transcription-language control.

Automatic mode has no main-screen label. For remaining layout details, use a
dedicated Settings entry point and a display-only language indicator by default;
exact placement will be specified during planning. Other settings are outside
this story.

## Non-functional requirements

- **Performance:** Preserve responsive startup. A recording must not accidentally
  use automatic detection while a saved explicit preference is still loading.
- **Security:** Validate saved and outgoing choices; retain app-lock and capture
  privacy behavior and sanitized user-facing errors.
- **Reliability:** The displayed selection, saved preference, and outgoing
  language must agree. In-flight operations must keep their starting language.
- **Scalability:** Selection stays usable for the agreed supported-language list.
- **Observability:** Verify language submission without adding transcript, audio,
  or sensitive-data logging.

## Test strategy

Cover opening/leaving Settings, selecting/changing a language, returning to
automatic detection, persistence across restart, recording in each mode, and
retained-audio retry after a preference change. Include failed saves, invalid
stored preferences, in-flight consistency, startup preference loading, and the
returned-language/cleanup behavior, including missing or differing results.

Check agreement between the main-screen indicator and outgoing transcription
request. Preserve recording, draft recovery, cleanup, feedback access, and
privacy-lock behavior. Verify the optional outgoing language code and simulated
backend responses at the request boundary. Backend processing of the new field
is deferred; live backend recognition of the hint is not required for this story.
Guaranteed accuracy improvement for every recording is not promised.

Planning must map every in-scope user flow to integration coverage and define
Android emulator and iOS simulator verification, including layout/accessibility
checks. No exception to app integration or dual-platform validation is requested.

## Out of scope

- Interface localization, transcript translation, or account preference sync.
- Per-entry language editing, bulk re-transcription, or rewriting saved entries.
- New transcription providers, model selection, or guaranteed accuracy targets.
- Additional settings or expanding backend language support beyond the agreed list.
- Backend implementation and verification of its future language-hint handling.

## Clarification decisions

Confirmed by the user on 2026-09-23:

1. Backend support will be implemented later; add the language code to the API call.
2. Do not label automatic mode on the main screen; reuse existing language labels.
3. Save immediately, capture the preference at recording start, and keep Settings
   unavailable during recording/transcription.
4. Audio retries use the current preference at retry start.
5. Use the returned language for entry metadata and subsequent text cleanup.

Scope interpretations included for final approval: reuse the existing selectable
language catalogue; retain existing missing-response-language fallback behavior;
use a display-only main-screen indicator. Exact visual placement and transport
field details belong in planning.

## Open questions

None. Finalized spec approved.

## Change request — 2026-10-02

The user requested three presentation changes after the initial implementation:

1. Capitalize the first letter of every language label where the script supports
   letter case. Keep language codes and scripts without case unchanged.
2. Replace the expanded Settings catalogue with a dropdown so the closed setting
   occupies little vertical space.
3. Make the explicit language indicator on the main screen open Settings at the
   transcription-language control when tapped.

These changes affect presentation and navigation only. Preference storage,
request serialization, recording/retry snapshots, automatic-mode behavior, and
returned-language authority remain unchanged.

Clarified behavior:

- Capitalization changes only the first cased character of each display label.
  It does not title-case later words or alter native spelling, diacritics, codes,
  ordering, or labels written in scripts without letter case.
- The closed dropdown shows the committed language label or “Automatic
  detection”. Selecting an item saves immediately and closes the dropdown; save
  and load failures continue using the existing sanitized feedback behavior.
- Opening Settings from the main indicator places the transcription-language
  control in view. Normal Settings entry still opens at the top of the page.
- The indicator remains visible during an active recording/transcription so the
  captured selection can be checked, but its navigation action is disabled while
  Settings is unavailable under AC-07. It becomes actionable again when the
  operation finishes.
- Back navigation returns to the same main-screen route. Automatic mode still
  hides the main-screen indicator, so Settings remains the entry point for users
  who have no explicit selection.

This clarified revision was approved and implemented before the later typography
change request below.

## Change request — 2026-10-03

The language dropdown currently appears visually oversized compared with the
rest of Settings. Its selected value, menu labels, and vertical distance between
menu rows should use the same visual scale and rhythm as the surrounding
interface.

Additional acceptance details:

- The closed dropdown value and every open-menu language label use the app's
  established control/body typography rather than a larger standalone style.
- Menu rows use compact, consistent vertical spacing so more languages fit on
  screen without feeling crowded or leaving excessive gaps.
- The field label, selected value, menu labels, and surrounding explanatory text
  form a consistent hierarchy in light and dark themes.
- Capitalization, native spelling, catalogue order, selected value, automatic
  mode, immediate saving, focused navigation, and activity guards remain
  unchanged.
- Text remains legible and selectable without clipping for long language names,
  supported phone widths, and enlarged accessibility text.
- Android and iOS validation covers the closed control, open menu, long labels,
  and enlarged text.

Clarified behavior:

- “Uniform with the rest of the text” means the selected value and menu labels
  follow the same themed body/control typography used by surrounding Settings
  controls, including size, weight, color, and line height. They do not use the
  larger heading or app-bar style.
- The closed field and open menu use a compact visual density. Visible gaps
  between labels are reduced while each option retains a clear, reliable touch
  target.
- Styling comes from the active app theme so light/dark colors and accessibility
  text scaling remain consistent; language labels do not receive isolated fixed
  font sizes.
- This revision changes presentation only. It does not alter menu behavior,
  language values, storage, navigation, request propagation, or transcription.

## Contract update — 2026-10-01

Use the user-supplied backend OpenAPI referenced in plan.md. Its accepted choices
include all existing app languages; keep the approved picker list and labels.
Additional backend languages and multilingual mode do not expand this UI scope.
The response remains authoritative. Implementation still awaits analysis approval.
