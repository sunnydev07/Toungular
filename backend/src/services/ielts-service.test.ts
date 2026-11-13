import assert from 'node:assert/strict';
import test from 'node:test';

import { IeltsService } from './ielts-service.js';

test('IELTS service evaluates attempt with 4 criteria, rounded to half-band, and 2 upgraded phrases', async () => {
  const service = new IeltsService({} as never);
  const responses = [
    {
      sectionId: 'part-1',
      transcript: 'I live in a very quiet neighborhood. However, it is very convenient because shops are near.',
    },
    {
      sectionId: 'part-2',
      transcript:
        'I learned how to code in Python. Furthermore, it required significant strategy and analytical perspective. In addition, I had to consider many complex elements.',
    },
    {
      sectionId: 'part-3',
      transcript:
        'People stay motivated when they see tangible progress. Consequently, setting clear goals is essential, although unexpected challenges occur.',
    },
  ];

  const rubric = await service.evaluateAttemptRubric(responses);

  assert.ok(rubric.overallBandEstimate >= 4.0 && rubric.overallBandEstimate <= 8.5);
  // Verify rounded to half band
  assert.equal(rubric.overallBandEstimate % 0.5, 0);

  // Four criteria verified
  assert.equal(rubric.fluencyAndCoherence.label, 'Fluency & Coherence');
  assert.equal(rubric.fluencyAndCoherence.score % 0.5, 0);

  assert.equal(rubric.lexicalResource.label, 'Lexical Resource');
  assert.equal(rubric.lexicalResource.score % 0.5, 0);

  assert.equal(rubric.grammaticalRange.label, 'Grammatical Range & Accuracy');
  assert.equal(rubric.grammaticalRange.score % 0.5, 0);

  assert.match(rubric.pronunciation.label, /Pronunciation/);
  assert.equal(rubric.pronunciation.score % 0.5, 0);

  // Two phrase upgrades
  assert.equal(rubric.upgradedPhrases.length, 2);
  assert.ok(rubric.upgradedPhrases[0]!.original.length > 0);
  assert.ok(rubric.upgradedPhrases[0]!.upgraded.length > 0);
  assert.ok(rubric.upgradedPhrases[0]!.reason.length > 0);

  // Mandatory non-affiliation disclaimer
  assert.equal(rubric.disclaimer, 'Practice estimate only — not an official IELTS band score.');
});
