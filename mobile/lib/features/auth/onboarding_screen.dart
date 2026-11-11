import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/toungular_theme.dart';
import '../../shared/models/learning_models.dart';
import 'profile_repository.dart';
import 'session_controller.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _goalOptions = <String, String>{
    'speakConfidently': 'Speak with confidence',
    'growVocabulary': 'Grow my vocabulary',
    'pronunciation': 'Improve pronunciation',
    'workAndStudy': 'English for work or study',
  };

  final Set<String> _goals = <String>{};
  Proficiency _proficiency = Proficiency.beginner;
  double _dailyMinutes = 15;
  bool _ieltsIntent = false;
  bool _busy = false;
  String? _error;
  bool _initialized = false;

  void _loadProfile(SessionState session) {
    if (_initialized) return;
    _initialized = true;
    final profile = session.session?.profile;
    if (profile == null) return;
    _goals.addAll(profile.goals);
    _proficiency = profile.proficiency;
    _dailyMinutes = profile.dailyMinutes.toDouble().clamp(5, 60).toDouble();
    _ieltsIntent = profile.ieltsIntent;
  }

  Future<void> _signOut() async {
    await ref.read(sessionControllerProvider.notifier).signOut();
    if (mounted) context.go('/auth');
  }

  Future<void> _save() async {
    if (_goals.isEmpty) {
      setState(() => _error = 'Choose at least one learning goal.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final localTimezone = await FlutterTimezone.getLocalTimezone();
      final profile = await ref
          .read(profileRepositoryProvider)
          .update(
            goals: _goals.toList(growable: false),
            proficiency: _proficiency,
            dailyMinutes: _dailyMinutes.round(),
            timezone: localTimezone.identifier,
            ieltsIntent: _ieltsIntent,
          );
      if (!mounted) return;
      ref.read(sessionControllerProvider.notifier).updateProfile(profile);
      context.go('/home');
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted)
        setState(() => _error = 'Your profile could not be saved. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    _loadProfile(session);
    if (!session.isSignedIn) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your English plan'),
        actions: <Widget>[
          TextButton(
            onPressed: _busy ? null : _signOut,
            child: const Text('Sign out'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            ToungularSpace.l,
            ToungularSpace.s,
            ToungularSpace.l,
            ToungularSpace.xl,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'A plan that fits you.',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: ToungularSpace.s),
                  Text(
                    'Tell us what you want to improve. Toungular will shape your daily practice around it.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: ToungularSpace.xl),
                  Text(
                    'Where are you today?',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: ToungularSpace.s),
                  DropdownButtonFormField<Proficiency>(
                    initialValue: _proficiency,
                    decoration: const InputDecoration(
                      labelText: 'English level',
                    ),
                    items: Proficiency.values
                        .map(
                          (level) => DropdownMenuItem<Proficiency>(
                            value: level,
                            child: Text(level.label),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: _busy
                        ? null
                        : (value) => setState(
                            () => _proficiency = value ?? _proficiency,
                          ),
                  ),
                  const SizedBox(height: ToungularSpace.xl),
                  Text(
                    'What would you like to work on?',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: ToungularSpace.s),
                  Wrap(
                    spacing: ToungularSpace.s,
                    runSpacing: ToungularSpace.s,
                    children: _goalOptions.entries
                        .map((goal) {
                          final selected = _goals.contains(goal.key);
                          return FilterChip(
                            selected: selected,
                            label: Text(goal.value),
                            onSelected: _busy
                                ? null
                                : (value) => setState(() {
                                    if (value) {
                                      _goals.add(goal.key);
                                    } else {
                                      _goals.remove(goal.key);
                                    }
                                  }),
                          );
                        })
                        .toList(growable: false),
                  ),
                  const SizedBox(height: ToungularSpace.xl),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'Daily practice time',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      Text(
                        _dailyMinutes.round().toString() + ' min',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  Slider(
                    value: _dailyMinutes,
                    min: 5,
                    max: 60,
                    divisions: 11,
                    label: _dailyMinutes.round().toString() + ' minutes',
                    onChanged: _busy
                        ? null
                        : (value) => setState(() => _dailyMinutes = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('I am preparing for IELTS'),
                    subtitle: const Text(
                      'Include speaking mock practice in my learning plan.',
                    ),
                    value: _ieltsIntent,
                    onChanged: _busy
                        ? null
                        : (value) => setState(() => _ieltsIntent = value),
                  ),
                  const SizedBox(height: ToungularSpace.m),
                  Card(
                    color: ToungularColor.mist,
                    child: Padding(
                      padding: const EdgeInsets.all(ToungularSpace.m),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Icon(Icons.mic_none_rounded, color: colors.primary),
                          const SizedBox(width: ToungularSpace.s),
                          const Expanded(
                            child: Text(
                              'You can explore lessons without a microphone. Toungular will ask for microphone access only when you choose to start speaking practice.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_error != null) ...<Widget>[
                    const SizedBox(height: ToungularSpace.m),
                    Text(_error!, style: TextStyle(color: colors.error)),
                  ],
                  const SizedBox(height: ToungularSpace.l),
                  FilledButton(
                    onPressed: _busy ? null : _save,
                    child: _busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Build my daily plan'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
