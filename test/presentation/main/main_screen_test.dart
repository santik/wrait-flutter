import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wrait/app.dart';
import 'package:wrait/core/config/app_config.dart';
import 'package:wrait/core/router/app_router.dart';
import 'package:wrait/data/api/backend_providers.dart';
import 'package:wrait/data/api/record_quota_state.dart';
import 'package:wrait/data/entries/entry_providers.dart';
import 'package:wrait/data/preferences/preferences_providers.dart';
import 'package:wrait/domain/model/entry.dart';
import 'package:wrait/domain/repository/entry_repository.dart';
import 'package:wrait/domain/repository/preferences_repository.dart';
import 'package:wrait/presentation/main/main_recording_controller.dart';
import 'package:wrait/presentation/main/recording_state.dart';
import 'package:wrait/presentation/theme/design_tokens.dart';

void main() {
  late _TestMainRecordingController controller;
  late _TestEntryRepository entryRepository;
  late _TestPreferencesRepository preferencesRepository;
  late _TestQuotaNotifier quotaNotifier;

  setUp(() async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    controller = _TestMainRecordingController();
    entryRepository = _TestEntryRepository();
    preferencesRepository = _TestPreferencesRepository(hasEverRecorded: true);
    quotaNotifier = _TestQuotaNotifier();
  });

  testWidgets(
    'renders the approved layout with reserved status and quota space',
    (tester) async {
      await _pumpTestApp(
        tester,
        controller: controller,
        entryRepository: entryRepository,
        preferencesRepository: preferencesRepository,
        quotaNotifier: quotaNotifier,
      );

      expect(find.byKey(const ValueKey('actionButton')), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey('statusLineSlot'))).height,
        WraitStatusLineTokens.reservedHeight,
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('quotaLineSlot'))).height,
        WraitQuotaLineTokens.reservedHeight,
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('statsLineSlot'))).height,
        WraitStatsLineTokens.reservedHeight,
      );
    },
  );

  testWidgets('first-time status tap starts recording through the controller', (
    tester,
  ) async {
    preferencesRepository = _TestPreferencesRepository(hasEverRecorded: false);

    await _pumpTestApp(
      tester,
      controller: controller,
      entryRepository: entryRepository,
      preferencesRepository: preferencesRepository,
      quotaNotifier: quotaNotifier,
    );

    await tester.tap(find.byKey(const ValueKey('statusLineButton')));
    await tester.pump();

    expect(controller.tapCount, 1);
  });

  testWidgets('saved status tap navigates to entry detail', (tester) async {
    controller.setTestState(
      RecordingControllerState(
        recordingState: RecordingSaved(entryId: 42, detectedLanguage: 'en-US'),
      ),
    );

    await _pumpTestApp(
      tester,
      controller: controller,
      entryRepository: entryRepository,
      preferencesRepository: preferencesRepository,
      quotaNotifier: quotaNotifier,
    );

    await tester.tap(find.byKey(const ValueKey('statusLineButton')));
    await tester.pumpAndSettle();

    expect(find.text('Entry preview'), findsOneWidget);
    expect(find.textContaining('42'), findsOneWidget);
  });

  testWidgets('stats tap navigates to entries', (tester) async {
    entryRepository.emitEntries([
      _entry(id: 1, createdAt: DateTime(2026, 6, 13, 9)),
      _entry(id: 2, createdAt: DateTime(2026, 6, 14, 9), isDraft: true),
    ]);

    await _pumpTestApp(
      tester,
      controller: controller,
      entryRepository: entryRepository,
      preferencesRepository: preferencesRepository,
      quotaNotifier: quotaNotifier,
    );

    await tester.ensureVisible(find.byKey(const ValueKey('statsLineButton')));
    await tester.tap(find.byKey(const ValueKey('statsLineButton')));
    await tester.pumpAndSettle();

    expect(find.text('Entries'), findsOneWidget);
  });

  testWidgets('saved feedback auto-clears after the saved display window', (
    tester,
  ) async {
    await _pumpTestApp(
      tester,
      controller: controller,
      entryRepository: entryRepository,
      preferencesRepository: preferencesRepository,
      quotaNotifier: quotaNotifier,
      feedbackDelays: const RecordingFeedbackDelays(
        savedDisplayWindow: Duration(milliseconds: 1),
      ),
    );

    controller.setTestState(
      RecordingControllerState(
        recordingState: RecordingSaved(entryId: 7, detectedLanguage: 'en-US'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 5));

    expect(controller.clearSavedCount, 1);
    expect(find.text('wrait'), findsWidgets);
  });

  testWidgets('saved feedback timer resets for a newer saved state', (
    tester,
  ) async {
    await _pumpTestApp(
      tester,
      controller: controller,
      entryRepository: entryRepository,
      preferencesRepository: preferencesRepository,
      quotaNotifier: quotaNotifier,
      feedbackDelays: const RecordingFeedbackDelays(
        savedDisplayWindow: Duration(milliseconds: 20),
      ),
    );

    controller.setTestState(
      RecordingControllerState(
        recordingState: RecordingSaved(entryId: 7, detectedLanguage: 'en-US'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));

    controller.setTestState(
      RecordingControllerState(
        recordingState: RecordingSaved(entryId: 8, detectedLanguage: 'en-US'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 15));

    expect(controller.clearSavedCount, 0);

    await tester.pump(const Duration(milliseconds: 10));
    expect(controller.clearSavedCount, 1);
  });

  testWidgets('quota is visible with valid quota and hidden without it', (
    tester,
  ) async {
    quotaNotifier.setQuota(
      RecordQuotaState(
        limit: 8,
        count: 3,
        remaining: 5,
        resetAt: DateTime.utc(2026, 6, 13),
      ),
    );

    await _pumpTestApp(
      tester,
      controller: controller,
      entryRepository: entryRepository,
      preferencesRepository: preferencesRepository,
      quotaNotifier: quotaNotifier,
    );
    expect(find.text('8 total / 5 left'), findsOneWidget);

    quotaNotifier.clear();
    await tester.pump();
    expect(find.text('8 total / 5 left'), findsNothing);
  });

  testWidgets('quota remains visible while listening', (tester) async {
    quotaNotifier.setQuota(
      RecordQuotaState(
        limit: 10,
        count: 1,
        remaining: 9,
        resetAt: DateTime.utc(2026, 6, 13),
      ),
    );
    controller.setTestState(
      RecordingControllerState(
        recordingState: RecordingListening(
          hardCapDeadlineElapsedRealtime: 120000,
        ),
      ),
    );

    await _pumpTestApp(
      tester,
      controller: controller,
      entryRepository: entryRepository,
      preferencesRepository: preferencesRepository,
      quotaNotifier: quotaNotifier,
      settle: false,
    );

    expect(find.text('10 total / 9 left'), findsOneWidget);
    expect(find.text('stop'), findsOneWidget);
  });

  testWidgets('hides countdown ring when recording hard cap is non-positive', (
    tester,
  ) async {
    controller.setTestState(
      RecordingControllerState(
        recordingState: RecordingListening(
          hardCapDeadlineElapsedRealtime: 120000,
        ),
      ),
    );

    await _pumpTestApp(
      tester,
      controller: controller,
      entryRepository: entryRepository,
      preferencesRepository: preferencesRepository,
      quotaNotifier: quotaNotifier,
      appConfig: const AppConfig(
        backendUrl: 'https://wrait-backend.vercel.app',
        proxySecret: '',
        recordingHardCapMs: 0,
      ),
      settle: false,
    );

    expect(find.byKey(const ValueKey('countdownRing')), findsNothing);
    expect(find.text('stop'), findsOneWidget);
  });

  testWidgets(
    'falls back to first-time idle copy when preference loading fails',
    (tester) async {
      preferencesRepository = _TestPreferencesRepository(
        hasEverRecorded: true,
        throwsOnGetHasEverRecorded: true,
      );

      await _pumpTestApp(
        tester,
        controller: controller,
        entryRepository: entryRepository,
        preferencesRepository: preferencesRepository,
        quotaNotifier: quotaNotifier,
      );

      expect(find.text('tap button to write'), findsOneWidget);
      expect(find.byKey(const ValueKey('statusLineButton')), findsOneWidget);
    },
  );

  testWidgets('disposing while listening cancels countdown updates cleanly', (
    tester,
  ) async {
    controller.setTestState(
      RecordingControllerState(
        recordingState: RecordingListening(
          hardCapDeadlineElapsedRealtime: 120000,
        ),
      ),
    );

    await _pumpTestApp(
      tester,
      controller: controller,
      entryRepository: entryRepository,
      preferencesRepository: preferencesRepository,
      quotaNotifier: quotaNotifier,
      settle: false,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
  });

  testWidgets('shows microphone-blocked status text', (tester) async {
    controller.setTestState(
      const RecordingControllerState(
        recordingState: RecordingErrorState(
          RecordingError.insufficientPermissions,
        ),
      ),
    );

    await _pumpTestApp(
      tester,
      controller: controller,
      entryRepository: entryRepository,
      preferencesRepository: preferencesRepository,
      quotaNotifier: quotaNotifier,
    );

    expect(find.text('mic blocked'), findsOneWidget);
  });
}

Future<void> _pumpTestApp(
  WidgetTester tester, {
  required _TestMainRecordingController controller,
  required _TestEntryRepository entryRepository,
  required _TestPreferencesRepository preferencesRepository,
  required _TestQuotaNotifier quotaNotifier,
  AppConfig appConfig = const AppConfig(
    backendUrl: 'https://wrait-backend.vercel.app',
    proxySecret: '',
    recordingHardCapMs: 120000,
  ),
  RecordingFeedbackDelays feedbackDelays = const RecordingFeedbackDelays(),
  bool settle = true,
}) async {
  final router = buildAppRouter();
  final sharedPreferences = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(appConfig),
        appRouterProvider.overrideWithValue(router),
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        preferencesRepositoryProvider.overrideWithValue(preferencesRepository),
        entryRepositoryProvider.overrideWithValue(entryRepository),
        mainRecordingControllerProvider.overrideWith(() => controller),
        sessionRecordQuotaStateProvider.overrideWith(() => quotaNotifier),
        recordingFeedbackDelaysProvider.overrideWithValue(feedbackDelays),
      ],
      child: const WraitApp(),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
    return;
  }
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1));
}

