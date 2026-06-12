import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time/monotonic_clock.dart';
import '../../data/api/backend_providers.dart';
import '../../data/api/backend_results.dart' as backend;
import '../../data/audio/audio_recording_providers.dart';
import '../../data/audio/audio_recording_service.dart';
import '../../data/entries/entry_providers.dart';
import '../../data/preferences/preferences_providers.dart';
import '../../data/transcription/transcription_providers.dart';
import '../../data/transcription/transcription_service.dart';
import '../../domain/repository/entry_repository.dart';
import '../../domain/repository/preferences_repository.dart';
import '../../domain/usecase/cleanup_transcript_use_case.dart';
import 'recording_state.dart';

typedef RecordingControllerWarningLogger =
    void Function(String message, {Object? error, StackTrace? stackTrace});

class RecordingFeedbackDelays {
  const RecordingFeedbackDelays({
    this.errorAndDeletedAutoClear = const Duration(seconds: 3),
    this.savedDisplayWindow = const Duration(seconds: 4),
  });

  final Duration errorAndDeletedAutoClear;
  final Duration savedDisplayWindow;
}

final recordingControllerWarningLoggerProvider =
    Provider<RecordingControllerWarningLogger>((ref) {
      return (message, {error, stackTrace}) {
        developer.log(
          message,
          name: 'MainRecordingController',
          error: error,
          stackTrace: stackTrace,
        );
      };
    });

final recordingFeedbackDelaysProvider = Provider<RecordingFeedbackDelays>(
  (ref) => const RecordingFeedbackDelays(),
);

final mainRecordingControllerProvider =
    NotifierProvider<MainRecordingController, RecordingControllerState>(
      MainRecordingController.new,
    );

class MainRecordingController extends Notifier<RecordingControllerState> {
  TranscriptionService get _transcriptionService =>
      ref.read(transcriptionServiceProvider);
  CleanupTranscriptUseCase get _cleanupTranscriptUseCase =>
      ref.read(cleanupTranscriptUseCaseProvider);
  EntryRepository get _entryRepository => ref.read(entryRepositoryProvider);
  PreferencesRepository get _preferencesRepository =>
      ref.read(preferencesRepositoryProvider);
  MonotonicClock get _monotonicClock => ref.read(monotonicClockProvider);
  RecordingControllerWarningLogger get _logWarning =>
      ref.read(recordingControllerWarningLoggerProvider);
  RecordingFeedbackDelays get _feedbackDelays =>
      ref.read(recordingFeedbackDelaysProvider);

  Timer? _autoClearTimer;
  int? _listeningStartedAtElapsedRealtime;
  bool _buttonActionInFlight = false;

  @override
  RecordingControllerState build() {
    ref.onDispose(() {
      _cancelAutoClearTimer();
    });
    return const RecordingControllerState();
  }

  Future<void> onMainButtonTapped() async {
    if (_buttonActionInFlight) {
      return;
    }

    final current = state.recordingState;
    switch (current) {
      case RecordingIdle():
        await _startListening();
        return;
      case RecordingListening():
        await _stopListening();
        return;
      case RecordingUploading() || RecordingProcessing():
        return;
      case RecordingSaved():
        await _startListening();
        return;
      case RecordingDeleted():
        await _startListening();
        return;
      case RecordingErrorState():
        if (current.error == RecordingError.insufficientPermissions) {
          resetToIdle();
          return;
        }
        await _startListening();
        return;
    }
  }

  void clearSaved() {
    if (state.recordingState is! RecordingSaved) {
      return;
    }
    resetToIdle();
  }

  void resetToIdle() {
    _cancelAutoClearTimer();
    _listeningStartedAtElapsedRealtime = null;
    state = state.copyWith(recordingState: const RecordingIdle());
  }

  void onEntriesDeleted(int count) {
    if (count <= 0) {
      return;
    }

    _cancelAutoClearTimer();
    _listeningStartedAtElapsedRealtime = null;
    final deletedState = RecordingDeleted(count);
    state = state.copyWith(recordingState: deletedState);
    _scheduleAutoClear(deletedState);
  }

