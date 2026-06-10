# Code Review: Audio Recording Service

> **Feature number:** 007
> **Reviewer:** Cascade
> **Date:** 2026-06-10
> **Branch:** 007

---

## Summary

This review identifies architectural issues, implementation problems, missing error handling, and other concerns in the audio recording service implementation. Findings are ranked by priority (PO = critical, P1 = high, P2 = medium, P3 = low).

---

## PO Findings (Critical - Must Fix)

### PO-1: Race condition in `_runExclusive` serialization mechanism

**Location:** `lib/data/audio/record_audio_recording_service.dart:130-144`

**Issue:** The serialization loop checks if `_operationCompleter` is null, then waits for it if not, then sets it. However, between the null check and the assignment, another async operation could check and also see null, leading to concurrent execution.

```dart
Future<T> _runExclusive<T>(Future<T> Function() action) async {
  while (_operationCompleter != null) {  // Check
    await _operationCompleter!.future;
  }

  final completer = Completer<void>();
  _operationCompleter = completer;  // Assign - race window here

  try {
    return await action();
  } finally {
    _operationCompleter = null;
    completer.complete();
  }
}
```

**Impact:** Two concurrent `startRecording` or `stopRecording` calls could execute simultaneously, violating the single-session invariant and potentially corrupting state.

**Recommendation:** Use a proper synchronization primitive like a `Lock` from the `async` package or a mutex pattern, or use a single async queue with explicit queuing.

---

### PO-2: `dispose()` does not stop active recording session

**Location:** `lib/data/audio/record_audio_recording_service.dart:123-128`

**Issue:** The `dispose()` method clears `_activeSession` and calls `recorder.dispose()`, but it never calls `recorder.stop()` if a recording is in progress. This leaves the underlying recorder in an active state.

```dart
Future<void> dispose() async {
  await _runExclusive(() async {
    _activeSession = null;  // Clears session without stopping recorder
    await recorder.dispose();
  });
}
```

**Impact:** If the service is disposed while recording, the recorder may continue capturing audio in the background, consuming resources and potentially corrupting the output file. The file may be left in an incomplete state on disk.

**Recommendation:** Check if `_activeSession` is not null, call `recorder.stop()` before clearing the session, and clean up the output file if disposal happens mid-recording.

---

### PO-3: No error handling for recorder start failures

**Location:** `lib/data/audio/record_audio_recording_service.dart:84`

**Issue:** If `recorder.start()` fails due to permission denial, hardware unavailability, or other platform-specific errors, the exception propagates but the service state may be inconsistent. The `_activeSession` is set after the start call, but if start fails, no cleanup occurs.

```dart
await recorder.start(config: _recordConfig, path: trimmedPath);

_activeSession = _ActiveRecordingSession(...);  // Only set if start succeeds
```

**Impact:** A failed start could leave the recorder in an unknown state, and subsequent operations might behave unexpectedly. The caller receives an exception but has no way to know if partial state was left behind.

**Recommendation:** Wrap recorder operations in try-catch blocks, ensure cleanup on failure, and consider mapping platform-specific errors to typed failures for better error handling by callers.

---

### PO-4: Silent exception swallowing in `_deleteFileIfPresent`

**Location:** `lib/data/audio/record_audio_recording_service.dart:146-159`

**Issue:** The method catches all exceptions silently with no logging or error reporting.

```dart
Future<void> _deleteFileIfPresent(String path) async {
  if (path.isEmpty) {
    return;
  }

  try {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  } catch (_) {
    // Best-effort cleanup only.
  }
}
```

**Impact:** Filesystem errors (permission denied, disk full, file locked, etc.) are silently ignored. This could lead to:
- Temporary files accumulating on disk
- Inability to clean up too-short recordings
- No visibility into cleanup failures during debugging

**Recommendation:** At minimum, log the error. Consider whether cleanup failures should be propagated or tracked separately. For a production app, silent failure of cleanup operations is unacceptable.

---

### PO-5: No validation that output path directory exists or is writable

**Location:** `lib/data/audio/record_audio_recording_service.dart:71-78`

**Issue:** The service validates that the output path is not blank, but does not check if the parent directory exists or if the location is writable before starting recording.

```dart
final trimmedPath = outputPath.trim();
if (trimmedPath.isEmpty) {
  throw ArgumentError.value(
    outputPath,
    'outputPath',
    'must not be blank',
  );
}
// No directory existence or writability check
```

