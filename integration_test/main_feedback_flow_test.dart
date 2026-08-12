import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wrait/app.dart';
import 'package:wrait/core/config/app_config.dart';
import 'package:wrait/core/router/app_router.dart';
import 'package:wrait/data/auth/app_lock_providers.dart';
import 'package:wrait/data/display/display_awake_service.dart';
import 'package:wrait/data/entries/entry_providers.dart';
import 'package:wrait/data/preferences/preferences_providers.dart';
import 'package:wrait/domain/model/entry.dart';
import 'package:wrait/domain/repository/entry_repository.dart';
import 'package:wrait/domain/repository/preferences_repository.dart';
import 'package:wrait/presentation/feedback/feedback_providers.dart';
import 'package:wrait/presentation/feedback/feedback_model.dart';
import 'package:wrait/presentation/feedback/feedback_preparation_sheet.dart';
import 'package:wrait/presentation/feedback/feedback_service.dart';
import 'package:wrait/presentation/main/main_recording_controller.dart';
import 'package:wrait/presentation/main/main_screen_test_keys.dart';
import 'package:wrait/presentation/main/recording_state.dart';

import '../test/test_doubles/fake_display_awake_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('submits feedback through the main-screen flow', (tester) async {
    final messageFlow = _FakeMessageFlow();
    final preferences = await _createPreferences();
    final feedbackService = WiredashFeedbackService(
      isConfigured: true,
      launchFlow: messageFlow.open,
    );

    await tester.pumpWidget(_buildApp(feedbackService, preferences));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(mainFeedbackButtonKey));
    await tester.pumpAndSettle();
    expect(find.text('send feedback'), findsOneWidget);
    expect(find.byKey(feedbackPrivacyCopyKey), findsOneWidget);

    await tester.tap(find.text('Idea'));
    await tester.enterText(
      find.byKey(feedbackContactFieldKey),
      'Signal: wrait-test',
    );
    await tester.tap(find.byKey(feedbackContinueButtonKey));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(_messageFieldKey),
      'The recording flow is clear.',
    );
    await tester.tap(find.text('submit feedback'));
    await tester.pumpAndSettle();

    expect(messageFlow.lastDraft?.category.name, 'idea');
    expect(messageFlow.lastDraft?.replyContact, 'Signal: wrait-test');
    expect(messageFlow.lastMessage, 'The recording flow is clear.');
    expect(find.text('feedback sent'), findsOneWidget);
    expect(find.byKey(mainFeedbackButtonKey), findsOneWidget);
  });

  testWidgets('cancels and retries without losing preparation data', (
    tester,
  ) async {
    final messageFlow = _FakeMessageFlow()..failNext = true;
    final preferences = await _createPreferences();
    final feedbackService = WiredashFeedbackService(
      isConfigured: true,
      launchFlow: messageFlow.open,
    );

    await tester.pumpWidget(_buildApp(feedbackService, preferences));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(mainFeedbackButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Praise'));
    await tester.enterText(find.byKey(feedbackContactFieldKey), 'not-an-email');
    await tester.tap(find.text('cancel'));
    await tester.pumpAndSettle();
    expect(find.text('send feedback'), findsNothing);
    expect(messageFlow.openCount, 0);

    await tester.tap(find.byKey(mainFeedbackButtonKey));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.byKey(feedbackContinueButtonKey))
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Praise'));
    await tester.enterText(find.byKey(feedbackContactFieldKey), 'not-an-email');
    await tester.tap(find.byKey(feedbackContinueButtonKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(_messageFieldKey), 'First attempt.');
    await tester.tap(find.text('submit feedback'));
    await tester.pumpAndSettle();

    expect(find.text('feedback could not be sent. try again'), findsOneWidget);
    tester
        .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
        .hideCurrentSnackBar();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(mainFeedbackButtonKey));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(feedbackContactFieldKey))
          .controller!
          .text,
      'not-an-email',
    );
    await tester.tap(find.byKey(feedbackContinueButtonKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(_messageFieldKey), 'Retry attempt.');
    await tester.tap(find.text('submit feedback'));
    await tester.pumpAndSettle();

    expect(messageFlow.openCount, 2);
    expect(find.text('feedback sent'), findsOneWidget);
  });
}

const _messageFieldKey = ValueKey<String>('fakeWiredashMessageField');

Widget _buildApp(
  FeedbackService feedbackService,
  SharedPreferences preferences,
) {
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWithValue(
        const AppConfig(
          backendUrl: 'https://wrait-backend.vercel.app',
          proxySecret: '',
          recordingHardCapMs: 120000,
        ),
      ),
      appRouterProvider.overrideWithValue(buildAppRouter()),
      appLockEnabledProvider.overrideWithValue(false),
      sharedPreferencesProvider.overrideWithValue(preferences),
      preferencesRepositoryProvider.overrideWithValue(
        const _TestPreferencesRepository(),
      ),
      entryRepositoryProvider.overrideWithValue(const _TestEntryRepository()),
      mainRecordingControllerProvider.overrideWith(_SmokeController.new),
      displayAwakeServiceProvider.overrideWithValue(FakeDisplayAwakeService()),
      feedbackServiceProvider.overrideWithValue(feedbackService),
    ],
    child: const WraitApp(),
  );
}

Future<SharedPreferences> _createPreferences() async {
  SharedPreferences.setMockInitialValues(const <String, Object>{});
  return SharedPreferences.getInstance();
}

class _FakeMessageFlow {
  bool failNext = false;
  int openCount = 0;
  FeedbackDraft? lastDraft;
  String? lastMessage;

  Future<bool> open({
    required BuildContext context,
    required FeedbackDraft draft,
    required String appArea,
  }) async {
    openCount += 1;
    lastDraft = draft;
    if (failNext) {
      failNext = false;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('wiredash feedback'),
          content: TextField(key: _messageFieldKey),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('submit feedback'),
            ),
          ],
        ),
      );
      throw StateError('network failure');
    }

    final message = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('wiredash feedback'),
          content: TextField(key: _messageFieldKey, controller: controller),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('submit feedback'),
            ),
          ],
        );
      },
    );
    if (message == null) {
      return false;
    }
    lastMessage = message;
    return true;
  }
}

class _SmokeController extends MainRecordingController {
  @override
  RecordingControllerState build() => const RecordingControllerState();

  @override
  Future<void> onMainButtonTapped() async {}
}

class _TestPreferencesRepository implements PreferencesRepository {
  const _TestPreferencesRepository();

  @override
  Future<String> getDeviceId() async => 'integration-device';

  @override
  Future<bool> getHasEverRecorded() async => false;

  @override
  Future<void> setHasEverRecorded(bool value) async {}
}

class _TestEntryRepository implements EntryRepository {
  const _TestEntryRepository();

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
  Future<void> importEntries(List<Entry> entries) async {}

  @override
  Future<List<Entry>> getPendingDrafts() async => const <Entry>[];

  @override
  Future<int> saveAudioDraft(String audioPath, String language) async => 1;

  @override
  Future<int> saveDraft(String transcript, String language) async => 1;

  @override
  Future<int> saveEntry(String transcript, String language) async => 1;

  @override
  Future<void> updateEditedCleanedText(int id, String cleanedText) async {}

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
  Stream<List<Entry>> watchAllEntries() =>
      Stream<List<Entry>>.value(const <Entry>[]);

  @override
  Stream<Entry?> watchEntryById(int id) => const Stream<Entry?>.empty();
}
