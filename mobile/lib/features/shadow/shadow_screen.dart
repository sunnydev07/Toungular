import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';

import '../../core/network/api_client.dart';
import '../../core/state/voice_activity_controller.dart';
import '../../core/theme/toungular_theme.dart';
import '../../core/voice/voice_repository.dart';
import '../../shared/models/learning_models.dart';
import '../exposure/exposure_repository.dart';
import 'shadow_repository.dart';

class ShadowScreen extends ConsumerStatefulWidget {
  const ShadowScreen({super.key, this.passageId});

  final String? passageId;

  @override
  ConsumerState<ShadowScreen> createState() => _ShadowScreenState();
}

class _ShadowScreenState extends ConsumerState<ShadowScreen> {
  final _recorder = AudioRecorder();
  final _modelPlayer = AudioPlayer();
  final _userPlayer = AudioPlayer();
  final _transcriptController = TextEditingController();

  List<ShadowPassage> _passages = <ShadowPassage>[];
  ShadowPassage? _currentPassage;
  Timer? _timer;
  int _seconds = 0;
  bool _loading = true;
  bool _modelPlaying = false;
  bool _recording = false;
  bool _busy = false;
  bool _transcribing = false;
  bool _sttAvailable = false;
  String? _modelAudioPath;
  String? _userAudioPath;
  String? _error;
  ShadowAnalysisResult? _analysis;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_recording) unawaited(_recorder.cancel());
    unawaited(_recorder.dispose());
    unawaited(_modelPlayer.dispose());
    unawaited(_userPlayer.dispose());
    _transcriptController.dispose();
    ref.read(voiceActivityProvider.notifier).setActive(false);
    super.dispose();
  }

  Future<void> _initData() async {
    try {
      final repository = ref.read(shadowRepositoryProvider);
      final passages = await repository.loadPassages();
      final status = await ref.read(voiceRepositoryProvider).status();

      if (!mounted) return;
      setState(() {
        _passages = passages;
        _sttAvailable = status.sttAvailable;
        if (widget.passageId != null) {
          _currentPassage = passages.firstWhere(
            (p) => p.id == widget.passageId,
            orElse: () => passages.first,
          );
        } else {
          _currentPassage = passages.isNotEmpty ? passages.first : null;
        }
        _loading = false;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() { _error = error.message; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Could not load shadowing passages.'; _loading = false; });
    }
  }

  Future<void> _playModelAudio() async {
    final passage = _currentPassage;
    if (passage == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      if (_modelAudioPath == null || !await File(_modelAudioPath!).exists()) {
        final path = await ref.read(voiceRepositoryProvider).synthesizeToFile(passage.text);
        _modelAudioPath = path;
      }
      await _modelPlayer.setFilePath(_modelAudioPath!);
      setState(() => _modelPlaying = true);
      await _modelPlayer.play();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Model audio preview is unavailable right now.');
    } finally {
      if (mounted) setState(() { _modelPlaying = false; _busy = false; });
    }
  }

  Future<void> _startRecording() async {
    final passage = _currentPassage;
    if (passage == null) return;

    setState(() {
      _busy = true;
      _error = null;
      _analysis = null;
      _seconds = 0;
    });

    try {
      final allowed = await _recorder.hasPermission();
      if (!allowed) {
        setState(() => _error = 'Microphone permission is required for shadowing practice.');
        return;
      }

      final path = '${Directory.systemTemp.path}${Platform.pathSeparator}toungular-shadow-${passage.id}.m4a';
      await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
      _userAudioPath = path;
      _transcriptController.clear();
      _recording = true;
      ref.read(voiceActivityProvider.notifier).setActive(true);

      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _seconds++);
      });
    } catch (_) {
      setState(() => _error = 'Recording could not start. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stopRecording() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final path = await _recorder.stop();
      if (path != null) _userAudioPath = path;
      _timer?.cancel();
      _recording = false;
      ref.read(voiceActivityProvider.notifier).setActive(false);

      if (_sttAvailable && path != null) {
        unawaited(_transcribe());
      } else {
        // Fallback default: set reference text so learner can submit immediately
        if (_currentPassage != null && _transcriptController.text.isEmpty) {
          _transcriptController.text = _currentPassage!.text;
        }
      }
    } catch (_) {
      setState(() => _error = 'Could not save the shadow recording.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _transcribe() async {
    final path = _userAudioPath;
    if (path == null || !await File(path).exists()) return;

    setState(() => _transcribing = true);
    try {
      final text = await ref.read(voiceRepositoryProvider).transcribe(File(path));
      if (mounted && text.isNotEmpty) {
        setState(() => _transcriptController.text = text);
      }
    } catch (_) {
      if (mounted && _currentPassage != null && _transcriptController.text.isEmpty) {
        setState(() => _transcriptController.text = _currentPassage!.text);
      }
    } finally {
      if (mounted) setState(() => _transcribing = false);
    }
  }

  Future<void> _playUserRecording() async {
    final path = _userAudioPath;
    if (path == null || !await File(path).exists()) {
      setState(() => _error = 'Recording is not available.');
      return;
    }
    try {
      await _userPlayer.setFilePath(path);
      await _userPlayer.play();
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not play your recording.');
    }
  }

  Future<void> _submitAnalysis() async {
    final passage = _currentPassage;
    final transcript = _transcriptController.text.trim();
    if (passage == null) return;
    if (transcript.isEmpty) {
      setState(() => _error = 'Please enter or confirm the words you spoke before analyzing.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final duration = _seconds > 0 ? _seconds : passage.durationEstimateSec;
      final result = await ref.read(shadowRepositoryProvider).analyze(
        passageId: passage.id,
        durationSeconds: duration,
        transcript: transcript,
      );

      // Record exposure session for Level 5
      try {
        await ref.read(exposureRepositoryProvider).complete(5);
      } catch (_) {}

      if (mounted) setState(() => _analysis = result);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Shadow analysis could not be completed.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Speech Shadowing')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final passage = _currentPassage;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Speech Shadowing'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Comfort path',
            onPressed: () => context.go('/exposure'),
            icon: const Icon(Icons.shield_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(ToungularSpace.l),
          children: <Widget>[
            Text('Shadow the Native Model', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: ToungularSpace.xs),
            const Text('Listen to the rhythm, then speak simultaneously to calibrate your speech rate and natural chunking.'),
            const SizedBox(height: ToungularSpace.l),
            if (_passages.length > 1)
              DropdownButtonFormField<String>(
                initialValue: passage?.id,
                decoration: const InputDecoration(labelText: 'Choose Passage'),
                items: _passages
                    .map((p) => DropdownMenuItem(
                          value: p.id,
                          child: Text('${p.title} (${p.level.toUpperCase()})'),
                        ))
                    .toList(growable: false),
                onChanged: (id) {
                  if (id == null) return;
                  setState(() {
                    _currentPassage = _passages.firstWhere((p) => p.id == id);
                    _modelAudioPath = null;
                    _analysis = null;
                    _userAudioPath = null;
                    _transcriptController.clear();
                  });
                },
              ),
            const SizedBox(height: ToungularSpace.m),
            if (passage != null) ...<Widget>[
              Card(
                color: ToungularColor.mist,
                child: Padding(
                  padding: const EdgeInsets.all(ToungularSpace.l),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Chip(label: Text('${passage.targetWpm} WPM Model')),
                          Chip(label: Text(passage.level.toUpperCase())),
                        ],
                      ),
                      const SizedBox(height: ToungularSpace.s),
                      Text('FOCUS: ${passage.focus}', style: const TextStyle(fontWeight: FontWeight.bold, color: ToungularColor.ink)),
                      const SizedBox(height: ToungularSpace.m),
                      ...passage.chunks.map((chunk) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              chunk,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(height: 1.4),
                            ),
                          )),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: ToungularSpace.l),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy || _recording ? null : _playModelAudio,
                      icon: Icon(_modelPlaying ? Icons.volume_up : Icons.play_circle_outline),
                      label: Text(_modelPlaying ? 'Playing Model…' : '1. Listen to Model'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ToungularSpace.s),
              Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy || _modelPlaying
                          ? null
                          : _recording
                              ? _stopRecording
                              : _startRecording,
                      icon: Icon(_recording ? Icons.stop_circle : Icons.mic),
                      label: Text(_recording ? 'Stop Shadowing (${_seconds}s)' : '2. Record Shadow Attempt'),
                    ),
                  ),
                ],
              ),
              if (_userAudioPath != null && !_recording) ...<Widget>[
                const SizedBox(height: ToungularSpace.s),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextButton.icon(
                        onPressed: _playUserRecording,
                        icon: const Icon(Icons.replay),
                        label: const Text('Play My Recording'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: ToungularSpace.s),
                TextField(
                  controller: _transcriptController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Spoken Transcript',
                    hintText: 'Transcript of what you shadowed...',
                  ),
                ),
                const SizedBox(height: ToungularSpace.s),
                FilledButton.icon(
                  onPressed: _busy || _transcribing ? null : _submitAnalysis,
                  icon: const Icon(Icons.analytics_outlined),
                  label: Text(_transcribing ? 'Transcribing…' : _busy ? 'Evaluating…' : '3. Analyze Prosody & Tempo'),
                ),
              ],
            ],
            if (_error != null) ...<Widget>[
              const SizedBox(height: ToungularSpace.m),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            if (_analysis != null) ...<Widget>[
              const SizedBox(height: ToungularSpace.l),
              _ShadowScorecard(analysis: _analysis!),
            ],
          ],
        ),
      ),
    );
  }
}

