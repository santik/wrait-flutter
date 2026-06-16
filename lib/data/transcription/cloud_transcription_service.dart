import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import '../../domain/model/supported_language.dart';
import '../audio/audio_recording_service.dart';
import '../api/backend_results.dart' as backend;
import '../api/record_quota_state.dart';
import 'transcription_service.dart';

typedef TranscribeAudioCallback =
    Future<backend.TranscriptionResult> Function(File audioFile);
typedef LiveRecordingPathFactory = Future<String> Function();
typedef TranscriptionWarningLogger =
    void Function(String message, {Object? error, StackTrace? stackTrace});

class CloudTranscriptionService implements TranscriptionService {
  CloudTranscriptionService({
    required this.audioRecordingService,
    required this.transcribeAudio,
    required this.createLiveRecordingPath,
    required this.setSessionQuota,
    TranscriptionWarningLogger? logWarning,
  }) : _logWarning = logWarning ?? _defaultLogWarning;

  final AudioRecordingService audioRecordingService;
  final TranscribeAudioCallback transcribeAudio;
  final LiveRecordingPathFactory createLiveRecordingPath;
  final void Function(RecordQuotaState quota) setSessionQuota;
  final TranscriptionWarningLogger _logWarning;

  _CloudTranscriptionState _state = _CloudTranscriptionState.idle;

  @override
  bool get isRecording => audioRecordingService.isRecording;

  @override
  bool get isTranscribing => _state == _CloudTranscriptionState.transcribing;

  @override
  int? get hardCapDeadlineElapsedRealtime =>
      audioRecordingService.hardCapDeadlineElapsedRealtime;

  @override
  Future<void> startLiveTranscription({
    required TranscriptionStatusCallback onStatus,
  }) async {
    _ensureIdle();
    _state = _CloudTranscriptionState.startingLiveRecording;

    try {
      final outputPath = await createLiveRecordingPath();
      await audioRecordingService.startRecording(outputPath);

      final deadline = audioRecordingService.hardCapDeadlineElapsedRealtime;
      if (deadline == null) {
        throw StateError(
          'Recording started without exposing a hard-cap deadline.',
        );
      }

      _state = _CloudTranscriptionState.liveRecording;
      onStatus(RecordingStarted(deadline));
    } on RecordingPermissionDeniedFailure {
      _state = _CloudTranscriptionState.idle;
      throw const MicBlockedTranscriptionServiceFailure();
    } catch (_) {
      _state = _CloudTranscriptionState.idle;
      rethrow;
    }
  }

  @override
  Future<TranscriptionResult> stopLiveTranscription({
    required TranscriptionStatusCallback onStatus,
  }) async {
    if (_state != _CloudTranscriptionState.liveRecording ||
        !audioRecordingService.isRecording) {
      throw const NoActiveLiveTranscriptionFailure();
    }

    _state = _CloudTranscriptionState.stoppingLiveRecording;

    late final String audioPath;
    try {
      audioPath = await audioRecordingService.stopRecording();
    } on RecordingTooShortFailure {
      _state = _CloudTranscriptionState.idle;
      return const TranscriptionFailure(
        reason: TranscriptionFailureReason.tooShort,
      );
    } catch (_) {
      _state = _CloudTranscriptionState.idle;
      rethrow;
    }

    _state = _CloudTranscriptionState.transcribing;
    try {
      onStatus(const Uploading());
      return await _transcribeCapturedAudio(
        audioPath: audioPath,
        preserveAudioOnFailure: true,
        deleteAudioOnSuccess: true,
      );
    } finally {
      _state = _CloudTranscriptionState.idle;
    }
  }

  @override
  Future<TranscriptionResult> transcribeAudioDraft(String audioPath) async {
    _ensureIdle();

    final validatedAudioPath = await _validateDraftAudioPath(audioPath);
    if (validatedAudioPath == null) {
      return const TranscriptionFailure(
        reason: TranscriptionFailureReason.apiError,
      );
    }

    _state = _CloudTranscriptionState.transcribing;
    try {
      return await _transcribeCapturedAudio(
        audioPath: validatedAudioPath,
        preserveAudioOnFailure: false,
        deleteAudioOnSuccess: false,
      );
    } finally {
      _state = _CloudTranscriptionState.idle;
    }
  }

  void _ensureIdle() {
    if (_state != _CloudTranscriptionState.idle ||
        audioRecordingService.isRecording) {
      throw const TranscriptionAlreadyInProgressFailure();
    }
  }

