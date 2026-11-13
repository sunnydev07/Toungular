import assert from 'node:assert/strict';
import test from 'node:test';

import { MasteryService } from './mastery-service.js';

function createMockPrisma(options: { frozenToday?: boolean } = {}) {
  const state = {
    userId: 'user-1',
    fluencyXp: 0,
    lexicalXp: 0,
    acousticXp: 0,
    interactionXp: 0,
    totalXp: 0,
    level: 1,
    rankTitle: 'Apprentice',
    freezeTokens: 2,
  };
  const snapshots: Array<Record<string, unknown>> = [];
  const streakWrites: Array<Record<string, unknown>> = [];

  const prisma = {
    masteryXp: {
      findUnique: async () => null,
      upsert: async () => ({ ...state }),
      update: async ({ data }: any) => {
        if (data.fluencyXp?.increment) state.fluencyXp += data.fluencyXp.increment;
        if (data.lexicalXp?.increment) state.lexicalXp += data.lexicalXp.increment;
        if (data.acousticXp?.increment) state.acousticXp += data.acousticXp.increment;
        if (data.interactionXp?.increment) state.interactionXp += data.interactionXp.increment;
        if (data.totalXp?.increment) state.totalXp += data.totalXp.increment;
        if (data.level) state.level = data.level;
        if (data.rankTitle) state.rankTitle = data.rankTitle;
        if (typeof data.freezeTokens === 'number') state.freezeTokens = data.freezeTokens;
        else if (data.freezeTokens?.decrement) state.freezeTokens -= data.freezeTokens.decrement;
        return { ...state };
      },
    },
    skillSnapshot: {
      findFirst: async () => (options.frozenToday ? { id: 'snap-today' } : null),
      create: async ({ data }: any) => {
        snapshots.push(data);
        return { id: `snap-${snapshots.length}` };
      },
    },
    streakState: {
      upsert: async ({ update }: any) => {
        streakWrites.push(update);
        return { userId: state.userId };
      },
    },
  } as any;

  prisma.$transaction = async (callback: (transaction: unknown) => Promise<unknown>) => callback(prisma);

  return { prisma, state, snapshots, streakWrites };
}

test('mastery service returns default apprentice profile', async () => {
  const { prisma } = createMockPrisma();
  const service = new MasteryService(prisma);

  const profile = await service.getProfile('user-1');
  assert.equal(profile.userId, 'user-1');
  assert.equal(profile.level, 1);
  assert.equal(profile.rankTitle, 'Apprentice');
  assert.equal(profile.totalXp, 0);
  assert.equal(profile.freezeTokens, 2);
  assert.equal(profile.nextLevelXpRequired, 250);
});

test('mastery service awards XP across categories and tracks totals', async () => {
  const { prisma } = createMockPrisma();
  const service = new MasteryService(prisma);

  const result = await service.awardXp('user-1', 'fluency', 100, '5-min speaking practice');
  assert.equal(result.awardedXp, 100);
  assert.equal(result.profile.fluencyXp, 100);
  assert.equal(result.profile.totalXp, 100);
  assert.equal(result.leveledUp, false);
});

test('mastery service levels up learner and awards freeze token when threshold crossed', async () => {
  const { prisma } = createMockPrisma();
  const service = new MasteryService(prisma);

  // Award 300 XP (crosses 250 XP threshold for Level 2 Explorer)
  const result = await service.awardXp('user-1', 'acoustic', 300, 'Mastered minimal pairs');
  assert.equal(result.leveledUp, true);
  assert.equal(result.previousLevel, 1);
  assert.equal(result.newLevel, 2);
  assert.equal(result.profile.rankTitle, 'Explorer');
  assert.equal(result.profile.freezeTokens, 3); // Started at 2, earned +1
});

test('using a freeze token records the protected day and consumes one token', async () => {
  const { prisma, snapshots, streakWrites } = createMockPrisma();
  const service = new MasteryService(prisma);
  const now = new Date('2026-11-13T09:30:00Z');

  const profile = await service.useFreezeToken('user-1', now);

  assert.equal(profile.freezeTokens, 1);
  assert.deepEqual(snapshots.map((snapshot) => snapshot.skill), ['streak_freeze']);
  assert.equal(snapshots[0]?.source, 'freeze-token');
  assert.deepEqual(streakWrites, [{ lastActivityOn: now }]);
});

test('a second freeze on the same day is rejected without spending a token', async () => {
  const { prisma, state } = createMockPrisma({ frozenToday: true });
  const service = new MasteryService(prisma);

  await assert.rejects(
    service.useFreezeToken('user-1', new Date('2026-11-13T10:00:00Z')),
    (error: unknown) => (error as { status?: number }).status === 409,
  );
  assert.equal(state.freezeTokens, 2);
});
