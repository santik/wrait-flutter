import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wrait/data/api/backend_results.dart' as backend;
import 'package:wrait/data/api/backend_providers.dart';
import 'package:wrait/data/api/record_quota_state.dart';
import 'package:wrait/data/audio/audio_recording_providers.dart';
import 'package:wrait/data/audio/audio_recording_service.dart';
import 'package:wrait/data/transcription/transcription_providers.dart';
import 'package:wrait/data/transcription/transcription_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'provider graph supports the live success flow with status ordering, language normalization, and quota updates',
    (tester) async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'wrait-cloud-transcription-int-success',
      );
      addTearDown(() async {
        if (await tempDirectory.exists()) {
          await tempDirectory.delete(recursive: true);
        }
      });

      final audioService = _FakeAudioRecordingService();
      final container = ProviderContainer(
        overrides: [
          audioRecordingServiceProvider.overrideWithValue(audioService),
          liveRecordingPathFactoryProvider.overrideWithValue(
            () async => '${tempDirectory.path}/live-success.m4a',
          ),
          transcribeAudioCallbackProvider.overrideWithValue((audioFile) async {
            expect(audioFile.path, '${tempDirectory.path}/live-success.m4a');
            return backend.TranscriptionSuccess(
              transcript: 'raw transcript',
              detectedLanguage: 'EN_us',
              quota: RecordQuotaState(
                limit: 5,
                count: 2,
                remaining: 3,
                resetAt: DateTime.utc(2026, 6, 12),
              ),
            );
          }),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(transcriptionServiceProvider);
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
              'en-US',
            )
            .having((value) => value.quota?.remaining, 'quotaRemaining', 3),
      );
      expect(container.read(sessionRecordQuotaStateProvider)?.remaining, 3);
      expect(
        await File('${tempDirectory.path}/live-success.m4a').exists(),
        isFalse,
      );
    },
  );

  testWidgets(
    'unsupported backend language still succeeds with no detected language',
    (tester) async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'wrait-cloud-transcription-int-invalid-language',
      );
      addTearDown(() async {
        if (await tempDirectory.exists()) {
          await tempDirectory.delete(recursive: true);
        }
      });

      final container = ProviderContainer(
        overrides: [
          audioRecordingServiceProvider.overrideWithValue(
            _FakeAudioRecordingService(),
          ),
          liveRecordingPathFactoryProvider.overrideWithValue(
            () async => '${tempDirectory.path}/live-invalid-language.m4a',
          ),
          transcribeAudioCallbackProvider.overrideWithValue(
            (_) async => const backend.TranscriptionSuccess(
              transcript: 'raw transcript',
              detectedLanguage: 'zz-ZZ',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(transcriptionServiceProvider);
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
    },
  );

  testWidgets(
    'live failure preserves audio path and surfaces network failures',
    (tester) async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'wrait-cloud-transcription-int-live-failure',
      );
      addTearDown(() async {
        if (await tempDirectory.exists()) {
          await tempDirectory.delete(recursive: true);
        }
      });

      final livePath = '${tempDirectory.path}/live-failure.m4a';
      final container = ProviderContainer(
        overrides: [
          audioRecordingServiceProvider.overrideWithValue(
            _FakeAudioRecordingService(),
          ),
          liveRecordingPathFactoryProvider.overrideWithValue(
            () async => livePath,
          ),
          transcribeAudioCallbackProvider.overrideWithValue(
            (_) async => const backend.TranscriptionFailure(
              reason: backend.BackendFailureReason.noInternet,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(transcriptionServiceProvider);
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
            .having(
              (value) => value.audioDraftPath,
              'audioDraftPath',
              livePath,
            ),
      );
      expect(await File(livePath).exists(), isTrue);
    },
  );

  testWidgets(
    'draft transcription keeps caller-owned audio and surfaces quota-bearing failures',
    (tester) async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'wrait-cloud-transcription-int-draft',
      );
      addTearDown(() async {
        if (await tempDirectory.exists()) {
          await tempDirectory.delete(recursive: true);
        }
      });

      final draftPath = '${tempDirectory.path}/draft.m4a';
      await File(draftPath).writeAsBytes(const <int>[1, 2, 3]);
      final quota = RecordQuotaState(
        limit: 5,
        count: 5,
        remaining: 0,
        resetAt: DateTime.utc(2026, 6, 12),
      );
      final container = ProviderContainer(
        overrides: [
          audioRecordingServiceProvider.overrideWithValue(
            _FakeAudioRecordingService(),
          ),
          transcribeAudioCallbackProvider.overrideWithValue(
            (_) async => backend.TranscriptionFailure(
              reason: backend.BackendFailureReason.quotaExceeded,
              quota: quota,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(transcriptionServiceProvider);
      final result = await service.transcribeAudioDraft(draftPath);

      expect(
        result,
        isA<TranscriptionFailure>()
            .having(
              (value) => value.reason,
              'reason',
              TranscriptionFailureReason.apiError,
            )
            .having((value) => value.quota?.remaining, 'quotaRemaining', 0),
      );
      expect(await File(draftPath).exists(), isTrue);
      expect(container.read(sessionRecordQuotaStateProvider)?.remaining, 0);
    },
  );

  testWidgets('provider graph rejects concurrent transcription requests', (
    tester,
  ) async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'wrait-cloud-transcription-int-concurrent',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final firstDraftPath = '${tempDirectory.path}/draft-1.m4a';
    final secondDraftPath = '${tempDirectory.path}/draft-2.m4a';
    await File(firstDraftPath).writeAsBytes(const <int>[1, 2, 3]);
    await File(secondDraftPath).writeAsBytes(const <int>[4, 5, 6]);
    final startedCompleter = Completer<void>();
    final resultCompleter = Completer<backend.TranscriptionResult>();
    final container = ProviderContainer(
      overrides: [
        audioRecordingServiceProvider.overrideWithValue(
          _FakeAudioRecordingService(),
        ),
        transcribeAudioCallbackProvider.overrideWithValue((_) {
          if (!startedCompleter.isCompleted) {
            startedCompleter.complete();
          }
          return resultCompleter.future;
        }),
      ],
    );
    addTearDown(container.dispose);

    final service = container.read(transcriptionServiceProvider);
    final firstCall = service.transcribeAudioDraft(firstDraftPath);
    await startedCompleter.future;

    await expectLater(
      service.transcribeAudioDraft(secondDraftPath),
      throwsA(isA<TranscriptionAlreadyInProgressFailure>()),
    );

    resultCompleter.complete(
      const backend.TranscriptionSuccess(
        transcript: 'done',
        detectedLanguage: 'en-US',
      ),
    );
    await expectLater(firstCall, completion(isA<TranscriptionSuccess>()));
  });
}

class _FakeAudioRecordingService implements AudioRecordingService {
  static const int fakeRecordingDeadlineElapsedRealtime = 123456;

  @override
  bool isRecording = false;

  @override
  int? hardCapDeadlineElapsedRealtime;

  String? _currentPath;

  @override
  Future<void> startRecording(String outputPath) async {
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

    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(const <int>[7, 8, 9]);
    _currentPath = null;
    isRecording = false;
    hardCapDeadlineElapsedRealtime = null;
    return path;
  }
}
