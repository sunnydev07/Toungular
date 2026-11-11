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
import '../ielts/ielts_repository.dart';
import 'speaking_repository.dart';

const _prompts = <String>[
  'Describe a small habit that helps you have a better day.',
  'Tell a friend about a place in your town that you enjoy.',
  'Explain a skill you would like to learn and why it matters to you.',
  'Talk about a time you solved a problem with someone else.',
];

const _silenceDbfs = -40.0;

class SpeakingScreen extends ConsumerStatefulWidget {
  const SpeakingScreen({
    super.key,
    this.prompt,
    this.type = 'prompt',
    this.maxDurationSeconds,
    this.ieltsAttemptId,
    this.ieltsSectionId,
  });

  final String? prompt;
  final String type;
  final int? maxDurationSeconds;
  final String? ieltsAttemptId;
  final String? ieltsSectionId;

  @override
  ConsumerState<SpeakingScreen> createState() => _SpeakingScreenState();
}

class _SpeakingScreenState extends ConsumerState<SpeakingScreen> {
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();
  final _transcriptController = TextEditingController();
  Timer? _timer;
  StreamSubscription<Amplitude>? _amplitude;
  final List<double> _pauses = <double>[];
  DateTime? _silenceStarted;
  int _promptIndex = 0;
  int _seconds = 0;
  bool _recording = false;
  bool _sessionStarted = false;
  bool _busy = false;
  bool _anonymous = false;
  bool _sttAvailable = false;
  bool _transcribing = false;
  String? _sessionId;
  String? _audioPath;
  String? _error;
  String? _exposureMessage;
  SpeakingFeedback? _feedback;
  AffectiveAssessmentResult? _affective;

  String get _prompt => widget.prompt ?? _prompts[_promptIndex];
  bool get _isAnonymous => _anonymous || widget.type == 'anonymous';
  bool get _isExposure => widget.type.startsWith('exposure-');
  int? get _exposureLevel => _isExposure ? int.tryParse(widget.type.split('-').last) : null;

  @override
  void initState() {
    super.initState();
    _anonymous = widget.type == 'anonymous';
    _loadVoiceStatus();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _amplitude?.cancel();
    if (_recording) unawaited(_recorder.cancel());
    unawaited(_recorder.dispose());
    unawaited(_player.dispose());
    _transcriptController.dispose();
    ref.read(voiceActivityProvider.notifier).setActive(false);
    super.dispose();
  }

  Future<void> _loadVoiceStatus() async {
    try {
      final status = await ref.read(voiceRepositoryProvider).status();
      if (mounted) {
        setState(() {
          _sttAvailable = status.sttAvailable;
        });
      }
    } catch (_) {
      // Voice is optional; transcript entry remains available.
    }
  }

  Future<void> _start() async {
    setState(() {
      _busy = true;
      _error = null;
      _feedback = null;
      _affective = null;
      _exposureMessage = null;
      _seconds = 0;
      _pauses.clear();
      _silenceStarted = null;
    });
    try {
      final allowed = await _recorder.hasPermission();
      if (!allowed) {
        setState(() => _error = 'Microphone access is needed to record your answer. You can change this in Android settings.');
        return;
      }
      final repository = ref.read(speakingRepositoryProvider);
      final session = await repository.create(
        prompt: _prompt,
        type: _isAnonymous ? 'anonymous' : widget.type,
      );
      final path = '${Directory.systemTemp.path}${Platform.pathSeparator}toungular-${session.id}.m4a';
      await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
      if (!_isAnonymous) await repository.saveAudioPath(session.id, path);
      _sessionId = session.id;
      _audioPath = path;
      _transcriptController.clear();
      _sessionStarted = true;
      _recording = true;
      _amplitude = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 250))
          .listen(_trackAmplitude);
      ref.read(voiceActivityProvider.notifier).setActive(true);
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        final limit = widget.maxDurationSeconds;
        if (limit != null && _seconds + 1 >= limit) {
          _timer?.cancel();
          setState(() => _seconds = limit);
          unawaited(_stop());
        } else {
          setState(() => _seconds++);
        }
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Recording could not start. Check microphone access and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _trackAmplitude(Amplitude amplitude) {
    if (!_recording) return;
    if (amplitude.current < _silenceDbfs) {
      _silenceStarted ??= DateTime.now();
      return;
    }
    _finishPause();
  }

