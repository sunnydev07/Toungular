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

function createHarness() {
  const user = { id: 'user-1', email: 'learner@toungular.app' };
  const rows: TokenRow[] = [];
  let sequence = 0;

  const matches = (row: TokenRow, where: Record<string, unknown>): boolean =>
    Object.entries(where).every(([key, value]) => {
      if (key === 'revokedAt' && value === null) return row.revokedAt === null;
      return (row as unknown as Record<string, unknown>)[key] === value;
    });

  const prisma = {
    user: {
      findUnique: async () => ({ ...user, passwordHash: 'unused' }),
      create: async () => user,
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

  return { service, rows, user };
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

test('logout with allSessions revokes every active token', async () => {
  const { service, rows } = createHarness();
  seedToken(rows, 'family-a');
  seedToken(rows, 'family-b');

  await service.logout('user-1', undefined, true);

  assert.equal(rows.every((row) => row.revokedAt !== null), true);
});
