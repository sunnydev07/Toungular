import 'package:flutter/foundation.dart';

/// Compile-time configuration for the Toungular API.
abstract final class AppEnvironment {
  static const String _configuredApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
  );

  /// The emulator loopback URL is a development default only. Release builds
  /// must be given an HTTPS API URL: Android blocks cleartext traffic there, so
  /// an unconfigured release could never reach any server.
  static String get apiBaseUrl => resolveApiBaseUrl(
    configured: _configuredApiBaseUrl,
    release: kReleaseMode,
  );

  @visibleForTesting
  static String resolveApiBaseUrl({
    required String configured,
    required bool release,
  }) {
    if (!release) {
      return configured.isEmpty ? 'http://10.0.2.2:3000' : configured;
    }
    if (configured.isEmpty) {
      throw StateError(
        'This release build has no API_BASE_URL. Rebuild with '
        '--dart-define=API_BASE_URL=https://<your-toungular-api>.',
      );
    }
    if (!configured.startsWith('https://')) {
      throw StateError(
        'Release builds require an HTTPS API_BASE_URL and this build uses '
        '"$configured". Rebuild with an https:// URL.',
      );
    }
    return configured;
  }

  static const bool adsEnabled = bool.fromEnvironment(
    'ADS_ENABLED',
    defaultValue: false,
  );
  static const String bannerAdUnitId = String.fromEnvironment(
    'ADMOB_BANNER_ID',
    defaultValue: 'ca-app-pub-3940256099942544/6300978111',
  );
  static const String rewardedAdUnitId = String.fromEnvironment(
    'ADMOB_REWARDED_ID',
    defaultValue: 'ca-app-pub-3940256099942544/5224354917',
  );
}
