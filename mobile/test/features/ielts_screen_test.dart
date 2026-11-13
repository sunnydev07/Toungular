import 'package:flutter_test/flutter_test.dart';
import 'package:toungular/shared/models/learning_models.dart';

void main() {
  test('IeltsBandRubric parses 4 criteria and phrase upgrades', () {
    final rubric = IeltsBandRubric.fromJson(<String, Object?>{
      'overallBandEstimate': 6.5,
      'fluencyAndCoherence': <String, Object?>{
        'score': 6.5,
        'label': 'Fluency & Coherence',
        'notes': 'Good discourse connector usage.',
      },
      'lexicalResource': <String, Object?>{
        'score': 6.0,
        'label': 'Lexical Resource',
        'notes': 'Tier-2 academic items used.',
      },
      'grammaticalRange': <String, Object?>{
        'score': 6.5,
        'label': 'Grammatical Range & Accuracy',
        'notes': 'Varied complex clauses.',
      },
      'pronunciation': <String, Object?>{
        'score': 6.5,
        'label': 'Pronunciation (Intelligibility & Rhythm Proxy)',
        'notes': 'Clear rhythm.',
      },
      'upgradedPhrases': <Object?>[
        <String, Object?>{
          'original': 'it is good',
          'upgraded': 'it is remarkably advantageous',
          'reason': 'Academic evaluative register.',
        },
      ],
      'disclaimer': 'Practice estimate only — not an official IELTS band score.',
    });

    expect(rubric.overallBandEstimate, 6.5);
    expect(rubric.fluencyAndCoherence.score, 6.5);
    expect(rubric.lexicalResource.score, 6.0);
    expect(rubric.grammaticalRange.score, 6.5);
    expect(rubric.pronunciation.score, 6.5);
    expect(rubric.upgradedPhrases.length, 1);
    expect(rubric.upgradedPhrases.first.upgraded, 'it is remarkably advantageous');
    expect(rubric.disclaimer, 'Practice estimate only — not an official IELTS band score.');
  });
}
