import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wrait/data/api/backend_client.dart';
import 'package:wrait/data/api/backend_results.dart';
import 'package:wrait/data/api/generated/backend_api_generated.dart';
import 'package:wrait/domain/repository/preferences_repository.dart';

void main() {
  group('WraitBackendClient', () {
    late _FakePreferencesRepository preferencesRepository;
    late _FakeGeneratedBackendApiClient generatedClient;
    late List<Duration> delayCalls;
    late WraitBackendClient backendClient;

    setUp(() {
      preferencesRepository = _FakePreferencesRepository();
      generatedClient = _FakeGeneratedBackendApiClient();
      delayCalls = <Duration>[];
      backendClient = WraitBackendClient(
        generatedClient: generatedClient,
        preferencesRepository: preferencesRepository,
        delay: (duration) async => delayCalls.add(duration),
      );
    });

    test(
      'register retries transient server failures and then succeeds',
      () async {
        generatedClient.registerResponses.addAll(<Object>[
          const GeneratedApiFailure<RegisterResponse>(
            statusCode: 500,
            data: <String, dynamic>{'error': 'server exploded'},
          ),
          const GeneratedApiFailure<RegisterResponse>(
            statusCode: 502,
            data: <String, dynamic>{'error': 'upstream exploded'},
          ),
          GeneratedApiSuccess<RegisterResponse>(
            statusCode: 201,
            data: RegisterResponse(
              ok: true,
              quota: RecordQuota(
                limit: 5,
                count: 1,
                remaining: 4,
                resetAt: DateTime.utc(2026, 6, 10),
              ),
            ),
          ),
        ]);

        final result = await backendClient.register();

        expect(result, isA<RegistrationSuccess>());
        expect(generatedClient.registerCallCount, 3);
        expect(delayCalls, <Duration>[
          const Duration(seconds: 1),
          const Duration(seconds: 2),
        ]);
        expect((result as RegistrationSuccess).quota?.remaining, 4);
      },
    );

    test('register stops after max transient attempts', () async {
      generatedClient.registerResponses.addAll(
        List<Object>.filled(
          3,
          const GeneratedApiFailure<RegisterResponse>(
            statusCode: 500,
            data: <String, dynamic>{'error': 'still broken'},
          ),
        ),
      );

      final result = await backendClient.register();

      expect(
        result,
        isA<RegistrationFailure>().having(
          (value) => value.reason,
          'reason',
          RegistrationFailureReason.transient,
        ),
      );
      expect(generatedClient.registerCallCount, 3);
      expect(delayCalls, <Duration>[
        const Duration(seconds: 1),
        const Duration(seconds: 2),
      ]);
    });

    test('register does not retry non transient 4xx failures', () async {
      generatedClient.registerResponses.add(
        const GeneratedApiFailure<RegisterResponse>(
          statusCode: 400,
          data: <String, dynamic>{'error': 'bad request'},
        ),
      );

      final result = await backendClient.register();

      expect(
        result,
        isA<RegistrationFailure>().having(
          (value) => value.reason,
          'reason',
          RegistrationFailureReason.apiError,
        ),
      );
      expect(generatedClient.registerCallCount, 1);
      expect(delayCalls, isEmpty);
    });

    test('register maps 401 to proxy auth failure without retrying', () async {
      generatedClient.registerResponses.add(
        const GeneratedApiFailure<RegisterResponse>(
          statusCode: 401,
          data: <String, dynamic>{'error': 'unauthorized'},
        ),
      );

      final result = await backendClient.register();

      expect(
        result,
        isA<RegistrationFailure>().having(
          (value) => value.reason,
          'reason',
          RegistrationFailureReason.proxyAuthFailed,
        ),
      );
      expect(generatedClient.registerCallCount, 1);
    });

    test('transcription maps 401 to proxy auth failure', () async {
      generatedClient.transcribeResponses.add(
        const GeneratedApiFailure<TranscribeResponse>(
          statusCode: 401,
          data: <String, dynamic>{'error': 'unauthorized'},
        ),
      );

      final result = await backendClient.transcribeAudio(
        await _createTempAudioFile('auth'),
      );

      expect(
        result,
        isA<TranscriptionFailure>().having(
          (value) => value.reason,
          'reason',
          BackendFailureReason.proxyAuthFailed,
        ),
      );
    });

    test('cleanup maps 401 to proxy auth failure', () async {
      generatedClient.cleanupResponses.add(
        const GeneratedApiFailure<CleanupResponse>(
          statusCode: 401,
          data: <String, dynamic>{'error': 'unauthorized'},
        ),
      );

      final result = await backendClient.cleanupTranscript(
        transcript: 'hello there diary',
        language: 'en-US',
      );

      expect(
        result,
        isA<CleanupFailure>().having(
          (value) => value.reason,
          'reason',
          BackendFailureReason.proxyAuthFailed,
        ),
      );
    });

    test('transcription and cleanup map 5xx to backend unavailable', () async {
      generatedClient.transcribeResponses.add(
        const GeneratedApiFailure<TranscribeResponse>(
          statusCode: 503,
          data: <String, dynamic>{'error': 'unavailable'},
        ),
      );
      generatedClient.cleanupResponses.add(
        const GeneratedApiFailure<CleanupResponse>(
          statusCode: 500,
          data: <String, dynamic>{'error': 'oops'},
        ),
      );

      final transcription = await backendClient.transcribeAudio(
        await _createTempAudioFile('503'),
      );
      final cleanup = await backendClient.cleanupTranscript(
        transcript: 'hello there diary',
        language: 'en-US',
      );

      expect(
        transcription,
        isA<TranscriptionFailure>().having(
          (value) => value.reason,
          'reason',
          BackendFailureReason.backendUnavailable,
        ),
      );
      expect(
        cleanup,
        isA<CleanupFailure>().having(
          (value) => value.reason,
          'reason',
          BackendFailureReason.backendUnavailable,
        ),
      );
    });

    test('transcription maps 413 to request too large', () async {
      generatedClient.transcribeResponses.add(
        const GeneratedApiFailure<TranscribeResponse>(
          statusCode: 413,
          data: <String, dynamic>{'error': 'too large'},
        ),
      );

      final result = await backendClient.transcribeAudio(
        await _createTempAudioFile('413'),
      );

      expect(
        result,
        isA<TranscriptionFailure>().having(
          (value) => value.reason,
          'reason',
          BackendFailureReason.requestTooLarge,
        ),
      );
    });

    test('cleanup maps 413 to request too large', () async {
      generatedClient.cleanupResponses.add(
        const GeneratedApiFailure<CleanupResponse>(
          statusCode: 413,
          data: <String, dynamic>{'error': 'too large'},
        ),
      );

      final result = await backendClient.cleanupTranscript(
        transcript: 'hello there diary',
        language: 'en-US',
      );

      expect(
        result,
        isA<CleanupFailure>().having(
          (value) => value.reason,
          'reason',
          BackendFailureReason.requestTooLarge,
        ),
      );
    });

    test(
      'transcription maps 502 and cleanup maps 504 to backend unavailable',
      () async {
        generatedClient.transcribeResponses.add(
          const GeneratedApiFailure<TranscribeResponse>(
            statusCode: 502,
            data: <String, dynamic>{'error': 'upstream exploded'},
          ),
        );
        generatedClient.cleanupResponses.add(
          const GeneratedApiFailure<CleanupResponse>(
            statusCode: 504,
            data: <String, dynamic>{'error': 'upstream timeout'},
          ),
        );

        final transcription = await backendClient.transcribeAudio(
          await _createTempAudioFile('upstream'),
        );
        final cleanup = await backendClient.cleanupTranscript(
          transcript: 'hello there diary',
          language: 'en-US',
        );

        expect(
          transcription,
          isA<TranscriptionFailure>().having(
            (value) => value.reason,
            'reason',
            BackendFailureReason.backendUnavailable,
          ),
        );
        expect(
          cleanup,
          isA<CleanupFailure>().having(
            (value) => value.reason,
            'reason',
            BackendFailureReason.backendUnavailable,
          ),
        );
      },
    );

    test('connection errors map to no internet', () async {
      generatedClient.transcribeResponses.add(
        DioException(
          requestOptions: RequestOptions(path: '/api/transcribe'),
          type: DioExceptionType.connectionError,
          error: const SocketException('offline'),
        ),
      );
      generatedClient.cleanupResponses.add(
        DioException(
          requestOptions: RequestOptions(path: '/api/cleanup'),
          type: DioExceptionType.connectionError,
          error: const SocketException('offline'),
        ),
      );

      final transcription = await backendClient.transcribeAudio(
        await _createTempAudioFile('offline'),
      );
      final cleanup = await backendClient.cleanupTranscript(
        transcript: 'hello there diary',
        language: 'en-US',
      );

      expect(
        transcription,
        isA<TranscriptionFailure>().having(
          (value) => value.reason,
          'reason',
          BackendFailureReason.noInternet,
        ),
      );
      expect(
        cleanup,
        isA<CleanupFailure>().having(
          (value) => value.reason,
          'reason',
          BackendFailureReason.noInternet,
        ),
      );
    });

    test('timeout errors map to timeout specific failures', () async {
      generatedClient.transcribeResponses.add(
        DioException(
          requestOptions: RequestOptions(path: '/api/transcribe'),
          type: DioExceptionType.receiveTimeout,
        ),
      );
      generatedClient.cleanupResponses.add(
        DioException(
          requestOptions: RequestOptions(path: '/api/cleanup'),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      final transcription = await backendClient.transcribeAudio(
        await _createTempAudioFile('timeout'),
      );
      final cleanup = await backendClient.cleanupTranscript(
        transcript: 'hello there diary',
        language: 'en-US',
      );

      expect(
        transcription,
        isA<TranscriptionFailure>().having(
          (value) => value.reason,
          'reason',
          BackendFailureReason.timeout,
        ),
      );
      expect(
        cleanup,
        isA<CleanupFailure>().having(
          (value) => value.reason,
          'reason',
          BackendFailureReason.timeout,
        ),
      );
    });

    test('429 maps to quota exceeded and surfaces valid quota', () async {
      generatedClient.transcribeResponses.add(
        const GeneratedApiFailure<TranscribeResponse>(
          statusCode: 429,
          data: <String, dynamic>{
            'error': 'Daily record limit exceeded',
            'quota': <String, dynamic>{
              'limit': 5,
              'count': 5,
              'remaining': 0,
              'resetAt': '2026-06-10T00:00:00Z',
            },
          },
        ),
      );

      final result = await backendClient.transcribeAudio(
        await _createTempAudioFile('quota'),
      );

      expect(
        result,
        isA<TranscriptionFailure>().having(
          (value) => value.reason,
          'reason',
          BackendFailureReason.quotaExceeded,
        ),
      );
      expect((result as TranscriptionFailure).quota?.remaining, 0);
    });

    test(
      'blank transcript is preserved as a success payload for caller classification',
      () async {
        generatedClient.transcribeResponses.add(
          const GeneratedApiSuccess<TranscribeResponse>(
            statusCode: 200,
            data: TranscribeResponse(
              transcript: '   ',
              detectedLanguage: 'en-US',
            ),
          ),
        );

        final result = await backendClient.transcribeAudio(
          await _createTempAudioFile('blank-transcript'),
        );

        expect(
          result,
          isA<TranscriptionSuccess>()
              .having((value) => value.transcript, 'transcript', '')
              .having(
                (value) => value.detectedLanguage,
                'detectedLanguage',
                'en-US',
              ),
        );
      },
    );

    test('blank detected language is allowed as nullable success', () async {
      generatedClient.transcribeResponses.add(
        const GeneratedApiSuccess<TranscribeResponse>(
          statusCode: 200,
          data: TranscribeResponse(
            transcript: 'usable transcript',
            detectedLanguage: '   ',
          ),
        ),
      );

      final result = await backendClient.transcribeAudio(
        await _createTempAudioFile('blank-language'),
      );

      expect(
        result,
        isA<TranscriptionSuccess>()
            .having(
              (value) => value.transcript,
              'transcript',
              'usable transcript',
            )
            .having(
              (value) => value.detectedLanguage,
              'detectedLanguage',
              isNull,
            ),
      );
    });

    test('blank cleaned text is treated as api error failure', () async {
      final quota = RecordQuota(
        limit: 5,
        count: 4,
        remaining: 1,
        resetAt: DateTime.utc(2026, 6, 10),
      );
      generatedClient.cleanupResponses.add(
        GeneratedApiSuccess<CleanupResponse>(
          statusCode: 200,
          data: CleanupResponse(
            cleanedText: '   ',
            wasTruncated: false,
            quota: quota,
          ),
        ),
      );

      final result = await backendClient.cleanupTranscript(
        transcript: 'hello there diary',
        language: 'en-US',
      );

      expect(
        result,
        isA<CleanupFailure>().having(
          (value) => value.reason,
          'reason',
          BackendFailureReason.apiError,
        ),
      );
      expect((result as CleanupFailure).quota?.remaining, 1);
    });

    test(
      'register sends device and proxy headers through the generated client',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));

        final requestSeen = Completer<HttpHeaders>();
        unawaited(() async {
          final request = await server.first;
          requestSeen.complete(request.headers);
          request.response
            ..statusCode = 201
            ..headers.contentType = ContentType.json
            ..write('{"ok":true}');
          await request.response.close();
        }());

        final realClient = WraitBackendClient(
          generatedClient: DioGeneratedBackendApiClient(
            Dio(
              BaseOptions(
                baseUrl: 'http://${server.address.host}:${server.port}',
                headers: <String, dynamic>{'X-Proxy-Secret': 'proxy-secret'},
              ),
            ),
          ),
          preferencesRepository: preferencesRepository,
        );

        final result = await realClient.register();

        expect(result, isA<RegistrationSuccess>());
        final headers = await requestSeen.future;
        expect(headers.value('X-Device-Id'), preferencesRepository.deviceId);
        expect(headers.value('X-Proxy-Secret'), 'proxy-secret');
      },
    );
  });
}

