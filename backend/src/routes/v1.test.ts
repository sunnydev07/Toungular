import assert from 'node:assert/strict';
import test from 'node:test';

import express from 'express';
import { pino } from 'pino';
import request from 'supertest';

import type { AppEnv } from '../config/env.js';
import { jsonErrorHandler } from '../lib/http.js';
import { QuotaService } from '../lib/quotas.js';
import { issueAccessToken } from '../lib/tokens.js';
import { IdempotencyService } from '../services/idempotency-service.js';
import { createV1Router } from './v1.js';

const env = { jwtSecret: 'x'.repeat(48) } as AppEnv;
const silentLogger = pino({ level: 'silent' });

function tokenFor(userId: string): string {
  return issueAccessToken({ userId, email: `${userId}@toungular.app` }, env);
}

function createHarness(options: { aiDaily?: number } = {}) {
  const calls = { addTurn: 0, schedule: 0, xp: 0 };
  const seen: Array<{ userId: string; limit: number; offset: number }> = [];
  const removed: Array<{ userId: string; id: string }> = [];
  const rows: Array<{ userId: string; scope: string; key: string; response: string; createdAt: Date }> = [];

  const idempotencyDatabase = {
    idempotencyKey: {
      findUnique: async ({ where }: { where: { userId_scope_key: { userId: string; scope: string; key: string } } }) => {
        const { userId, scope, key } = where.userId_scope_key;
        return rows.find((row) => row.userId === userId && row.scope === scope && row.key === key) ?? null;
      },
      create: async ({ data }: { data: { userId: string; scope: string; key: string; response: string } }) => {
        rows.push({ ...data, createdAt: new Date() });
        return data;
      },
      update: async ({ where, data }: { where: { userId_scope_key: { userId: string; scope: string; key: string } }; data: { response: string } }) => {
        const { userId, scope, key } = where.userId_scope_key;
        const row = rows.find((candidate) => candidate.userId === userId && candidate.scope === scope && candidate.key === key);
        if (row) row.response = data.response;
        return row;
      },
      deleteMany: async ({ where }: { where: { userId: string; scope: string; key: string; response?: string } }) => {
        const index = rows.findIndex((row) => row.userId === where.userId
          && row.scope === where.scope
          && row.key === where.key
          && (where.response === undefined || row.response === where.response));
        if (index >= 0) rows.splice(index, 1);
        return { count: index >= 0 ? 1 : 0 };
      },
    },
  };

  const quotas = new QuotaService({
    aiDaily: options.aiDaily ?? 5,
    voiceDaily: 5,
    failureAlertRate: 1,
    failureWindowMs: 60_000,
    failureAlertMinimumCalls: 100,
  }, silentLogger as never);

  const dependencies = {
    env,
    quotas,
    idempotency: new IdempotencyService(idempotencyDatabase as never),
    coach: {
      addTurn: async (userId: string, id: string, transcript: string) => {
        calls.addTurn += 1;
        return { turn: { id: `turn-${calls.addTurn}` }, replyTurn: { id: 'reply' }, userId, conversationId: id, transcript };
      },
    },
    speaking: {
      history: async (userId: string, limit: number, offset: number) => {
        seen.push({ userId, limit, offset });
        return [{ id: 'session-1', userId }];
      },
      remove: async (userId: string, id: string) => {
        removed.push({ userId, id });
      },
    },
    vocabulary: { scheduleEncounterWords: async () => { calls.schedule += 1; return 0; } },
    mastery: { awardXp: async () => { calls.xp += 1; return {}; } },
    auth: {},
    ielts: {},
    monetization: {},
    profiles: {},
    placement: {},
    progress: {},
    curriculum: {},
    exposure: {},
    voice: {},
    shadow: {},
    content: {},
    decision: {},
    pronunciation: {},
  };

  const app = express();
  app.use(express.json());
  app.use('/v1', createV1Router(dependencies as never));
  app.use(jsonErrorHandler);

  return { app, calls, seen, removed };
}

test('protected routes reject requests without a bearer token', async () => {
  const { app } = createHarness();

  const response = await request(app).get('/v1/speaking-sessions');

  assert.equal(response.status, 401);
  assert.equal(response.body.error.code, 'UNAUTHORIZED');
});

test('history reads the identity from the access token, not the request', async () => {
  const { app, seen } = createHarness();

  const response = await request(app)
    .get('/v1/speaking-sessions')
    .set('Authorization', `Bearer ${tokenFor('user-42')}`);

  assert.equal(response.status, 200);
  assert.deepEqual(seen, [{ userId: 'user-42', limit: 30, offset: 0 }]);
  assert.deepEqual(response.body.data, [{ id: 'session-1', userId: 'user-42' }]);
});

test('discarding a speaking draft soft-deletes it through the API', async () => {
  const { app, removed } = createHarness();

  const response = await request(app)
    .delete('/v1/speaking-sessions/session-9')
    .set('Authorization', `Bearer ${tokenFor('user-7')}`);

  assert.equal(response.status, 204);
  assert.deepEqual(removed, [{ userId: 'user-7', id: 'session-9' }]);
});

test('an idempotency key replays the stored coach turn without duplicate side effects', async () => {
  const { app, calls } = createHarness({ aiDaily: 1 });
  const token = tokenFor('user-1');
  const send = () => request(app)
    .post('/v1/conversations/conversation-1/turns')
    .set('Authorization', `Bearer ${token}`)
    .set('Idempotency-Key', 'retry-key-0001')
    .send({ transcript: 'I went to the market yesterday.' });

  const first = await send();
  const second = await send();

  assert.equal(first.status, 201);
  assert.equal(second.status, 201);
  assert.deepEqual(second.body.data, first.body.data);
  assert.equal(calls.addTurn, 1);
  assert.equal(calls.schedule, 1);
  assert.equal(calls.xp, 1);
});

test('malformed idempotency keys are rejected', async () => {
  const { app } = createHarness();

  const response = await request(app)
    .post('/v1/conversations/conversation-1/turns')
    .set('Authorization', `Bearer ${tokenFor('user-1')}`)
    .set('Idempotency-Key', 'bad key!')
    .send({ transcript: 'Hello there.' });

  assert.equal(response.status, 400);
  assert.equal(response.body.error.code, 'INVALID_IDEMPOTENCY_KEY');
});

test('the daily AI quota returns 429 after the limit is spent', async () => {
  const { app, calls } = createHarness({ aiDaily: 1 });
  const token = tokenFor('user-1');

  const first = await request(app)
    .post('/v1/conversations/conversation-1/turns')
    .set('Authorization', `Bearer ${token}`)
    .set('Idempotency-Key', 'quota-key-0001')
    .send({ transcript: 'First turn.' });
  const second = await request(app)
    .post('/v1/conversations/conversation-1/turns')
    .set('Authorization', `Bearer ${token}`)
    .set('Idempotency-Key', 'quota-key-0002')
    .send({ transcript: 'Second turn.' });

  assert.equal(first.status, 201);
  assert.equal(second.status, 429);
  assert.equal(second.body.error.code, 'QUOTA_EXCEEDED');
  assert.equal(calls.addTurn, 1);
});
