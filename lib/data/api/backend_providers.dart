import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../domain/usecase/register_device_on_launch_use_case.dart';
import '../preferences/preferences_providers.dart';
import 'backend_client.dart';
import 'generated/backend_api_generated.dart';
import 'record_quota_state.dart';

const backendConnectTimeout = Duration(seconds: 15);
const backendSendTimeout = Duration(seconds: 60);
const backendReceiveTimeout = Duration(seconds: 60);

final backendDioProvider = Provider<Dio>((ref) {
  final appConfig = ref.watch(appConfigProvider);

  return Dio(
    BaseOptions(
      baseUrl: appConfig.backendUrl,
      headers: <String, dynamic>{'X-Proxy-Secret': appConfig.proxySecret},
      connectTimeout: backendConnectTimeout,
      sendTimeout: backendSendTimeout,
      receiveTimeout: backendReceiveTimeout,
    ),
  );
});

final generatedBackendApiClientProvider = Provider<GeneratedBackendApiClient>((
  ref,
) {
  return DioGeneratedBackendApiClient(ref.watch(backendDioProvider));
});

final wraitBackendClientProvider = Provider<WraitBackendClient>((ref) {
  return WraitBackendClient(
    generatedClient: ref.watch(generatedBackendApiClientProvider),
    preferencesRepository: ref.watch(preferencesRepositoryProvider),
  );
});

class RegistrationQuotaStateNotifier extends Notifier<RecordQuotaState?> {
  @override
  RecordQuotaState? build() => null;

  void setQuota(RecordQuotaState quota) {
    state = quota;
  }
}

final registrationQuotaStateProvider =
    NotifierProvider<RegistrationQuotaStateNotifier, RecordQuotaState?>(
      RegistrationQuotaStateNotifier.new,
    );

final registrationWarningLoggerProvider = Provider<RegistrationWarningLogger>((
  ref,
) {
  return (message, {error, stackTrace}) {
    developer.log(
      message,
      name: 'DeviceRegistration',
      error: error,
      stackTrace: stackTrace,
    );
  };
});

final registerDeviceOnLaunchUseCaseProvider =
    Provider<RegisterDeviceOnLaunchUseCase>((ref) {
      return RegisterDeviceOnLaunchUseCase(
        registerDevice: ref.watch(wraitBackendClientProvider).register,
        setRecordQuota: (quota) {
          ref.read(registrationQuotaStateProvider.notifier).setQuota(quota);
        },
        logWarning: ref.watch(registrationWarningLoggerProvider),
      );
    });
