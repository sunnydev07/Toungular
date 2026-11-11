import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';

import '../../core/network/api_client.dart';
import '../../core/state/voice_activity_controller.dart';
import '../../core/theme/toungular_theme.dart';
import '../../core/voice/voice_repository.dart';
import '../../shared/content/speaking_prompts.dart';
import '../../shared/models/learning_models.dart';
import '../exposure/exposure_repository.dart';
import '../ielts/ielts_repository.dart';
import 'speaking_feedback_view.dart';
import 'speaking_repository.dart';

const _silenceDbfs = -40.0;
const _meterBars = 22;

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

class _SpeakingScreenState extends ConsumerState<SpeakingScreen>
    with SingleTickerProviderStateMixin {
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
  double _level = 0;
  String? _promptOverride;
  String? _tip;
  String? _sessionId;
  String? _audioPath;
  String? _error;
  String? _exposureMessage;
  SpeakingFeedback? _feedback;
  AffectiveAssessmentResult? _affective;
  late final AnimationController _pulse;

  // IELTS and comfort prompts are fixed; prompt-type sessions may switch.
  bool get _fixedPrompt => widget.prompt != null && widget.type != 'prompt';
  String get _prompt =>
      _promptOverride ?? widget.prompt ?? speakingPrompts[_promptIndex].text;
  bool get _isAnonymous => _anonymous || widget.type == 'anonymous';
  bool get _isExposure => widget.type.startsWith('exposure-');
  int? get _exposureLevel =>
      _isExposure ? int.tryParse(widget.type.split('-').last) : null;
  int get _cueAfterSeconds => (widget.maxDurationSeconds ?? 120) ~/ 2;
  bool get _showCue => _recording && _seconds >= _cueAfterSeconds;

  SpeakingPrompt? get _matchedPrompt {
    for (final candidate in speakingPrompts) {
      if (candidate.text == _prompt) return candidate;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _anonymous = widget.type == 'anonymous';
    if (widget.prompt != null && widget.type == 'prompt') {
      _promptIndex = dailyPromptIndex(DateTime.now());
    }
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
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
    _pulse.dispose();
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
      _level = 0;
      _pauses.clear();
      _silenceStarted = null;
    });
    try {
      final allowed = await _recorder.hasPermission();
      if (!allowed) {
        setState(
          () => _error = 'Microphone access is needed to record your answer. You can change this in Android settings.',
        );
        return;
      }
      final repository = ref.read(speakingRepositoryProvider);
      final session = await repository.create(
        prompt: _prompt,
        type: _isAnonymous ? 'anonymous' : widget.type,
      );
      final path =
          '${Directory.systemTemp.path}${Platform.pathSeparator}toungular-${session.id}.m4a';
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
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
      if (mounted && !MediaQuery.disableAnimationsOf(context))
        _pulse.repeat(reverse: true);
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
      if (mounted)
        setState(
          () => _error = 'Recording could not start. Check microphone access and try again.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _trackAmplitude(Amplitude amplitude) {
    if (!_recording) return;
    final db = amplitude.current.clamp(-60.0, 0.0).toDouble();
    if (mounted) setState(() => _level = (db + 60) / 60);
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
      _pulse.stop();
      _pulse.value = 0;
      ref.read(voiceActivityProvider.notifier).setActive(false);
      if (_sttAvailable && path != null) {
        unawaited(_transcribe());
      }
    } catch (_) {
      setState(
        () => _error = 'The recording could not be saved. You can discard it and start again.',
      );
    } finally {
      if (mounted)
        setState(() {
          _busy = false;
          _level = 0;
        });
    }
  }

  Future<void> _discard() async {
    _finishPause();
    await _amplitude?.cancel();
    _amplitude = null;
    if (_recording) await _recorder.cancel();
    _timer?.cancel();
    _pulse.stop();
    _pulse.value = 0;
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
      _level = 0;
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
      setState(
        () => _error = 'This recording is no longer available on this device.',
      );
      return;
    }
    try {
      await _player.setFilePath(path);
      unawaited(_player.play());
    } catch (_) {
      if (mounted)
        setState(() => _error = 'This recording could not be played.');
    }
  }

  Future<void> _transcribe() async {
    final path = _audioPath;
    if (path == null || !await File(path).exists()) {
      setState(
        () => _error = 'This recording is no longer available on this device.',
      );
      return;
    }
    setState(() {
      _transcribing = true;
      _error = null;
    });
    try {
      final text = await ref
          .read(voiceRepositoryProvider)
          .transcribe(File(path));
      if (mounted) setState(() => _transcriptController.text = text);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted)
        setState(
          () => _error = 'Transcription is unavailable right now. Type what you said instead.',
        );
    } finally {
      if (mounted) setState(() => _transcribing = false);
    }
  }

  Future<void> _analyze() async {
    final sessionId = _sessionId;
    final transcript = _transcriptController.text.trim();
    if (sessionId == null || transcript.isEmpty) {
      setState(
        () => _error = 'Add the words you said so Toungular can show transcript-based feedback.',
      );
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
        await ref
            .read(ieltsRepositoryProvider)
            .submitResponse(
              widget.ieltsAttemptId!,
              widget.ieltsSectionId!,
              transcript,
            );
      }
      final level = _exposureLevel;
      if (level != null) {
        try {
          await ref.read(exposureRepositoryProvider).complete(level);
          if (mounted)
            setState(
              () => _exposureMessage = 'Comfort level $level session recorded.',
            );
        } on ApiException catch (error) {
          if (mounted)
            setState(
              () => _exposureMessage =
                  'Your feedback is ready, but the comfort level could not be updated: ${error.message}',
            );
        }
      }
      if (mounted) setState(() => _feedback = feedback);
      try {
        final affective = await ref
            .read(speakingRepositoryProvider)
            .assessAffectiveState(
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
      if (mounted)
        setState(
          () => _error = 'Feedback is unavailable right now. Your draft remains on this screen.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The one primary action from feedback: keep the tip, drop the take, record again.
  Future<void> _retryWithTip() async {
    setState(() => _tip = _feedback?.nextStep);
    await _discard();
    if (mounted) await _start();
  }

  Future<void> _nextPrompt() async {
    setState(() {
      _tip = null;
      _promptIndex = (_promptIndex + 1) % speakingPrompts.length;
      _promptOverride = speakingPrompts[_promptIndex].text;
    });
    await _discard();
  }

  void _showHelp() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(ToungularSpace.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'How this works',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: ToungularSpace.s),
            const Text(
              '1. Tap the record button and answer out loud.\n'
              '2. Stop — Toungular writes a transcript you can edit.\n'
              '3. Tap Check my answer for feedback.\n'
              '4. Retry with the tip still in view.',
            ),
            const SizedBox(height: ToungularSpace.l),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: const Text('Got it'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _clock =>
      '${(_seconds ~/ 60).toString().padLeft(2, '0')}:${(_seconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final feedback = _feedback;
    final showAnonymousOption =
        widget.prompt == null && widget.type == 'prompt';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          feedback != null
              ? 'Feedback'
              : (_isExposure ? 'Comfort practice' : 'Speaking'),
        ),
        actions: feedback == null
            ? <Widget>[
                IconButton(
                  tooltip: 'Help',
                  onPressed: _showHelp,
                  icon: const Icon(Icons.help_outline_rounded),
                ),
                IconButton(
                  tooltip: 'Practice history',
                  onPressed: () => context.pushReplacement('/speaking/history'),
                  icon: const Icon(Icons.history_outlined),
                ),
              ]
            : const <Widget>[],
      ),
      body: SafeArea(
        child: feedback != null
            ? SpeakingFeedbackView(
                feedback: feedback,
                affective: _affective,
                transcript: _transcriptController.text,
                showRetry: widget.ieltsAttemptId == null && !_isExposure,
                onRetryWithTip: _retryWithTip,
                onNextPrompt: _nextPrompt,
                onReturnToIelts: widget.ieltsAttemptId != null
                    ? () => context.pop(true)
                    : null,
                onBackToComfort: widget.ieltsAttemptId == null && _isExposure
                    ? () => context.pop()
                    : null,
                onViewHistory: () =>
                    context.pushReplacement('/speaking/history'),
              )
            : _practiceBody(context, showAnonymousOption),
      ),
    );
  }

  Widget _practiceBody(BuildContext context, bool showAnonymousOption) {
    final matched = _matchedPrompt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (_tip != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              ToungularSpace.l,
              ToungularSpace.s,
              ToungularSpace.l,
              0,
            ),
            child: Container(
              padding: const EdgeInsets.all(ToungularSpace.s),
              decoration: BoxDecoration(
                color: ToungularColor.butter,
                borderRadius: BorderRadius.circular(ToungularRadius.card),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 18,
                    color: ToungularColor.leaf,
                  ),
                  const SizedBox(width: ToungularSpace.xs),
                  Expanded(
                    child: Text(
                      'Tip from your last attempt: $_tip',
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: ToungularColor.ink),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            ToungularSpace.l,
            ToungularSpace.s,
            ToungularSpace.l,
            0,
          ),
          child: Container(
            padding: const EdgeInsets.all(ToungularSpace.m),
            decoration: BoxDecoration(
              color: ToungularColor.mist,
              borderRadius: BorderRadius.circular(ToungularRadius.card),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'YOUR PROMPT',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 1.2,
                    color: ToungularColor.leaf,
                  ),
                ),
                const SizedBox(height: ToungularSpace.xs),
                Text(_prompt, style: Theme.of(context).textTheme.titleLarge),
                if (matched != null && matched.hints.isNotEmpty) ...<Widget>[
                  const SizedBox(height: ToungularSpace.s),
                  for (final hint in matched.hints)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Icon(
                            Icons.subdirectory_arrow_right_rounded,
                            size: 18,
                            color: ToungularColor.leaf,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              hint,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                if (_isAnonymous) ...<Widget>[
                  const SizedBox(height: ToungularSpace.s),
                  const Text(
                    'Anonymous mode: only transcript-based feedback is shown, and it is not saved.',
                  ),
                ],
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              ToungularSpace.l,
              ToungularSpace.m,
              ToungularSpace.l,
              ToungularSpace.xl,
            ),
            children: <Widget>[
              if (!_fixedPrompt && !_sessionStarted)
                DropdownButtonFormField<int>(
                  initialValue: _promptIndex,
                  decoration: const InputDecoration(
                    labelText: 'Choose a prompt',
                  ),
                  items: List<DropdownMenuItem<int>>.generate(
                    speakingPrompts.length,
                    (index) => DropdownMenuItem<int>(
                      value: index,
                      child: Text('Prompt ${index + 1}'),
                    ),
                  ),
                  onChanged: (value) => setState(() {
                    _promptIndex = value ?? _promptIndex;
                    _promptOverride = speakingPrompts[_promptIndex].text;
                  }),
                ),
              if (showAnonymousOption && !_sessionStarted) ...<Widget>[
                const SizedBox(height: ToungularSpace.s),
                Card(
                  color: ToungularColor.mist,
                  child: SwitchListTile(
                    value: _anonymous,
                    onChanged: (value) => setState(() => _anonymous = value),
                    title: const Text('Anonymous practice'),
                    subtitle: const Text(
                      'Feedback appears here, but your transcript and result are not saved to history.',
                    ),
                  ),
                ),
              ],
              const SizedBox(height: ToungularSpace.s),
              Center(
                child: ExcludeSemantics(
                  child: Text(
                    _clock,
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                ),
              ),
              const SizedBox(height: ToungularSpace.m),
              if (!_sessionStarted) ...<Widget>[
                Center(
                  child: _RecordButton(
                    recording: false,
                    reducedMotion: MediaQuery.disableAnimationsOf(context),
                    pulse: _pulse,
                    label: 'Start recording',
                    onTap: _busy ? null : _start,
                  ),
                ),
                const SizedBox(height: ToungularSpace.s),
                Center(
                  child: Text(
                    _busy ? 'Starting…' : 'Tap to record',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ] else if (_recording) ...<Widget>[
                Center(
                  child: _RecordButton(
                    recording: true,
                    reducedMotion: MediaQuery.disableAnimationsOf(context),
                    pulse: _pulse,
                    label: 'Recording, tap to stop',
                    onTap: _busy ? null : _stop,
                  ),
                ),
                const SizedBox(height: ToungularSpace.s),
                Center(
                  child: Text(
                    'Recording · tap to stop',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(color: ToungularColor.coral),
                  ),
                ),
                const SizedBox(height: ToungularSpace.s),
                _LevelMeter(level: _level),
                if (_showCue) ...<Widget>[
                  const SizedBox(height: ToungularSpace.s),
                  Container(
                    padding: const EdgeInsets.all(ToungularSpace.s),
                    decoration: BoxDecoration(
                      color: ToungularColor.peach,
                      borderRadius: BorderRadius.circular(ToungularRadius.card),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Icon(
                          Icons.wb_sunny_outlined,
                          size: 18,
                          color: ToungularColor.coral,
                        ),
                        const SizedBox(width: ToungularSpace.xs),
                        Expanded(
                          child: Text(
                            'Halfway through your planned time. Slow down slightly and finish the thought.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: ToungularColor.ink),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ] else ...<Widget>[
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(ToungularSpace.m),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                'Transcript',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            if (_transcribing)
                              Text(
                                'Transcribing…',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                          ],
                        ),
                        const SizedBox(height: ToungularSpace.xs),
                        if (_transcribing)
                          const LinearProgressIndicator(
                            semanticsLabel: 'Transcribing your recording',
                          )
                        else
                          TextField(
                            controller: _transcriptController,
                            minLines: 3,
                            maxLines: 6,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              hintText: _sttAvailable
                                  ? 'Edit what Toungular heard…'
                                  : 'Type what you said…',
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: ToungularSpace.s),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _transcriptController,
                  builder: (context, value, _) => FilledButton(
                    onPressed:
                        _busy || _transcribing || value.text.trim().isEmpty
                        ? null
                        : _analyze,
                    child: Text(_busy ? 'Saving…' : 'Check my answer'),
                  ),
                ),
                const SizedBox(height: ToungularSpace.xs),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _playRecording,
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Play'),
                      ),
                    ),
                    TextButton(
                      onPressed: _busy ? null : _discard,
                      child: const Text('Discard'),
                    ),
                    if (!_fixedPrompt)
                      TextButton(
                        onPressed: _busy ? null : _nextPrompt,
                        child: const Text('New prompt'),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: ToungularSpace.m),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(
                    Icons.lock_outline_rounded,
                    size: 16,
                    color: ToungularColor.mutedInk,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Audio is sent only when you tap Check my answer.',
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(fontSize: 13),
                    ),
                  ),
                ],
              ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: ToungularSpace.s),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (_exposureMessage != null) ...<Widget>[
                const SizedBox(height: ToungularSpace.s),
                Text(
                  _exposureMessage!,
                  style: const TextStyle(color: ToungularColor.leaf),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _RecordButton extends StatelessWidget {
  const _RecordButton({
    required this.recording,
    required this.reducedMotion,
    required this.pulse,
    required this.label,
    this.onTap,
  });

  final bool recording;
  final bool reducedMotion;
  final AnimationController pulse;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final core = Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: recording ? ToungularColor.coral : ToungularColor.leaf,
        shape: BoxShape.circle,
      ),
      child: Icon(
        recording ? Icons.stop_rounded : Icons.mic_rounded,
        size: 42,
        color: Colors.white,
      ),
    );

    return Semantics(
      button: onTap != null,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? .6 : 1,
          child: Container(
            width: 112,
            height: 112,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: recording
                    ? ToungularColor.coral.withValues(alpha: .45)
                    : ToungularColor.sand,
                width: 3,
              ),
            ),
            child: recording && !reducedMotion
                ? ScaleTransition(
                    scale: Tween<double>(begin: .96, end: 1.04).animate(
                      CurvedAnimation(parent: pulse, curve: Curves.easeInOut),
                    ),
                    child: core,
                  )
                : core,
          ),
        ),
      ),
    );
  }
}

class _LevelMeter extends StatelessWidget {
  const _LevelMeter({required this.level});

  final double level;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      excludeSemantics: true,
      child: SizedBox(
        height: 56,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List<Widget>.generate(_meterBars, (index) {
            // Deterministic wave pattern scaled by the current level: no jitter.
            final wave = math.sin((index + 1) * 0.7) * .5 + .5;
            final height = 6.0 + wave * level * 46.0;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Container(
                  height: height,
                  decoration: BoxDecoration(
                    color: level > 0
                        ? ToungularColor.leaf
                        : ToungularColor.sand,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
