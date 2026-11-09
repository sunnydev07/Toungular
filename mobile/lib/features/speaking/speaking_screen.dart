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
import '../../shared/models/learning_models.dart';
import '../ielts/ielts_repository.dart';
import 'speaking_repository.dart';

const _prompts = <String>[
  'Describe a small habit that helps you have a better day.',
  'Tell a friend about a place in your town that you enjoy.',
  'Explain a skill you would like to learn and why it matters to you.',
  'Talk about a time you solved a problem with someone else.',
];

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
  int _promptIndex = 0;
  int _seconds = 0;
  bool _recording = false;
  bool _sessionStarted = false;
  bool _busy = false;
  String? _sessionId;
  String? _audioPath;
  String? _error;
  SpeakingFeedback? _feedback;

  String get _prompt => widget.prompt ?? _prompts[_promptIndex];

  @override
  void dispose() {
    _timer?.cancel();
    if (_recording) unawaited(_recorder.cancel());
    unawaited(_recorder.dispose());
    unawaited(_player.dispose());
    _transcriptController.dispose();
    ref.read(voiceActivityProvider.notifier).setActive(false);
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _busy = true;
      _error = null;
      _feedback = null;
      _seconds = 0;
    });
    try {
      final allowed = await _recorder.hasPermission();
      if (!allowed) {
        setState(() => _error = 'Microphone access is needed to record your answer. You can change this in Android settings.');
        return;
      }
      final repository = ref.read(speakingRepositoryProvider);
      final session = await repository.create(prompt: _prompt, type: widget.type);
      final path = '${Directory.systemTemp.path}${Platform.pathSeparator}toungular-${session.id}.m4a';
      await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
      await repository.saveAudioPath(session.id, path);
      _sessionId = session.id;
      _audioPath = path;
      _transcriptController.clear();
      _sessionStarted = true;
      _recording = true;
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

  Future<void> _stop() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final path = await _recorder.stop();
      if (path != null) _audioPath = path;
      _timer?.cancel();
      _recording = false;
      ref.read(voiceActivityProvider.notifier).setActive(false);
    } catch (_) {
      setState(() => _error = 'The recording could not be saved. You can discard it and start again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _discard() async {
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
      _error = null;
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
      await repository.saveTranscript(sessionId, transcript);
      final feedback = await repository.analyze(sessionId, _seconds);
      if (widget.ieltsAttemptId != null && widget.ieltsSectionId != null) {
        await ref.read(ieltsRepositoryProvider).submitResponse(
              widget.ieltsAttemptId!,
              widget.ieltsSectionId!,
              transcript,
            );
      }
      if (mounted) setState(() => _feedback = feedback);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Speaking practice'),
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
                value: _promptIndex,
                decoration: const InputDecoration(labelText: 'Choose a prompt'),
                items: List<DropdownMenuItem<int>>.generate(
                  _prompts.length,
                  (index) => DropdownMenuItem<int>(value: index, child: Text('Prompt ${index + 1}')),
                ),
                onChanged: (value) => setState(() => _promptIndex = value ?? _promptIndex),
              ),
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
              const SizedBox(height: ToungularSpace.s),
              TextField(
                controller: _transcriptController,
                minLines: 4,
                maxLines: 9,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'What did you say?', hintText: 'Type an editable transcript of your answer…'),
              ),
              const SizedBox(height: ToungularSpace.s),
              FilledButton(onPressed: _busy ? null : _analyze, child: Text(_busy ? 'Saving…' : 'Get practice feedback')),
              TextButton(onPressed: _busy ? null : _discard, child: const Text('Discard and try another prompt')),
            ],
            if (_error != null) ...<Widget>[
              const SizedBox(height: ToungularSpace.s),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            if (_feedback != null) ...<Widget>[
              const SizedBox(height: ToungularSpace.l),
              _FeedbackCard(feedback: _feedback!),
              const SizedBox(height: ToungularSpace.s),
              if (widget.ieltsAttemptId != null)
                FilledButton(onPressed: () => context.pop(true), child: const Text('Return to IELTS practice'))
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
  const _FeedbackCard({required this.feedback});

  final SpeakingFeedback feedback;

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
              const SizedBox(height: ToungularSpace.m),
              Text('${feedback.wordCount} words · about ${feedback.wordsPerMinute} words per minute'),
              Text('${feedback.fillerCount} detected filler words · ${feedback.vocabularyVariety} unique-word ratio'),
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