  Future<void> _startListening() async {
    _buttonActionInFlight = true;
    _cancelAutoClearTimer();
    _listeningStartedAtElapsedRealtime = null;

    try {
      await _transcriptionService.startLiveTranscription(
        onStatus: _handleTranscriptionStatus,
      );
    } on TranscriptionServiceFailure catch (error, stackTrace) {
      _handleStartFailure(error, stackTrace);
    } catch (error, stackTrace) {
      _emitError(
        RecordingError.apiFailed,
        cause: error,
        stackTrace: stackTrace,
      );
    } finally {
      _buttonActionInFlight = false;
    }
  }

  Future<void> _stopListening() async {
    _buttonActionInFlight = true;
    final isTooShortTap =
        _listeningStartedAtElapsedRealtime != null &&
        _monotonicClock.now() - _listeningStartedAtElapsedRealtime! <
            minimumRecordingDuration.inMilliseconds;

    try {
      final result = await _transcriptionService.stopLiveTranscription(
        onStatus: _handleTranscriptionStatus,
      );
      if (isTooShortTap && result is TranscriptionSuccess) {
        _logWarning(
          'Stop requested before the minimum duration, but transcription unexpectedly succeeded.',
        );
      }
      await _handleTranscriptionResult(result);
    } on TranscriptionServiceFailure catch (error, stackTrace) {
      _emitError(
        RecordingError.apiFailed,
        cause: error,
        stackTrace: stackTrace,
      );
    } catch (error, stackTrace) {
      _emitError(
        RecordingError.apiFailed,
        cause: error,
        stackTrace: stackTrace,
      );
    } finally {
      _buttonActionInFlight = false;
    }
  }

  void _handleTranscriptionStatus(TranscriptionStatus status) {
    switch (status) {
      case RecordingStarted():
        _listeningStartedAtElapsedRealtime = _monotonicClock.now();
        state = state.copyWith(recordingState: const RecordingListening());
        return;
      case Uploading():
        state = state.copyWith(recordingState: const RecordingUploading());
        return;
    }
  }

  void _handleStartFailure(
    TranscriptionServiceFailure error,
    StackTrace stackTrace,
  ) {
    _emitError(
      switch (error) {
        MicBlockedTranscriptionServiceFailure() =>
          RecordingError.insufficientPermissions,
        _ => RecordingError.apiFailed,
      },
      cause: error,
      stackTrace: stackTrace,
    );
  }

  Future<void> _handleTranscriptionResult(TranscriptionResult result) async {
    _listeningStartedAtElapsedRealtime = null;

    switch (result) {
      case TranscriptionSuccess():
        state = state.copyWith(recordingState: const RecordingProcessing());
        await _handleCleanup(result);
        return;
      case TranscriptionFailure():
        await _persistAudioDraftIfNeeded(result.audioDraftPath);
        _emitError(_mapTranscriptionFailure(result.reason));
        return;
    }
  }

  Future<void> _handleCleanup(TranscriptionSuccess result) async {
    final cleanupResult = await _cleanupTranscriptUseCase(
      rawTranscript: result.transcript,
      language: result.detectedLanguage,
    );

    switch (cleanupResult) {
      case CleanupTranscriptSuccess():
        final entryId = cleanupResult.entryId;
        if (entryId == null || entryId <= 0) {
          _logWarning(
            'Cleanup succeeded without a valid entry id; Saved state was not published.',
            error: ArgumentError.value(entryId, 'entryId', 'must be positive'),
          );
          _emitError(RecordingError.apiFailed);
          return;
        }
        await _markHasEverRecorded();
        state = state.copyWith(
          recordingState: RecordingSaved(
            entryId: entryId,
            detectedLanguage: result.detectedLanguage,
          ),
        );
        return;
      case CleanupTranscriptFailure():
        _emitError(_mapCleanupFailure(cleanupResult.reason));
        return;
    }
  }