**Impact:** Recording may start successfully but fail when the recorder tries to write to a non-existent or read-only location. The error will occur late in the flow, making debugging harder and potentially leaving inconsistent state.

**Recommendation:** Validate that the parent directory exists and is writable before calling `recorder.start()`. Create the directory if appropriate, or fail fast with a clear error.

---

### PO-6: Integer overflow risk in monotonic time calculations

**Location:** `lib/data/audio/record_audio_recording_service.dart:89-90`

**Issue:** The hard-cap deadline is calculated as `startedAtElapsedRealtime + hardCap.inMilliseconds`. On a long-running app, the monotonic clock value could overflow the 53-bit mantissa of JavaScript-style numbers or exceed practical int limits.

```dart
hardCapDeadlineElapsedRealtime:
    startedAtElapsedRealtime + hardCap.inMilliseconds,
```

**Impact:** While unlikely in practice (would require ~248 days of continuous app runtime), the design doesn't account for overflow. If overflow occurs, the deadline would be incorrect and the hard-cap enforcement would fail.

**Recommendation:** Document the overflow risk and acceptable runtime bounds, or use a different approach (e.g., store deadline as a Duration from start time rather than absolute monotonic time).

---

## P1 Findings (High - Should Fix)

### P1-1: No cancellation mechanism for in-progress recordings

**Location:** `lib/data/audio/audio_recording_service.dart`

**Issue:** The service provides `startRecording` and `stopRecording`, but no way to cancel a recording that hasn't reached the minimum duration. If a user starts recording then immediately changes their mind, they must wait 5 seconds to get a valid file or stop early and trigger the too-short failure.

**Impact:** Poor user experience. Users cannot abandon a recording without either waiting or triggering an error flow.

**Recommendation:** Add a `cancelRecording()` method that stops the recording, deletes the file, and returns without treating it as a failure. This is distinct from `stopRecording()` which expects a valid result.

---

### P1-2: Minimum recording duration is hardcoded

**Location:** `lib/data/audio/audio_recording_service.dart:1`

**Issue:** The 5-second minimum is a top-level constant rather than configurable.

```dart
const minimumRecordingDuration = Duration(seconds: 5);
```

**Impact:** Cannot adjust the minimum duration based on product requirements, A/B testing, or different use cases without code changes.

**Recommendation:** Move to `AppConfig` or pass as a constructor parameter to the service.

---

### P1-3: Audio configuration is hardcoded and not extensible

**Location:** `lib/data/audio/record_audio_recording_service.dart:55-59`

**Issue:** The recording configuration (AAC, 16kHz, mono) is a static constant.

```dart
static const RecordConfig _recordConfig = RecordConfig(
  encoder: AudioEncoder.aacLc,
  sampleRate: 16000,
  numChannels: 1,
);
```

**Impact:** Cannot adapt to different transcription requirements, quality settings, or platform-specific optimizations without code changes.

**Recommendation:** Make the configuration injectable or configurable via `AppConfig`. Consider whether different recording modes (high quality vs. low bandwidth) might be needed in the future.

---

### P1-4: Incomplete error handling for recorder.stop() returning null

**Location:** `lib/data/audio/record_audio_recording_service.dart:103-104`

**Issue:** The code handles `recorder.stop()` returning null by falling back to `session.outputPath`, but doesn't validate that the file actually exists at that path.

```dart
final stoppedPath = await recorder.stop();
final resolvedPath = (stoppedPath ?? session.outputPath).trim();
```

**Impact:** If the recorder fails silently and returns null, the service returns a path that may not correspond to a valid file. Downstream processing would fail when trying to read a non-existent file.

**Recommendation:** After resolving the path, verify the file exists and is non-empty before returning it. If not, treat it as a recording failure.

---

### P1-5: No handling for concurrent stop calls

**Location:** `lib/data/audio/record_audio_recording_service.dart:96-121`

**Issue:** While `_runExclusive` serializes operations, there's no specific handling for what happens if `stopRecording()` is called twice concurrently. The second call would wait for the first, then throw `NoActiveRecordingFailure` because the first cleared `_activeSession`.

**Impact:** The behavior is technically correct (second stop fails), but the error message might be confusing if the second call was intentional (e.g., UI component and orchestrator both try to stop).

