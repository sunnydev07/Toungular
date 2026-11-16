import assert from 'node:assert/strict';
import test from 'node:test';

import type { AppEnv } from '../config/env.js';
import { AppError } from '../lib/http.js';
import { hashRefreshToken, issueRefreshToken } from '../lib/tokens.js';
import { AuthService } from './auth-service.js';

type TokenRow = {
  id: string;
  userId: string;
  tokenHash: string;
  familyId: string | null;
  expiresAt: Date;
  revokedAt: Date | null;
  createdAt: Date;
};

function createHarness(options: { guest?: boolean } = {}) {
  const user = {
    id: 'user-1',
    email: options.guest ? 'guest-abc@guest.toungular.app' : 'learner@toungular.app',
    isGuest: options.guest ?? false,
  };
  const rows: TokenRow[] = [];
  const created: Array<Record<string, unknown>> = [];
  let sequence = 0;

  const matches = (row: TokenRow, where: Record<string, unknown>): boolean =>
    Object.entries(where).every(([key, value]) => {
      if (key === 'revokedAt' && value === null) return row.revokedAt === null;
      return (row as unknown as Record<string, unknown>)[key] === value;
    });

  const prisma = {
    user: {
      findUnique: async ({ where }: { where: Record<string, unknown> }) => {
        if (typeof where.email === 'string' && where.email !== user.email) return null;
        if (typeof where.id === 'string' && where.id !== user.id) return null;
        return { ...user, passwordHash: 'unused' };
      },
      create: async ({ data }: { data: Record<string, unknown> }) => {
        created.push(data);
        return {
          ...user,
          email: data.email as string,
          isGuest: data.isGuest === true,
          passwordHash: data.passwordHash as string,
        };
      },
      update: async ({ data }: { data: Record<string, unknown> }) => {
        Object.assign(user, data);
        return { ...user, passwordHash: data.passwordHash as string };
      },
    },
    refreshToken: {
      findUnique: async ({ where }: { where: { tokenHash: string } }) => {
        const row = rows.find((candidate) => candidate.tokenHash === where.tokenHash);
        return row ? { ...row, user } : null;
      },
      create: async ({ data }: { data: Omit<TokenRow, 'id' | 'revokedAt' | 'createdAt'> }) => {
        const row: TokenRow = {
          id: `token-${(sequence += 1)}`,
          revokedAt: null,
          createdAt: new Date(),
          ...data,
        };
        rows.push(row);
        return row;
      },
      updateMany: async ({ where, data }: { where: Record<string, unknown>; data: Partial<TokenRow> }) => {
        const affected = rows.filter((row) => matches(row, where));
        for (const row of affected) Object.assign(row, data);
        return { count: affected.length };
      },
    },
    $transaction: async (callback: (transaction: unknown) => Promise<unknown>) => callback(prisma),
  };

  const service = new AuthService(prisma as never, { jwtSecret: 'x'.repeat(48) } as AppEnv);
  // Profile hydration is unrelated to rotation; keep the unit test on tokens.
  (service as unknown as { profiles: unknown }).profiles = {
    get: async () => ({
      userId: user.id,
      email: user.email,
      goals: [],
      proficiency: 'beginner',
      dailyMinutes: 15,
      timezone: 'UTC',
      ieltsIntent: false,
    }),
  };

  return { service, rows, user, created };
}

function seedToken(rows: TokenRow[], familyId: string | null = null): string {
  const issued = issueRefreshToken();
  rows.push({
    id: `seed-${rows.length}`,
    userId: 'user-1',
    tokenHash: issued.tokenHash,
    familyId,
    expiresAt: issued.expiresAt,
    revokedAt: null,
    createdAt: new Date(),
  });
  return issued.token;
}

const unauthorized = (error: unknown) => error instanceof AppError && error.status === 401;

