import 'dart:io';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wrait/app.dart';
import 'package:wrait/core/config/app_config.dart';
import 'package:wrait/core/router/app_router.dart';
import 'package:wrait/core/time/system_clock.dart';
import 'package:wrait/data/api/backend_providers.dart';
import 'package:wrait/data/api/record_quota_state.dart';
import 'package:wrait/data/entries/database_key_store.dart';
import 'package:wrait/data/entries/entry_providers.dart';
import 'package:wrait/data/entries/local_entry_database.dart';
import 'package:wrait/data/preferences/preferences_providers.dart';
import 'package:wrait/domain/repository/preferences_repository.dart';
import 'package:wrait/presentation/main/main_recording_controller.dart';
import 'package:wrait/presentation/main/recording_state.dart';

import '../test/test_doubles/fake_secure_storage.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('shows the empty state on the entry list route', (tester) async {
    final harness = await _createHarness();
    addTearDown(harness.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const WraitApp(),
      ),
    );
    await tester.pumpAndSettle();
    await _prepareScreenshots(binding, tester);
    await binding.takeScreenshot('entry-list-empty');

    expect(find.text('no entries yet'), findsOneWidget);
  });

  testWidgets('shows finalized and draft entries newest first', (tester) async {
    final harness = await _createHarness();
    addTearDown(harness.dispose);

    final repository = harness.container.read(entryRepositoryProvider);
    await repository.saveEntry('older final entry', 'en-US');
    harness.entryClock.advance(const Duration(days: 1));
    await repository.saveDraft('newer draft entry', 'en-US');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const WraitApp(),
      ),
    );
    await tester.pumpAndSettle();
    await _prepareScreenshots(binding, tester);
    await binding.takeScreenshot('entry-list-populated');

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

  testWidgets('row tap navigates to the detail route', (tester) async {
    final harness = await _createHarness();
    addTearDown(harness.dispose);

    final repository = harness.container.read(entryRepositoryProvider);
    final id = await repository.saveEntry('entry to open', 'en-US');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const WraitApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ValueKey('entryCard-$id')));
    await tester.pumpAndSettle();

    expect(find.text('Entry preview'), findsOneWidget);
    expect(find.byKey(const ValueKey('entryIdValue')), findsOneWidget);
  });

  testWidgets('audio-only draft stays on the list when tapped', (tester) async {
    final harness = await _createHarness();
    addTearDown(harness.dispose);

    final repository = harness.container.read(entryRepositoryProvider);
    final id = await repository.saveAudioDraft('/tmp/pending.m4a', 'en-US');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const WraitApp(),
      ),
    );
    await tester.pumpAndSettle();
    await _prepareScreenshots(binding, tester);
    await binding.takeScreenshot('entry-list-audio-draft');

    expect(find.text('pending · will retry'), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('entryCard-$id')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('entryListView')), findsOneWidget);
    expect(find.text('Entry preview'), findsNothing);
  });

  testWidgets('cancel keeps the row after swipe-to-delete', (tester) async {
    final harness = await _createHarness();
    addTearDown(harness.dispose);

    final repository = harness.container.read(entryRepositoryProvider);
    final id = await repository.saveEntry('entry to keep', 'en-US');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const WraitApp(),
      ),
    );
    await tester.pumpAndSettle();

    final cardFinder = find.byKey(ValueKey('entryCard-$id'));
    final initialLeft = tester.getTopLeft(cardFinder).dx;

    await tester.drag(cardFinder, const Offset(120, 0));
    await tester.pumpAndSettle();
    await _prepareScreenshots(binding, tester);
    await binding.takeScreenshot('entry-list-delete-prompt-cancel');
    await tester.tap(find.byKey(const ValueKey('entryDeleteCancelButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(ValueKey('entryRow-$id')), findsOneWidget);
    expect(tester.getTopLeft(cardFinder).dx, initialLeft);
  });

  testWidgets('audio-only draft can be deleted from the list', (tester) async {
    final harness = await _createHarness();
    addTearDown(harness.dispose);

    final repository = harness.container.read(entryRepositoryProvider);
    final deletedId = await repository.saveAudioDraft(
      '/tmp/pending.m4a',
      'en-US',
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const WraitApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(ValueKey('entryCard-$deletedId')),
      const Offset(120, 0),
    );
    await tester.pumpAndSettle();
    await _prepareScreenshots(binding, tester);
    await binding.takeScreenshot('entry-list-audio-draft-delete-prompt');
    await tester.tap(find.byKey(const ValueKey('entryDeleteConfirmButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(ValueKey('entryRow-$deletedId')), findsNothing);
    expect(find.byKey(const ValueKey('entryListEmptyState')), findsOneWidget);
  });

  testWidgets('delete removes the row and stays on the list', (tester) async {
    final harness = await _createHarness();
    addTearDown(harness.dispose);

    final repository = harness.container.read(entryRepositoryProvider);
    final deletedId = await repository.saveEntry('entry to delete', 'en-US');
    await repository.saveEntry('entry to keep', 'en-US');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const WraitApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(ValueKey('entryCard-$deletedId')),
      const Offset(120, 0),
    );
    await tester.pumpAndSettle();
    await _prepareScreenshots(binding, tester);
    await binding.takeScreenshot('entry-list-delete-prompt-confirm');
    await tester.tap(find.byKey(const ValueKey('entryDeleteConfirmButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(ValueKey('entryRow-$deletedId')), findsNothing);
    expect(find.byKey(const ValueKey('entryListView')), findsOneWidget);
  });

  testWidgets('back button returns to the main screen', (tester) async {
    final harness = await _createHarness();
    addTearDown(harness.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: const WraitApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('entryListBackButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('actionButton')), findsOneWidget);
  });
}

Future<void> _prepareScreenshots(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester,
) async {
  await binding.convertFlutterSurfaceToImage();
  await tester.pump();
}

class _Harness {
  _Harness({
    required this.container,
    required this.database,
    required this.tempDirectory,
    required this.entryClock,
  });

  final ProviderContainer container;
  final LocalEntryDatabase database;
  final Directory tempDirectory;
  final _MutableClock entryClock;

  Future<void> dispose() async {
    container.dispose();
    await database.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  }
}

Future<_Harness> _createHarness() async {
  final tempDirectory = await Directory.systemTemp.createTemp(
    'wrait-entry-list-int',
  );
  final database = await LocalEntryDatabase.open(
    keyStore: DatabaseKeyStore(FakeSecureKeyValueStore(), random: Random(7)),
    databaseFile: File(
      '${tempDirectory.path}/${LocalEntryDatabase.databaseFileName}',
    ),
  );
  final entryClock = _MutableClock(DateTime(2026, 6, 15, 9));

  final container = ProviderContainer(
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
      localEntryDatabaseProvider.overrideWithValue(database),
      clockProvider.overrideWithValue(entryClock),
      preferencesRepositoryProvider.overrideWithValue(
        const _EntryListPreferencesRepository(),
      ),
      mainRecordingControllerProvider.overrideWith(
        _IdleMainRecordingController.new,
      ),
      sessionRecordQuotaStateProvider.overrideWith(_IdleQuotaNotifier.new),
    ],
  );

  return _Harness(
    container: container,
    database: database,
    tempDirectory: tempDirectory,
    entryClock: entryClock,
  );
}

class _IdleMainRecordingController extends MainRecordingController {
  @override
  RecordingControllerState build() => const RecordingControllerState();

  @override
  Future<void> onMainButtonTapped() async {}
}

class _IdleQuotaNotifier extends SessionRecordQuotaStateNotifier {
  @override
  RecordQuotaState? build() => null;
}

class _EntryListPreferencesRepository implements PreferencesRepository {
  const _EntryListPreferencesRepository();

  @override
  Future<String> getDeviceId() async => 'device-id';

  @override
  Future<bool> getHasEverRecorded() async => true;

  @override
  Future<void> setHasEverRecorded(bool value) async {}
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
