import '../../data/transcription/transcription_service.dart';
import '../model/entry.dart';
import '../repository/entry_repository.dart';
import 'cleanup_transcript_use_case.dart';

typedef ValidateDraftAudioPathCallback = Future<String?> Function(String path);
typedef DeleteRetainedAudioCallback = Future<void> Function(String path);
typedef RetryPendingDraftsWarningLogger =
    void Function(String message, {Object? error, StackTrace? stackTrace});

const launchRetryStaleDraftDays = 7;

class RetryPendingDraftsUseCase {
  RetryPendingDraftsUseCase({
    required this.entryRepository,
    required this.transcriptionService,
    required this.cleanupTranscriptUseCase,
    required this.validateDraftAudioPath,
    required this.deleteRetainedAudio,
    required this.logWarning,
  });

  final EntryRepository entryRepository;
  final TranscriptionService transcriptionService;
  final CleanupTranscriptUseCase cleanupTranscriptUseCase;
  final ValidateDraftAudioPathCallback validateDraftAudioPath;
  final DeleteRetainedAudioCallback deleteRetainedAudio;
  final RetryPendingDraftsWarningLogger logWarning;

  Future<void>? _inFlight;

  Future<void> call() {
    final inFlight = _inFlight;
    if (inFlight != null) {
      return inFlight;
    }

    final future = _run();
    _inFlight = future;
    future.whenComplete(() {
      if (identical(_inFlight, future)) {
        _inFlight = null;
      }
    });
    return future;
  }

  Future<void> _run() async {
    try {
      await entryRepository.deleteStaleDrafts(
        daysOld: launchRetryStaleDraftDays,
      );
    } catch (error, stackTrace) {
      logWarning(
        'Failed to delete stale drafts before launch retry.',
        error: error,
        stackTrace: stackTrace,
      );
      return;
    }

    final drafts = await _loadPendingDrafts();
    if (drafts == null) {
      return;
    }

    for (final draft in drafts) {
      try {
        if (_isAudioDraft(draft)) {
          await _retryAudioDraft(draft);
        } else {
          await _retryTextDraft(draft);
        }
      } catch (error, stackTrace) {
        logWarning(
          'Failed to retry draft ${draft.id}.',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
  }

  Future<List<Entry>?> _loadPendingDrafts() async {
    try {
      return await entryRepository.getPendingDrafts();
    } catch (error, stackTrace) {
      logWarning(
        'Failed to load pending drafts during app launch.',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  bool _isAudioDraft(Entry entry) {
    final audioPath = entry.audioPath;
    return audioPath != null && audioPath.trim().isNotEmpty;
  }

  Future<void> _retryAudioDraft(Entry draft) async {
    final audioPath = draft.audioPath;
    if (audioPath == null) {
      return;
    }

    final validatedPath = await validateDraftAudioPath(audioPath);
    if (validatedPath == null) {
      await _deleteMalformedAudioDraft(draft.id);
      return;
    }

    final TranscriptionResult transcriptionResult;
    try {
      transcriptionResult = await transcriptionService.transcribeAudioDraft(
        validatedPath,
      );
    } on TranscriptionServiceFailure catch (error, stackTrace) {
      logWarning(
        'Launch retry preserved audio draft ${draft.id} after transcription service failure.',
        error: error,
        stackTrace: stackTrace,
      );
      return;
    }

    switch (transcriptionResult) {
      case TranscriptionSuccess():
        if (transcriptionResult.transcript.trim().isEmpty) {
          logWarning(
            'Launch retry preserved audio draft ${draft.id} because transcription returned a blank transcript.',
          );
          return;
        }
        await _handleSuccessfulAudioRetry(
          draftId: draft.id,
          audioPath: validatedPath,
          transcriptionResult: transcriptionResult,
        );
        return;
      case TranscriptionFailure():
        logWarning(
          'Launch retry preserved audio draft ${draft.id} after transcription failure: '
          '${transcriptionResult.reason.name}.',
        );
        return;
    }
  }

  Future<void> _handleSuccessfulAudioRetry({
    required int draftId,
    required String audioPath,
    required TranscriptionSuccess transcriptionResult,
  }) async {
    final cleanupResult = await cleanupTranscriptUseCase(
      entryId: draftId,
      rawTranscript: transcriptionResult.transcript,
      language: transcriptionResult.detectedLanguage,
    );

    switch (cleanupResult) {
      case CleanupTranscriptSuccess():
        await _deleteRetainedAudioBestEffort(
          audioPath,
          logContext: 'successful draft finalization',
        );
        return;
      case CleanupTranscriptFailure():
        final refreshedEntry = await _safeGetEntryById(draftId);
        if (refreshedEntry != null && !_isAudioDraft(refreshedEntry)) {
          await _deleteRetainedAudioBestEffort(
            audioPath,
            logContext: 'audio-to-text draft promotion',
          );
          return;
        }

        logWarning(
          'Launch retry preserved audio draft $draftId after cleanup failure: '
          '${cleanupResult.reason.name}.',
        );
        return;
    }
  }

  Future<void> _retryTextDraft(Entry draft) async {
    final cleanupResult = await cleanupTranscriptUseCase(
      entryId: draft.id,
      rawTranscript: draft.rawTranscript,
      language: draft.language,
    );

    if (cleanupResult case CleanupTranscriptFailure(reason: final reason)) {
      logWarning(
        'Launch retry preserved text draft ${draft.id} after cleanup failure: '
        '${reason.name}.',
      );
    }
  }

  Future<void> _deleteMalformedAudioDraft(int draftId) async {
    try {
      await entryRepository.deleteEntry(draftId);
    } catch (error, stackTrace) {
      logWarning(
        'Failed to delete malformed audio draft $draftId.',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<Entry?> _safeGetEntryById(int draftId) async {
    try {
      return await entryRepository.getEntryById(draftId);
    } catch (error, stackTrace) {
      logWarning(
        'Failed to reload draft $draftId after cleanup retry.',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<void> _deleteRetainedAudioBestEffort(
    String audioPath, {
    required String logContext,
  }) async {
    try {
      await deleteRetainedAudio(audioPath);
    } catch (error, stackTrace) {
      logWarning(
        'Failed to delete retained draft audio after $logContext.',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
