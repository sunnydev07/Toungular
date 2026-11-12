import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toungular/core/network/api_client.dart';
import 'package:toungular/core/storage/session_store.dart';
import 'package:toungular/features/vocabulary/vocabulary_repository.dart';
import 'package:toungular/shared/models/learning_models.dart';

class _FakeSessionStore extends SessionStore {
  _FakeSessionStore(this._session);

  final LearnerSession? _session;

  @override
  Future<LearnerSession?> readSession() async => _session;

  @override
  Future<String?> readAccessToken() async => _session?.accessToken;

  @override
  Future<void> clearSession() async {}

  @override
  Future<void> writeSession(LearnerSession value) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final session = LearnerSession.fromJson(<String, Object?>{
    'userId': 'user-test',
    'email': 'learner@test.com',
    'accessToken': 'token-1',
    'refreshToken': 'refresh-1',
  });

  test('submitReview enqueues action and does not crash when queue key has invalid JSON', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'toungular.vocab-actions.v1.user-test': 'broken-json{{{',
    });

    final dio = Dio(BaseOptions(baseUrl: 'http://toungular.test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.connectionError,
              error: 'No internet',
            ),
          );
        },
      ),
    );

    final api = ApiClient(_FakeSessionStore(session), dio: dio);
    final repo = VocabularyRepository(api, _FakeSessionStore(session));

    // When network fails, it enqueues to the queue without crashing despite existing corrupted JSON
    await repo.submitReview('item-123', 'good');

    final prefs = await SharedPreferences.getInstance();
    final queued = prefs.getString('toungular.vocab-actions.v1.user-test');
    expect(queued, isNotNull);
    expect(queued, contains('item-123'));
  });

  test('flushPending drops action after exceeding maxRetryCount', () async {
    // Queued action already at maxRetryCount - 1 (2 retries). Next failure reaches 3 and is dropped.
    SharedPreferences.setMockInitialValues(<String, Object>{
      'toungular.vocab-actions.v1.user-test':
          '[{"itemId":"item-drop","grade":"good","retryCount":2}]',
    });

    final dio = Dio(BaseOptions(baseUrl: 'http://toungular.test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.connectionError,
              error: 'Network failure',
            ),
          );
        },
      ),
    );

    final api = ApiClient(_FakeSessionStore(session), dio: dio);
    final repo = VocabularyRepository(api, _FakeSessionStore(session));

    // Calling submitReview attempts to flushPending first
    await repo.submitReview('new-item', 'easy');

    final prefs = await SharedPreferences.getInstance();
    final queued = prefs.getString('toungular.vocab-actions.v1.user-test');
    expect(queued, isNotNull);
    // item-drop reached max retries (3) and was dropped
    expect(queued, isNot(contains('item-drop')));
    // new-item was newly enqueued
    expect(queued, contains('new-item'));
  });
}
