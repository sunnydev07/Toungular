import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/toungular_theme.dart';
import 'speaking_repository.dart';

class SpeakingHistoryScreen extends ConsumerStatefulWidget {
  const SpeakingHistoryScreen({super.key});

  @override
  ConsumerState<SpeakingHistoryScreen> createState() =>
      _SpeakingHistoryScreenState();
}

class _SpeakingHistoryScreenState extends ConsumerState<SpeakingHistoryScreen> {
  final _player = AudioPlayer();
  String? _playingId;
  String? _error;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _play(String id) async {
    setState(() => _error = null);
    try {
      final path = await ref.read(speakingRepositoryProvider).audioPath(id);
      if (path == null || !await File(path).exists()) {
        setState(
          () => _error = 'The original audio is not available on this device.',
        );
        return;
      }
      await _player.setFilePath(path);
      setState(() => _playingId = id);
      await _player.play();
      if (mounted) setState(() => _playingId = null);
    } catch (_) {
      if (mounted) {
        setState(() {
          _playingId = null;
          _error = 'This recording could not be played.';
        });
      }
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(speakingHistoryProvider);
    try {
      await ref.read(speakingHistoryProvider.future);
    } catch (_) {
      // The screen shows the recoverable request state.
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Speaking history')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => context.pushReplacement('/speaking'),
      icon: const Icon(Icons.mic),
      label: const Text('Practice'),
    ),
    body: ref
        .watch(speakingHistoryProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(ToungularSpace.l),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'History could not load',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: ToungularSpace.s),
                  Text(
                    error is ApiException
                        ? error.message
                        : 'Reconnect and try again.',
                  ),
                  const SizedBox(height: ToungularSpace.m),
                  OutlinedButton(
                    onPressed: _refresh,
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
          ),
          data: (sessions) {
            if (sessions.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(ToungularSpace.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(Icons.record_voice_over_outlined, size: 52),
                      const SizedBox(height: ToungularSpace.m),
                      Text(
                        'Your practice starts here',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: ToungularSpace.s),
                      const Text(
                        'Your completed recordings and transcript reflections will appear here.',
                      ),
                      const SizedBox(height: ToungularSpace.l),
                      FilledButton(
                        onPressed: () => context.pushReplacement('/speaking'),
                        child: const Text('Start a speaking session'),
                      ),
                    ],
                  ),
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  ToungularSpace.l,
                  ToungularSpace.s,
                  ToungularSpace.l,
                  100,
                ),
                children: <Widget>[
                  if (_error != null) ...<Widget>[
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: ToungularSpace.s),
                  ],
                  for (final session in sessions) ...<Widget>[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(ToungularSpace.m),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    session.startedAt
                                            ?.toLocal()
                                            .toString()
                                            .split('.')
                                            .first ??
                                        'Speaking practice',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Play recording',
                                  onPressed: _playingId == session.id
                                      ? _player.pause
                                      : () => _play(session.id),
                                  icon: Icon(
                                    _playingId == session.id
                                        ? Icons.pause
                                        : Icons.play_arrow,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              session.prompt,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            if ((session.transcript ?? '')
                                .isNotEmpty) ...<Widget>[
                              const SizedBox(height: ToungularSpace.s),
                              Text(
                                'Transcript',
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              const SizedBox(height: ToungularSpace.xs),
                              Text(session.transcript!),
                            ],
                            if (session.feedback != null) ...<Widget>[
                              const SizedBox(height: ToungularSpace.s),
                              Text(
                                session.feedback!.label,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              Text(
                                '${session.feedback!.wordCount} words · ${session.feedback!.fillerCount} filler words · about ${session.feedback!.wordsPerMinute} words/min',
                              ),
                              Text('Next step: ${session.feedback!.nextStep}'),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: ToungularSpace.s),
                  ],
                ],
              ),
            );
          },
        ),
  );
}
