import assert from 'node:assert/strict';
import test from 'node:test';

import { buildCloze, nextSchedule, recallModeFor } from './srs.js';

test('a good grade grows the interval with the ease factor', () => {
  const next = nextSchedule(
    { intervalDays: 10, repetitions: 3, easeFactor: 2.5, lapses: 0 },
    'good',
    { now: new Date('2026-01-01T00:00:00Z'), mode: 'definition' },
  );
  assert.equal(next.intervalDays, 26);
  assert.equal(next.repetitions, 4);
  assert.equal(next.easeFactor, 2.6);
});

test('again resets repetitions and records a lapse', () => {
  const next = nextSchedule(
    { intervalDays: 10, repetitions: 3, easeFactor: 2.5, lapses: 1 },
    'again',
    { now: new Date('2026-01-01T00:00:00Z') },
  );
  assert.equal(next.intervalDays, 1);
  assert.equal(next.repetitions, 0);
  assert.equal(next.lapses, 2);
  // One lapse costs a single 0.2 ease step, not the SM-2 polynomial plus 0.2.
  assert.equal(next.easeFactor, 2.3);
});

test('recall modes rotate through the four retrieval styles', () => {
  assert.equal(recallModeFor(0, true), 'definition');
  assert.equal(recallModeFor(1, true), 'cloze');
  assert.equal(recallModeFor(2, true), 'audio');
  assert.equal(recallModeFor(3, true), 'sentence');
  assert.equal(recallModeFor(2, false), 'sentence');
});

test('cloze replaces the target word in its example', () => {
  assert.equal(
    buildCloze('The attentive listener noticed the main concern.', 'attentive'),
    'The ____ listener noticed the main concern.',
  );
  assert.equal(buildCloze('No target here.', 'attentive'), null);
});

test('FSRS-5 computes initial stability and difficulty on first review', () => {
  const next = nextSchedule(
    { intervalDays: 0, repetitions: 0, easeFactor: 2.5, stability: 0, difficulty: 5.0, lapses: 0 },
    'good',
    { now: new Date('2026-01-01T00:00:00Z'), mode: 'definition' },
  );
  assert.equal(next.repetitions, 1);
  assert.equal(next.stability, 3.17);
  assert.equal(next.difficulty, 5.3);
  assert.equal(next.retrievability, 1.0);
  assert.equal(next.intervalDays, 3);
});

test('FSRS-5 applies sentence active recall mode multiplier to stability', () => {
  const next = nextSchedule(
    { intervalDays: 0, repetitions: 0, easeFactor: 2.5, stability: 0, difficulty: 5.0, lapses: 0 },
    'good',
    { now: new Date('2026-01-01T00:00:00Z'), mode: 'sentence' },
  );
  // 3.17 * 1.12 = 3.5504 -> 3.55
  assert.equal(next.stability, 3.55);
  assert.equal(next.intervalDays, 4);
});

test('FSRS-5 subsequent review updates stability and difficulty with mean reversion', () => {
  const next = nextSchedule(
    { intervalDays: 3, repetitions: 1, easeFactor: 2.6, stability: 3.17, difficulty: 5.3, lapses: 0 },
    'good',
    { now: new Date('2026-01-04T00:00:00Z'), elapsedDays: 3, mode: 'definition' },
  );
  assert.equal(next.repetitions, 2);
  assert.ok(next.stability > 3.17);
  assert.ok(next.intervalDays > 3);
  assert.ok(next.retrievability > 0.8 && next.retrievability <= 1.0);
});

test('FSRS-5 lapse resets repetitions and updates lapse stability', () => {
  const next = nextSchedule(
    { intervalDays: 10, repetitions: 3, easeFactor: 2.5, stability: 12.0, difficulty: 5.0, lapses: 0 },
    'again',
    { now: new Date('2026-01-11T00:00:00Z'), elapsedDays: 10 },
  );
  assert.equal(next.repetitions, 0);
  assert.equal(next.lapses, 1);
  assert.equal(next.intervalDays, 1);
  assert.ok(next.stability < 12.0);
});
