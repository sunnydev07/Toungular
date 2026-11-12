import assert from 'node:assert/strict';
import test from 'node:test';

import { AppError } from '../lib/http.js';
import { ShadowService } from './shadow-service.js';

// Minimal mock Prisma client for unit testing
const mockPrisma = {
  skillSnapshot: {
    create: async () => ({ id: 'snap-1' }),
  },
} as any;

test('shadow service returns passages and finds individual passage', () => {
  const service = new ShadowService(mockPrisma);
  const passages = service.passages();
  assert.equal(passages.length, 6);
  assert.equal(passages[0]?.id, 'shadow-01-morning-routine');

  const found = service.passage('shadow-01-morning-routine');
  assert.equal(found.title, 'A Simple Morning Routine');
  assert.equal(found.targetWpm, 110);
});

test('shadow service accurately scores speech matching tempo and vocabulary', async () => {
  const service = new ShadowService(mockPrisma);
  const result = await service.analyze(
    'user-1',
    'shadow-01-morning-routine',
    18,
    "Every morning I wake up at seven o'clock. I make a cup of warm tea and sit by the window. It gives me ten quiet minutes before my busy day begins.",
    [1.2, 1.0],
  );

  assert.equal(result.passageId, 'shadow-01-morning-routine');
  assert.ok(result.wordMatchPercent >= 90);
  assert.ok(result.actualWpm > 0);
  assert.ok(result.overallScore >= 80);
  assert.equal(typeof result.rhythmScore, 'number');
  assert.equal(result.assessmentBasis, 'transcript_and_pauses');
  assert.match(result.feedback.paceDiagnosis, /pacing/i);
});

test('shadow service diagnoses rushing and pacing divergence', async () => {
  const service = new ShadowService(mockPrisma);
  // Extremely fast duration (6 seconds for 30 words = 300 WPM)
  const result = await service.analyze(
    'user-1',
    'shadow-01-morning-routine',
    6,
    "Every morning I wake up at seven o'clock. I make a cup of warm tea and sit by the window.",
    [],
  );

  assert.ok(result.actualWpm >= 150);
  assert.equal(result.rhythmScore, null);
  assert.equal(result.assessmentBasis, 'transcript_and_pace');
  assert.match(result.feedback.paceDiagnosis, /faster than the 110 WPM model/i);
});

test('shadow service scores pause timing only when pauses are supplied', async () => {
  const service = new ShadowService(mockPrisma);
  const result = await service.analyze(
    'user-1',
    'shadow-01-morning-routine',
    18,
    "Every morning I wake up at seven o'clock. I make a cup of warm tea and sit by the window. It gives me ten quiet minutes before my busy day begins.",
    [1.5, 1.0],
  );

  assert.equal(typeof result.rhythmScore, 'number');
  assert.equal(result.assessmentBasis, 'transcript_and_pauses');
});

test('shadow service rejects a duration too short for the transcript', async () => {
  const service = new ShadowService(mockPrisma);
  await assert.rejects(
    service.analyze(
      'user-1',
      'shadow-01-morning-routine',
      2,
      "Every morning I wake up at seven o'clock. I make a cup of warm tea and sit by the window. It gives me ten quiet minutes before my busy day begins.",
      [],
    ),
    (error) => error instanceof AppError && error.status === 422,
  );
});

test('shadow service rejects pauses longer than the recording', async () => {
  const service = new ShadowService(mockPrisma);
  await assert.rejects(
    service.analyze(
      'user-1',
      'shadow-01-morning-routine',
      18,
      'Every morning I wake up at seven.',
      [10, 10],
    ),
    (error) => error instanceof AppError && error.status === 422,
  );
});
