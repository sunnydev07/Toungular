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

  testWidgets('speaking feedback renders affective support and CEFR calibration cards', (
    tester,
  ) async {
    const testFeedback = SpeakingFeedback(
      label: 'Practice estimate',
      wordCount: 80,
      uniqueWordCount: 50,
      wordsPerMinute: 120,
      articulationRate: 130,
      fillerCount: 1,
      fillers: <FillerUse>[FillerUse(word: 'like', count: 1, category: 'hesitation')],
      vocabularyVariety: 0.65,
      pauseCount: 2,
      longPauseCount: 0,
      pauseSeconds: 1.0,
      pauseRatio: 0.05,
      pauseNote: 'Natural phrasing.',
      wpmChange: 4,
      wpmTrend: <int>[110, 116, 120],
      wpmTrendMessage: 'Great progress.',
      pronunciationMessage: 'Clear.',
      nextStep: 'Try Part 2 mock.',
      affective: AffectiveAssessmentResult(
        anxietyState: 'mild_hesitation',
        shouldScaffold: true,
        intervention: 'step_down_to_whisper',
        confidenceScore: 0.6,
        latencyMs: 120,
        provider: 'jev',
      ),
      cefrCalibration: CefrCalibrationResult(
        calibratedCefr: 'B2',
        syntacticComplexity: 0.75,
        lexicalRange: 0.80,
        adaptiveAction: 'promote_higher',
        latencyMs: 140,
        provider: 'jev',
      ),
    );

    String? openedCefrLevel;
    bool steppedDown = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SpeakingFeedbackView(
            feedback: testFeedback,
            showRetry: false,
            onNextPrompt: () {},
            onViewHistory: () {},
            onOpenCefrContent: (level) => openedCefrLevel = level,
            onStepDownToWhisper: () => steppedDown = true,
          ),
        ),
      ),
    );

    await tester.scrollUntilVisible(
      find.text('Try Whisper Comfort Path'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Affective Support'), findsOneWidget);
    expect(find.text('Try Whisper Comfort Path'), findsOneWidget);

    await tester.tap(find.text('Try Whisper Comfort Path'));
    expect(steppedDown, isTrue);

    await tester.scrollUntilVisible(
      find.text('Explore B2 Content'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('CEFR Calibration'), findsOneWidget);
    expect(find.text('B2'), findsOneWidget);
    expect(find.text('Explore B2 Content'), findsOneWidget);

    await tester.tap(find.text('Explore B2 Content'));
    expect(openedCefrLevel, 'B2');
  });
}
