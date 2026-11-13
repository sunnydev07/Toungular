import assert from 'node:assert/strict';
import test from 'node:test';

import { IdempotencyService } from './idempotency-service.js';

type Row = { userId: string; scope: string; key: string; response: string; createdAt: Date };

function createDatabase() {
  const rows: Row[] = [];
  const database = {
    idempotencyKey: {
      findUnique: async ({ where }: { where: { userId_scope_key: { userId: string; scope: string; key: string } } }) => {
        const { userId, scope, key } = where.userId_scope_key;
        return rows.find((row) => row.userId === userId && row.scope === scope && row.key === key) ?? null;
      },
      create: async ({ data }: { data: Row }) => {
        const exists = rows.some(
          (row) => row.userId === data.userId && row.scope === data.scope && row.key === data.key,
        );
        if (exists) throw Object.assign(new Error('duplicate'), { code: 'P2002' });
        rows.push({ ...data, createdAt: data.createdAt ?? new Date() });
        return data;
      },
      update: async ({ where, data }: { where: { userId_scope_key: { userId: string; scope: string; key: string } }; data: { response: string } }) => {
        const { userId, scope, key } = where.userId_scope_key;
        const row = rows.find((candidate) => candidate.userId === userId && candidate.scope === scope && candidate.key === key);
        if (row) row.response = data.response;
        return row;
      },
      deleteMany: async ({ where }: { where: { createdAt?: { lt: Date }; userId?: string; scope?: string; key?: string; response?: string } }) => {
        const before = rows.length;
        for (let index = rows.length - 1; index >= 0; index -= 1) {
          const row = rows[index]!;
          const matches = where.createdAt
            ? row.createdAt < where.createdAt.lt
            : row.userId === where.userId
              && row.scope === where.scope
              && row.key === where.key
              && (where.response === undefined || row.response === where.response);
          if (matches) rows.splice(index, 1);
        }
        return { count: before - rows.length };
      },
    },
  };
  return { database: database as never, rows };
}

test('the handler runs once and the stored response is replayed', async () => {
  const { database, rows } = createDatabase();
  const service = new IdempotencyService(database);
  let calls = 0;
  const handler = async () => {
    calls += 1;
    return { reply: 'hello', turn: 1 };
  };

  const first = await service.run('user-1', 'coach-turn:conversation-1', 'key-12345678', handler);
  const second = await service.run('user-1', 'coach-turn:conversation-1', 'key-12345678', handler);

  assert.equal(calls, 1);
  assert.equal(first.replayed, false);
  assert.equal(second.replayed, true);
  assert.deepEqual(second.value, { reply: 'hello', turn: 1 });
  assert.equal(rows.length, 1);
});

test('keys are scoped per resource so the same key can be reused elsewhere', async () => {
  const { database } = createDatabase();
  const service = new IdempotencyService(database);
  let calls = 0;
  const handler = async () => ({ call: (calls += 1) });

  await service.run('user-1', 'speaking-analyze:session-1', 'key-12345678', handler);
  await service.run('user-1', 'speaking-analyze:session-2', 'key-12345678', handler);

  assert.equal(calls, 2);
});

test('a duplicate while the first handler is still running is rejected', async () => {
  const { database } = createDatabase();
  const service = new IdempotencyService(database);
  let release: (() => void) | undefined;
  const blocked = new Promise<void>((resolve) => {
    release = resolve;
  });
  let calls = 0;
  const handler = async () => {
    calls += 1;
    await blocked;
    return { reply: 'slow' };
  };

  const first = service.run('user-1', 'coach-turn:c1', 'key-12345678', handler);
  await new Promise((resolve) => setTimeout(resolve, 0));
  const duplicate = service.run('user-1', 'coach-turn:c1', 'key-12345678', handler);

  await assert.rejects(
    duplicate,
    (error: unknown) => (error as { status?: number }).status === 409,
  );
  release?.();
  await first;
  assert.equal(calls, 1);
});

test('a failed handler releases the pending claim so a retry can run', async () => {
  const { database, rows } = createDatabase();
  const service = new IdempotencyService(database);
  let calls = 0;

  await assert.rejects(service.run('user-1', 'coach-turn:c1', 'key-12345678', async () => {
    calls += 1;
    throw new Error('provider down');
  }));

  assert.equal(rows.length, 0);
  const retry = await service.run('user-1', 'coach-turn:c1', 'key-12345678', async () => {
    calls += 1;
    return { reply: 'ok' };
  });

  assert.equal(calls, 2);
  assert.equal(retry.replayed, false);
});

test('prune deletes responses older than the retention window', async () => {
  const { database, rows } = createDatabase();
  const service = new IdempotencyService(database);
  const now = new Date('2026-11-13T12:00:00Z');

  rows.push({ userId: 'user-1', scope: 'a', key: 'old', response: '{}', createdAt: new Date('2026-11-11T12:00:00Z') });
  rows.push({ userId: 'user-1', scope: 'b', key: 'new', response: '{}', createdAt: new Date('2026-11-13T11:00:00Z') });

  assert.equal(await service.prune(now), 1);
  assert.equal(rows.length, 1);
  assert.equal(rows[0]!.key, 'new');
});
