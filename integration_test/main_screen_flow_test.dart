import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wrait/app.dart';
import 'package:wrait/core/config/app_config.dart';
import 'package:wrait/core/router/app_router.dart';
import 'package:wrait/core/time/system_clock.dart';
import 'package:wrait/data/api/backend_providers.dart';
import 'package:wrait/data/api/backend_results.dart' as backend;
import 'package:wrait/data/api/record_quota_state.dart';
import 'package:wrait/data/audio/audio_recording_providers.dart';
import 'package:wrait/data/audio/microphone_permission_service.dart';
import 'package:wrait/data/entries/database_key_store.dart';
import 'package:wrait/data/entries/entry_providers.dart';
import 'package:wrait/data/entries/local_entry_database.dart';
import 'package:wrait/data/preferences/preferences_providers.dart';
import 'package:wrait/data/transcription/transcription_providers.dart';
import 'package:wrait/data/transcription/transcription_service.dart';
import 'package:wrait/presentation/main/main_recording_controller.dart';
import 'package:wrait/presentation/main/main_screen_test_keys.dart';

import '../test/test_doubles/fake_monotonic_clock.dart';
import '../test/test_doubles/fake_secure_storage.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets(
    'first-time status tap starts listening and successful save auto-clears',
    (tester) async {
      final harness = await _createHarness(
        feedbackDelays: const RecordingFeedbackDelays(
          savedDisplayWindow: Duration(milliseconds: 50),
        ),
      );
      addTearDown(harness.dispose);

      harness.transcriptionService.nextStopResult = const TranscriptionSuccess(
        transcript: 'raw transcript',
        detectedLanguage: 'fr-FR',
      );
      harness.cleanupCallbackHolder.callback =
          ({required transcript, required language}) async =>
              const backend.CleanupSuccess(cleanedText: 'Cleaned transcript.');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: harness.container,
          child: const WraitApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('tap button to write'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('statusLineButton')));
      await tester.pump();
      expect(find.text('listening...'), findsOneWidget);

      harness.monotonicClock.advance(const Duration(seconds: 6));
      await tester.tap(find.byKey(mainActionButtonKey));
      await _pumpUntilFound(
        tester,
        find.text('saved, tap to read'),
        timeout: const Duration(milliseconds: 40),
      );

      expect(find.text('saved, tap to read'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump();
      expect(find.text('wrait'), findsWidgets);
    },
  );

  testWidgets('saved status tap navigates to the saved detail route', (
    tester,
  ) async {
    final harness = await _createHarness();
    addTearDown(harness.dispose);

    harness.transcriptionService.nextStopResult = const TranscriptionSuccess(
      transcript: 'raw transcript',
      detectedLanguage: 'en-US',
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const WraitApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('statusLineButton')));
    await tester.pump();
    harness.monotonicClock.advance(const Duration(seconds: 6));
    await tester.tap(find.byKey(mainActionButtonKey));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('statusLineButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('entryDetailReadText')), findsOneWidget);
    expect(find.text('Cleaned transcript.'), findsOneWidget);
  });

  testWidgets(
    'stats show drafts and finalized entries and navigate to entries',
    (tester) async {
      final harness = await _createHarness();
      addTearDown(harness.dispose);

      final repository = harness.container.read(entryRepositoryProvider);
      await repository.saveEntry('final entry', 'en-US');
      harness.entryClock.advance(const Duration(days: 1));
      await repository.saveDraft('draft entry', 'en-US');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: harness.container,
          child: const WraitApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2 entries - 2 days'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const ValueKey('statsLineButton')));
      await tester.tap(find.byKey(const ValueKey('statsLineButton')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('entryListView')), findsOneWidget);
    },
  );

  testWidgets('quota stays visible while idle and listening', (tester) async {
    final harness = await _createHarness();
    addTearDown(harness.dispose);

    harness.container
        .read(sessionRecordQuotaStateProvider.notifier)
        .setQuota(
          RecordQuotaState(
            limit: 9,
            count: 3,
            remaining: 6,
            resetAt: DateTime.utc(2026, 6, 13),
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const WraitApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('9 total / 6 left'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('statusLineButton')));
    await tester.pump();
    expect(find.text('listening...'), findsOneWidget);
    expect(find.text('9 total / 6 left'), findsOneWidget);
  });

  testWidgets('microphone-blocked start failure shows mic blocked status', (
    tester,
  ) async {
    final harness = await _createHarness();
    addTearDown(harness.dispose);
    harness.transcriptionService.startFailure =
        const MicBlockedTranscriptionServiceFailure(
          MicrophoneAccessState.permanentlyDenied,
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const WraitApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('statusLineButton')));
    await tester.pumpAndSettle();

    expect(find.text('mic blocked · tap settings'), findsOneWidget);
  });
}

class _CleanupCallbackHolder {
  Future<backend.CleanupResult> Function({
    required String transcript,
    required String language,
  })
  callback = ({required String transcript, required String language}) async =>
      const backend.CleanupSuccess(cleanedText: 'Cleaned transcript.');
}

