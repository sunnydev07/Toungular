import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';

final voiceRepositoryProvider = Provider<VoiceRepository>(
  (ref) => VoiceRepository(ref.watch(apiClientProvider)),
);

class VoiceStatus {
  const VoiceStatus({required this.ttsAvailable, required this.sttAvailable});

  final bool ttsAvailable;
  final bool sttAvailable;

  static const VoiceStatus unavailable = VoiceStatus(ttsAvailable: false, sttAvailable: false);
}

class VoiceRepository {
  const VoiceRepository(this._api);

  final ApiClient _api;

  Future<VoiceStatus> status() => _api.get<VoiceStatus>(
        '/v1/voice/providers',
        (json) {
          final map = json is Map ? json.cast<String, Object?>() : const <String, Object?>{};
          final tts = map['tts'] is Map ? (map['tts']! as Map).cast<String, Object?>() : const <String, Object?>{};
          final stt = map['stt'] is Map ? (map['stt']! as Map).cast<String, Object?>() : const <String, Object?>{};
          return VoiceStatus(ttsAvailable: tts['available'] == true, sttAvailable: stt['available'] == true);
        },
      );

  Future<String> synthesizeToFile(String text) async {
    final file = File('${Directory.systemTemp.path}${Platform.pathSeparator}toungular-voice-${text.hashCode}.mp3');
    if (await file.exists() && await file.length() > 0) return file.path;
    final bytes = await _api.postBytes('/v1/voice/tts', <String, Object?>{'text': text});
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<String> transcribe(File file) async {
    final contentType = _contentType(file.path);
    final result = await _api.postRaw<Map<String, Object?>>(
      '/v1/voice/stt?contentType=${Uri.encodeQueryComponent(contentType)}',
      await file.readAsBytes(),
      contentType,
      (json) => json is Map ? json.cast<String, Object?>() : const <String, Object?>{},
    );
    return result['text'] as String? ?? '';
  }

  String _contentType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.ogg')) return 'audio/ogg';
    return 'audio/mp4';
  }
}