class _TestMainRecordingController extends MainRecordingController {
  RecordingControllerState _initialState = const RecordingControllerState();
  int tapCount = 0;
  int clearSavedCount = 0;

  @override
  RecordingControllerState build() => _initialState;

  @override
  Future<void> onMainButtonTapped() async {
    tapCount += 1;
  }

  @override
  void clearSaved() {
    clearSavedCount += 1;
    try {
      state = const RecordingControllerState();
    } catch (_) {
      _initialState = const RecordingControllerState();
    }
  }

  void setTestState(RecordingControllerState nextState) {
    _initialState = nextState;
    try {
      state = nextState;
    } catch (_) {}
  }
}

class _TestQuotaNotifier extends SessionRecordQuotaStateNotifier {
  _TestQuotaNotifier([RecordQuotaState? initialQuota])
    : _currentQuota = initialQuota;

  RecordQuotaState? _currentQuota;

  @override
  RecordQuotaState? build() => _currentQuota;

  @override
  void setQuota(RecordQuotaState quota) {
    _currentQuota = quota;
    try {
      state = quota;
    } catch (_) {}
  }

  void clear() {
    _currentQuota = null;
    try {
      state = null;
    } catch (_) {}
  }
}

class _TestEntryRepository implements EntryRepository {
  final StreamController<List<Entry>> _controller =
      StreamController<List<Entry>>.broadcast();

