import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wrait/data/api/backend_results.dart' as backend;
import 'package:wrait/data/api/record_quota_state.dart';
import 'package:wrait/data/audio/microphone_permission_service.dart';
import 'package:wrait/data/audio/audio_recording_service.dart';
import 'package:wrait/data/transcription/cloud_transcription_service.dart';
import 'package:wrait/data/transcription/transcription_service.dart';

void main() {
  late Directory tempDirectory;
  late _FakeAudioRecordingService audioRecordingService;
  late RecordQuotaState? currentQuota;
  late List<String> logMessages;
  late List<Object?> logErrors;
  late String livePath;
  late CloudTranscriptionService service;
  late Future<backend.TranscriptionResult> Function(File audioFile) transcribe;
  late int transcribeCallCount;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'wrait-cloud-transcription-test',
    );
    audioRecordingService = _FakeAudioRecordingService();
    currentQuota = null;
    logMessages = <String>[];
    logErrors = <Object?>[];
    livePath = '${tempDirectory.path}/live.m4a';
    transcribeCallCount = 0;
    transcribe = (_) async => const backend.TranscriptionSuccess(
      transcript: 'raw transcript',
      detectedLanguage: 'en-US',
    );
    service = CloudTranscriptionService(
      audioRecordingService: audioRecordingService,
      transcribeAudio: (audioFile) {
        transcribeCallCount += 1;
        return transcribe(audioFile);
      },
      createLiveRecordingPath: () async => livePath,
      setSessionQuota: (quota) => currentQuota = quota,
      logWarning: (message, {error, stackTrace}) {
        logMessages.add(message);
        logErrors.add(error);
      },
    );
  });

  tearDown(() async {
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('start emits RecordingStarted with the recording deadline', () async {
    final statuses = <TranscriptionStatus>[];

    await service.startLiveTranscription(onStatus: statuses.add);

    expect(service.isRecording, isTrue);
    expect(statuses, hasLength(1));
    expect(
      statuses.single,
      isA<RecordingStarted>().having(
        (value) => value.hardCapDeadlineElapsedRealtime,
        'hardCapDeadlineElapsedRealtime',
        120000,
      ),
    );
    expect(audioRecordingService.startedPaths.single, livePath);
  });

  test('denied microphone access surfaces a typed start failure', () async {
    audioRecordingService.startFailure = const RecordingPermissionDeniedFailure(
      MicrophoneAccessState.denied,
    );

    await expectLater(
      service.startLiveTranscription(onStatus: (_) {}),
      throwsA(isA<MicBlockedTranscriptionServiceFailure>()),
    );

    expect(service.isRecording, isFalse);
    expect(service.isTranscribing, isFalse);
  });

  test(
    'successful live transcription uploads and deletes the temp file',
    () async {
      final quota = RecordQuotaState(
        limit: 5,
        count: 2,
        remaining: 3,
        resetAt: DateTime.utc(2026, 6, 12),
      );
      transcribe = (audioFile) async {
        expect(audioFile.path, livePath);
        return backend.TranscriptionSuccess(
          transcript: 'raw transcript',
          detectedLanguage: 'FR_fr',
          quota: quota,
        );
      };

      final statuses = <TranscriptionStatus>[];
      await service.startLiveTranscription(onStatus: statuses.add);
      final result = await service.stopLiveTranscription(
        onStatus: statuses.add,
      );

      expect(statuses, [isA<RecordingStarted>(), isA<Uploading>()]);
      expect(
        result,
        isA<TranscriptionSuccess>()
            .having((value) => value.transcript, 'transcript', 'raw transcript')
            .having(
              (value) => value.detectedLanguage,
              'detectedLanguage',
              'fr-FR',
            )
            .having((value) => value.quota?.remaining, 'quotaRemaining', 3),
      );
      expect(currentQuota?.remaining, 3);
      expect(await File(livePath).exists(), isFalse);
      expect(service.isRecording, isFalse);
      expect(service.isTranscribing, isFalse);
    },
  );

  test(
    'live transcription succeeds without detected language when unsupported',
    () async {
      final invalidLanguages = <String>[
        'zz-ZZ',
        ' zh-Hans-CN ',
        'en-001',
        '   ',
      ];

      for (final invalidLanguage in invalidLanguages) {
        transcribe = (_) async => backend.TranscriptionSuccess(
          transcript: 'raw transcript',
          detectedLanguage: invalidLanguage,
        );

        await service.startLiveTranscription(onStatus: (_) {});
        final result = await service.stopLiveTranscription(onStatus: (_) {});

        expect(
          result,
          isA<TranscriptionSuccess>().having(
            (value) => value.detectedLanguage,
            'detectedLanguage',
            isNull,
          ),
        );
        expect(await File(livePath).exists(), isFalse);
      }
    },
  );

  test('stop throws when no live transcription is active', () async {
    await expectLater(
      service.stopLiveTranscription(onStatus: (_) {}),
      throwsA(isA<NoActiveLiveTranscriptionFailure>()),
    );
  });

  test(
    'failed live transcription preserves the audio path for retry',
    () async {
      final quota = RecordQuotaState(
        limit: 5,
        count: 5,
        remaining: 0,
        resetAt: DateTime.utc(2026, 6, 12),
      );
      transcribe = (_) async => backend.TranscriptionFailure(
        reason: backend.BackendFailureReason.noInternet,
        quota: quota,
      );

      await service.startLiveTranscription(onStatus: (_) {});
      final result = await service.stopLiveTranscription(onStatus: (_) {});

      expect(
        result,
        isA<TranscriptionFailure>()
            .having(
              (value) => value.reason,
              'reason',
              TranscriptionFailureReason.network,
            )
            .having((value) => value.audioDraftPath, 'audioDraftPath', livePath)
            .having((value) => value.quota?.remaining, 'quotaRemaining', 0),
      );
      expect(currentQuota?.remaining, 0);
      expect(await File(livePath).exists(), isTrue);
      expect(logMessages.single, contains('noInternet'));
    },
  );

  test(
    'draft transcription leaves caller-owned audio untouched on success',
    () async {
      final draftPath = '${tempDirectory.path}/draft.m4a';
      await File(draftPath).writeAsBytes(const <int>[1, 2, 3]);

      transcribe = (audioFile) async {
        expect(audioFile.path, draftPath);
        return const backend.TranscriptionSuccess(
          transcript: 'draft transcript',
          detectedLanguage: 'en-US',
        );
      };

      final result = await service.transcribeAudioDraft(draftPath);

      expect(
        result,
        isA<TranscriptionSuccess>().having(
          (value) => value.detectedLanguage,
          'detectedLanguage',
          'en-US',
        ),
      );
      expect(await File(draftPath).exists(), isTrue);
    },
  );

  test(
    'unexpected upload exceptions return apiError and preserve live audio',
    () async {
      transcribe = (_) async => throw StateError('boom');

      await service.startLiveTranscription(onStatus: (_) {});
      final result = await service.stopLiveTranscription(onStatus: (_) {});

      expect(
        result,
        isA<TranscriptionFailure>()
            .having(
              (value) => value.reason,
              'reason',
              TranscriptionFailureReason.apiError,
            )
            .having(
              (value) => value.audioDraftPath,
              'audioDraftPath',
              livePath,
            ),
      );
      expect(await File(livePath).exists(), isTrue);
      expect(logErrors.single, isA<StateError>());
    },
  );

  test(
    'too-short live stop returns a typed failure without uploading',
    () async {
      await service.startLiveTranscription(onStatus: (_) {});
      audioRecordingService.stopFailure = const RecordingTooShortFailure();

      final result = await service.stopLiveTranscription(onStatus: (_) {});

      expect(
        result,
        isA<TranscriptionFailure>().having(
          (value) => value.reason,
          'reason',
          TranscriptionFailureReason.tooShort,
        ),
      );
      expect(transcribeCallCount, 0);
      expect(service.isRecording, isFalse);
      expect(service.isTranscribing, isFalse);
    },
  );

  test(
    'blank live transcript success becomes nothingCaught and keeps retryable audio',
    () async {
      transcribe = (_) async => const backend.TranscriptionSuccess(
        transcript: '   ',
        detectedLanguage: 'en-US',
      );

      await service.startLiveTranscription(onStatus: (_) {});
      final result = await service.stopLiveTranscription(onStatus: (_) {});

      expect(
        result,
        isA<TranscriptionFailure>()
            .having(
              (value) => value.reason,
              'reason',
              TranscriptionFailureReason.nothingCaught,
            )
            .having(
              (value) => value.audioDraftPath,
              'audioDraftPath',
              livePath,
            ),
      );
      expect(await File(livePath).exists(), isTrue);
    },
  );

  test('rejects new work while another transcription is in progress', () async {
    final startedCompleter = Completer<void>();
    final resultCompleter = Completer<backend.TranscriptionResult>();
    final draftPath = '${tempDirectory.path}/draft.m4a';
    final secondDraftPath = '${tempDirectory.path}/draft-2.m4a';
    await File(draftPath).writeAsBytes(const <int>[1, 2, 3]);
    await File(secondDraftPath).writeAsBytes(const <int>[4, 5, 6]);
    transcribe = (_) {
      if (!startedCompleter.isCompleted) {
        startedCompleter.complete();
      }
      return resultCompleter.future;
    };

    final firstCall = service.transcribeAudioDraft(draftPath);
    await startedCompleter.future;

    await expectLater(
      service.transcribeAudioDraft(secondDraftPath),
      throwsA(isA<TranscriptionAlreadyInProgressFailure>()),
    );

    resultCompleter.complete(
      const backend.TranscriptionSuccess(
        transcript: 'finished',
        detectedLanguage: 'en-US',
      ),
    );
    await expectLater(firstCall, completion(isA<TranscriptionSuccess>()));
  });

  test(
    'rejects a second live start while the first live start is in progress',
    () async {
      final livePathCompleter = Completer<String>();
      service = CloudTranscriptionService(
        audioRecordingService: audioRecordingService,
        transcribeAudio: (audioFile) {
          transcribeCallCount += 1;
          return transcribe(audioFile);
        },
        createLiveRecordingPath: () => livePathCompleter.future,
        setSessionQuota: (quota) => currentQuota = quota,
        logWarning: (message, {error, stackTrace}) {
          logMessages.add(message);
          logErrors.add(error);
        },
      );

      final firstStart = service.startLiveTranscription(onStatus: (_) {});
      await Future<void>.delayed(Duration.zero);

      await expectLater(
        service.startLiveTranscription(onStatus: (_) {}),
        throwsA(isA<TranscriptionAlreadyInProgressFailure>()),
      );

      livePathCompleter.complete(livePath);
      await firstStart;
      expect(service.isRecording, isTrue);
    },
  );

  test(
    'draft transcription fails fast for a blank path without uploading',
    () async {
      final result = await service.transcribeAudioDraft('   ');

      expect(
        result,
        isA<TranscriptionFailure>().having(
          (value) => value.reason,
          'reason',
          TranscriptionFailureReason.apiError,
        ),
      );
      expect(transcribeCallCount, 0);
      expect(logMessages.single, contains('audio path was blank'));
    },
  );

  test(
    'draft transcription fails fast for a missing file without uploading',
    () async {
      final result = await service.transcribeAudioDraft(
        '${tempDirectory.path}/missing.m4a',
      );

      expect(
        result,
        isA<TranscriptionFailure>().having(
          (value) => value.reason,
          'reason',
          TranscriptionFailureReason.apiError,
        ),
      );
      expect(transcribeCallCount, 0);
      expect(logMessages.single, contains('audio file was missing'));
    },
  );

  test(
    'draft transcription fails fast for an empty file without uploading',
    () async {
      final draftPath = '${tempDirectory.path}/empty.m4a';
      await File(draftPath).writeAsBytes(const <int>[]);

      final result = await service.transcribeAudioDraft(draftPath);

      expect(
        result,
        isA<TranscriptionFailure>().having(
          (value) => value.reason,
          'reason',
          TranscriptionFailureReason.apiError,
        ),
      );
      expect(transcribeCallCount, 0);
      expect(logMessages.single, contains('audio file was empty'));
    },
  );

  test(
    'blank transcript success payload becomes nothingCaught without updating quota',
    () async {
      final draftPath = '${tempDirectory.path}/draft.m4a';
      await File(draftPath).writeAsBytes(const <int>[1, 2, 3]);
      final quota = RecordQuotaState(
        limit: 5,
        count: 5,
        remaining: 0,
        resetAt: DateTime.utc(2026, 6, 12),
      );
      transcribe = (_) async => backend.TranscriptionSuccess(
        transcript: '   ',
        detectedLanguage: 'en-US',
        quota: quota,
      );

      final result = await service.transcribeAudioDraft(draftPath);

      expect(
        result,
        isA<TranscriptionFailure>()
            .having(
              (value) => value.reason,
              'reason',
              TranscriptionFailureReason.nothingCaught,
            )
            .having((value) => value.quota?.remaining, 'quotaRemaining', 0),
      );
      expect(currentQuota, isNull);
      expect(logMessages.single, contains('blank transcript'));
    },
  );

  test(
    'maps backend failure reasons into the narrowed service failure surface',
    () async {
      final cases = <backend.BackendFailureReason, TranscriptionFailureReason>{
        backend.BackendFailureReason.timeout:
            TranscriptionFailureReason.timeout,
        backend.BackendFailureReason.noInternet:
            TranscriptionFailureReason.network,
        backend.BackendFailureReason.backendUnavailable:
            TranscriptionFailureReason.backendUnavailable,
        backend.BackendFailureReason.proxyAuthFailed:
            TranscriptionFailureReason.proxyAuthFailed,
        backend.BackendFailureReason.requestTooLarge:
            TranscriptionFailureReason.apiError,
        backend.BackendFailureReason.quotaExceeded:
            TranscriptionFailureReason.apiError,
        backend.BackendFailureReason.apiError:
            TranscriptionFailureReason.apiError,
      };

      for (final entry in cases.entries) {
        final draftPath = '${tempDirectory.path}/${entry.key.name}.m4a';
        await File(draftPath).writeAsBytes(const <int>[7, 8, 9]);
        transcribe = (_) async =>
            backend.TranscriptionFailure(reason: entry.key);

        final result = await service.transcribeAudioDraft(draftPath);

        expect(
          result,
          isA<TranscriptionFailure>().having(
            (value) => value.reason,
            '${entry.key.name} -> ${entry.value.name}',
            entry.value,
          ),
        );
        expect(await File(draftPath).exists(), isTrue);
      }
    },
  );
}

class _FakeAudioRecordingService implements AudioRecordingService {
  static const int fakeRecordingDeadlineElapsedRealtime = 120000;

  @override
  bool isRecording = false;

  @override
  int? hardCapDeadlineElapsedRealtime;

  final List<String> startedPaths = <String>[];
  String? _currentPath;
  AudioRecordingFailure? startFailure;
  AudioRecordingFailure? stopFailure;

  @override
  Future<void> startRecording(String outputPath) async {
    if (startFailure case final failure?) {
      startFailure = null;
      throw failure;
    }
    startedPaths.add(outputPath);
    _currentPath = outputPath;
    isRecording = true;
    hardCapDeadlineElapsedRealtime = fakeRecordingDeadlineElapsedRealtime;
  }

  @override
  Future<String> stopRecording() async {
    final path = _currentPath;
    if (path == null) {
      throw const NoActiveRecordingFailure();
    }

    if (stopFailure case final failure?) {
      stopFailure = null;
      _currentPath = null;
      isRecording = false;
      hardCapDeadlineElapsedRealtime = null;
      throw failure;
    }

    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(const <int>[9, 9, 9]);
    _currentPath = null;
    isRecording = false;
    hardCapDeadlineElapsedRealtime = null;
    return path;
  }
}
