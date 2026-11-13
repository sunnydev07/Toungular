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

test('transcript analysis classifies mid-clause vs boundary pauses with wordTimings', () => {
  const analysis = analyzeTranscript(
    'I like coffee, because it is good.',
    10,
    [0.8, 0.9],
    [
      { word: 'I', start: 0.0, end: 0.2 },
      { word: 'like', start: 0.8, end: 1.1 }, // 0.6s gap, mid-clause
      { word: 'coffee,', start: 1.2, end: 1.6 },
      { word: 'because', start: 2.3, end: 2.7 }, // 0.7s gap after comma, boundary
      { word: 'it', start: 2.8, end: 2.9 },
      { word: 'is', start: 3.0, end: 3.1 },
      { word: 'good.', start: 3.2, end: 3.5 },
    ],
  );
  assert.ok(analysis.pauseClassification);
  assert.equal(analysis.pauseClassification?.boundaryPauses, 1);
  assert.equal(analysis.pauseClassification?.midClausePauses, 1);
  assert.match(analysis.pauseNote, /natural phrasing boundaries/);
  assert.match(analysis.pauseNote, /mid-clause/);
});
