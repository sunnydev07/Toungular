import 'package:flutter_test/flutter_test.dart';
import 'package:toungular/core/config/app_environment.dart';

void main() {
  group('resolveApiBaseUrl', () {
    test('development builds keep the emulator loopback default', () {
      expect(
        AppEnvironment.resolveApiBaseUrl(configured: '', release: false),
        'http://10.0.2.2:3000',
      );
      expect(
        AppEnvironment.resolveApiBaseUrl(
          configured: 'http://192.168.1.20:3000',
          release: false,
        ),
        'http://192.168.1.20:3000',
      );
    });

    test('release builds refuse to fall back to the emulator default', () {
      expect(
        () => AppEnvironment.resolveApiBaseUrl(configured: '', release: true),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('API_BASE_URL'),
          ),
        ),
      );
    });

    test('release builds reject cleartext URLs', () {
      expect(
        () => AppEnvironment.resolveApiBaseUrl(
          configured: 'http://10.0.2.2:3000',
          release: true,
        ),
        throwsStateError,
      );
    });

    test('release builds accept an HTTPS URL', () {
      expect(
        AppEnvironment.resolveApiBaseUrl(
          configured: 'https://api.toungular.app',
          release: true,
        ),
        'https://api.toungular.app',
      );
    });
  });
}
