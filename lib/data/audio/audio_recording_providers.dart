import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../core/time/monotonic_clock.dart';
import 'audio_recording_service.dart';
import 'record_audio_recording_service.dart';

final monotonicClockProvider = Provider<MonotonicClock>(
  (ref) => StopwatchMonotonicClock(),
);

final recorderAdapterProvider = Provider<RecorderAdapter>(
  (ref) => AudioRecorderAdapter(),
);

final audioRecordingServiceProvider = Provider<AudioRecordingService>((ref) {
  final service = RecordAudioRecordingService(
    recorder: ref.watch(recorderAdapterProvider),
    monotonicClock: ref.watch(monotonicClockProvider),
    hardCap: Duration(
      milliseconds: ref.watch(appConfigProvider).recordingHardCapMs,
    ),
  );

  ref.onDispose(() {
    unawaited(service.dispose());
  });

  return service;
});
