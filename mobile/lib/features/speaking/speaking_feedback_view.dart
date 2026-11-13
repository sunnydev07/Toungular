import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/toungular_theme.dart';
import '../../shared/models/learning_models.dart';

/// Feedback state of the speaking loop: one screen for the numbers, the trend,
/// the transcript and the single retry action.
class SpeakingFeedbackView extends StatelessWidget {
  const SpeakingFeedbackView({
    super.key,
    required this.feedback,
    this.affective,
    this.transcript = '',
    required this.showRetry,
    this.onRetryWithTip,
    required this.onNextPrompt,
    this.onReturnToIelts,
    this.onBackToComfort,
    required this.onViewHistory,
    this.onOpenCefrContent,
    this.onStepDownToWhisper,
  });

  final SpeakingFeedback feedback;
  final AffectiveAssessmentResult? affective;
  final String transcript;
  final bool showRetry;
  final VoidCallback? onRetryWithTip;
  final VoidCallback onNextPrompt;
  final VoidCallback? onReturnToIelts;
  final VoidCallback? onBackToComfort;
  final VoidCallback onViewHistory;
  final ValueChanged<String>? onOpenCefrContent;
  final VoidCallback? onStepDownToWhisper;

  void _handleStepDown(BuildContext context) {
    if (onStepDownToWhisper != null) {
      onStepDownToWhisper!();
    } else if (onBackToComfort != null) {
      onBackToComfort!();
    } else {
      context.push('/exposure');
    }
  }

  void _handleOpenCefr(BuildContext context, String level) {
    if (onOpenCefrContent != null) {
      onOpenCefrContent!(level);
    } else {
      context.push('/content?level=$level');
    }
  }

