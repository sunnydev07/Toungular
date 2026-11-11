import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/toungular_theme.dart';
import '../../shared/models/learning_models.dart';
import 'coach_repository.dart';

class CoachScenariosScreen extends ConsumerStatefulWidget {
  const CoachScenariosScreen({super.key});
  @override
  ConsumerState<CoachScenariosScreen> createState() =>
      _CoachScenariosScreenState();
}

class _CoachScenariosScreenState extends ConsumerState<CoachScenariosScreen> {
  late Future<List<CoachScenario>> _scenarios;
  String? _error;
  String? _startingId;

  @override
  void initState() {
    super.initState();
    _scenarios = ref.read(coachRepositoryProvider).scenarios();
  }

  Future<void> _start(CoachScenario scenario) async {
    setState(() {
      _startingId = scenario.id;
      _error = null;
    });
    try {
      final conversation = await ref
          .read(coachRepositoryProvider)
          .start(scenario.id);
      if (mounted) context.push('/coach/${conversation.id}');
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted)
        setState(
          () => _error = 'This practice scenario could not start. Try again.',
        );
    } finally {
      if (mounted) setState(() => _startingId = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Conversation practice')),
    body: FutureBuilder<List<CoachScenario>>(
      future: _scenarios,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) {
          final error = snapshot.error;
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(ToungularSpace.l),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'Scenarios are unavailable',
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
                    onPressed: () => setState(
                      () => _scenarios = ref
                          .read(coachRepositoryProvider)
                          .scenarios(),
                    ),
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(ToungularSpace.l),
          children: <Widget>[
            Text(
              'Practice a real moment.',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: ToungularSpace.s),
            const Text(
              'Toungular saves your responses and gives you a structured cue. Live AI replies are not enabled yet.',
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: ToungularSpace.s),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: ToungularSpace.l),
            for (final scenario in snapshot.data!) ...<Widget>[
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(ToungularSpace.m),
                  title: Text(
                    scenario.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: ToungularSpace.xs),
                    child: Text(
                      '${scenario.description}\n\nStart: ${scenario.opening}',
                    ),
                  ),
                  trailing: _startingId == scenario.id
                      ? const CircularProgressIndicator()
                      : const Icon(Icons.arrow_forward),
                  onTap: _startingId == null ? () => _start(scenario) : null,
                ),
              ),
              const SizedBox(height: ToungularSpace.s),
            ],
          ],
        );
      },
    ),
  );
}
