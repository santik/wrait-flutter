import 'recording_state.dart';

enum MainScreenStatusAction { startRecording, openSavedEntry }

class MainScreenStatusPresentation {
  const MainScreenStatusPresentation({
    required this.buttonLabel,
    required this.statusText,
    this.action,
    this.savedEntryId,
  });

  final String buttonLabel;
  final String statusText;
  final MainScreenStatusAction? action;
  final int? savedEntryId;

  bool get isStatusTappable => action != null;
}

MainScreenStatusPresentation resolveMainScreenStatus({
  required RecordingControllerState controllerState,
  required bool hasEverRecorded,
}) {
  final recordingState = controllerState.recordingState;
  final buttonLabel = switch (recordingState) {
    RecordingListening() => 'stop',
    _ => 'wrait',
  };

  return switch (recordingState) {
    RecordingIdle() when !hasEverRecorded => MainScreenStatusPresentation(
      buttonLabel: buttonLabel,
      statusText: 'tap button to write',
      action: MainScreenStatusAction.startRecording,
    ),
    RecordingIdle() => MainScreenStatusPresentation(
      buttonLabel: buttonLabel,
      statusText: 'wrait',
    ),
    RecordingListening() => MainScreenStatusPresentation(
      buttonLabel: buttonLabel,
      statusText: 'listening...',
    ),
    RecordingUploading() => MainScreenStatusPresentation(
      buttonLabel: buttonLabel,
      statusText: 'uploading...',
    ),
    RecordingProcessing() => MainScreenStatusPresentation(
      buttonLabel: buttonLabel,
      statusText: 'cleaning up...',
    ),
    RecordingSaved(entryId: final entryId) => MainScreenStatusPresentation(
      buttonLabel: buttonLabel,
      statusText: 'saved, tap to read',
      action: MainScreenStatusAction.openSavedEntry,
      savedEntryId: entryId,
    ),
    RecordingDeleted() => MainScreenStatusPresentation(
      buttonLabel: buttonLabel,
      statusText: 'deleted',
    ),
    RecordingErrorState(preservedDraft: true) => MainScreenStatusPresentation(
      buttonLabel: buttonLabel,
      statusText: 'saved as draft',
    ),
    RecordingErrorState(error: RecordingError.tooShort) =>
      MainScreenStatusPresentation(
        buttonLabel: buttonLabel,
        statusText: 'too short · keep talking',
      ),
    RecordingErrorState(error: RecordingError.noMatch) =>
      MainScreenStatusPresentation(
        buttonLabel: buttonLabel,
        statusText: 'nothing caught · too quiet?',
      ),
    RecordingErrorState(error: RecordingError.insufficientPermissions) =>
      MainScreenStatusPresentation(
        buttonLabel: buttonLabel,
        statusText: 'mic blocked',
      ),
    RecordingErrorState(error: RecordingError.noInternet) =>
      MainScreenStatusPresentation(
        buttonLabel: buttonLabel,
        statusText: 'no connection',
      ),
    RecordingErrorState(error: RecordingError.backendUnavailable) =>
      MainScreenStatusPresentation(
        buttonLabel: buttonLabel,
        statusText: 'service unavailable',
      ),
    RecordingErrorState(error: RecordingError.proxyAuthFailed) =>
      MainScreenStatusPresentation(
        buttonLabel: buttonLabel,
        statusText: 'server config error',
      ),
    RecordingErrorState(error: RecordingError.apiFailed) =>
      MainScreenStatusPresentation(
        buttonLabel: buttonLabel,
        statusText: 'something went wrong',
      ),
  };
}
