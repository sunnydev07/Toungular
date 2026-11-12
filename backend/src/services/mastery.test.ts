import assert from 'node:assert/strict';
import test from 'node:test';

import { MasteryService } from './mastery-service.js';

function createMockPrisma() {
  let state = {
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

  return {
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
        if (data.freezeTokens) state.freezeTokens = data.freezeTokens;
        return { ...state };
      },
    },
    skillSnapshot: {
      create: async () => ({ id: 'snap-1' }),
    },
  } as any;
}

test('mastery service returns default apprentice profile', async () => {
  const prisma = createMockPrisma();
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
  const prisma = createMockPrisma();
  const service = new MasteryService(prisma);

  const result = await service.awardXp('user-1', 'fluency', 100, '5-min speaking practice');
  assert.equal(result.awardedXp, 100);
  assert.equal(result.profile.fluencyXp, 100);
  assert.equal(result.profile.totalXp, 100);
  assert.equal(result.leveledUp, false);
});

test('mastery service levels up learner and awards freeze token when threshold crossed', async () => {
  const prisma = createMockPrisma();
  const service = new MasteryService(prisma);

  // Award 300 XP (crosses 250 XP threshold for Level 2 Explorer)
  const result = await service.awardXp('user-1', 'acoustic', 300, 'Mastered minimal pairs');
  assert.equal(result.leveledUp, true);
  assert.equal(result.previousLevel, 1);
  assert.equal(result.newLevel, 2);
  assert.equal(result.profile.rankTitle, 'Explorer');
  assert.equal(result.profile.freezeTokens, 3); // Started at 2, earned +1
});
