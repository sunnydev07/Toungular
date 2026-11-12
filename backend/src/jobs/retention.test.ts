import assert from 'node:assert/strict';
import test from 'node:test';

import { DRAFT_MAX_AGE_MS, IELTS_ATTEMPT_MAX_AGE_MS, runRetention } from './retention.js';

type Captured = {
  draftWhere?: Record<string, unknown>;
  attemptWhere?: Record<string, unknown>;
  attemptData?: Record<string, unknown>;
  keyWhere?: Record<string, unknown>;
};

function createDatabase(captured: Captured) {
  return {
    speakingSession: {
      deleteMany: async ({ where }: { where: Record<string, unknown> }) => {
        captured.draftWhere = where;
        return { count: 2 };
      },
    },
    ieltsAttempt: {
      updateMany: async ({ where, data }: { where: Record<string, unknown>; data: Record<string, unknown> }) => {
        captured.attemptWhere = where;
        captured.attemptData = data;
        return { count: 1 };
      },
    },
    idempotencyKey: {
      deleteMany: async ({ where }: { where: Record<string, unknown> }) => {
        captured.keyWhere = where;
        return { count: 3 };
      },
    },
  } as never;
}

test('retention removes stale drafts, abandons old attempts, and prunes keys', async () => {
  const captured: Captured = {};
  const now = new Date('2026-11-13T12:00:00Z');

  const report = await runRetention(createDatabase(captured), now);

  assert.deepEqual(report, { draftsDeleted: 2, attemptsAbandoned: 1, idempotencyKeysPruned: 3 });
  assert.deepEqual(captured.attemptData, {
    status: 'abandoned',
    finishedAt: now,
    feedback: 'This attempt expired after 24 hours without being finished. No band score is provided.',
  });
  assert.deepEqual(captured.draftWhere, {
    status: { in: ['draft', 'transcript_saved'] },
    deletedAt: null,
    startedAt: { lt: new Date(now.getTime() - DRAFT_MAX_AGE_MS) },
  });
  assert.deepEqual(captured.attemptWhere, {
    status: 'in_progress',
    startedAt: { lt: new Date(now.getTime() - IELTS_ATTEMPT_MAX_AGE_MS) },
  });
  assert.deepEqual(captured.keyWhere, {
    createdAt: { lt: new Date(now.getTime() - 24 * 60 * 60 * 1000) },
  });
});
