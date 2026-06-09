import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../preferences/preferences_providers.dart';
import 'backend_client.dart';
import 'generated/backend_api_generated.dart';

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
