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
import 'coach_repository.dart';

class CoachConversationScreen extends ConsumerStatefulWidget {
  const CoachConversationScreen({required this.conversationId, super.key});
  final String conversationId;

  @override
  ConsumerState<CoachConversationScreen> createState() =>
      _CoachConversationScreenState();
}

class _CoachConversationScreenState
    extends ConsumerState<CoachConversationScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _player = AudioPlayer();
  final _recorder = AudioRecorder();

  late Future<CoachConversation> _conversation;
  final List<CoachTurn> _newTurns = <CoachTurn>[];
  bool _busy = false;
  bool _recording = false;
  bool _transcribing = false;
  bool _sttAvailable = false;
  bool _handsFreeCall = false;
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  bool _speechDetected = false;
  int _speechDurationMs = 0;
  int _silenceDurationMs = 0;
  String? _playingTurnId;
  Duration _recordDuration = Duration.zero;
  Timer? _timer;
  String? _recordingPath;

  String? _cue;
  String? _lastRecast;
  CoachTurnGate? _lastTurnGate;
  String? _summary;
  String? _error;

  @override
  void initState() {
    super.initState();
    _conversation = ref
        .read(coachRepositoryProvider)
        .load(widget.conversationId);
    _checkVoiceStatus();
  }

  Future<void> _checkVoiceStatus() async {
    try {
      final status = await ref.read(voiceRepositoryProvider).status();
      if (mounted) {
        setState(() => _sttAvailable = status.sttAvailable);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    _amplitudeSubscription?.cancel();
    if (_recording) unawaited(_recorder.cancel());
    _player.dispose();
    _recorder.dispose();
    _textController.dispose();
    _scrollController.dispose();
    ref.read(voiceActivityProvider.notifier).setActive(false);
    final path = _recordingPath;
    if (path != null) {
      try {
        final file = File(path);
        if (file.existsSync()) {
          file.deleteSync();
        }
      } catch (_) {}
    }
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _toggleTts(CoachTurn turn) async {
    if (_playingTurnId == turn.id) {
      await _player.stop();
      if (mounted) setState(() => _playingTurnId = null);
      return;
    }

    try {
      if (mounted) {
        setState(() {
          _playingTurnId = turn.id;
          _error = null;
        });
      }
      final path = await ref
          .read(voiceRepositoryProvider)
          .synthesizeToFile(turn.text);
      await _player.setFilePath(path);
      await _player.play();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not generate speech audio for this turn.',
        );
      }
    } finally {
      if (mounted) setState(() => _playingTurnId = null);
    }
  }

  Future<void> _toggleRecording() async {
    if (_recording) {
      await _amplitudeSubscription?.cancel();
      _amplitudeSubscription = null;
      final path = await _recorder.stop();
      _recordingPath = null;
      _timer?.cancel();
      ref.read(voiceActivityProvider.notifier).setActive(false);
      setState(() {
        _recording = false;
        _recordDuration = Duration.zero;
        _transcribing = true;
      });

      if (path != null) {
        try {
          final text = await ref
              .read(voiceRepositoryProvider)
              .transcribe(File(path));
          if (mounted && text.isNotEmpty) {
            _textController.text = text;
          }
        } catch (_) {
          if (mounted) {
            setState(
              () => _error = 'Audio transcription failed. You can type your response instead.',
            );
          }
        } finally {
          try {
            final file = File(path);
            if (await file.exists()) {
              await file.delete();
            }
          } catch (_) {}
          if (mounted) setState(() => _transcribing = false);
        }
      } else {
        if (mounted) setState(() => _transcribing = false);
      }
    } else {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        setState(
          () => _error = 'Microphone permission is required to record audio.',
        );
        return;
      }
      final path =
          '${Directory.systemTemp.path}${Platform.pathSeparator}toungular-coach-${DateTime.now().millisecondsSinceEpoch}.m4a';
      _recordingPath = path;
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
      ref.read(voiceActivityProvider.notifier).setActive(true);
      setState(() {
        _recording = true;
        _recordDuration = Duration.zero;
        _error = null;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() => _recordDuration += const Duration(seconds: 1));
        }
      });

      if (_handsFreeCall) {
        _startVadListening();
      }
    }
  }

  void _startVadListening() {
    _amplitudeSubscription?.cancel();
    _speechDetected = false;
    _speechDurationMs = 0;
    _silenceDurationMs = 0;

    _amplitudeSubscription = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 200))
        .listen((amp) {
      if (!_recording || !_handsFreeCall || !mounted) return;
      final dbfs = amp.current;
      if (dbfs > -35.0) {
        _speechDurationMs += 200;
        _silenceDurationMs = 0;
        if (_speechDurationMs >= 400) {
          _speechDetected = true;
        }
      } else if (dbfs < -40.0) {
        if (_speechDetected) {
          _silenceDurationMs += 200;
          if (_silenceDurationMs >= 1500) {
            _amplitudeSubscription?.cancel();
            _amplitudeSubscription = null;
            unawaited(_autoStopAndSend());
          }
        }
      }
    });
  }

  Future<void> _autoStopAndSend() async {
    if (!_recording) return;
    await _toggleRecording();
    if (mounted && _textController.text.trim().isNotEmpty) {
      await _send();
    }
  }

  Future<void> _send() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final receipt = await ref
          .read(coachRepositoryProvider)
          .sendTurn(widget.conversationId, text);
      if (!mounted) return;
      setState(() {
        _newTurns.add(receipt.turn);
        if (receipt.replyTurn != null) {
          _newTurns.add(receipt.replyTurn!);
        }
        _cue = receipt.practiceCue;
        if (receipt.recast != null) {
          _lastRecast = receipt.recast;
        }
        if (receipt.turnGate != null) {
          _lastTurnGate = receipt.turnGate;
        }
        _textController.clear();
      });
      _scrollToBottom();

      if (_handsFreeCall && receipt.replyTurn != null && mounted) {
        setState(() => _busy = false);
        await _toggleTts(receipt.replyTurn!);
        if (mounted && _handsFreeCall && !_recording && !_busy && _summary == null) {
          await _toggleRecording();
        }
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Your response was not saved. Try again.');
      }
    } finally {
      if (mounted && _busy) setState(() => _busy = false);
    }
  }

  Future<void> _finish() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final summary = await ref
          .read(coachRepositoryProvider)
          .finish(widget.conversationId);
      // A finished live conversation is the Level 6 comfort-path session.
      try {
        await ref.read(exposureRepositoryProvider).complete(6);
      } catch (_) {}

      if (mounted) {
        setState(() => _summary = summary);
        _scrollToBottom();
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'This practice session could not be finished.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this practice?'),
        content: const Text(
          'The saved responses in this conversation will be deleted.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(coachRepositoryProvider).delete(widget.conversationId);
      if (mounted) context.pop();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Practice conversation'),
      actions: <Widget>[
        if (_sttAvailable)
          IconButton(
            tooltip: _handsFreeCall
                ? 'Hands-free call active (tap to turn off)'
                : 'Hands-free voice call mode',
            icon: Icon(
              _handsFreeCall ? Icons.headset_mic : Icons.spatial_audio_off,
              color: _handsFreeCall ? ToungularColor.leaf : null,
            ),
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _handsFreeCall = !_handsFreeCall);
                    if (_handsFreeCall) {
                      if (!_recording && !_busy) {
                        await _toggleRecording();
                      } else if (_recording) {
                        _startVadListening();
                      }
                    } else {
                      await _amplitudeSubscription?.cancel();
                      _amplitudeSubscription = null;
                    }
                  },
          ),
        IconButton(
          tooltip: 'Delete conversation',
          onPressed: _busy || _recording ? null : _delete,
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    ),
    body: FutureBuilder<CoachConversation>(
      future: _conversation,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          final error = snapshot.error;
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(ToungularSpace.l),
              child: Text(
                error is ApiException
                    ? error.message
                    : 'This conversation could not load.',
              ),
            ),
          );
        }
        final conversation = snapshot.data!;
        final turns = <CoachTurn>[...conversation.turns, ..._newTurns];
        final complete = conversation.status != 'active' || _summary != null;

        return Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.all(ToungularSpace.l),
                children: <Widget>[
                  Text(
                    conversation.scenario.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: ToungularSpace.s),
                  Card(
                    color: ToungularColor.mist,
                    child: Padding(
                      padding: const EdgeInsets.all(ToungularSpace.m),
                      child: Row(
                        children: <Widget>[
                          const Icon(
                            Icons.flag_outlined,
                            color: ToungularColor.leaf,
                          ),
                          const SizedBox(width: ToungularSpace.s),
                          Expanded(child: Text(conversation.scenario.opening)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: ToungularSpace.m),
                  for (final turn in turns) ...<Widget>[
                    _TurnBubble(
                      turn: turn,
                      isPlaying: _playingTurnId == turn.id,
                      onToggleTts: () => _toggleTts(turn),
                    ),
                    const SizedBox(height: ToungularSpace.s),
                  ],
                  if (_lastRecast != null) ...<Widget>[
                    Card(
                      color: const Color(0xFFF1F8E9),
                      child: Padding(
                        padding: const EdgeInsets.all(ToungularSpace.m),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Icon(
                              Icons.lightbulb_outline,
                              color: Color(0xFF558B2F),
                            ),
                            const SizedBox(width: ToungularSpace.s),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Row(
                                    children: <Widget>[
                                      const Text(
                                        'Natural phrasing tip',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF2E7D32),
                                        ),
                                      ),
                                      if (_lastTurnGate?.needsRecast == true &&
                                          _lastTurnGate?.errorCategory != null &&
                                          _lastTurnGate!.errorCategory.isNotEmpty) ...<Widget>[
                                        const SizedBox(width: ToungularSpace.s),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFC8E6C9),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            _lastTurnGate!.errorCategory,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF1B5E20),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: ToungularSpace.xs),
                                  Text(
                                    _lastRecast!,
                                    style: const TextStyle(
                                      color: Color(0xFF1B5E20),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: ToungularSpace.s),
                  ],
                  if (_cue != null) ...<Widget>[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(ToungularSpace.m),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Practice cue',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: ToungularSpace.xs),
                            Text(_cue!),
                            const SizedBox(height: ToungularSpace.xs),
                            const Text(
                              'Try incorporating this prompt into your next reply.',
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: ToungularSpace.s),
                  ],
                  if (_summary != null) ...<Widget>[
                    Card(
                      color: ToungularColor.lime.withValues(alpha: 0.3),
                      child: Padding(
                        padding: const EdgeInsets.all(ToungularSpace.l),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                const Icon(
                                  Icons.check_circle,
                                  color: ToungularColor.leaf,
                                ),
                                const SizedBox(width: ToungularSpace.s),
                                Text(
                                  'Practice summary',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                              ],
                            ),
                            const SizedBox(height: ToungularSpace.s),
                            Text(_summary!),
                            const SizedBox(height: ToungularSpace.m),
                            FilledButton(
                              onPressed: () => context.pop(),
                              child: const Text('Back to scenarios'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (_error != null) ...<Widget>[
                    const SizedBox(height: ToungularSpace.s),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!complete)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(ToungularSpace.m),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (_recording)
                        Container(
                          margin: const EdgeInsets.only(
                            bottom: ToungularSpace.s,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: ToungularSpace.m,
                            vertical: ToungularSpace.s,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: <Widget>[
                              const Icon(
                                Icons.fiber_manual_record,
                                color: Colors.red,
                                size: 16,
                              ),
                              const SizedBox(width: ToungularSpace.s),
                              Text(
                                _handsFreeCall
                                    ? 'Hands-free call… ${_recordDuration.inSeconds}s (pause speaking to send)'
                                    : 'Listening… ${_recordDuration.inSeconds}s (Tap mic to stop)',
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_transcribing)
                        const Padding(
                          padding: EdgeInsets.only(bottom: ToungularSpace.s),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: ToungularSpace.s),
                              Text('Transcribing speech…'),
                            ],
                          ),
                        ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          Expanded(
                            child: TextField(
                              controller: _textController,
                              minLines: 1,
                              maxLines: 4,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: InputDecoration(
                                hintText: _recording
                                    ? 'Recording…'
                                    : 'Write or speak your reply…',
                              ),
                            ),
                          ),
                          const SizedBox(width: ToungularSpace.s),
                          IconButton.filled(
                            onPressed: _busy || _transcribing
                                ? null
                                : _toggleRecording,
                            icon: Icon(_recording ? Icons.stop : Icons.mic),
                            style: IconButton.styleFrom(
                              backgroundColor: _recording
                                  ? Colors.red
                                  : ToungularColor.leaf,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: ToungularSpace.s),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _busy || _recording ? null : _finish,
                              child: const Text('Finish'),
                            ),
                          ),
                          const SizedBox(width: ToungularSpace.s),
                          Expanded(
                            child: FilledButton(
                              onPressed: _busy || _recording ? null : _send,
                              child: Text(_busy ? 'Replying…' : 'Send reply'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class _TurnBubble extends StatelessWidget {
  const _TurnBubble({
    required this.turn,
    required this.isPlaying,
    required this.onToggleTts,
  });

  final CoachTurn turn;
  final bool isPlaying;
  final VoidCallback onToggleTts;

  @override
  Widget build(BuildContext context) {
    final isAssistant = turn.role == 'assistant';

    if (isAssistant) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const CircleAvatar(
            radius: 16,
            backgroundColor: ToungularColor.leaf,
            child: Icon(Icons.psychology, size: 18, color: Colors.white),
          ),
          const SizedBox(width: ToungularSpace.s),
          Expanded(
            child: Card(
              color: ToungularColor.mist,
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(ToungularSpace.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'AI Coach',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: ToungularColor.leaf,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: ToungularSpace.xs),
                    Text(
                      turn.text,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: ToungularSpace.xs),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: onToggleTts,
                        icon: Icon(
                          isPlaying ? Icons.stop_circle : Icons.volume_up,
                          size: 16,
                        ),
                        label: Text(
                          isPlaying ? 'Playing' : 'Listen',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: ToungularSpace.xl),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        const SizedBox(width: ToungularSpace.xl),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: Card(
              color: ToungularColor.ink,
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(ToungularSpace.m),
                child: Text(
                  turn.text,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: ToungularSpace.s),
        const CircleAvatar(
          radius: 16,
          backgroundColor: ToungularColor.ink,
          child: Icon(Icons.person, size: 18, color: Colors.white),
        ),
      ],
    );
  }
}
