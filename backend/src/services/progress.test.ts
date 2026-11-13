import assert from 'node:assert/strict';
import test from 'node:test';

import { ProgressService } from './progress-service.js';

function createDatabase(now: Date) {
  return {
    lessonProgress: {
      count: async () => 3,
      findMany: async () => [{ completedAt: now }],
    },
    reviewSchedule: {
      aggregate: async () => ({ _sum: { repetitions: 7 }, _count: { _all: 5 } }),
      findMany: async () => [],
    },
    speakingSession: {
      count: async () => 2,
      findMany: async ({ where }: { where: { completedAt?: unknown; select?: unknown } }) => {
        if (where.completedAt) return [{ completedAt: now }];
        return [
          { id: 's1', prompt: 'Describe your day', status: 'completed', startedAt: now, completedAt: now },
        ];
      },
    },
    skillSnapshot: {
      findMany: async ({ where }: { where: { source?: unknown; skill?: unknown } }) => {
        if (typeof where.skill === 'object' && where.skill !== null && 'in' in where.skill) {
          return [{ recordedAt: now }];
        }
        const source = where.source;
        if (typeof source === 'object' && source !== null && 'in' in source) {
          return [
            { value: 80, source: 'placement-follow-up', recordedAt: now },
            { value: 60, source: 'placement-baseline', recordedAt: now },
          ];
        }
        if (source === 'speaking-baseline') return [{ value: 100 }, { value: 110 }];
        if (source === 'speaking-follow-up') return [];
        // The query orders newest first, so the latest session leads.
        return [{ value: 130 }, { value: 120 }];
      },
    },
    conversation: { findMany: async () => [{ finishedAt: now }] },
    ieltsAttempt: { findMany: async () => [] },
    streakState: {
      findUnique: async () => ({ longestDays: 12, reminderTime: '08:00', reminderDays: '[1,3]' }),
      upsert: async () => ({ reminderTime: '08:00', reminderDays: '[1,3]' }),
    },
    profile: { findUnique: async () => ({ timezone: 'UTC' }) },
  } as never;
}

test('summary aggregates lesson, review, speaking, and vocabulary progress', async () => {
  const now = new Date();
  const service = new ProgressService(createDatabase(now));

  const summary = await service.summary('user-1');

  assert.equal(summary.lessonsCompleted, 3);
  assert.equal(summary.vocabularyItemsReviewed, 5);
  assert.equal(summary.vocabularyRecallRepetitions, 7);
  assert.equal(summary.speakingSessionsCompleted, 2);
  assert.equal(summary.vocabularyBaselineScore, 60);
  assert.equal(summary.vocabularyLatestScore, 80);
  assert.equal(summary.vocabularyScoreChange, 20);
  assert.equal(summary.fluencyBaselineWpm, 105);
  assert.equal(summary.fluencyLatestWpm, 130);
  assert.equal(summary.fluencyScoreChange, 25);
  assert.deepEqual(summary.fluencyTrend, [120, 130]);
  assert.equal(summary.currentStreak, 1);
  assert.equal(summary.longestStreak, 12);
  assert.equal(summary.recentSpeakingSessions.length, 1);
  assert.match(summary.note, /Practice estimates/);
});

test('streak merges the stored longest run and exposes the reminder schedule', async () => {
  const now = new Date();
  const service = new ProgressService(createDatabase(now));

  const streak = await service.streak('user-1');

  assert.equal(streak.currentDays, 1);
  assert.equal(streak.longestDays, 12);
  assert.equal(streak.reminderTime, '08:00');
  assert.deepEqual(streak.reminderDays, [1, 3]);
  assert.equal(streak.lastActivityOn, now.toISOString().slice(0, 10));
  assert.ok(streak.activeDates.includes(now.toISOString().slice(0, 10)));
});
