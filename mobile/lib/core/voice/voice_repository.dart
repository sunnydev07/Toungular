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

  static const VoiceStatus unavailable = VoiceStatus(
    ttsAvailable: false,
    sttAvailable: false,
  );
}

class VoiceRepository {
  VoiceRepository(
    this._api, {
    Directory? cacheDirectory,
    this.maxCacheFiles = 50,
    this.maxCacheBytes = 25 * 1024 * 1024,
  }) : _cacheDir = cacheDirectory ?? Directory.systemTemp;

  final ApiClient _api;
  final Directory _cacheDir;
  final int maxCacheFiles;
  final int maxCacheBytes;

  Future<VoiceStatus> status() =>
      _api.get<VoiceStatus>('/v1/voice/providers', (json) {
        final map = json is Map
            ? json.cast<String, Object?>()
            : const <String, Object?>{};
        final tts = map['tts'] is Map
            ? (map['tts']! as Map).cast<String, Object?>()
            : const <String, Object?>{};
        final stt = map['stt'] is Map
            ? (map['stt']! as Map).cast<String, Object?>()
            : const <String, Object?>{};
        return VoiceStatus(
          ttsAvailable: tts['available'] == true,
          sttAvailable: stt['available'] == true,
        );
      });

  Future<String> synthesizeToFile(String text) async {
    final file = File(
      '${_cacheDir.path}${Platform.pathSeparator}toungular-voice-${text.hashCode}.mp3',
    );
    if (await file.exists() && await file.length() > 0) {
      try {
        await file.setLastModified(DateTime.now());
      } catch (_) {}
      return file.path;
    }
    final bytes = await _api.postBytes('/v1/voice/tts', <String, Object?>{
      'text': text,
    });
    await file.writeAsBytes(bytes, flush: true);
    await pruneCache();
    return file.path;
  }

  Future<void> pruneCache() async {
    try {
      if (!await _cacheDir.exists()) return;
      final entities = await _cacheDir.list().toList();
      final voiceFiles = <File>[];
      for (final entity in entities) {
        if (entity is File) {
          final name = entity.uri.pathSegments.last;
          if (name.startsWith('toungular-voice-') && name.endsWith('.mp3')) {
            voiceFiles.add(entity);
          }
        }
      }

      if (voiceFiles.isEmpty) return;

      final fileStats = <File, ({DateTime modified, int size})>{};
      int totalBytes = 0;
      for (final file in voiceFiles) {
        try {
          final stat = await file.stat();
          fileStats[file] = (modified: stat.modified, size: stat.size);
          totalBytes += stat.size;
        } catch (_) {}
      }

      voiceFiles.sort((a, b) {
        final aMod =
            fileStats[a]?.modified ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bMod =
            fileStats[b]?.modified ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aMod.compareTo(bMod);
      });

      while (voiceFiles.isNotEmpty &&
          (voiceFiles.length > maxCacheFiles || totalBytes > maxCacheBytes)) {
        final oldest = voiceFiles.removeAt(0);
        final size = fileStats[oldest]?.size ?? 0;
        try {
          await oldest.delete();
          totalBytes -= size;
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<String> transcribe(File file) async {
    final contentType = _contentType(file.path);
    final result = await _api.postRaw<Map<String, Object?>>(
      '/v1/voice/stt?contentType=${Uri.encodeQueryComponent(contentType)}',
      await file.readAsBytes(),
      contentType,
      (json) => json is Map
          ? json.cast<String, Object?>()
          : const <String, Object?>{},
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