  void _finishPause() {
    final started = _silenceStarted;
    _silenceStarted = null;
    if (started == null) return;
    final seconds = DateTime.now().difference(started).inMilliseconds / 1000;
    if (seconds >= 0.5) {
      _pauses.add(double.parse(seconds.toStringAsFixed(1)));
    }
  }

  Future<void> _stop() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _finishPause();
      await _amplitude?.cancel();
      _amplitude = null;
      final path = await _recorder.stop();
      if (path != null) _audioPath = path;
      _timer?.cancel();
      _recording = false;
      ref.read(voiceActivityProvider.notifier).setActive(false);
      if (_sttAvailable && path != null) {
        unawaited(_transcribe());
      }
    } catch (_) {
      setState(() => _error = 'The recording could not be saved. You can discard it and start again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _discard() async {
    _finishPause();
    await _amplitude?.cancel();
    _amplitude = null;
    if (_recording) await _recorder.cancel();
    _timer?.cancel();
    final path = _audioPath;
    if (path != null) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
    if (!mounted) return;
    setState(() {
      _recording = false;
      _sessionStarted = false;
      _sessionId = null;
      _audioPath = null;
      _seconds = 0;
      _feedback = null;
      _affective = null;
      _error = null;
      _exposureMessage = null;
      _pauses.clear();
      _silenceStarted = null;
    });
    ref.read(voiceActivityProvider.notifier).setActive(false);
  }

  Future<void> _playRecording() async {
    final path = _audioPath;
    if (path == null || !await File(path).exists()) {
      setState(() => _error = 'This recording is no longer available on this device.');
      return;
    }
    try {
      await _player.setFilePath(path);
      unawaited(_player.play());
    } catch (_) {
      if (mounted) setState(() => _error = 'This recording could not be played.');
    }
  }

  Future<void> _transcribe() async {
    final path = _audioPath;
    if (path == null || !await File(path).exists()) {
      setState(() => _error = 'This recording is no longer available on this device.');
      return;
    }
    setState(() {
      _transcribing = true;
      _error = null;
    });
    try {
      final text = await ref.read(voiceRepositoryProvider).transcribe(File(path));
      if (mounted) setState(() => _transcriptController.text = text);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Transcription is unavailable right now. Type what you said instead.');
    } finally {
      if (mounted) setState(() => _transcribing = false);
    }
  }

  Future<void> _analyze() async {
    final sessionId = _sessionId;
    final transcript = _transcriptController.text.trim();
    if (sessionId == null || transcript.isEmpty) {
      setState(() => _error = 'Add the words you said so Toungular can show transcript-based feedback.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repository = ref.read(speakingRepositoryProvider);
      if (!_isAnonymous) await repository.saveTranscript(sessionId, transcript);
      final feedback = await repository.analyze(
        sessionId,
        _seconds,
        transcript: _isAnonymous ? transcript : null,
        pauses: _pauses,
      );
      if (widget.ieltsAttemptId != null && widget.ieltsSectionId != null) {
        await ref.read(ieltsRepositoryProvider).submitResponse(
              widget.ieltsAttemptId!,
              widget.ieltsSectionId!,
              transcript,
            );
      }
      final level = _exposureLevel;
      if (level != null) {
        try {
          await ref.read(exposureRepositoryProvider).complete(level);
          if (mounted) setState(() => _exposureMessage = 'Comfort level $level session recorded.');
        } on ApiException catch (error) {
          if (mounted) setState(() => _exposureMessage = 'Your feedback is ready, but the comfort level could not be updated: ${error.message}');
        }
      }
      if (mounted) setState(() => _feedback = feedback);
      try {
        final affective = await ref.read(speakingRepositoryProvider).assessAffectiveState(
              transcript: transcript,
              durationSeconds: _seconds,
              pauseCount: _pauses.length,
              wpm: feedback.wordsPerMinute.toDouble(),
            );
        if (mounted) setState(() => _affective = affective);
      } catch (_) {}
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Feedback is unavailable right now. Your draft remains on this screen.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _clock => '${(_seconds ~/ 60).toString().padLeft(2, '0')}:${(_seconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final isFixedPrompt = widget.prompt != null;
    final showAnonymousOption = !isFixedPrompt && widget.type == 'prompt';
    return Scaffold(
      appBar: AppBar(
        title: Text(_isExposure ? 'Comfort practice' : 'Speaking practice'),
        actions: <Widget>[
          IconButton(tooltip: 'Practice history', onPressed: () => context.go('/speaking/history'), icon: const Icon(Icons.history)),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(ToungularSpace.l, ToungularSpace.s, ToungularSpace.l, ToungularSpace.xl),
          children: <Widget>[
            Text('Take a moment. Then say it your way.', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: ToungularSpace.s),
            const Text('Your recording stays on this device. Transcript estimates describe this practice attempt and are not a proficiency score.'),
            const SizedBox(height: ToungularSpace.l),
            if (!isFixedPrompt && !_sessionStarted)
              DropdownButtonFormField<int>(
                initialValue: _promptIndex,
                decoration: const InputDecoration(labelText: 'Choose a prompt'),
                items: List<DropdownMenuItem<int>>.generate(
                  _prompts.length,
                  (index) => DropdownMenuItem<int>(value: index, child: Text('Prompt ${index + 1}')),
                ),
                onChanged: (value) => setState(() => _promptIndex = value ?? _promptIndex),
              ),
            if (showAnonymousOption && !_sessionStarted) ...<Widget>[
              const SizedBox(height: ToungularSpace.s),
              Card(
                color: ToungularColor.mist,
                child: SwitchListTile(
                  value: _anonymous,
                  onChanged: (value) => setState(() => _anonymous = value),
                  title: const Text('Anonymous practice'),
                  subtitle: const Text('Feedback appears here, but your transcript and result are not saved to history.'),
                ),
              ),
            ],
            Card(
              color: ToungularColor.mist,
              child: Padding(
                padding: const EdgeInsets.all(ToungularSpace.l),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('YOUR PROMPT', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: ToungularSpace.s),
                    Text(_prompt, style: Theme.of(context).textTheme.titleLarge),
                    if (_isAnonymous) ...<Widget>[
                      const SizedBox(height: ToungularSpace.s),
                      const Text('Anonymous mode: only transcript-based feedback is shown, and it is not saved.'),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: ToungularSpace.l),
            Center(child: Text(_clock, style: Theme.of(context).textTheme.displaySmall)),
            const SizedBox(height: ToungularSpace.s),
            if (!_sessionStarted)
              FilledButton.icon(
                onPressed: _busy ? null : _start,
                icon: const Icon(Icons.mic),
                label: Text(_busy ? 'Starting…' : 'Start recording'),
              )
            else if (_recording)
              FilledButton.icon(onPressed: _busy ? null : _stop, icon: const Icon(Icons.stop_circle_outlined), label: const Text('Stop recording'))
            else ...<Widget>[
              OutlinedButton.icon(onPressed: _busy ? null : _playRecording, icon: const Icon(Icons.play_arrow), label: const Text('Play my recording')),
              if (_sttAvailable) ...<Widget>[
                const SizedBox(height: ToungularSpace.s),
                OutlinedButton.icon(
                  onPressed: _busy || _transcribing ? null : _transcribe,
                  icon: const Icon(Icons.graphic_eq_rounded),
                  label: Text(_transcribing ? 'Transcribing…' : 'Transcribe my recording'),
                ),
              ],
              const SizedBox(height: ToungularSpace.s),
              TextField(
                controller: _transcriptController,
                minLines: 4,
                maxLines: 9,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'What did you say?', hintText: 'Type an editable transcript of your answer…'),
              ),
              const SizedBox(height: ToungularSpace.s),
              FilledButton(
                onPressed: _busy || _transcribing || _feedback != null ? null : _analyze,
                child: Text(_transcribing ? 'Transcribing…' : _busy ? 'Saving…' : 'Get practice feedback'),
              ),
              TextButton(onPressed: _busy ? null : _discard, child: const Text('Discard and try another prompt')),
            ],
            if (_error != null) ...<Widget>[
              const SizedBox(height: ToungularSpace.s),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            if (_exposureMessage != null) ...<Widget>[
              const SizedBox(height: ToungularSpace.s),
              Text(_exposureMessage!, style: const TextStyle(color: ToungularColor.leaf)),
            ],
            if (_feedback != null) ...<Widget>[
              const SizedBox(height: ToungularSpace.l),
              _FeedbackCard(feedback: _feedback!, affective: _affective),
              const SizedBox(height: ToungularSpace.s),
              if (widget.ieltsAttemptId != null)
                FilledButton(onPressed: () => context.pop(true), child: const Text('Return to IELTS practice'))
              else if (_isExposure)
                FilledButton(onPressed: () => context.pop(), child: const Text('Back to comfort path'))
              else
                OutlinedButton(onPressed: () => context.go('/speaking/history'), child: const Text('View speaking history')),
            ],
          ],
        ),
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({required this.feedback, this.affective});

  final SpeakingFeedback feedback;
  final AffectiveAssessmentResult? affective;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(ToungularSpace.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Practice reflection', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: ToungularSpace.xs),
              Text(feedback.label),
              if (affective != null) ...<Widget>[
                const SizedBox(height: ToungularSpace.m),
                Container(
                  padding: const EdgeInsets.all(ToungularSpace.m),
                  decoration: BoxDecoration(
                    color: affective!.anxietyState == 'calm'
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        affective!.anxietyState == 'calm' ? Icons.spa_outlined : Icons.psychology_outlined,
                        color: affective!.anxietyState == 'calm' ? ToungularColor.leaf : Colors.orange.shade800,
                      ),
                      const SizedBox(width: ToungularSpace.s),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              affective!.anxietyState == 'calm' ? 'Composed Delivery' : 'Mindful Speaking',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: affective!.anxietyState == 'calm' ? ToungularColor.leaf : Colors.orange.shade900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              affective!.shouldScaffold
                                  ? 'Take natural pauses without worry. Pace and confidence improve with every small step.'
                                  : 'Confidence score: ${(affective!.confidenceScore * 100).round()}%. Great steady composure!',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: ToungularSpace.m),
              Wrap(
                spacing: ToungularSpace.xs,
                runSpacing: ToungularSpace.xs,
                children: <Widget>[
                  Chip(label: Text('${feedback.wordCount} words')),
                  Chip(label: Text('${feedback.wordsPerMinute} wpm')),
                  Chip(label: Text('${feedback.articulationRate} articulation')),
                  Chip(label: Text('${(feedback.vocabularyVariety * 100).round()}% unique')),
                  Chip(label: Text('${feedback.fillerCount} fillers')),
                  Chip(label: Text('${feedback.pauseCount} pauses')),
                ],
              ),
              const SizedBox(height: ToungularSpace.m),
              if (feedback.fillers.isNotEmpty)
                Text('Fillers: ${feedback.fillers.map((filler) => '${filler.word} ×${filler.count}').join(', ')}'),
              Text(feedback.pauseNote),
              const SizedBox(height: ToungularSpace.m),
              Text('Pace trend', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: ToungularSpace.xs),
              if (feedback.wpmTrend.isNotEmpty) ...<Widget>[
                _TrendBars(points: feedback.wpmTrend),
                const SizedBox(height: ToungularSpace.xs),
              ],
              Text(feedback.wpmTrendMessage),
              const SizedBox(height: ToungularSpace.s),
              Text(feedback.pronunciationMessage),
              const SizedBox(height: ToungularSpace.m),
              Text('Try next', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: ToungularSpace.xs),
              Text(feedback.nextStep),
            ],
          ),
        ),
      );
}

class _TrendBars extends StatelessWidget {
  const _TrendBars({required this.points});

  final List<int> points;

  @override
  Widget build(BuildContext context) {
    final maxValue = points.fold<int>(0, (max, value) => value > max ? value : max);
    return SizedBox(
      height: 76,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: points
            .map((point) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: <Widget>[
                        Text('$point', style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 2),
                        Container(
                          height: maxValue == 0 ? 8 : (point / maxValue * 46).clamp(8, 46).toDouble(),
                          decoration: BoxDecoration(
                            color: ToungularColor.leaf,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ))
            .toList(growable: false),
      ),
    );
  }
}
