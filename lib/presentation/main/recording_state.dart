class RecordingControllerState {
  const RecordingControllerState({
    this.recordingState = const RecordingIdle(),
    this.shakeErrorKey = 0,
  });

  final RecordingState recordingState;
  final int shakeErrorKey;

  bool get isActive => switch (recordingState) {
    RecordingListening() ||
    RecordingUploading() ||
    RecordingProcessing() => true,
    _ => false,
  };

  RecordingControllerState copyWith({
    RecordingState? recordingState,
    int? shakeErrorKey,
  }) {
    return RecordingControllerState(
      recordingState: recordingState ?? this.recordingState,
      shakeErrorKey: shakeErrorKey ?? this.shakeErrorKey,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is RecordingControllerState &&
            other.recordingState == recordingState &&
            other.shakeErrorKey == shakeErrorKey;
  }

  @override
  int get hashCode => Object.hash(recordingState, shakeErrorKey);
}

sealed class RecordingState {
  const RecordingState();
}

final class RecordingIdle extends RecordingState {
  const RecordingIdle();

  @override
  bool operator ==(Object other) => other is RecordingIdle;

  @override
  int get hashCode => runtimeType.hashCode;
}

final class RecordingListening extends RecordingState {
  const RecordingListening();

  @override
  bool operator ==(Object other) => other is RecordingListening;

  @override
  int get hashCode => runtimeType.hashCode;
}

final class RecordingUploading extends RecordingState {
  const RecordingUploading();

  @override
  bool operator ==(Object other) => other is RecordingUploading;

  @override
  int get hashCode => runtimeType.hashCode;
}

final class RecordingProcessing extends RecordingState {
  const RecordingProcessing();

  @override
  bool operator ==(Object other) => other is RecordingProcessing;

  @override
  int get hashCode => runtimeType.hashCode;
}

final class RecordingSaved extends RecordingState {
  RecordingSaved({required int entryId, this.detectedLanguage})
    : entryId = _validateEntryId(entryId);

  final int entryId;
  final String? detectedLanguage;

  static int _validateEntryId(int entryId) {
    if (entryId <= 0) {
      throw ArgumentError.value(entryId, 'entryId', 'must be positive');
    }
    return entryId;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is RecordingSaved &&
            other.entryId == entryId &&
            other.detectedLanguage == detectedLanguage;
  }

  @override
  int get hashCode => Object.hash(entryId, detectedLanguage);
}

final class RecordingErrorState extends RecordingState {
  const RecordingErrorState(this.error);

  final RecordingError error;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is RecordingErrorState && other.error == error;
  }

  @override
  int get hashCode => error.hashCode;
}

final class RecordingDeleted extends RecordingState {
  const RecordingDeleted(this.count);

  final int count;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is RecordingDeleted && other.count == count;
  }

  @override
  int get hashCode => count.hashCode;
}

enum RecordingError {
  tooShort,
  noMatch,
  insufficientPermissions,
  noInternet,
  backendUnavailable,
  proxyAuthFailed,
  apiFailed,
}
