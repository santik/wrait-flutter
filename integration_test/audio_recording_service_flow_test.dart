import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wrait/app.dart';
import 'package:wrait/core/config/app_config.dart';
import 'package:wrait/data/audio/audio_recording_providers.dart';
import 'package:wrait/data/audio/audio_recording_service.dart';
import 'package:wrait/data/audio/record_audio_recording_service.dart';

import '../test/test_doubles/fake_monotonic_clock.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'provider graph supports start and valid stop with a completed file path',
    (tester) async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'wrait-audio-int',
      );
      addTearDown(() async {
        if (await tempDirectory.exists()) {
          await tempDirectory.delete(recursive: true);
        }
      });

      final monotonicClock = FakeMonotonicClock(1000);
      final recorder = _FakeRecorderAdapter();
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig.fromValues(recordingHardCapMs: '120000'),
          ),
          monotonicClockProvider.overrideWithValue(monotonicClock),
          recorderAdapterProvider.overrideWithValue(recorder),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(audioRecordingServiceProvider);
      final path = '${tempDirectory.path}/valid-flow.m4a';

      await service.startRecording(path);

      expect(service.isRecording, isTrue);
      expect(service.hardCapDeadlineElapsedRealtime, 121000);

      monotonicClock.advance(const Duration(seconds: 6));
      final returnedPath = await service.stopRecording();

      expect(returnedPath, path);
      expect(service.isRecording, isFalse);
      expect(await File(path).exists(), isTrue);
    },
  );

  testWidgets(
    'an orchestrator can stop the recording at the hard cap using the exposed deadline',
    (tester) async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'wrait-audio-int-cap',
      );
      addTearDown(() async {
        if (await tempDirectory.exists()) {
          await tempDirectory.delete(recursive: true);
        }
      });

      final monotonicClock = FakeMonotonicClock(2000);
      final recorder = _FakeRecorderAdapter();
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig.fromValues(recordingHardCapMs: '5000'),
          ),
          monotonicClockProvider.overrideWithValue(monotonicClock),
          recorderAdapterProvider.overrideWithValue(recorder),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(audioRecordingServiceProvider);
      final path = '${tempDirectory.path}/cap-stop.m4a';

      await service.startRecording(path);

      final stoppedPath = await _stopAtHardCap(
        service: service,
        monotonicClock: monotonicClock,
      );

      expect(stoppedPath, path);
      expect(await File(path).exists(), isTrue);
      expect(service.isRecording, isFalse);
    },
  );

  testWidgets(
    'provider graph rejects a too-short recording and does not keep the file',
    (tester) async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'wrait-audio-int-short',
      );
      addTearDown(() async {
        if (await tempDirectory.exists()) {
          await tempDirectory.delete(recursive: true);
        }
      });

      final monotonicClock = FakeMonotonicClock(3000);
      final recorder = _FakeRecorderAdapter();
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig.fromValues(recordingHardCapMs: '120000'),
          ),
          monotonicClockProvider.overrideWithValue(monotonicClock),
          recorderAdapterProvider.overrideWithValue(recorder),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(audioRecordingServiceProvider);
      final path = '${tempDirectory.path}/too-short.m4a';

      await service.startRecording(path);
      monotonicClock.advance(const Duration(seconds: 4));

      await expectLater(
        service.stopRecording(),
        throwsA(isA<RecordingTooShortFailure>()),
      );

      expect(await File(path).exists(), isFalse);
      expect(service.isRecording, isFalse);
    },
  );
}

Future<String> _stopAtHardCap({
  required AudioRecordingService service,
  required FakeMonotonicClock monotonicClock,
}) async {
  final deadline = service.hardCapDeadlineElapsedRealtime;
  expect(deadline, isNotNull);

  while (monotonicClock.now() < deadline!) {
    monotonicClock.advance(const Duration(milliseconds: 250));
    await Future<void>.delayed(Duration.zero);
  }

  return service.stopRecording();
}

class _FakeRecorderAdapter implements RecorderAdapter {
  String? _lastPath;

  @override
  Future<void> start({required config, required String path}) async {
    _lastPath = path;
  }

  @override
  Future<String?> stop() async {
    final path = _lastPath;
    if (path == null) {
      return null;
    }

    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(const <int>[5, 6, 7, 8]);
    _lastPath = null;
    return path;
  }

  @override
  Future<void> cancel() async {
    _lastPath = null;
  }

  @override
  Future<void> dispose() async {}
}
