import 'package:flutter_test/flutter_test.dart';
import 'package:wrait/presentation/main/main_screen_status.dart';
import 'package:wrait/presentation/main/recording_state.dart';

void main() {
  test('returns the first-time idle presentation', () {
    final presentation = resolveMainScreenStatus(
      controllerState: const RecordingControllerState(),
      hasEverRecorded: false,
    );

    expect(presentation.buttonLabel, 'wrait');
    expect(presentation.statusText, 'tap button to write');
    expect(presentation.action, MainScreenStatusAction.startRecording);
  });

  test('returns the returning-user idle presentation', () {
    final presentation = resolveMainScreenStatus(
      controllerState: const RecordingControllerState(),
      hasEverRecorded: true,
    );

    expect(presentation.buttonLabel, 'wrait');
    expect(presentation.statusText, 'wrait');
    expect(presentation.action, isNull);
  });

  test('returns the listening presentation', () {
    final presentation = resolveMainScreenStatus(
      controllerState: RecordingControllerState(
        recordingState: RecordingListening(
          hardCapDeadlineElapsedRealtime: 120000,
        ),
      ),
      hasEverRecorded: true,
    );

    expect(presentation.buttonLabel, 'stop');
    expect(presentation.statusText, 'listening...');
  });

  test('returns the saved presentation with detail navigation action', () {
    final presentation = resolveMainScreenStatus(
      controllerState: RecordingControllerState(
        recordingState: RecordingSaved(entryId: 14, detectedLanguage: 'en-US'),
      ),
      hasEverRecorded: true,
    );

    expect(presentation.buttonLabel, 'wrait');
    expect(presentation.statusText, 'saved, tap to read');
    expect(presentation.action, MainScreenStatusAction.openSavedEntry);
    expect(presentation.savedEntryId, 14);
  });

  test('returns draft-preserved error text when a draft was saved', () {
    final presentation = resolveMainScreenStatus(
      controllerState: const RecordingControllerState(
        recordingState: RecordingErrorState(
          RecordingError.noInternet,
          preservedDraft: true,
        ),
      ),
      hasEverRecorded: true,
    );

    expect(presentation.statusText, 'saved as draft');
  });

  test('returns approved error copy for specific non-draft errors', () {
    final cases = <RecordingState, String>{
      const RecordingErrorState(RecordingError.tooShort):
          'too short · keep talking',
      const RecordingErrorState(RecordingError.noMatch):
          'nothing caught · too quiet?',
      const RecordingErrorState(RecordingError.insufficientPermissions):
          'mic blocked',
      const RecordingDeleted(2): 'deleted',
      const RecordingUploading(): 'uploading...',
      const RecordingProcessing(): 'cleaning up...',
    };

    for (final entry in cases.entries) {
      final presentation = resolveMainScreenStatus(
        controllerState: RecordingControllerState(recordingState: entry.key),
        hasEverRecorded: true,
      );
      expect(presentation.statusText, entry.value);
    }
  });
}
