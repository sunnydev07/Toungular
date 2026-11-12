import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toungular/features/speaking/speaking_feedback_view.dart';
import 'package:toungular/shared/models/learning_models.dart';

SpeakingFeedback feedback() => const SpeakingFeedback(
  label: 'Practice estimate based on your transcript and session length',
  wordCount: 70,
  uniqueWordCount: 42,
  wordsPerMinute: 118,
  articulationRate: 124,
  fillerCount: 2,
  fillers: <FillerUse>[FillerUse(word: 'um', count: 2, category: 'hesitation')],
  vocabularyVariety: 0.6,
  pauseCount: 3,
  longPauseCount: 1,
  pauseSeconds: 2.5,
  pauseRatio: 0.08,
  pauseNote: 'Pauses were detected from the timings you supplied.',
  wpmChange: 6,
  wpmTrend: <int>[98, 106, 118],
  wpmTrendMessage: 'Your pace is steady and improving.',
  pronunciationMessage: 'Pronunciation scoring is not configured yet.',
  nextStep: 'Add one concrete example to your next answer.',
);

void main() {
  testWidgets('speaking feedback renders pace, fillers, and pauses', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SpeakingFeedbackView(
            feedback: feedback(),
            transcript: 'I usually describe my routine after work.',
            showRetry: true,
            onRetryWithTip: () {},
            onNextPrompt: () {},
            onViewHistory: () {},
          ),
        ),
      ),
    );

    expect(find.text('Pace'), findsOneWidget);
    expect(find.text('118'), findsOneWidget);
    expect(find.text('Fillers'), findsOneWidget);
    expect(find.text('um ×2'), findsOneWidget);
    expect(find.text('Long pauses'), findsOneWidget);
    expect(find.text('Pace trend'), findsOneWidget);
    expect(
      find.text('Pronunciation scoring is not configured yet.'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Try again with this tip'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Try again with this tip'), findsOneWidget);
  });
}