class _FakeGeneratedBackendApiClient implements GeneratedBackendApiClient {
  final List<Object> registerResponses = <Object>[];
  final List<Object> transcribeResponses = <Object>[];
  final List<Object> cleanupResponses = <Object>[];

  int registerCallCount = 0;

  @override
  Future<GeneratedApiResponse<CleanupResponse>> cleanupTranscript({
    required String xDeviceId,
    required CleanupRequest cleanupRequest,
  }) async {
    return _takeNext<GeneratedApiResponse<CleanupResponse>>(cleanupResponses);
  }

  @override
  Future<GeneratedApiResponse<RegisterResponse>> registerDevice({
    required String xDeviceId,
  }) async {
    registerCallCount += 1;
    return _takeNext<GeneratedApiResponse<RegisterResponse>>(registerResponses);
  }

  @override
  Future<GeneratedApiResponse<TranscribeResponse>> transcribeAudio({
    required String xDeviceId,
    required List<int> audioBytes,
    required String audioFilename,
  }) async {
    return _takeNext<GeneratedApiResponse<TranscribeResponse>>(
      transcribeResponses,
    );
  }

  Future<T> _takeNext<T>(List<Object> values) async {
    if (values.isEmpty) {
      throw StateError('No queued response left for fake generated client.');
    }

    final next = values.removeAt(0);
    if (next is DioException) {
      throw next;
    }

    return next as T;
  }
}

class _FakePreferencesRepository implements PreferencesRepository {
  final String deviceId =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

  @override
  Future<String> getDeviceId() async => deviceId;

  @override
  Future<bool> getHasEverRecorded() async => false;

  @override
  Future<void> setHasEverRecorded(bool value) async {}
}

Future<File> _createTempAudioFile(String name) async {
  final directory = await Directory.systemTemp.createTemp('wrait-backend-test');
  final file = File('${directory.path}/$name.m4a');
  await file.writeAsString('audio-data-$name');
  return file;
}
