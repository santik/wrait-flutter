import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wrait/app.dart';
import 'package:wrait/core/config/app_config.dart';
import 'package:wrait/core/router/app_router.dart';
import 'package:wrait/data/auth/app_lock_providers.dart';
import 'package:wrait/data/api/backend_providers.dart';
import 'package:wrait/data/api/record_quota_state.dart';
import 'package:wrait/data/entries/entry_providers.dart';
import 'package:wrait/data/preferences/preferences_providers.dart';
import 'package:wrait/domain/model/entry.dart';
import 'package:wrait/domain/repository/entry_repository.dart';
import 'package:wrait/domain/repository/preferences_repository.dart';
import 'package:wrait/presentation/entries/entry_list_formatters.dart';
import 'package:wrait/presentation/main/main_recording_controller.dart';
import 'package:wrait/presentation/main/recording_state.dart';

void main() {
  late _TestEntryRepository entryRepository;

  setUp(() async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    entryRepository = _TestEntryRepository();
  });

  tearDown(() async {
    await entryRepository.dispose();
  });

  testWidgets('shows the centered empty state when no entries exist', (
    tester,
  ) async {
    await _pumpEntryListApp(tester, entryRepository: entryRepository);

    expect(find.text('no entries yet'), findsOneWidget);
    expect(find.byKey(const ValueKey('entryListView')), findsNothing);
  });

  testWidgets('renders populated entries newest first with language labels', (
    tester,
  ) async {
    entryRepository.emitEntries([
      _entry(id: 1, createdAt: DateTime(2026, 6, 14, 9)),
      _entry(id: 2, createdAt: DateTime(2026, 6, 15, 9), isDraft: true),
    ]);

    await _pumpEntryListApp(tester, entryRepository: entryRepository);

    final firstRowTop = tester
        .getTopLeft(find.byKey(const ValueKey('entryRow-2')))
        .dy;
    final secondRowTop = tester
        .getTopLeft(find.byKey(const ValueKey('entryRow-1')))
        .dy;

    expect(firstRowTop, lessThan(secondRowTop));
    expect(find.text('draft'), findsOneWidget);
    expect(find.text('English'), findsNWidgets(2));
  });

  testWidgets('row tap navigates to entry detail', (tester) async {
    entryRepository.emitEntries([_entry(id: 7)]);

    await _pumpEntryListApp(tester, entryRepository: entryRepository);
    await tester.tap(find.byKey(const ValueKey('entryCard-7')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('entryDetailReadText')), findsOneWidget);
    expect(find.text('clean entry 7'), findsOneWidget);
  });

  testWidgets('audio-only draft shows retry preview and does not navigate', (
    tester,
  ) async {
    entryRepository.emitEntries([_audioDraftEntry(id: 9)]);

    await _pumpEntryListApp(tester, entryRepository: entryRepository);

    expect(find.text(entryListAudioDraftPreview), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('entryCard-9')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('entryListView')), findsOneWidget);
    expect(find.byKey(const ValueKey('entryDetailReadText')), findsNothing);
  });

  testWidgets('back button returns to the main screen', (tester) async {
    await _pumpEntryListApp(tester, entryRepository: entryRepository);

    await tester.tap(find.byKey(const ValueKey('entryListBackButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('actionButton')), findsOneWidget);
  });

  testWidgets('exposes back, row, and delete semantics actions', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    entryRepository.emitEntries([_entry(id: 1)]);

    await _pumpEntryListApp(tester, entryRepository: entryRepository);

    expect(find.bySemanticsLabel('Back to main screen'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Entry ')), findsWidgets);
    final semanticsData = tester
        .getSemantics(find.byKey(const ValueKey('entryRow-1')))
        .getSemanticsData();
    final customActions =
        semanticsData.customSemanticsActionIds
            ?.map(CustomSemanticsAction.getAction)
            .whereType<CustomSemanticsAction>()
            .toList() ??
        const <CustomSemanticsAction>[];

    expect(
      customActions,
      contains(const CustomSemanticsAction(label: entryListDeleteActionLabel)),
    );

    semanticsHandle.dispose();
  });

  testWidgets('delete failure keeps the row visible and stays on the list', (
    tester,
  ) async {
    entryRepository
      ..throwsOnDelete = true
      ..emitEntries([_entry(id: 5)]);

    await _pumpEntryListApp(tester, entryRepository: entryRepository);

    await tester.drag(
      find.byKey(const ValueKey('entryCard-5')),
      const Offset(120, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('entryDeleteConfirmButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('entryRow-5')), findsOneWidget);
    expect(find.byKey(const ValueKey('entryListView')), findsOneWidget);
  });

  testWidgets('delete dialog exposes destructive semantics labels', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    entryRepository.emitEntries([_entry(id: 3)]);

    await _pumpEntryListApp(tester, entryRepository: entryRepository);

    await tester.drag(
      find.byKey(const ValueKey('entryCard-3')),
      const Offset(120, 0),
    );
    await tester.pumpAndSettle();

    final confirmSemantics = tester
        .getSemantics(find.bySemanticsLabel('Delete entry permanently'))
        .getSemanticsData();
    final cancelSemantics = tester
        .getSemantics(find.bySemanticsLabel('Cancel deletion'))
        .getSemanticsData();

    expect(confirmSemantics.label, 'Delete entry permanently');
    expect(confirmSemantics.hint, 'Removes this entry from the list.');
    expect(cancelSemantics.label, 'Cancel deletion');
    expect(cancelSemantics.hint, 'Keeps this entry in the list.');

    semanticsHandle.dispose();
  });
}

Future<void> _pumpEntryListApp(
  WidgetTester tester, {
  required _TestEntryRepository entryRepository,
}) async {
  final sharedPreferences = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(
            backendUrl: 'https://wrait-backend.vercel.app',
            proxySecret: '',
            recordingHardCapMs: 120000,
          ),
        ),
        appRouterProvider.overrideWithValue(
          buildAppRouter(initialLocation: '/entries'),
        ),
        appLockEnabledProvider.overrideWithValue(false),
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        preferencesRepositoryProvider.overrideWithValue(
          const _TestPreferencesRepository(),
        ),
        entryRepositoryProvider.overrideWithValue(entryRepository),
        mainRecordingControllerProvider.overrideWith(
          _TestMainRecordingController.new,
        ),
        sessionRecordQuotaStateProvider.overrideWith(_TestQuotaNotifier.new),
      ],
      child: const WraitApp(),
    ),
  );

  await tester.pumpAndSettle();
}

class _TestMainRecordingController extends MainRecordingController {
  @override
  RecordingControllerState build() => const RecordingControllerState();

  @override
  Future<void> onMainButtonTapped() async {}
}

class _TestQuotaNotifier extends SessionRecordQuotaStateNotifier {
  @override
  RecordQuotaState? build() => null;
}

class _TestEntryRepository implements EntryRepository {
  final StreamController<List<Entry>> _controller =
      StreamController<List<Entry>>.broadcast();
  List<Entry> _entries = const <Entry>[];
  bool throwsOnDelete = false;

  void emitEntries(List<Entry> entries) {
    _entries = List<Entry>.from(entries);
    _controller.add(_entries);
  }

  Future<void> dispose() => _controller.close();

  @override
  Stream<List<Entry>> watchAllEntries() async* {
    yield _entries;
    yield* _controller.stream;
  }

  @override
  Stream<Entry?> watchEntryById(int id) async* {
    yield _findEntry(id);
    yield* _controller.stream.map((entries) {
      return _findEntry(id, entries: entries);
    });
  }

  @override
  Future<Entry?> getEntryById(int id) async => _findEntry(id);

  @override
  Future<int> saveDraft(String transcript, String language) async => 1;

  @override
  Future<int> saveEntry(String transcript, String language) async => 1;

  @override
  Future<int> saveAudioDraft(String audioPath, String language) async => 1;

  @override
  Future<void> updateEditedCleanedText(int id, String cleanedText) async {}

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
  Future<void> deleteEntry(int id) async {
    if (throwsOnDelete) {
      throw StateError('delete failed');
    }

    _entries = _entries.where((entry) => entry.id != id).toList();
    _controller.add(_entries);
  }

  @override
  Future<void> deleteStaleDrafts({int daysOld = 7}) async {}

  Entry? _findEntry(int id, {List<Entry>? entries}) {
    final source = entries ?? _entries;
    for (final entry in source) {
      if (entry.id == id) {
        return entry;
      }
    }
    return null;
  }
}

class _TestPreferencesRepository implements PreferencesRepository {
  const _TestPreferencesRepository();

  @override
  Future<String> getDeviceId() async => 'device-id';

  @override
  Future<bool> getHasEverRecorded() async => true;

  @override
  Future<void> setHasEverRecorded(bool value) async {}
}

Entry _entry({required int id, DateTime? createdAt, bool isDraft = false}) {
  return Entry(
    id: id,
    rawTranscript: 'entry $id',
    cleanedText: 'clean entry $id',
    isDraft: isDraft,
    language: 'en-US',
    createdAt: (createdAt ?? DateTime(2026, 6, 15, 9)).millisecondsSinceEpoch,
    wordCount: 3,
  );
}

Entry _audioDraftEntry({required int id}) {
  return Entry(
    id: id,
    rawTranscript: '',
    cleanedText: null,
    isDraft: true,
    language: 'en-US',
    createdAt: DateTime(2026, 6, 15, 9).millisecondsSinceEpoch,
    wordCount: 0,
    audioPath: '/tmp/pending.m4a',
  );
}