  @override
  Widget build(BuildContext context) {
    final topFiller = feedback.fillers.isEmpty ? null : feedback.fillers.first;
    final delta = feedback.wpmChange;
    final effectiveAffective = affective ?? feedback.affective;
    final cefr = feedback.cefrCalibration;
    final affectiveLine = effectiveAffective == null
        ? null
        : effectiveAffective.anxietyState == 'calm'
        ? 'You sounded calm and steady.'
        : 'You sounded a little tense — keep it slow and steady.';

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        ToungularSpace.l,
        ToungularSpace.s,
        ToungularSpace.l,
        ToungularSpace.xl,
      ),
      children: <Widget>[
        Text(feedback.label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: ToungularSpace.m),
        Row(
          children: <Widget>[
            Expanded(
              child: _Metric(
                label: 'Pace',
                value: '${feedback.wordsPerMinute}',
                unit: 'wpm',
                note: delta == null
                    ? null
                    : '${delta > 0 ? '+' : ''}$delta vs last session',
              ),
            ),
            const SizedBox(width: ToungularSpace.s),
            Expanded(
              child: _Metric(
                label: 'Fillers',
                value: '${feedback.fillerCount}',
                unit: 'words',
                note: topFiller == null
                    ? null
                    : '${topFiller.word} ×${topFiller.count}',
              ),
            ),
            const SizedBox(width: ToungularSpace.s),
            Expanded(
              child: _Metric(
                label: 'Long pauses',
                value: '${feedback.longPauseCount}',
                unit: 'count',
              ),
            ),
          ],
        ),
        const SizedBox(height: ToungularSpace.xs),
        Text(feedback.pauseNote, style: Theme.of(context).textTheme.bodyMedium),
        if (feedback.wpmTrend.length >= 2) ...<Widget>[
          const SizedBox(height: ToungularSpace.m),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(ToungularSpace.m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Pace trend',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: ToungularSpace.s),
                  SizedBox(
                    height: 72,
                    child: CustomPaint(
                      size: const Size(double.infinity, 72),
                      painter: _TrendPainter(points: feedback.wpmTrend),
                    ),
                  ),
                  const SizedBox(height: ToungularSpace.xs),
                  Text(
                    feedback.wpmTrendMessage,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: ToungularSpace.m),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(ToungularSpace.m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Pronunciation',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: ToungularSpace.xs),
                Text(
                  feedback.pronunciationMessage,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: ToungularSpace.m),
        Container(
          padding: const EdgeInsets.all(ToungularSpace.m),
          decoration: BoxDecoration(
            color: ToungularColor.ink,
            borderRadius: BorderRadius.circular(ToungularRadius.card),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Next step',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(color: ToungularColor.lime),
              ),
              const SizedBox(height: ToungularSpace.xs),
              Text(
                feedback.nextStep,
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(color: Colors.white),
              ),
            ],
          ),
        ),
        if (effectiveAffective != null && effectiveAffective.shouldScaffold) ...<Widget>[
          const SizedBox(height: ToungularSpace.m),
          Card(
            margin: EdgeInsets.zero,
            color: Theme.of(context).colorScheme.tertiaryContainer.withValues(alpha: 0.3),
            child: Padding(
              padding: const EdgeInsets.all(ToungularSpace.m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Icon(Icons.psychology_outlined, size: 20),
                      const SizedBox(width: ToungularSpace.xs),
                      Text(
                        'Affective Support',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Spacer(),
                      Chip(
                        label: Text(
                          effectiveAffective.anxietyState.replaceAll('_', ' '),
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: ToungularSpace.xs),
                  if (effectiveAffective.intervention == 'step_down_to_whisper') ...<Widget>[
                    const Text(
                      'Speaking pressure seems elevated right now. Step down to low-stress whisper exposure to build comfort:',
                    ),
                    const SizedBox(height: ToungularSpace.s),
                    FilledButton.tonalIcon(
                      onPressed: () => _handleStepDown(context),
                      icon: const Icon(Icons.spa_outlined),
                      label: const Text('Try Whisper Comfort Path'),
                    ),
                  ] else if (effectiveAffective.intervention == 'provide_sentence_starter') ...<Widget>[
                    const Text(
                      'Starter cue: "When I think about this, one clear reason is..."',
                    ),
                    const SizedBox(height: ToungularSpace.s),
                    OutlinedButton.icon(
                      onPressed: onRetryWithTip,
                      icon: const Icon(Icons.lightbulb_outline),
                      label: const Text('Retry with sentence starter'),
                    ),
                  ] else ...<Widget>[
                    Text(
                      'Great effort pushing through hesitation — building conversational momentum takes practice!',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
        if (cefr != null) ...<Widget>[
          const SizedBox(height: ToungularSpace.m),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(ToungularSpace.m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Icon(Icons.auto_graph_outlined, size: 20),
                      const SizedBox(width: ToungularSpace.xs),
                      Text(
                        'CEFR Calibration',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Spacer(),
                      Chip(
                        backgroundColor: ToungularColor.lime,
                        label: Text(
                          cefr.calibratedCefr,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: ToungularColor.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: ToungularSpace.s),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'Syntactic complexity: ${(cefr.syntacticComplexity * 100).toInt()}%',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Lexical range: ${(cefr.lexicalRange * 100).toInt()}%',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: ToungularSpace.s),
                  FilledButton.tonalIcon(
                    onPressed: () => _handleOpenCefr(context, cefr.calibratedCefr),
                    icon: const Icon(Icons.menu_book_outlined),
                    label: Text('Explore ${cefr.calibratedCefr} Content'),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (affectiveLine != null) ...<Widget>[
          const SizedBox(height: ToungularSpace.m),
          Row(
            children: <Widget>[
              Icon(
                effectiveAffective!.anxietyState == 'calm'
                    ? Icons.spa_outlined
                    : Icons.self_improvement_outlined,
                size: 18,
                color: ToungularColor.leaf,
              ),
              const SizedBox(width: ToungularSpace.xs),
              Expanded(
                child: Text(
                  affectiveLine,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: ToungularSpace.m),
        if (transcript.isNotEmpty)
          Card(
            margin: EdgeInsets.zero,
            child: ExpansionTile(
              shape: const Border(),
              title: Text(
                'Transcript',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    ToungularSpace.m,
                    0,
                    ToungularSpace.m,
                    ToungularSpace.m,
                  ),
                  child: Text(
                    transcript,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: ToungularSpace.l),
        if (showRetry)
          FilledButton.icon(
            onPressed: onRetryWithTip,
            icon: const Icon(Icons.replay_rounded),
            label: const Text('Try again with this tip'),
          ),
        if (showRetry) const SizedBox(height: ToungularSpace.s),
        if (onReturnToIelts != null)
          FilledButton(
            onPressed: onReturnToIelts,
            child: const Text('Return to IELTS practice'),
          )
        else if (onBackToComfort != null)
          FilledButton(
            onPressed: onBackToComfort,
            child: const Text('Back to comfort path'),
          )
        else ...<Widget>[
          TextButton(onPressed: onNextPrompt, child: const Text('Next prompt')),
          TextButton(
            onPressed: onViewHistory,
            child: const Text('View speaking history'),
          ),
        ],
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.unit,
    this.note,
  });

  final String label;
  final String value;
  final String unit;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(ToungularSpace.s),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(fontSize: 12),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontSize: 26),
            ),
            Text(
              unit,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(fontSize: 12),
            ),
            if (note != null) ...<Widget>[
              const SizedBox(height: 2),
              Text(
                note!,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter({required this.points});

  final List<int> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    var min = points.first;
    var max = points.first;
    for (final point in points) {
      if (point < min) min = point;
      if (point > max) max = point;
    }
    final span = (max - min) == 0 ? 1 : (max - min);
    final step = size.width / (points.length - 1);
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = i * step;
      final y =
          size.height - 8 - ((points[i] - min) / span) * (size.height - 16);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final paint = Paint()
      ..color = ToungularColor.leaf
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, paint);

    final dot = Paint()..color = ToungularColor.leaf;
    for (var i = 0; i < points.length; i++) {
      final x = i * step;
      final y =
          size.height - 8 - ((points[i] - min) / span) * (size.height - 16);
      canvas.drawCircle(
        Offset(x, math.max(4, math.min(size.height - 4, y))),
        3.5,
        dot,
      );
    }
  }

  @override
  bool shouldRepaint(_TrendPainter oldDelegate) => oldDelegate.points != points;
}