class _ShadowScorecard extends StatelessWidget {
  const _ShadowScorecard({required this.analysis});

  final ShadowAnalysisResult analysis;

  @override
  Widget build(BuildContext context) {
    final isHigh = analysis.overallScore >= 80;
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(ToungularSpace.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text('Shadowing Scorecard', style: Theme.of(context).textTheme.titleLarge),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: isHigh ? Colors.green.shade100 : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${analysis.overallScore} / 100',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isHigh ? Colors.green.shade900 : Colors.orange.shade900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: ToungularSpace.m),
            Row(
              children: <Widget>[
                Expanded(
                  child: _MetricTile(
                    label: 'Target Speed',
                    value: '${analysis.targetWpm} WPM',
                  ),
                ),
                Expanded(
                  child: _MetricTile(
                    label: 'Your Pace',
                    value: '${analysis.actualWpm} WPM',
                  ),
                ),
                Expanded(
                  child: _MetricTile(
                    label: 'Word Match',
                    value: '${analysis.wordMatchPercent}%',
                  ),
                ),
              ],
            ),
            const Divider(height: ToungularSpace.xl),
            Text('Pacing Diagnosis', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: ToungularSpace.xs),
            Text(analysis.feedback.paceDiagnosis),
            const SizedBox(height: ToungularSpace.m),
            Text('Prosody & Linking Tip', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: ToungularSpace.xs),
            Text(analysis.feedback.prosodyTip),
            const SizedBox(height: ToungularSpace.m),
            Text('Next Step', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: ToungularSpace.xs),
            Text(analysis.feedback.nextStep),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      );
}
