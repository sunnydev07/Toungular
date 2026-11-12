import assert from 'node:assert/strict';
import test from 'node:test';

import { AppError } from '../lib/http.js';
import { SpeakingService } from './speaking-service.js';

type Session = {
  id: string;
  userId: string;
  type: string;
  status: string;
  transcript: string | null;
};

const session: Session = {
  id: 'session-1',
  userId: 'user-1',
  type: 'prompt',
  status: 'draft',
  transcript: null,
};

function createService(): SpeakingService {
  const prisma = {
    speakingSession: {
      findFirst: async () => session,
      findMany: async () => [],
      update: async () => ({ id: session.id, status: 'completed' }),
    },
    skillSnapshot: {
      create: async () => ({ id: 'snap-1' }),
    },
  };
  return new SpeakingService(prisma as never);
}

const rejectedTiming = (error: unknown) =>
  error instanceof AppError && error.status === 422;

test('speaking analysis rejects a duration too short for the transcript', async () => {
  await assert.rejects(
    createService().analyze('user-1', 'session-1', {
      durationSeconds: 2,
      transcript: 'one two three four five six seven eight nine ten eleven twelve',
    }),
    rejectedTiming,
  );
});

test('speaking analysis rejects pauses longer than the recording', async () => {
  await assert.rejects(
    createService().analyze('user-1', 'session-1', {
      durationSeconds: 10,
      transcript: 'one two three four five',
      pauses: [9, 9],
    }),
    rejectedTiming,
  );
});

test('speaking analysis scores a plausible session', async () => {
  const result = await createService().analyze('user-1', 'session-1', {
    durationSeconds: 30,
    transcript: 'one two three four five six seven eight nine ten',
    pauses: [1.5, 2.5],
  });

  assert.equal(result.wordCount, 10);
  assert.equal(result.wordsPerMinute, 20);
  assert.equal(result.pronunciation.status, 'unavailable');
});
