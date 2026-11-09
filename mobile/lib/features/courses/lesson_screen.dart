import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/toungular_theme.dart';
import '../../shared/models/learning_models.dart';
import 'curriculum_repository.dart';

class LessonScreen extends ConsumerStatefulWidget {
  const LessonScreen({required this.lessonId, super.key});

  final String lessonId;

  @override
  ConsumerState<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends ConsumerState<LessonScreen> {
  late Future<LessonContent> _lesson;
  bool _saving = false;
  String? _error;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _lesson = ref.read(curriculumRepositoryProvider).loadLesson(widget.lessonId);
  }

  Future<void> _complete() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(curriculumRepositoryProvider).completeLesson(widget.lessonId);
      if (mounted) setState(() => _finished = true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Your progress could not be saved. Please retry.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Lesson')),
        body: FutureBuilder<LessonContent>(
          future: _lesson,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              final error = snapshot.error;
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(ToungularSpace.l),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text('This lesson is unavailable', style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: ToungularSpace.s),
                      Text(error is ApiException ? error.message : 'Reconnect and try again.'),
                      const SizedBox(height: ToungularSpace.m),
                      OutlinedButton(onPressed: () => context.go('/courses'), child: const Text('Back to courses')),
                    ],
                  ),
                ),
              );
            }
            final lesson = snapshot.data!;
            return SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(ToungularSpace.l, ToungularSpace.s, ToungularSpace.l, ToungularSpace.xl),
                children: <Widget>[
                  Text(lesson.courseTitle.toUpperCase(), style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: ToungularSpace.s),
                  Text(lesson.title, style: Theme.of(context).textTheme.displaySmall),
                  const SizedBox(height: ToungularSpace.s),
                  Text('${lesson.durationMin} minute lesson · ${lesson.summary}', style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: ToungularSpace.l),
                  Card(
                    color: ToungularColor.mist,
                    child: Padding(
                      padding: const EdgeInsets.all(ToungularSpace.l),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('Try this pattern', style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: ToungularSpace.s),
                          Text(lesson.content, style: Theme.of(context).textTheme.bodyLarge),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: ToungularSpace.l),
                  Text('Make it yours', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: ToungularSpace.s),
                  Text('Write or say a sentence using this idea. Your draft stays on this screen while you practice.'),
                  const SizedBox(height: ToungularSpace.m),
                  const TextField(
                    minLines: 3,
                    maxLines: 6,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(hintText: 'Your example sentence…'),
                  ),
                  const SizedBox(height: ToungularSpace.l),
                  if (_finished || lesson.completedAt != null)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(ToungularSpace.m),
                        child: Row(children: <Widget>[Icon(Icons.check_circle, color: ToungularColor.leaf), SizedBox(width: ToungularSpace.s), Text('Lesson complete. Nice work!')]),
                      ),
                    )
                  else
                    FilledButton.icon(
                      onPressed: _saving ? null : _complete,
                      icon: _saving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check),
                      label: const Text('Complete lesson'),
                    ),
                  if (_error != null) ...<Widget>[
                    const SizedBox(height: ToungularSpace.s),
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: ToungularSpace.s),
                  TextButton(onPressed: () => context.go('/courses'), child: const Text('Return to course path')),
                ],
              ),
            );
          },
        ),
      );
}
