import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/toungular_theme.dart';
import '../../shared/models/learning_models.dart';
import 'coach_repository.dart';

class CoachConversationScreen extends ConsumerStatefulWidget {
  const CoachConversationScreen({required this.conversationId, super.key});
  final String conversationId;

  @override
  ConsumerState<CoachConversationScreen> createState() => _CoachConversationScreenState();
}

class _CoachConversationScreenState extends ConsumerState<CoachConversationScreen> {
  final _textController = TextEditingController();
  late Future<CoachConversation> _conversation;
  final List<CoachTurn> _newTurns = <CoachTurn>[];
  bool _busy = false;
  String? _cue;
  String? _summary;
  String? _error;

  @override
  void initState() {
    super.initState();
    _conversation = ref.read(coachRepositoryProvider).load(widget.conversationId);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final receipt = await ref.read(coachRepositoryProvider).sendTurn(widget.conversationId, text);
      if (!mounted) return;
      setState(() {
        _newTurns.add(receipt.turn);
        _cue = receipt.practiceCue;
        _textController.clear();
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Your response was not saved. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finish() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final summary = await ref.read(coachRepositoryProvider).finish(widget.conversationId);
      if (mounted) setState(() => _summary = summary);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'This practice session could not be finished.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this practice?'),
        content: const Text('The saved responses in this conversation will be deleted.'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep it')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(coachRepositoryProvider).delete(widget.conversationId);
      if (mounted) context.go('/coach');
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Practice conversation'),
          actions: <Widget>[IconButton(tooltip: 'Delete conversation', onPressed: _busy ? null : _delete, icon: const Icon(Icons.delete_outline))],
        ),
        body: FutureBuilder<CoachConversation>(
          future: _conversation,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError) {
              final error = snapshot.error;
              return Center(child: Padding(padding: const EdgeInsets.all(ToungularSpace.l), child: Text(error is ApiException ? error.message : 'This conversation could not load.')));
            }
            final conversation = snapshot.data!;
            final turns = <CoachTurn>[...conversation.turns, ..._newTurns];
            final complete = conversation.status != 'active' || _summary != null;
            return Column(
              children: <Widget>[
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(ToungularSpace.l),
                    children: <Widget>[
                      Text(conversation.scenario.title, style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: ToungularSpace.s),
                      Card(color: ToungularColor.mist, child: Padding(padding: const EdgeInsets.all(ToungularSpace.m), child: Text(conversation.scenario.opening))),
                      const SizedBox(height: ToungularSpace.m),
                      for (final turn in turns) ...<Widget>[
                        Align(
                          alignment: Alignment.centerRight,
                          child: Card(
                            color: ToungularColor.ink,
                            child: Padding(padding: const EdgeInsets.all(ToungularSpace.m), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 320), child: Text(turn.text, style: const TextStyle(color: Colors.white)))),
                          ),
                        ),
                        const SizedBox(height: ToungularSpace.xs),
                      ],
                      if (_cue != null) ...<Widget>[
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(ToungularSpace.m),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                              Text('Practice cue', style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: ToungularSpace.xs),
                              Text(_cue!),
                              const SizedBox(height: ToungularSpace.xs),
                              const Text('This is a written learning prompt, not an AI reply.', style: TextStyle(fontStyle: FontStyle.italic)),
                            ]),
                          ),
                        ),
                      ],
                      if (_summary != null) Card(child: Padding(padding: const EdgeInsets.all(ToungularSpace.m), child: Text(_summary!))),
                      if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ],
                  ),
                ),
                if (!complete)
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(ToungularSpace.m),
                      child: Column(children: <Widget>[
                        TextField(controller: _textController, minLines: 1, maxLines: 4, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(hintText: 'Write your response…')),
                        const SizedBox(height: ToungularSpace.s),
                        Row(children: <Widget>[
                          Expanded(child: OutlinedButton(onPressed: _busy ? null : _finish, child: const Text('Finish'))),
                          const SizedBox(width: ToungularSpace.s),
                          Expanded(child: FilledButton(onPressed: _busy ? null : _send, child: Text(_busy ? 'Saving…' : 'Save response'))),
                        ]),
                      ]),
                    ),
                  ),
              ],
            );
          },
        ),
      );
}
