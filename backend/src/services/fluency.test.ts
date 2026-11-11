import assert from 'node:assert/strict';
import test from 'node:test';

import { analyzeTranscript, wpmTrend } from './fluency.js';

test('transcript analysis counts fillers and separates long pauses', () => {
  const analysis = analyzeTranscript(
    'Um, I like this place, you know, because it is quiet.',
    20,
    [0.6, 2.5],
  );
  assert.equal(analysis.fillerCount, 3);
  assert.equal(analysis.pauseCount, 2);
  assert.equal(analysis.longPauseCount, 1);
  assert.equal(analysis.wordsPerMinute, 33);
  assert.equal(analysis.articulationRate, 39);
});

test('pace trend compares this session with the previous point', () => {
  const trend = wpmTrend([90, 96], 104);
  assert.deepEqual(trend.points, [90, 96, 104]);
  assert.equal(trend.change, 8);
  assert.match(trend.message, /8 words per minute faster/);
});