  _TestEntryRepository() {
    _controller.add(const <Entry>[]);
  }

  void emitEntries(List<Entry> entries) {
    _controller.add(entries);
  }

  @override
  Stream<List<Entry>> watchAllEntries() => _controller.stream;

  @override
  Stream<Entry?> watchEntryById(int id) => const Stream<Entry?>.empty();

  @override
  Future<Entry?> getEntryById(int id) async => null;

  @override
  Future<int> saveDraft(String transcript, String language) async => 1;

  @override
  Future<int> saveEntry(String transcript, String language) async => 1;

  @override
  Future<int> saveAudioDraft(String audioPath, String language) async => 1;

  @override
  Future<void> updateWithCleanedText(
    int id,
    String cleanedText,
    int wordCount,
  ) async {}

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
  Future<void> finalizeDraftWithCleanedText(
    int id,
    String rawTranscript,
    String cleanedText,
    int wordCount,
  ) async {}

  @override
  Future<void> updateEntryLanguage(int id, String language) async {}

  @override
  Future<List<Entry>> getPendingDrafts() async => const <Entry>[];

  @override
  Future<void> deleteEntry(int id) async {}

  @override
  Future<void> deleteStaleDrafts({int daysOld = 7}) async {}
}

class _TestPreferencesRepository implements PreferencesRepository {
  _TestPreferencesRepository({
    required this.hasEverRecorded,
    this.throwsOnGetHasEverRecorded = false,
  });

  final bool hasEverRecorded;
  final bool throwsOnGetHasEverRecorded;

  @override
  Future<String> getDeviceId() async => 'device-id';

  @override
  Future<bool> getHasEverRecorded() async {
    if (throwsOnGetHasEverRecorded) {
      throw StateError('preferences unavailable');
    }
    return hasEverRecorded;
  }

  @override
  Future<void> setHasEverRecorded(bool value) async {}
}

Entry _entry({
  required int id,
  required DateTime createdAt,
  bool isDraft = false,
}) {
  return Entry(
    id: id,
    rawTranscript: 'entry $id',
    isDraft: isDraft,
    language: 'en-US',
    createdAt: createdAt.millisecondsSinceEpoch,
    wordCount: 2,
  );
}