**Recommendation:** Consider whether this is the desired behavior or if a "already stopped" outcome should be distinct from "never started". Document the expected behavior clearly.

---

### P1-6: Missing test for dispose behavior with active recording

**Location:** `test/data/audio/audio_recording_service_test.dart`

**Issue:** The unit tests do not cover calling `dispose()` while a recording is in progress.

**Impact:** The critical bug identified in PO-2 is not caught by tests, allowing it to reach production.

**Recommendation:** Add a test that starts a recording, calls `dispose()` without stopping, and verifies that the recorder is stopped and the file is cleaned up appropriately.

---

### P1-7: Missing test for recorder.start() failure scenarios

**Location:** `test/data/audio/audio_recording_service_test.dart`

**Issue:** Tests use a fake recorder that always succeeds. There are no tests for what happens when `recorder.start()` throws an exception.

**Impact:** Error handling paths for start failures are untested and may be incorrect.

**Recommendation:** Add tests where the fake recorder throws exceptions during start to verify state cleanup and error propagation.

---

## P2 Findings (Medium - Nice to Have)

### P2-1: `_runExclusive` is a custom reimplementation of async queuing

**Location:** `lib/data/audio/record_audio_recording_service.dart:130-144`

**Issue:** The serialization mechanism is a custom implementation with potential bugs (PO-1) rather than using a well-tested library pattern.

**Impact:** Maintenance burden and risk of subtle bugs. The pattern is not immediately obvious to readers.

**Recommendation:** Consider using the `async` package's `Lock` or a simple async queue implementation. If keeping the custom implementation, add extensive documentation explaining the pattern and its invariants.

---

### P2-2: `RecorderAdapter` naming is too generic

**Location:** `lib/data/audio/record_audio_recording_service.dart:9-13`

**Issue:** The name `RecorderAdapter` is generic and doesn't indicate it's specifically for the `record` package.

**Impact:** Could be confused with other recorder adapters in the future (e.g., for different recording packages or platforms).

**Recommendation:** Rename to `RecordPackageAdapter` or `AudioRecorderAdapter` to be more specific about what it adapts.

---

### P2-3: Provider creates new service instance on each read

**Location:** `lib/data/audio/audio_recording_providers.dart:18-32`

**Issue:** The `audioRecordingServiceProvider` is a regular `Provider`, not a singleton. Each `container.read()` creates a new instance, though the dispose handler suggests it expects a single instance.

```dart
final audioRecordingServiceProvider = Provider<AudioRecordingService>((ref) {
  final service = RecordAudioRecordingService(...);
  ref.onDispose(() {
    unawaited(service.dispose());
  });
  return service;
});
```

**Impact:** If multiple parts of the app read the provider independently, they get different service instances with different state, breaking the single-session invariant.

**Recommendation:** Use `Provider` correctly (it should be singleton-like in behavior) or clarify the expected usage pattern. Consider whether the service should be a singleton at the app level.

---

### P2-4: Integration test duplicates fake recorder implementation

**Location:** `integration_test/audio_recording_service_flow_test.dart:157-182`

**Issue:** The integration test defines its own `_FakeRecorderAdapter` that is nearly identical to the one in the unit tests.

**Impact:** Code duplication. If the fake behavior needs to change, it must be updated in two places.

**Recommendation:** Extract the fake recorder to a shared test utility file that both unit and integration tests can use.

---

### P2-5: Integration test helper function lacks type annotations

**Location:** `integration_test/audio_recording_service_flow_test.dart:142-155`

**Issue:** The `_stopAtHardCap` helper function has no parameter type annotations.

```dart
Future<String> _stopAtHardCap({
  required AudioRecordingService service,
  required FakeMonotonicClock monotonicClock,
}) async {
```

**Impact:** Reduces readability and relies on type inference. In a test file, this is minor but inconsistent with the rest of the codebase.

**Recommendation:** Add explicit type annotations for consistency.

---

### P2-6: No documentation for public classes and methods

**Location:** Multiple files

**Issue:** Key public classes (`MonotonicClock`, `AudioRecordingService`, `RecordAudioRecordingService`) and their public methods lack documentation comments.

**Impact:** Future maintainers must read implementation code to understand usage and behavior. Contract violations are harder to detect.

**Recommendation:** Add Dart doc comments to all public APIs explaining their purpose, parameters, return values, and any important invariants or error conditions.

---

## P3 Findings (Low - Minor Issues)

