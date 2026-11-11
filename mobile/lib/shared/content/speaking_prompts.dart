class SpeakingPrompt {
  const SpeakingPrompt(this.text, this.hints);

  final String text;

  /// Three short cues shown with the prompt; empty for ad-hoc prompts.
  final List<String> hints;
}

const speakingPrompts = <SpeakingPrompt>[
  SpeakingPrompt(
    'Describe a small habit that helps you have a better day.',
    <String>['What the habit is', 'When you do it', 'How it changes your day'],
  ),
  SpeakingPrompt(
    'Tell a friend about a place in your town that you enjoy.',
    <String>[
      'Where it is',
      'What you do there',
      'Why you would bring a friend',
    ],
  ),
  SpeakingPrompt(
    'Explain a skill you would like to learn and why it matters to you.',
    <String>[
      'Which skill',
      'How you would start',
      'What it would open up for you',
    ],
  ),
  SpeakingPrompt(
    'Talk about a time you solved a problem with someone else.',
    <String>['The problem', 'What you each did', 'What you learned'],
  ),
];

/// Deterministic prompt-of-the-day; no storage needed.
int dailyPromptIndex(DateTime now) {
  final days = now.difference(DateTime(2026)).inDays;
  return ((days % speakingPrompts.length) + speakingPrompts.length) %
      speakingPrompts.length;
}
