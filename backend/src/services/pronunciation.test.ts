import assert from 'node:assert/strict';
import test from 'node:test';

import { AppError } from '../lib/http.js';
import { DecisionService } from './decision-service.js';
import { MasteryService } from './mastery-service.js';
import { PronunciationService } from './pronunciation-service.js';

function createMockPrisma() {
  const state = {
    userId: 'user-1',
    fluencyXp: 0,
    lexicalXp: 0,
    acousticXp: 0,
    interactionXp: 0,
    totalXp: 0,
    level: 1,
    rankTitle: 'Apprentice',
    freezeTokens: 2,
  };

  return {
    masteryXp: {
      upsert: async () => ({ ...state }),
      update: async ({ data }: any) => {
        if (data.acousticXp?.increment) state.acousticXp += data.acousticXp.increment;
        if (data.totalXp?.increment) state.totalXp += data.totalXp.increment;
        return { ...state };
      },
    },
  } as any;
}

function createMockDecision(): DecisionService {
  return {
    assessAffectiveState: async () => ({
      state: 'calm',
      anxietyIndex: 10,
      confidenceScore: 90,
      scaffoldingRecommended: false,
      supportMessage: 'Clear delivery',
    }),
  } as unknown as DecisionService;
}

test('pronunciation service returns minimal pairs with category and level filters', () => {
  const prisma = createMockPrisma();
  const mastery = new MasteryService(prisma);
  const decision = createMockDecision();
  const service = new PronunciationService(prisma, decision, mastery);

  const allPairs = service.getPairs();
  assert.ok(allPairs.length >= 6);

  const vowels = service.getPairs('vowel');
  assert.ok(vowels.every((p) => p.category === 'vowel'));
  assert.ok(vowels.some((p) => p.id === 'pair-ee-vs-ih'));

  const consonantsA1 = service.getPairs('consonant', 'A1');
  assert.ok(consonantsA1.every((p) => p.category === 'consonant' && p.level === 'A1'));
  assert.ok(consonantsA1.some((p) => p.id === 'pair-r-vs-l'));
});

test('pronunciation service gets pair by id and throws 404 for unknown pair', () => {
  const prisma = createMockPrisma();
  const mastery = new MasteryService(prisma);
  const decision = createMockDecision();
  const service = new PronunciationService(prisma, decision, mastery);

  const pair = service.getPair('pair-th-vs-s');
  assert.equal(pair.title, 'Think vs. Sink');
  assert.equal(pair.phoneticContrast, '/θ/ vs /s/');
  assert.equal(pair.wordA.word, 'Think');
  assert.equal(pair.wordB.word, 'Sink');

  assert.throws(
    () => service.getPair('pair-unknown-999'),
    (err: unknown) => {
      assert.ok(err instanceof AppError);
      assert.equal(err.code, 'PAIR_NOT_FOUND');
      return true;
    },
  );
});

test('pronunciation service detects accurate pronunciation and awards acoustic XP', async () => {
  const prisma = createMockPrisma();
  const mastery = new MasteryService(prisma);
  const decision = createMockDecision();
  const service = new PronunciationService(prisma, decision, mastery);

  const result = await service.analyzeAttempt(
    'user-1',
    'pair-r-vs-l',
    'A', // Target: 'Right'
    'Turn to the right side of the street',
    3,
  );

  assert.equal(result.pairId, 'pair-r-vs-l');
  assert.equal(result.targetWord, 'Right');
  assert.equal(result.isAccurate, true);
  assert.equal(result.confusedWithCounterpart, false);
  assert.ok(result.accuracyScore >= 90);
  assert.equal(result.awardedXp, 25);
  assert.ok(result.phonemeFeedback.includes('Excellent acoustic precision'));
  assert.ok(result.articulatoryTip.includes('curl the tongue'));
});

test('pronunciation service detects phoneme substitution confusion and offers articulatory correction', async () => {
  const prisma = createMockPrisma();
  const mastery = new MasteryService(prisma);
  const decision = createMockDecision();
  const service = new PronunciationService(prisma, decision, mastery);

  const result = await service.analyzeAttempt(
    'user-1',
    'pair-r-vs-l',
    'A', // Target: 'Right', but learner said 'Light'
    'Turn to the light at the corner',
    2,
  );

  assert.equal(result.pairId, 'pair-r-vs-l');
  assert.equal(result.targetWord, 'Right');
  assert.equal(result.isAccurate, false);
  assert.equal(result.confusedWithCounterpart, true);
  assert.ok(result.accuracyScore <= 40);
  assert.equal(result.awardedXp, 10);
  assert.ok(result.phonemeFeedback.includes('Noticeable phoneme substitution'));
  assert.ok(result.phonemeFeedback.includes('Light'));
});

test('pronunciation service integrates acoustic GOP assessor when provided', async () => {
  const prisma = createMockPrisma();
  const mastery = new MasteryService(prisma);
  const decision = createMockDecision();
  const mockAssessor = {
    id: 'mock-azure',
    assess: async (_audio: Buffer, _contentType: string, _referenceText: string) => ({
      accuracyScore: 88,
      fluencyScore: 85,
      completenessScore: 100,
      pronScore: 89,
      words: [
        {
          word: 'Right',
          accuracyScore: 88,
          phonemes: [
            { phoneme: 'r', accuracyScore: 92 },
            { phoneme: 'aɪ', accuracyScore: 86 },
            { phoneme: 't', accuracyScore: 87 },
          ],
        },
      ],
    }),
  };
  const service = new PronunciationService(prisma, decision, mastery, mockAssessor);

  const result = await service.analyzeAttempt(
    'user-1',
    'pair-r-vs-l',
    'A',
    'Right',
    2,
    Buffer.from('fake-audio-bytes'),
    'audio/wav',
  );

  assert.equal(result.pairId, 'pair-r-vs-l');
  assert.equal(result.accuracyScore, 88);
  assert.equal(result.isAccurate, true);
  assert.ok(result.acousticAssessment);
  assert.equal(result.acousticAssessment?.accuracyScore, 88);
  assert.equal(result.acousticAssessment?.phonemes?.length, 3);
  assert.equal(result.acousticAssessment?.phonemes?.[0]?.phoneme, 'r');
});
