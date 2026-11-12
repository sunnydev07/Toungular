import assert from 'node:assert/strict';
import test from 'node:test';

import { AppError } from '../lib/http.js';
import { CoachService } from './coach-service.js';

const conversation = {
  id: 'conversation-1',
  userId: 'user-1',
  scenarioId: 'daily-introduction',
  status: 'active',
  createdAt: new Date('2026-01-01T00:00:00.000Z'),
  turns: [],
};

function createService(found = true) {
  const calls: Array<{ take: number; skip: number }> = [];
  const prisma = {
    conversation: {
      findFirst: async (args: { include: { turns: { take: number; skip: number } } }) => {
        calls.push(args.include.turns);
        return found ? conversation : null;
      },
    },
    conversationTurn: {
      count: async () => 42,
    },
  };
  return { service: new CoachService(prisma as never), calls };
}

test('coach load paginates turns and reports the total count', async () => {
  const { service, calls } = createService();

  const result = await service.load('user-1', 'conversation-1', 10, 20);

  assert.equal(calls[0]!.take, 10);
  assert.equal(calls[0]!.skip, 20);
  assert.equal(result.turnsTotal, 42);
  assert.equal(result.scenario.id, 'daily-introduction');
});

test('coach load defaults to the first 30 turns', async () => {
  const { service, calls } = createService();

  await service.load('user-1', 'conversation-1');

  assert.equal(calls[0]!.take, 30);
  assert.equal(calls[0]!.skip, 0);
});

test('coach load rejects a conversation owned by another user', async () => {
  const { service } = createService(false);

  await assert.rejects(
    service.load('user-1', 'conversation-1'),
    (error: unknown) => error instanceof AppError && error.status === 404,
  );
});