### P3-1: `StopwatchMonotonicClock` always starts the stopwatch

**Location:** `lib/core/time/monotonic_clock.dart:5-11`

**Issue:** The constructor always starts the stopwatch, even if one is passed in. If a stopwatch is passed in that's already running, it starts it again (which is a no-op but confusing).

```dart
StopwatchMonotonicClock({Stopwatch? stopwatch})
  : _stopwatch = stopwatch ?? Stopwatch() {
  if (!_stopwatch.isRunning) {
    _stopwatch.start();
  }
}
```

**Impact:** Minor confusion in the constructor logic. The behavior is correct but the intent is unclear.

**Recommendation:** Clarify the contract: either always create and start a new stopwatch, or respect the passed stopwatch's state without modification.

---

### P3-2: Fake monotonic clock uses mutable state

**Location:** `test/test_doubles/fake_monotonic_clock.dart:3-14`

**Issue:** The `currentTimeMs` field is public and mutable.

```dart
int currentTimeMs;
```

**Impact:** Tests could accidentally modify the time directly instead of using `advance()`, making tests harder to understand.

**Recommendation:** Make `currentTimeMs` private and expose it only through `now()` and `advance()`.

---

### P3-3: Test naming inconsistency

**Location:** `test/data/audio/audio_recording_service_test.dart`

**Issue:** Some test names use full sentences while others are more concise. No consistent naming pattern.

**Impact:** Reduced readability of the test suite.

**Recommendation:** Establish and follow a consistent test naming convention (e.g., "should X when Y" or "X_givenY_expectsZ").

---

### P3-4: No documentation for monotonic clock abstraction

**Location:** `lib/core/time/monotonic_clock.dart:1-3`

**Issue:** The `MonotonicClock` interface has no documentation explaining what "monotonic" means in this context or why it's needed.

**Impact:** Future developers may not understand the purpose or when to use it vs. `DateTime.now()`.

**Recommendation:** Add a doc comment explaining the monotonic time concept and its use case for deadline calculations.

---

### P3-5: Hard-coded assumption about record package behavior

**Location:** `lib/data/audio/record_audio_recording_service.dart:103-104`

**Issue:** The code assumes `recorder.stop()` returns the output path, but falls back to the session path if null. This suggests uncertainty about the package's contract.

```dart
final stoppedPath = await recorder.stop();
final resolvedPath = (stoppedPath ?? session.outputPath).trim();
```

**Impact:** If the package's behavior changes, the fallback might be incorrect. The uncertainty should be resolved.

**Recommendation:** Verify the actual contract of the `record` package's `stop()` method through documentation or testing, then remove the fallback if it's unnecessary, or add a comment explaining why it's needed.

---

### P3-6: No validation of hardCap in provider

**Location:** `lib/data/audio/audio_recording_providers.dart:22-24`

**Issue:** The provider reads `recordingHardCapMs` from config but doesn't validate it before passing to the service constructor, even though the service validates it.

```dart
hardCap: Duration(
  milliseconds: ref.watch(appConfigProvider).recordingHardCapMs,
),
```

**Impact:** Redundant validation (service validates again). If the config value is invalid, the error occurs at service construction time rather than provider read time.

**Recommendation:** Either validate in the provider for earlier error detection, or rely solely on service validation and document the contract.

---

## Architecture Concerns

### A-1: Service owns file lifecycle but doesn't own cleanup policy

**Location:** `lib/data/audio/record_audio_recording_service.dart`

**Issue:** The service deletes too-short files but leaves valid files for downstream cleanup. This creates a split ownership model where the service owns some cleanup but not all.

**Impact:** Confusing ownership boundaries. Callers must remember to delete files after successful processing, but the service handles deletion for too-short recordings.

**Recommendation:** Consider either:
- Service owns all file lifecycle (provide a `cleanupFile()` method)
- Service owns no file lifecycle (always return the path, let caller decide)
- Document the ownership model explicitly and consistently

---

### A-2: Monotonic clock abstraction may be over-engineering

**Location:** `lib/core/time/monotonic_clock.dart`

**Issue:** The monotonic clock abstraction adds complexity for a single use case (deadline calculations). The `record` package likely doesn't need monotonic time.

**Impact:** Additional abstraction layer without clear benefit beyond deadline math. The fake implementation is simple enough that the abstraction might not be pulling its weight.