test('a guest session is created without reusable credentials', async () => {
  const { service, rows, created } = createHarness();

  const result = await service.createGuest();

  assert.equal(created.length, 1);
  assert.equal(created[0]!.isGuest, true);
  assert.match(created[0]!.email as string, /^guest-[\w-]+@guest\.toungular\.app$/);
  assert.equal(typeof created[0]!.passwordHash, 'string');
  assert.equal(result.user.isGuest, true);
  assert.equal(rows.length, 1);
  assert.ok(result.accessToken);
  assert.ok(result.refreshToken);
});

test('upgrading a guest keeps the account and clears the guest flag', async () => {
  const { service, user } = createHarness({ guest: true });

  const result = await service.upgradeGuest('user-1', {
    email: 'Learner@Toungular.app',
    password: 'password123',
  });

  assert.equal(result.user.id, 'user-1');
  assert.equal(result.user.email, 'learner@toungular.app');
  assert.equal(result.user.isGuest, false);
  assert.equal(user.email, 'learner@toungular.app');
  assert.equal(user.isGuest, false);
  assert.equal(typeof (user as { passwordHash?: string }).passwordHash, 'string');
});

test('a permanent account cannot be upgraded again', async () => {
  const { service } = createHarness();

  await assert.rejects(
    service.upgradeGuest('user-1', { email: 'other@toungular.app', password: 'password123' }),
    (error: unknown) => error instanceof AppError && error.status === 409 && error.code === 'ACCOUNT_ALREADY_REGISTERED',
  );
});

test('refresh rotates the token inside the same family', async () => {
  const { service, rows } = createHarness();
  const token = seedToken(rows, 'family-1');

  const result = await service.refresh(token);

  assert.equal(rows.length, 2);
  assert.notEqual(rows[0]!.revokedAt, null);
  assert.equal(rows[1]!.familyId, 'family-1');
  assert.equal(rows[1]!.tokenHash, hashRefreshToken(result.refreshToken));
  assert.notEqual(result.refreshToken, token);
});

test('replaying a rotated token revokes every descendant in the family', async () => {
  const { service, rows } = createHarness();
  const token = seedToken(rows, 'family-1');
  const first = await service.refresh(token);
  const rotated = rows.find((row) => row.tokenHash === hashRefreshToken(first.refreshToken))!;

  await assert.rejects(service.refresh(token), unauthorized);

  assert.notEqual(rotated.revokedAt, null);
  await assert.rejects(service.refresh(first.refreshToken), unauthorized);
});

test('logout revokes the presented token family only', async () => {
  const { service, rows } = createHarness();
  const first = seedToken(rows, 'family-a');
  seedToken(rows, 'family-b');

  await service.logout('user-1', first);

  const revoked = rows.filter((row) => row.revokedAt !== null);
  assert.equal(revoked.length, 1);
  assert.equal(revoked[0]!.tokenHash, hashRefreshToken(first));
});

test('logout after a rotation revokes the replacement token too', async () => {
  const { service, rows } = createHarness();
  const token = seedToken(rows, 'family-1');
  const first = await service.refresh(token);
  const rotated = rows.find((row) => row.tokenHash === hashRefreshToken(first.refreshToken))!;

  await service.logout('user-1', token);

  assert.notEqual(rotated.revokedAt, null);
  await assert.rejects(service.refresh(first.refreshToken), unauthorized);
});

test('two concurrent refreshes of the same token: exactly one succeeds', async () => {
  const { service, rows } = createHarness();
  const token = seedToken(rows, 'family-1');

  const results = await Promise.allSettled([service.refresh(token), service.refresh(token)]);
  const fulfilled = results.filter((result) => result.status === 'fulfilled');

  assert.equal(fulfilled.length, 1);
  const rejected = results.find((result) => result.status === 'rejected');
  assert.ok(rejected && rejected.status === 'rejected' && unauthorized(rejected.reason));
});

test('logout with allSessions revokes every active token', async () => {
  const { service, rows } = createHarness();
  seedToken(rows, 'family-a');
  seedToken(rows, 'family-b');

  await service.logout('user-1', undefined, true);

  assert.equal(rows.every((row) => row.revokedAt !== null), true);
});
