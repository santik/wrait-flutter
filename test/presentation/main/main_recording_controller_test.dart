import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wrait/data/api/backend_providers.dart';
import 'package:wrait/data/api/backend_results.dart' as backend;
import 'package:wrait/data/audio/audio_recording_providers.dart';
import 'package:wrait/data/entries/entry_providers.dart';
import 'package:wrait/data/preferences/preferences_providers.dart';
import 'package:wrait/data/transcription/transcription_providers.dart';
import 'package:wrait/data/transcription/transcription_service.dart';
import 'package:wrait/domain/model/entry.dart';
import 'package:wrait/domain/repository/entry_repository.dart';
import 'package:wrait/domain/repository/preferences_repository.dart';
import 'package:wrait/domain/usecase/cleanup_transcript_use_case.dart';
import 'package:wrait/presentation/main/main_recording_controller.dart';
import 'package:wrait/presentation/main/recording_state.dart';

import '../../test_doubles/fake_monotonic_clock.dart';

void main() {
  late _FakeTranscriptionService transcriptionService;
  late _FakeCleanupTranscriptUseCase cleanupUseCase;
  late _FakeEntryRepository entryRepository;
  late _FakePreferencesRepository preferencesRepository;
  late FakeMonotonicClock monotonicClock;
  late List<String> logMessages;
  late List<Object?> logErrors;
  late Directory tempDirectory;
  late ProviderContainer container;

  ProviderContainer buildContainer({
    RecordingFeedbackDelays feedbackDelays = const RecordingFeedbackDelays(
      errorAndDeletedAutoClear: Duration(milliseconds: 1),
    ),
  }) {
    transcriptionService = _FakeTranscriptionService();
    cleanupUseCase = _FakeCleanupTranscriptUseCase();
    entryRepository = _FakeEntryRepository();
    preferencesRepository = _FakePreferencesRepository();
    monotonicClock = FakeMonotonicClock(0);
    logMessages = <String>[];
    logErrors = <Object?>[];

    return ProviderContainer(
      overrides: [
        transcriptionServiceProvider.overrideWithValue(transcriptionService),
        cleanupTranscriptUseCaseProvider.overrideWithValue(cleanupUseCase),
        entryRepositoryProvider.overrideWithValue(entryRepository),
        preferencesRepositoryProvider.overrideWithValue(preferencesRepository),
        monotonicClockProvider.overrideWithValue(monotonicClock),
        recordingFeedbackDelaysProvider.overrideWithValue(feedbackDelays),
        recordingControllerWarningLoggerProvider.overrideWithValue((
          message, {
          error,
          stackTrace,
        }) {
          logMessages.add(message);
          logErrors.add(error);
        }),
      ],
    );
  }

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'wrait-main-recording-controller-test',
    );
    container = buildContainer();
  });

  tearDown(() async {
    container.dispose();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  Future<void> driveSuccessfulSave({required int entryId}) async {
    cleanupUseCase.nextResult = CleanupTranscriptSuccess(
      entryId: entryId,
      cleanedText: 'saved',
    );
    transcriptionService.nextStopResult = const TranscriptionSuccess(
      transcript: 'raw transcript',
      detectedLanguage: 'en-US',
    );

    await container
        .read(mainRecordingControllerProvider.notifier)
        .onMainButtonTapped();
    monotonicClock.advance(const Duration(seconds: 6));
    await container
        .read(mainRecordingControllerProvider.notifier)
        .onMainButtonTapped();
  }

  test(
    'idle button tap starts live recording and publishes Listening',
    () async {
      await container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();

      expect(transcriptionService.startCallCount, 1);
      expect(
        container.read(mainRecordingControllerProvider),
        RecordingControllerState(
          recordingState: RecordingListening(
            hardCapDeadlineElapsedRealtime: 120000,
          ),
        ),
      );
      expect(container.read(mainRecordingControllerProvider).isActive, isTrue);
    },
  );

  test('start failure from blocked microphone publishes mic error', () async {
    transcriptionService.startError =
        const MicBlockedTranscriptionServiceFailure();

    await container
        .read(mainRecordingControllerProvider.notifier)
        .onMainButtonTapped();

    expect(
      container.read(mainRecordingControllerProvider).recordingState,
      const RecordingErrorState(RecordingError.insufficientPermissions),
    );
  });

  test(
    'Listening stop before five seconds publishes TooShort, increments shake once, and auto-clears',
    () async {
      await container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();
      transcriptionService.nextStopResult = const TranscriptionFailure(
        reason: TranscriptionFailureReason.tooShort,
      );

      await container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();

      expect(
        container.read(mainRecordingControllerProvider),
        const RecordingControllerState(
          recordingState: RecordingErrorState(RecordingError.tooShort),
          shakeErrorKey: 1,
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(
        container.read(mainRecordingControllerProvider).recordingState,
        const RecordingIdle(),
      );
    },
  );

  test(
    'valid stop publishes Uploading then Processing then Saved with entry id and detected language',
    () async {
      await container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();
      monotonicClock.advance(const Duration(seconds: 6));
      cleanupUseCase.nextResult = const CleanupTranscriptSuccess(
        entryId: 42,
        cleanedText: 'Cleaned transcript',
      );
      transcriptionService.nextStopResult = const TranscriptionSuccess(
        transcript: 'raw transcript',
        detectedLanguage: 'fr-FR',
      );

      await container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();

      expect(transcriptionService.statusHistory, contains(const Uploading()));
      expect(cleanupUseCase.calls.single.rawTranscript, 'raw transcript');
      expect(
        container.read(mainRecordingControllerProvider),
        RecordingControllerState(
          recordingState: RecordingSaved(
            entryId: 42,
            detectedLanguage: 'fr-FR',
          ),
        ),
      );
      expect(preferencesRepository.hasEverRecorded, isTrue);
      expect(container.read(mainRecordingControllerProvider).isActive, isFalse);
    },
  );

  test('Uploading and Processing button taps are ignored', () async {
    final stopCompleter = Completer<TranscriptionResult>();
    transcriptionService.stopFutureFactory = () => stopCompleter.future;

    await container
        .read(mainRecordingControllerProvider.notifier)
        .onMainButtonTapped();
    monotonicClock.advance(const Duration(seconds: 6));

    final stopFuture = container
        .read(mainRecordingControllerProvider.notifier)
        .onMainButtonTapped();

    expect(
      container.read(mainRecordingControllerProvider).recordingState,
      const RecordingUploading(),
    );

    await container
        .read(mainRecordingControllerProvider.notifier)
        .onMainButtonTapped();
    expect(transcriptionService.startCallCount, 1);
    expect(transcriptionService.stopCallCount, 1);

    stopCompleter.complete(
      const TranscriptionFailure(reason: TranscriptionFailureReason.apiError),
    );
    await stopFuture;
  });

  test('Saved tap starts a new independent recording attempt', () async {
    await driveSuccessfulSave(entryId: 10);

    await container
        .read(mainRecordingControllerProvider.notifier)
        .onMainButtonTapped();

    expect(transcriptionService.startCallCount, 2);
    expect(
      container.read(mainRecordingControllerProvider).recordingState,
      RecordingListening(hardCapDeadlineElapsedRealtime: 120000),
    );
  });

  test('Deleted tap starts a new independent recording attempt', () async {
    container
        .read(mainRecordingControllerProvider.notifier)
        .onEntriesDeleted(2);

    await container
        .read(mainRecordingControllerProvider.notifier)
        .onMainButtonTapped();

    expect(transcriptionService.startCallCount, 1);
    expect(
      container.read(mainRecordingControllerProvider).recordingState,
      RecordingListening(hardCapDeadlineElapsedRealtime: 120000),
    );
  });

  test(
    'retryable Error tap starts a new independent recording attempt',
    () async {
      await container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();
      monotonicClock.advance(const Duration(seconds: 6));
      transcriptionService.nextStopResult = const TranscriptionFailure(
        reason: TranscriptionFailureReason.apiError,
      );
      await container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();

      await container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();

      expect(transcriptionService.startCallCount, 2);
      expect(
        container.read(mainRecordingControllerProvider).recordingState,
        RecordingListening(hardCapDeadlineElapsedRealtime: 120000),
      );
    },
  );

  test('insufficient-permissions Error tap resets to Idle', () async {
    await container
        .read(mainRecordingControllerProvider.notifier)
        .onMainButtonTapped();
    monotonicClock.advance(const Duration(seconds: 6));
    transcriptionService.nextStopResult = const TranscriptionFailure(
      reason: TranscriptionFailureReason.micBlocked,
    );

    await container
        .read(mainRecordingControllerProvider.notifier)
        .onMainButtonTapped();

    expect(
      container.read(mainRecordingControllerProvider).recordingState,
      const RecordingErrorState(RecordingError.insufficientPermissions),
    );

    await container
        .read(mainRecordingControllerProvider.notifier)
        .onMainButtonTapped();

    expect(
      container.read(mainRecordingControllerProvider).recordingState,
      const RecordingIdle(),
    );
  });

  test('transcription failure mapping covers all supported outcomes', () async {
    final cases = <TranscriptionFailureReason, RecordingError>{
      TranscriptionFailureReason.tooShort: RecordingError.tooShort,
      TranscriptionFailureReason.nothingCaught: RecordingError.noMatch,
      TranscriptionFailureReason.network: RecordingError.noInternet,
      TranscriptionFailureReason.backendUnavailable:
          RecordingError.backendUnavailable,
      TranscriptionFailureReason.proxyAuthFailed:
          RecordingError.proxyAuthFailed,
      TranscriptionFailureReason.apiError: RecordingError.apiFailed,
    };

    for (final entry in cases.entries) {
      await container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();
      monotonicClock.advance(const Duration(seconds: 6));
      transcriptionService.nextStopResult = TranscriptionFailure(
        reason: entry.key,
      );

      await container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();

      expect(
        container.read(mainRecordingControllerProvider).recordingState,
        RecordingErrorState(entry.value),
      );

      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  });

  test(
    'transcription failure with audioDraftPath persists an audio draft using the fallback language',
    () async {
      final audioDraftFile = File('${tempDirectory.path}/retry-audio.m4a');
      await audioDraftFile.writeAsString('audio');

      await container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();
      monotonicClock.advance(const Duration(seconds: 6));
      transcriptionService.nextStopResult = TranscriptionFailure(
        reason: TranscriptionFailureReason.network,
        audioDraftPath: audioDraftFile.path,
      );

      await container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();

      expect(entryRepository.savedAudioDrafts, [
        (audioDraftFile.path, cleanupTranscriptFallbackLanguage),
      ]);
      expect(
        container.read(mainRecordingControllerProvider).recordingState,
        const RecordingErrorState(
          RecordingError.noInternet,
          preservedDraft: true,
        ),
      );
    },
  );

  test(
    'transcription failure with missing audioDraftPath keeps the original error and skips draft persistence',
    () async {
      final missingAudioPath = '${tempDirectory.path}/missing-audio.m4a';

      await container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();
      monotonicClock.advance(const Duration(seconds: 6));
      transcriptionService.nextStopResult = TranscriptionFailure(
        reason: TranscriptionFailureReason.network,
        audioDraftPath: '  $missingAudioPath  ',
      );

      await container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();

      expect(entryRepository.savedAudioDrafts, isEmpty);
      expect(
        container.read(mainRecordingControllerProvider).recordingState,
        const RecordingErrorState(RecordingError.noInternet),
      );
      expect(
        logMessages,
        contains(
          'Ignoring retryable audio draft path because it is not a readable file.',
        ),
      );
    },
  );

  test(
    'cleanup failure preserves the draft, publishes mapped Error, and does not set hasEverRecorded',
    () async {
      await container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();
      monotonicClock.advance(const Duration(seconds: 6));
      cleanupUseCase.nextResult = const CleanupTranscriptFailure(
        entryId: 41,
        reason: backend.BackendFailureReason.backendUnavailable,
      );
      transcriptionService.nextStopResult = const TranscriptionSuccess(
        transcript: 'raw transcript',
        detectedLanguage: 'en-US',
      );

      await container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();

      expect(cleanupUseCase.calls.single.rawTranscript, 'raw transcript');
      expect(preferencesRepository.hasEverRecorded, isFalse);
      expect(
        container.read(mainRecordingControllerProvider).recordingState,
        const RecordingErrorState(
          RecordingError.backendUnavailable,
          preservedDraft: true,
        ),
      );
    },
  );

  test(
    'cleanup success still publishes Saved when preference persistence logs a warning',
    () async {
      preferencesRepository.failSetHasEverRecorded = true;
      await container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();
      monotonicClock.advance(const Duration(seconds: 6));
      cleanupUseCase.nextResult = const CleanupTranscriptSuccess(
        entryId: 50,
        cleanedText: 'cleaned',
      );
      transcriptionService.nextStopResult = const TranscriptionSuccess(
        transcript: 'raw transcript',
        detectedLanguage: 'nl-NL',
      );

      await container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();

      expect(
        container.read(mainRecordingControllerProvider).recordingState,
        RecordingSaved(entryId: 50, detectedLanguage: 'nl-NL'),
      );
      expect(logMessages.single, contains('hasEverRecorded'));
      expect(logErrors.single, isA<StateError>());
    },
  );

  test(
    'cleanup success with a non-positive entry id publishes ApiFailed and does not set hasEverRecorded',
    () async {
      await container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();
      monotonicClock.advance(const Duration(seconds: 6));
      cleanupUseCase.nextResult = const CleanupTranscriptSuccess(
        entryId: 0,
        cleanedText: 'cleaned',
      );
      transcriptionService.nextStopResult = const TranscriptionSuccess(
        transcript: 'raw transcript',
        detectedLanguage: 'en-US',
      );

      await container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();

      expect(preferencesRepository.hasEverRecorded, isFalse);
      expect(
        container.read(mainRecordingControllerProvider).recordingState,
        const RecordingErrorState(RecordingError.apiFailed),
      );
      expect(
        logMessages,
        contains(
          'Cleanup succeeded without a valid entry id; Saved state was not published.',
        ),
      );
      expect(logErrors.last, isA<ArgumentError>());
    },
  );

  test(
    'Deleted feedback ignores non-positive counts, publishes positive counts, and auto-clears',
    () async {
      container
          .read(mainRecordingControllerProvider.notifier)
          .onEntriesDeleted(0);
      expect(
        container.read(mainRecordingControllerProvider).recordingState,
        const RecordingIdle(),
      );

      container
          .read(mainRecordingControllerProvider.notifier)
          .onEntriesDeleted(3);
      expect(
        container.read(mainRecordingControllerProvider).recordingState,
        const RecordingDeleted(3),
      );

      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(
        container.read(mainRecordingControllerProvider).recordingState,
        const RecordingIdle(),
      );
    },
  );

  test(
    'Saved feedback does not auto-clear and clears through clearSaved',
    () async {
      await driveSuccessfulSave(entryId: 70);

      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(
        container.read(mainRecordingControllerProvider).recordingState,
        RecordingSaved(entryId: 70, detectedLanguage: 'en-US'),
      );

      container.read(mainRecordingControllerProvider.notifier).clearSaved();

      expect(
        container.read(mainRecordingControllerProvider).recordingState,
        const RecordingIdle(),
      );
    },
  );

  test(
    'rapid repeated taps while start is in flight trigger only one start attempt',
    () async {
      final startCompleter = Completer<void>();
      transcriptionService.startFutureFactory = (onStatus) async {
        await startCompleter.future;
        final status = RecordingStarted(120000);
        transcriptionService.statusHistory.add(status);
        onStatus(status);
      };

      final firstTap = container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();
      final secondTap = container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();

      expect(transcriptionService.startCallCount, 1);
      expect(
        container.read(mainRecordingControllerProvider).recordingState,
        const RecordingIdle(),
      );

      startCompleter.complete();
      await Future.wait([firstTap, secondTap]);

      expect(transcriptionService.startCallCount, 1);
      expect(
        container.read(mainRecordingControllerProvider).recordingState,
        RecordingListening(hardCapDeadlineElapsedRealtime: 120000),
      );
    },
  );

  test(
    'starting a new recording cancels a stale Error auto-clear timer',
    () async {
      container.dispose();
      container = buildContainer(
        feedbackDelays: const RecordingFeedbackDelays(
          errorAndDeletedAutoClear: Duration(milliseconds: 20),
        ),
      );

      await container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();
      transcriptionService.nextStopResult = const TranscriptionFailure(
        reason: TranscriptionFailureReason.tooShort,
      );
      await container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();

      expect(
        container.read(mainRecordingControllerProvider).recordingState,
        const RecordingErrorState(RecordingError.tooShort),
      );

      await container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();
      expect(
        container.read(mainRecordingControllerProvider).recordingState,
        RecordingListening(hardCapDeadlineElapsedRealtime: 120000),
      );

      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(
        container.read(mainRecordingControllerProvider).recordingState,
        RecordingListening(hardCapDeadlineElapsedRealtime: 120000),
      );
    },
  );

  test(
    'starting a new recording cancels a stale Deleted auto-clear timer',
    () async {
      container.dispose();
      container = buildContainer(
        feedbackDelays: const RecordingFeedbackDelays(
          errorAndDeletedAutoClear: Duration(milliseconds: 20),
        ),
      );

      container
          .read(mainRecordingControllerProvider.notifier)
          .onEntriesDeleted(2);
      expect(
        container.read(mainRecordingControllerProvider).recordingState,
        const RecordingDeleted(2),
      );

      await container
          .read(mainRecordingControllerProvider.notifier)
          .onMainButtonTapped();
      expect(
        container.read(mainRecordingControllerProvider).recordingState,
        RecordingListening(hardCapDeadlineElapsedRealtime: 120000),
      );

      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(
        container.read(mainRecordingControllerProvider).recordingState,
        RecordingListening(hardCapDeadlineElapsedRealtime: 120000),
      );
    },
  );
}

class _CleanupCall {
  const _CleanupCall({
    required this.rawTranscript,
    required this.language,
    required this.entryId,
  });

  final String rawTranscript;
  final String? language;
  final int? entryId;
}

class _FakeTranscriptionService implements TranscriptionService {
  int startCallCount = 0;
  int stopCallCount = 0;
  Object? startError;
  TranscriptionResult nextStopResult = const TranscriptionFailure(
    reason: TranscriptionFailureReason.apiError,
  );
  final List<TranscriptionStatus> statusHistory = <TranscriptionStatus>[];
  Future<void> Function(TranscriptionStatusCallback onStatus)?
  startFutureFactory;
  Future<TranscriptionResult> Function()? stopFutureFactory;
  bool _isRecording = false;
  bool _isTranscribing = false;
  int? _hardCapDeadlineElapsedRealtime;

  @override
  int? get hardCapDeadlineElapsedRealtime => _hardCapDeadlineElapsedRealtime;

  @override
  bool get isRecording => _isRecording;

  @override
  bool get isTranscribing => _isTranscribing;

  @override
  Future<void> startLiveTranscription({
    required TranscriptionStatusCallback onStatus,
  }) async {
    startCallCount += 1;
    if (startError case final error?) {
      startError = null;
      throw error;
    }
    _isRecording = true;
    _hardCapDeadlineElapsedRealtime = 120000;
    final pendingStart = startFutureFactory?.call(onStatus);
    if (pendingStart != null) {
      await pendingStart;
      return;
    }
    final status = RecordingStarted(_hardCapDeadlineElapsedRealtime!);
    statusHistory.add(status);
    onStatus(status);
  }

  @override
  Future<TranscriptionResult> stopLiveTranscription({
    required TranscriptionStatusCallback onStatus,
  }) async {
    stopCallCount += 1;
    _isRecording = false;
    final pendingResult = stopFutureFactory?.call();
    final immediateResult = pendingResult == null ? nextStopResult : null;

    if (immediateResult case TranscriptionFailure(
      reason: final reason,
    ) when reason == TranscriptionFailureReason.tooShort) {
      return immediateResult;
    }

    _isTranscribing = true;
    const status = Uploading();
    statusHistory.add(status);
    onStatus(status);
    final result = pendingResult != null
        ? await pendingResult
        : immediateResult!;
    _isTranscribing = false;
    return result;
  }

  @override
  Future<TranscriptionResult> transcribeAudioDraft(String audioPath) async {
    return nextStopResult;
  }
}

class _FakeCleanupTranscriptUseCase extends CleanupTranscriptUseCase {
  _FakeCleanupTranscriptUseCase()
    : super(
        cleanupTranscript: ({required transcript, required language}) async =>
            const backend.CleanupFailure(
              reason: backend.BackendFailureReason.apiError,
            ),
        entryRepository: _FakeEntryRepository(),
        setRecordQuota: (_) {},
        logWarning: (_, {error, stackTrace}) {},
      );

  CleanupTranscriptResult nextResult = const CleanupTranscriptFailure(
    entryId: 1,
    reason: backend.BackendFailureReason.apiError,
  );
  final List<_CleanupCall> calls = <_CleanupCall>[];

  @override
  Future<CleanupTranscriptResult> call({
    required String rawTranscript,
    String? language,
    int? entryId,
  }) async {
    calls.add(
      _CleanupCall(
        rawTranscript: rawTranscript,
        language: language,
        entryId: entryId,
      ),
    );
    return nextResult;
  }
}

class _FakeEntryRepository implements EntryRepository {
  final List<(String, String)> savedAudioDrafts = <(String, String)>[];

  @override
  Future<void> deleteEntry(int id) async {}

  @override
  Future<void> deleteStaleDrafts({int daysOld = 7}) async {}

  @override
  Future<void> finalizeDraftWithCleanedText(
    int id,
    String rawTranscript,
    String cleanedText,
    int wordCount,
  ) async {}

  @override
  Future<Entry?> getEntryById(int id) async => null;

  @override
  Future<List<Entry>> getPendingDrafts() async => const <Entry>[];

  @override
  Future<int> saveAudioDraft(String audioPath, String language) async {
    savedAudioDrafts.add((audioPath, language));
    return 1;
  }

  @override
  Future<int> saveDraft(String transcript, String language) async => 1;

  @override
  Future<int> saveEntry(String transcript, String language) async => 1;

  @override
  Future<void> updateDraftTranscript(
    int id,
    String rawTranscript,
    int wordCount,
  ) async {}

  @override
  Future<void> updateDraftTranscriptAndLanguage(
    int id,
    String rawTranscript,
    int wordCount,
    String language,
  ) async {}

  @override
  Future<void> updateEntryLanguage(int id, String language) async {}

  @override
  Future<void> updateWithCleanedText(
    int id,
    String cleanedText,
    int wordCount,
  ) async {}

  @override
  Stream<List<Entry>> watchAllEntries() => const Stream<List<Entry>>.empty();

  @override
  Stream<Entry?> watchEntryById(int id) => const Stream<Entry?>.empty();
}

class _FakePreferencesRepository implements PreferencesRepository {
  bool hasEverRecorded = false;
  bool failSetHasEverRecorded = false;

  @override
  Future<String> getDeviceId() async => 'device-id';

  @override
  Future<bool> getHasEverRecorded() async => hasEverRecorded;

  @override
  Future<void> setHasEverRecorded(bool value) async {
    if (failSetHasEverRecorded) {
      throw StateError('Failed to persist hasEverRecorded');
    }
    hasEverRecorded = value;
  }
}