**Recommendation:** Evaluate whether the abstraction is necessary. If only used for deadline math, consider calculating deadlines as `Duration` offsets from start time rather than absolute monotonic timestamps.

---

### A-3: No separation between service contract and implementation concerns

**Location:** `lib/data/audio/audio_recording_service.dart` and `record_audio_recording_service.dart`

**Issue:** The service contract includes implementation details like `hardCapDeadlineElapsedRealtime` which exposes the monotonic time implementation to callers.

**Impact:** Callers must understand monotonic time to use the deadline correctly. The contract leaks implementation details.

**Recommendation:** Consider exposing the deadline as a `Duration` remaining rather than an absolute monotonic timestamp, or provide a helper method like `Duration timeUntilHardCap()`.

---

## Library Usage Concerns

### L-1: Using `record` package without exploring alternatives

**Location:** `pubspec.yaml:45`

**Issue:** The implementation uses the `record` package without documented evaluation of alternatives or justification for this choice.

**Impact:** No record of why this package was selected over alternatives like `flutter_sound`, `audio_recorder`, or platform-specific implementations.

**Recommendation:** Document the evaluation criteria and why `record` was chosen (cross-platform support, maintenance status, API design, etc.) in the plan or implementation notes.

---

### L-2: AAC encoder choice not justified

**Location:** `lib/data/audio/record_audio_recording_service.dart:56`

**Issue:** The choice of `AudioEncoder.aacLc` is not documented with rationale.

**Impact:** Future developers may not understand why AAC was chosen over other formats (MP3, WAV, Opus, etc.) or why AAC-LC specifically.

**Recommendation:** Document the rationale: compatibility with transcription service, file size considerations, platform support, etc.

---

### L-3: 16kHz sample rate not justified

**Location:** `lib/data/audio/record_audio_recording_service.dart:57`

**Issue:** The 16kHz sample rate choice is not documented with rationale.

**Impact:** Unclear why this specific rate was chosen over 8kHz, 44.1kHz, or 48kHz.

**Recommendation:** Document the rationale: transcription service requirements, speech recognition optimization, bandwidth considerations, etc.

---

## Missing Cases

### M-1: No handling for app backgrounding/foregrounding

**Issue:** The spec and implementation don't address what happens if the app goes to the background during recording.

**Impact:** On some platforms, recording may be interrupted when the app backgrounds. The service has no handling for this case.

**Recommendation:** Document whether background recording is supported, or add handling for recording interruption and recovery.

---

### M-2: No handling for audio session interruptions (calls, other apps)

**Issue:** The implementation doesn't handle audio session interruptions from phone calls, other apps playing audio, or system sounds.

**Impact:** Recording may be interrupted or corrupted by system audio events.

**Recommendation:** Consider whether audio session handling is in scope. If not, document this limitation explicitly.

---

### M-3: No handling for storage space exhaustion

**Issue:** The implementation doesn't check available storage space before starting recording or handle out-of-space errors during recording.

**Impact:** Recording may fail mid-way due to insufficient disk space, leaving an incomplete file.

**Recommendation:** Add storage space checks before recording, or handle out-of-space errors gracefully with clear error messages.

---

### M-4: No handling for microphone permission changes after start

**Issue:** If microphone permission is revoked while recording is in progress, the implementation doesn't handle this case.

**Impact:** Recording may fail or stop unexpectedly with unclear error handling.

**Recommendation:** Document whether permission revocation during recording is handled, or add monitoring for permission changes.

---

### M-5: No file size limits

**Issue:** The implementation enforces a time limit (hard cap) but no file size limit.

**Impact:** On devices with unusual audio hardware or bugs, the file could grow unexpectedly large within the time limit.

**Recommendation:** Consider adding a file size limit as a safety measure, or document why this is not needed.

---

## Summary Statistics

- **PO findings:** 6 (critical)
- **P1 findings:** 7 (high)
- **P2 findings:** 6 (medium)
- **P3 findings:** 6 (low)
- **Architecture concerns:** 3
- **Library usage concerns:** 3
- **Missing cases:** 5

**Total findings:** 36

---

## Recommended Action Order

1. Fix all PO findings before merge
2. Address P1 findings related to error handling and test coverage
3. Resolve architecture concerns that affect future extensibility
4. Address P2 findings for code quality and maintainability
5. Consider P3 findings and missing cases based on product priorities
