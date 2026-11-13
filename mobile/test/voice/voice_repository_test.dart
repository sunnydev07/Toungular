import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toungular/core/network/api_client.dart';
import 'package:toungular/core/network/session_manager.dart';
import 'package:toungular/core/storage/session_store.dart';
import 'package:toungular/core/voice/voice_repository.dart';
import 'package:toungular/shared/models/learning_models.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.onFetch);

  final void Function(RequestOptions options) onFetch;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    onFetch(options);
    return ResponseBody.fromBytes(
      <int>[1, 2, 3],
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['audio/mpeg'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _NoOpSessionStore extends SessionStore {
  @override
  Future<void> clearSession() async {}

  @override
  Future<String?> readAccessToken() async => null;

  @override
  Future<LearnerSession?> readSession() async => null;

  @override
  Future<void> writeSession(LearnerSession value) async {}
}

void main() {
  late Directory tempDir;
  late VoiceRepository repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('voice_repo_test_');
    repository = VoiceRepository(
      ApiClient(SessionManager(_NoOpSessionStore())),
      cacheDirectory: tempDir,
      maxCacheFiles: 2,
      maxCacheBytes: 1000,
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('synthesizeToFile forwards provider, voiceId, and speed in the body', () async {
    Map<String, Object?>? sent;
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000'));
    dio.httpClientAdapter = _FakeAdapter((options) {
      sent = (options.data as Map).cast<String, Object?>();
    });
    final cached = VoiceRepository(
      ApiClient(SessionManager(_NoOpSessionStore()), dio: dio),
      cacheDirectory: tempDir,
    );

    final path = await cached.synthesizeToFile(
      'Hello there',
      provider: 'google',
      voiceId: 'voice-1',
      speed: 1.2,
    );

    expect(File(path).existsSync(), isTrue);
    expect(sent?['text'], 'Hello there');
    expect(sent?['provider'], 'google');
    expect(sent?['voiceId'], 'voice-1');
    expect(sent?['speed'], 1.2);
  });

  test('pruneCache removes oldest files when count exceeds maxCacheFiles', () async {
    final file1 = File('${tempDir.path}${Platform.pathSeparator}toungular-voice-1.mp3');
    final file2 = File('${tempDir.path}${Platform.pathSeparator}toungular-voice-2.mp3');
    final file3 = File('${tempDir.path}${Platform.pathSeparator}toungular-voice-3.mp3');

    await file1.writeAsBytes([1, 2, 3]);
    await file1.setLastModified(DateTime.now().subtract(const Duration(minutes: 10)));

    await file2.writeAsBytes([4, 5, 6]);
    await file2.setLastModified(DateTime.now().subtract(const Duration(minutes: 5)));

    await file3.writeAsBytes([7, 8, 9]);
    await file3.setLastModified(DateTime.now());

    await repository.pruneCache();

    expect(await file1.exists(), isFalse, reason: 'Oldest file should have been pruned');
    expect(await file2.exists(), isTrue);
    expect(await file3.exists(), isTrue);
  });

  test('pruneCache ignores non-TTS files', () async {
    final otherFile = File('${tempDir.path}${Platform.pathSeparator}other_recording.m4a');
    await otherFile.writeAsBytes(List.filled(500, 0));

    final file1 = File('${tempDir.path}${Platform.pathSeparator}toungular-voice-1.mp3');
    await file1.writeAsBytes([1, 2, 3]);

    await repository.pruneCache();

    expect(await otherFile.exists(), isTrue);
    expect(await file1.exists(), isTrue);
  });

  test('pruneCache removes oldest files when bytes exceed maxCacheBytes', () async {
    final customRepo = VoiceRepository(
      ApiClient(SessionManager(_NoOpSessionStore())),
      cacheDirectory: tempDir,
      maxCacheFiles: 10,
      maxCacheBytes: 100, // Small byte limit
    );

    final file1 = File('${tempDir.path}${Platform.pathSeparator}toungular-voice-1.mp3');
    final file2 = File('${tempDir.path}${Platform.pathSeparator}toungular-voice-2.mp3');

    await file1.writeAsBytes(List.filled(80, 1));
    await file1.setLastModified(DateTime.now().subtract(const Duration(minutes: 5)));

    await file2.writeAsBytes(List.filled(80, 2));
    await file2.setLastModified(DateTime.now());

    await customRepo.pruneCache();

    // 80 + 80 = 160 > 100. Oldest file1 should be deleted, leaving file2 (80 bytes <= 100).
    expect(await file1.exists(), isFalse);
    expect(await file2.exists(), isTrue);
  });
}