class _Harness {
  _Harness({
    required this.container,
    required this.database,
    required this.tempDirectory,
    required this.monotonicClock,
    required this.entryClock,
    required this.transcriptionService,
    required this.sharedPreferences,
    required this.cleanupCallbackHolder,
  });

  final ProviderContainer container;
  final LocalEntryDatabase database;
  final Directory tempDirectory;
  final FakeMonotonicClock monotonicClock;
  final _MutableClock entryClock;
  final _FakeTranscriptionService transcriptionService;
  final SharedPreferences sharedPreferences;
  final _CleanupCallbackHolder cleanupCallbackHolder;

  Future<void> dispose() async {
    container.dispose();
    await database.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  }
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration step = const Duration(milliseconds: 5),
  Duration timeout = const Duration(milliseconds: 100),
}) async {
  final iterations = timeout.inMicroseconds ~/ step.inMicroseconds;
  for (var index = 0; index < iterations; index += 1) {
    await tester.pump(step);
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
}

Future<_Harness> _createHarness({
  RecordingFeedbackDelays feedbackDelays = const RecordingFeedbackDelays(
    errorAndDeletedAutoClear: Duration(minutes: 1),
  ),
}) async {
  final tempDirectory = await Directory.systemTemp.createTemp(
    'wrait-main-screen-int',
  );
  final database = await LocalEntryDatabase.open(
    keyStore: DatabaseKeyStore(FakeSecureKeyValueStore(), random: Random(7)),
    databaseFile: File(
      '${tempDirectory.path}/${LocalEntryDatabase.databaseFileName}',
    ),
  );
  SharedPreferences.setMockInitialValues(const <String, Object>{});
  final sharedPreferences = await SharedPreferences.getInstance();
  final monotonicClock = FakeMonotonicClock(0);
  final entryClock = _MutableClock(DateTime(2026, 6, 13, 9));
  final transcriptionService = _FakeTranscriptionService();
  final cleanupCallbackHolder = _CleanupCallbackHolder();

  final container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(
        const AppConfig(
          backendUrl: 'https://wrait-backend.vercel.app',
          proxySecret: '',
          recordingHardCapMs: 120000,
        ),
      ),
      appRouterProvider.overrideWithValue(buildAppRouter()),
      localEntryDatabaseProvider.overrideWithValue(database),
      sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      monotonicClockProvider.overrideWithValue(monotonicClock),
      clockProvider.overrideWithValue(entryClock),
      transcriptionServiceProvider.overrideWithValue(transcriptionService),
      cleanupTranscriptCallbackProvider.overrideWithValue(({
        required transcript,
        required language,
      }) {
        return cleanupCallbackHolder.callback(
          transcript: transcript,
          language: language,
        );
      }),
      recordingFeedbackDelaysProvider.overrideWithValue(feedbackDelays),
    ],
  );

  return _Harness(
    container: container,
    database: database,
    tempDirectory: tempDirectory,
    monotonicClock: monotonicClock,
    entryClock: entryClock,
    transcriptionService: transcriptionService,
    sharedPreferences: sharedPreferences,
    cleanupCallbackHolder: cleanupCallbackHolder,
  );
}

class _FakeTranscriptionService implements TranscriptionService {
  @override
  int? hardCapDeadlineElapsedRealtime = 120000;

  @override
  bool isRecording = false;

  @override
  bool isTranscribing = false;

  TranscriptionServiceFailure? startFailure;
  TranscriptionResult nextStopResult = const TranscriptionSuccess(
    transcript: 'raw transcript',
    detectedLanguage: 'en-US',
  );

  @override
  Future<void> startLiveTranscription({
    required TranscriptionStatusCallback onStatus,
  }) async {
    if (startFailure case final failure?) {
      throw failure;
    }

    isRecording = true;
    onStatus(RecordingStarted(hardCapDeadlineElapsedRealtime!));
  }

  @override
  Future<TranscriptionResult> stopLiveTranscription({
    required TranscriptionStatusCallback onStatus,
  }) async {
    isRecording = false;
    if (nextStopResult case TranscriptionFailure(
      reason: final reason,
    ) when reason == TranscriptionFailureReason.tooShort) {
      return nextStopResult;
    }

    isTranscribing = true;
    onStatus(const Uploading());
    isTranscribing = false;
    return nextStopResult;
  }

  @override
  Future<void> cancelLiveTranscription() async {
    isRecording = false;
    isTranscribing = false;
    hardCapDeadlineElapsedRealtime = null;
  }

  @override
  Future<TranscriptionResult> transcribeAudioDraft(String audioPath) async {
    return nextStopResult;
  }
}

class _MutableClock implements Clock {
  _MutableClock(this.current);

  DateTime current;

  @override
  int now() => current.millisecondsSinceEpoch;

  void advance(Duration duration) {
    current = current.add(duration);
  }
}
