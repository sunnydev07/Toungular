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
      deleteMany: async ({ where }: { where: { createdAt: { lt: Date } } }) => {
        const before = rows.length;
        for (let index = rows.length - 1; index >= 0; index -= 1) {
          if (rows[index]!.createdAt < where.createdAt.lt) rows.splice(index, 1);
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
