import '../../data/api/backend_results.dart';
import '../../data/api/record_quota_state.dart';

typedef RegisterDeviceCallback = Future<RegistrationResult> Function();
typedef SetRecordQuotaCallback = void Function(RecordQuotaState quota);
typedef RegistrationWarningLogger =
    void Function(String message, {Object? error, StackTrace? stackTrace});

class RegisterDeviceOnLaunchUseCase {
  RegisterDeviceOnLaunchUseCase({
    required this.registerDevice,
    required this.setRecordQuota,
    required this.logWarning,
  });

  final RegisterDeviceCallback registerDevice;
  final SetRecordQuotaCallback setRecordQuota;
  final RegistrationWarningLogger logWarning;

  Future<void> call() async {
    try {
      final result = await registerDevice();
      switch (result) {
        case RegistrationSuccess(quota: final quota?):
          setRecordQuota(quota);
        case RegistrationSuccess():
          return;
        case RegistrationFailure(reason: final reason):
          logWarning('Device registration failed during app launch: $reason');
      }
    } catch (error, stackTrace) {
      logWarning(
        'Device registration crashed during app launch.',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