  Future<void> _persistAudioDraftIfNeeded(String? audioDraftPath) async {
    if (audioDraftPath == null) {
      return;
    }

    final normalizedAudioDraftPath = audioDraftPath.trim();
    if (normalizedAudioDraftPath.isEmpty) {
      return;
    }

    try {
      final entityType = await FileSystemEntity.type(normalizedAudioDraftPath);
      if (entityType != FileSystemEntityType.file) {
        _logWarning(
          'Ignoring retryable audio draft path because it is not a readable file.',
          error: ArgumentError.value(
            normalizedAudioDraftPath,
            'audioDraftPath',
            'must point to an existing file',
          ),
        );
        return;
      }
    } catch (error, stackTrace) {
      _logWarning(
        'Ignoring retryable audio draft path because it could not be validated.',
        error: error,
        stackTrace: stackTrace,
      );
      return;
    }

    try {
      await _entryRepository.saveAudioDraft(
        normalizedAudioDraftPath,
        cleanupTranscriptFallbackLanguage,
      );
    } catch (error, stackTrace) {
      _logWarning(
        'Failed to persist retryable audio draft after transcription failure.',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _markHasEverRecorded() async {
    try {
      await _preferencesRepository.setHasEverRecorded(true);
    } catch (error, stackTrace) {
      _logWarning(
        'Failed to persist hasEverRecorded after successful save.',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  RecordingError _mapTranscriptionFailure(TranscriptionFailureReason reason) {
    return switch (reason) {
      TranscriptionFailureReason.tooShort => RecordingError.tooShort,
      TranscriptionFailureReason.nothingCaught => RecordingError.noMatch,
      TranscriptionFailureReason.micBlocked =>
        RecordingError.insufficientPermissions,
      TranscriptionFailureReason.network ||
      TranscriptionFailureReason.timeout => RecordingError.noInternet,
      TranscriptionFailureReason.backendUnavailable =>
        RecordingError.backendUnavailable,
      TranscriptionFailureReason.proxyAuthFailed =>
        RecordingError.proxyAuthFailed,
      TranscriptionFailureReason.apiError => RecordingError.apiFailed,
    };
  }

  RecordingError _mapCleanupFailure(backend.BackendFailureReason reason) {
    return switch (reason) {
      backend.BackendFailureReason.timeout ||
      backend.BackendFailureReason.noInternet => RecordingError.noInternet,
      backend.BackendFailureReason.backendUnavailable =>
        RecordingError.backendUnavailable,
      backend.BackendFailureReason.proxyAuthFailed =>
        RecordingError.proxyAuthFailed,
      backend.BackendFailureReason.requestTooLarge ||
      backend.BackendFailureReason.quotaExceeded ||
      backend.BackendFailureReason.apiError => RecordingError.apiFailed,
    };
  }

  void _emitError(
    RecordingError nextError, {
    Object? cause,
    StackTrace? stackTrace,
  }) {
    if (cause != null) {
      _logWarning(
        'Recording flow moved to error state: ${nextError.name}.',
        error: cause,
        stackTrace: stackTrace,
      );
    }

    final nextShakeKey = switch (nextError) {
      RecordingError.tooShort ||
      RecordingError.noMatch => state.shakeErrorKey + 1,
      _ => state.shakeErrorKey,
    };
    final errorState = RecordingErrorState(nextError);
    state = state.copyWith(
      recordingState: errorState,
      shakeErrorKey: nextShakeKey,
    );
    _scheduleAutoClear(errorState);
  }

  void _scheduleAutoClear(RecordingState targetState) {
    _cancelAutoClearTimer();
    _autoClearTimer = Timer(_feedbackDelays.errorAndDeletedAutoClear, () {
      if (state.recordingState == targetState) {
        resetToIdle();
      }
    });
  }

  void _cancelAutoClearTimer() {
    _autoClearTimer?.cancel();
    _autoClearTimer = null;
  }
}
