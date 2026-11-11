import assert from 'node:assert/strict';
import test from 'node:test';

import { JevClient } from '../providers/jev-client.js';
import { DecisionService } from './decision-service.js';

test('jev client formats queries and processes decisions correctly', async () => {
  const client = new JevClient(undefined);
  const result = await client.query({
    state: 'Learner is speaking with hesitation: pause_count=6, wpm=85.',
    questions: [
      { id: 'anxiety_state', type: 'choice', options: ['calm', 'mild_hesitation', 'high_anxiety'], description: 'anxiety level' },
      { id: 'should_scaffold', type: 'noul', description: 'is scaffolding needed' },
      { id: 'fluency_score', type: 'score', description: 'fluency score' },
    ],
  });

  assert.ok(result.decisions['anxiety_state']);
  assert.equal(result.decisions['anxiety_state']?.type, 'choice');
  assert.ok(result.decisions['should_scaffold']);
  assert.equal(result.decisions['should_scaffold']?.type, 'noul');
  assert.ok(result.decisions['fluency_score']);
  assert.equal(result.decisions['fluency_score']?.type, 'score');
});

test('decision service assesses affective state and recommends scaffolding', async () => {
  const client = new JevClient(undefined);
  const service = new DecisionService(client);

  const calmResult = await service.assessAffectiveState({
    transcript: 'I had a wonderful morning walking in the park.',
    durationSeconds: 15,
    pauseCount: 1,
    wpm: 135,
  });

  assert.equal(calmResult.anxietyState, 'calm');
  assert.equal(calmResult.shouldScaffold, false);

  const anxiousResult = await service.assessAffectiveState({
    transcript: 'I... uh... I freeze... I do not know... pause_count=7',
    durationSeconds: 20,
    pauseCount: 7,
    wpm: 60,
  });

  assert.ok(anxiousResult.shouldScaffold);
  assert.notEqual(anxiousResult.anxietyState, 'calm');
});

test('decision service accurately calibrates CEFR level from lexical range', async () => {
  const client = new JevClient(undefined);
  const service = new DecisionService(client);

  const c1Result = await service.calibrateCefrLevel({
    transcript: 'The subtle cadence and rhetorical resonance created an enduring emotional equilibrium.',
    targetWordsUsed: ['cadence', 'resonance'],
  });

  assert.equal(c1Result.calibratedCefr, 'C1');
  assert.ok(c1Result.lexicalRange > 0);

  const a1Result = await service.calibrateCefrLevel({
    transcript: 'I like apples and bananas. They are fresh.',
    targetWordsUsed: ['fresh'],
  });

  assert.equal(a1Result.calibratedCefr, 'A1');
});

test('decision service gates coach turns and classifies error categories', async () => {
  const client = new JevClient(undefined);
  const service = new DecisionService(client);

  const errorResult = await service.gateCoachTurn({
    scenarioTitle: 'Ordering coffee',
    previousTurns: [{ role: 'assistant', text: 'What would you like today?' }],
    learnerTurn: 'Yesterday I goed to store and buyed two coffee.',
  });

  assert.equal(errorResult.isOffTopic, false);
  assert.equal(errorResult.needsRecast, true);
});

test('decision service predicts SM-2 recall grade and lapse risk', async () => {
  const client = new JevClient(undefined);
  const service = new DecisionService(client);

  const correctFast = await service.predictSrsGrade({
    intervalDays: 6,
    repetitions: 3,
    responseTimeMs: 850,
    isCorrect: true,
  });

  assert.notEqual(correctFast.predictedGrade, 'again');
  assert.ok(correctFast.lapseRisk < 0.5);

  const failure = await service.predictSrsGrade({
    intervalDays: 1,
    repetitions: 0,
    responseTimeMs: 9000,
    isCorrect: false,
  });

  assert.equal(failure.predictedGrade, 'again');
  assert.ok(failure.lapseRisk > 0.5);
});
