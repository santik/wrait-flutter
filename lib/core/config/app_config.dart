class AppConfig {
  static const String backendUrlDefine = 'BACKEND_URL';
  static const String proxySecretDefine = 'PROXY_SECRET';
  static const String recordingHardCapMsDefine = 'RECORDING_HARD_CAP_MS';

  static const String defaultBackendUrl = 'https://wrait-backend.vercel.app';
  static const String defaultRecordingHardCapMs = '120000';

  const AppConfig({
    required this.backendUrl,
    required this.proxySecret,
    required this.recordingHardCapMs,
  });

  final String backendUrl;
  final String proxySecret;
  final int recordingHardCapMs;

  Uri get backendUri => Uri.parse(backendUrl);

  factory AppConfig.fromEnvironment() {
    return AppConfig.fromValues(
      backendUrl: const String.fromEnvironment(
        backendUrlDefine,
        defaultValue: defaultBackendUrl,
      ),
      proxySecret: const String.fromEnvironment(
        proxySecretDefine,
        defaultValue: '',
      ),
      recordingHardCapMs: const String.fromEnvironment(
        recordingHardCapMsDefine,
        defaultValue: defaultRecordingHardCapMs,
      ),
    );
  }

  factory AppConfig.fromValues({
    String? backendUrl,
    String? proxySecret,
    String? recordingHardCapMs,
  }) {
    final resolvedBackendUrl = (backendUrl ?? defaultBackendUrl).trim();
    final resolvedProxySecret = (proxySecret ?? '').trim();
    final resolvedHardCapRaw = (recordingHardCapMs ?? defaultRecordingHardCapMs)
        .trim();

    final parsedBackendUri = Uri.tryParse(resolvedBackendUrl);
    if (parsedBackendUri == null ||
        !parsedBackendUri.hasScheme ||
        parsedBackendUri.host.isEmpty) {
      throw FormatException(
        'Invalid $backendUrlDefine value: "$resolvedBackendUrl". Expected an absolute URL.',
      );
    }

    final parsedHardCap = int.tryParse(resolvedHardCapRaw);
    if (parsedHardCap == null || parsedHardCap <= 0) {
      throw FormatException(
        'Invalid $recordingHardCapMsDefine value: "$resolvedHardCapRaw". Expected a positive integer.',
      );
    }

    return AppConfig(
      backendUrl: parsedBackendUri.toString(),
      proxySecret: resolvedProxySecret,
      recordingHardCapMs: parsedHardCap,
    );
  }
}