  Future<String?> _validateDraftAudioPath(String audioPath) async {
    final trimmedPath = audioPath.trim();
    if (trimmedPath.isEmpty) {
      _logWarning(
        'Cloud transcription draft upload skipped because the audio path was blank.',
      );
      return null;
    }

    final file = File(trimmedPath);
    try {
      if (!await file.exists()) {
        _logWarning(
          'Cloud transcription draft upload skipped because the audio file was missing: $trimmedPath',
        );
        return null;
      }

      final handle = await file.open(mode: FileMode.read);
      await handle.close();

      if (await file.length() <= 0) {
        _logWarning(
          'Cloud transcription draft upload skipped because the audio file was empty: $trimmedPath',
        );
        return null;
      }
    } on FileSystemException catch (error, stackTrace) {
      _logWarning(
        'Cloud transcription draft upload skipped because the audio file was unreadable: $trimmedPath',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }

    return trimmedPath;
  }

  Future<TranscriptionResult> _transcribeCapturedAudio({
    required String audioPath,
    required bool preserveAudioOnFailure,
    required bool deleteAudioOnSuccess,
  }) async {
    try {
      final backendResult = await transcribeAudio(File(audioPath));
      return switch (backendResult) {
        backend.TranscriptionSuccess() => _handleSuccessResult(
          backendResult,
          audioPath: audioPath,
          deleteAudioOnSuccess: deleteAudioOnSuccess,
        ),
        backend.TranscriptionFailure() => _handleFailureResult(
          backendResult,
          audioPath: audioPath,
          preserveAudioOnFailure: preserveAudioOnFailure,
        ),
      };
    } catch (error, stackTrace) {
      _logWarning(
        'Cloud transcription crashed while uploading audio.',
        error: error,
        stackTrace: stackTrace,
      );
      return TranscriptionFailure(
        reason: TranscriptionFailureReason.apiError,
        audioDraftPath: preserveAudioOnFailure ? audioPath : null,
      );
    }
  }

  Future<TranscriptionResult> _handleSuccessResult(
    backend.TranscriptionSuccess result, {
    required String audioPath,
    required bool deleteAudioOnSuccess,
  }) async {
    final transcript = result.transcript.trim();
    if (transcript.isEmpty) {
      _logWarning(
        'Cloud transcription returned a blank transcript in a success payload.',
      );
      return TranscriptionFailure(
        reason: TranscriptionFailureReason.nothingCaught,
        audioDraftPath: deleteAudioOnSuccess ? audioPath : null,
        quota: result.quota,
      );
    }

    _propagateQuota(result.quota);
    final normalizedLanguage = resolveSupportedLanguageCode(
      result.detectedLanguage,
    );

    if (deleteAudioOnSuccess) {
      await _deleteFileIfPresent(audioPath);
    }

    return TranscriptionSuccess(
      transcript: transcript,
      detectedLanguage: normalizedLanguage,
      quota: result.quota,
    );
  }

  TranscriptionResult _handleFailureResult(
    backend.TranscriptionFailure result, {
    required String audioPath,
    required bool preserveAudioOnFailure,
  }) {
    _propagateQuota(result.quota);
    _logWarning('Cloud transcription failed with ${result.reason.name}.');

    return TranscriptionFailure(
      reason: _mapFailureReason(result.reason),
      audioDraftPath: preserveAudioOnFailure ? audioPath : null,
      quota: result.quota,
    );
  }

  void _propagateQuota(RecordQuotaState? quota) {
    if (quota != null) {
      setSessionQuota(quota);
    }
  }

  TranscriptionFailureReason _mapFailureReason(
    backend.BackendFailureReason reason,
  ) {
    return switch (reason) {
      backend.BackendFailureReason.timeout =>
        TranscriptionFailureReason.timeout,
      backend.BackendFailureReason.noInternet =>
        TranscriptionFailureReason.network,
      backend.BackendFailureReason.backendUnavailable =>
        TranscriptionFailureReason.backendUnavailable,
      backend.BackendFailureReason.proxyAuthFailed =>
        TranscriptionFailureReason.proxyAuthFailed,
      backend.BackendFailureReason.requestTooLarge ||
      backend.BackendFailureReason.quotaExceeded ||
      backend.BackendFailureReason.apiError =>
        TranscriptionFailureReason.apiError,
    };
  }

  Future<void> _deleteFileIfPresent(String audioPath) async {
    try {
      final file = File(audioPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (error, stackTrace) {
      _logWarning(
        'Failed to delete live transcription audio after success.',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  static void _defaultLogWarning(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    developer.log(
      message,
      name: 'CloudTranscriptionService',
      error: error,
      stackTrace: stackTrace,
    );
  }
}

enum _CloudTranscriptionState {
  idle,
  startingLiveRecording,
  liveRecording,
  stoppingLiveRecording,
  transcribing,
}
