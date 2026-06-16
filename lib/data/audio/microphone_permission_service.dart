import 'package:permission_handler/permission_handler.dart';

enum MicrophoneAccessState { granted, denied, permanentlyDenied, restricted }

abstract interface class MicrophonePermissionService {
  Future<MicrophoneAccessState> ensureMicrophoneAccess();
}

class PermissionHandlerMicrophonePermissionService
    implements MicrophonePermissionService {
  @override
  Future<MicrophoneAccessState> ensureMicrophoneAccess() async {
    final currentState = _resolveState(await Permission.microphone.status);
    if (currentState
        case MicrophoneAccessState.granted ||
            MicrophoneAccessState.permanentlyDenied ||
            MicrophoneAccessState.restricted) {
      return currentState;
    }

    return _resolveState(await Permission.microphone.request());
  }
}

MicrophoneAccessState _resolveState(PermissionStatus status) {
  return switch (status) {
    PermissionStatus.granted ||
    PermissionStatus.limited ||
    PermissionStatus.provisional => MicrophoneAccessState.granted,
    PermissionStatus.permanentlyDenied =>
      MicrophoneAccessState.permanentlyDenied,
    PermissionStatus.restricted => MicrophoneAccessState.restricted,
    PermissionStatus.denied => MicrophoneAccessState.denied,
  };
}
