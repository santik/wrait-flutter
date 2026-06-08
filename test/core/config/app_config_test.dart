import 'package:flutter_test/flutter_test.dart';
import 'package:wrait/core/config/app_config.dart';

void main() {
  group('AppConfig', () {
    test('uses defaults when values are omitted', () {
      final config = AppConfig.fromValues();

      expect(config.backendUrl, AppConfig.defaultBackendUrl);
      expect(config.proxySecret, isEmpty);
      expect(
        config.recordingHardCapMs,
        int.parse(AppConfig.defaultRecordingHardCapMs),
      );
    });

    test('applies explicit override values', () {
      final config = AppConfig.fromValues(
        backendUrl: 'https://example.com/api',
        proxySecret: 'proxy-secret',
        recordingHardCapMs: '60000',
      );

      expect(config.backendUrl, 'https://example.com/api');
      expect(config.backendUri.host, 'example.com');
      expect(config.proxySecret, 'proxy-secret');
      expect(config.recordingHardCapMs, 60000);
    });

    test('rejects a non-positive recording hard cap', () {
      expect(
        () => AppConfig.fromValues(recordingHardCapMs: '0'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => AppConfig.fromValues(recordingHardCapMs: '-1'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
