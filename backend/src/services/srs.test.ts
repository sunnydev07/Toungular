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
