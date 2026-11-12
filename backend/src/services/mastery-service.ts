import type { PrismaClient } from '@prisma/client';

import { AppError } from '../lib/http.js';

export type XpCategory = 'fluency' | 'lexical' | 'acoustic' | 'interaction';

export type RankMilestone = {
  level: number;
  rankTitle: string;
  minXp: number;
  maxXp: number;
  perk: string;
};

export const RANK_MILESTONES: RankMilestone[] = [
  { level: 1, rankTitle: 'Apprentice', minXp: 0, maxXp: 249, perk: 'Unlocked basic practice paths' },
  { level: 2, rankTitle: 'Explorer', minXp: 250, maxXp: 749, perk: 'Earned 1 Mastery Freeze token' },
  { level: 3, rankTitle: 'Practitioner', minXp: 750, maxXp: 1499, perk: 'Unlocked Phoneme Lab advanced contrast drills' },
  { level: 4, rankTitle: 'Conversationalist', minXp: 1500, maxXp: 2999, perk: 'Unlocked AI Coach extended multi-turn dialogue' },
  { level: 5, rankTitle: 'Articulate Speaker', minXp: 3000, maxXp: 5999, perk: 'Earned Gold Mastery Badge & accent profiling' },
  { level: 6, rankTitle: 'Mastery', minXp: 6000, maxXp: 999999, perk: 'All Toungular superpower modules mastered' },
];

export type MasteryProfile = {
  userId: string;
  fluencyXp: number;
  lexicalXp: number;
  acousticXp: number;
  interactionXp: number;
  totalXp: number;
  level: number;
  rankTitle: string;
  freezeTokens: number;
  levelProgressPercent: number;
  nextLevelXpRequired: number;
  perk: string;
};

export type AwardXpResult = {
  profile: MasteryProfile;
  awardedXp: number;
  category: XpCategory;
  reason: string;
  leveledUp: boolean;
  previousLevel: number;
  newLevel: number;
};

export class MasteryService {
  public constructor(private readonly database: PrismaClient) {}

  public async getProfile(userId: string): Promise<MasteryProfile> {
    // Read-only: fall back to the starting profile instead of upserting a row.
    const row = await this.database.masteryXp.findUnique({ where: { userId } });
    return this.calculateProfile(row ?? this.blankRow(userId));
  }

  /// Creates the row only when XP is actually written, not on every read.
  private async ensureRow(userId: string) {
    return this.database.masteryXp.upsert({
      where: { userId },
      update: {},
      create: this.blankRow(userId),
    });
  }

  private blankRow(userId: string) {
    return {
      userId,
      fluencyXp: 0,
      lexicalXp: 0,
      acousticXp: 0,
      interactionXp: 0,
      totalXp: 0,
      level: 1,
      rankTitle: 'Apprentice',
      freezeTokens: 2,
    };
  }

  public async awardXp(
    userId: string,
    category: XpCategory,
    points: number,
    reason: string,
  ): Promise<AwardXpResult> {
    if (points <= 0) {
      throw new AppError(400, 'INVALID_POINTS', 'Awarded XP points must be strictly positive.');
    }

    const current = this.calculateProfile(await this.ensureRow(userId));
    const previousLevel = current.level;

    const updateField =
      category === 'fluency'
        ? { fluencyXp: { increment: points } }
        : category === 'lexical'
            ? { lexicalXp: { increment: points } }
            : category === 'acoustic'
                ? { acousticXp: { increment: points } }
                : { interactionXp: { increment: points } };

    const updated = await this.database.masteryXp.update({
      where: { userId },
      data: {
        ...updateField,
        totalXp: { increment: points },
      },
    });

    // Check level progression
    const milestone = this.getMilestoneForXp(updated.totalXp);
    let leveledUp = false;
    let finalFreezeTokens = updated.freezeTokens;

    if (milestone.level > previousLevel) {
      leveledUp = true;
      finalFreezeTokens += 1;
      await this.database.masteryXp.update({
        where: { userId },
        data: {
          level: milestone.level,
          rankTitle: milestone.rankTitle,
          freezeTokens: finalFreezeTokens,
        },
      });
    }

    // Record skill snapshot non-blockingly
    try {
      await this.database.skillSnapshot.create({
        data: {
          userId,
          skill: `xp_${category}`,
          value: points,
          source: reason,
        },
      });
    } catch {
      // Non-blocking
    }

    const calculated = this.calculateProfile({
      ...updated,
      level: milestone.level,
      rankTitle: milestone.rankTitle,
      freezeTokens: finalFreezeTokens,
    });

    return {
      profile: calculated,
      awardedXp: points,
      category,
      reason,
      leveledUp,
      previousLevel,
      newLevel: milestone.level,
    };
  }

  public async useFreezeToken(userId: string): Promise<MasteryProfile> {
    const current = this.calculateProfile(await this.ensureRow(userId));
    if (current.freezeTokens <= 0) {
      throw new AppError(400, 'NO_FREEZE_TOKENS', 'No freeze tokens available to use.');
    }

    const updated = await this.database.masteryXp.update({
      where: { userId },
      data: {
        freezeTokens: { decrement: 1 },
      },
    });

    return this.calculateProfile(updated);
  }

  private getMilestoneForXp(totalXp: number): RankMilestone {
    for (let i = RANK_MILESTONES.length - 1; i >= 0; i--) {
      const milestone = RANK_MILESTONES[i]!;
      if (totalXp >= milestone.minXp) {
        return milestone;
      }
    }
    return RANK_MILESTONES[0]!;
  }

  private calculateProfile(row: {
    userId: string;
    fluencyXp: number;
    lexicalXp: number;
    acousticXp: number;
    interactionXp: number;
    totalXp: number;
    level: number;
    rankTitle: string;
    freezeTokens: number;
  }): MasteryProfile {
    const currentMilestone = this.getMilestoneForXp(row.totalXp);
    const nextMilestone =
      RANK_MILESTONES.find((m) => m.level === currentMilestone.level + 1) ?? currentMilestone;

    let levelProgressPercent = 100;
    let nextLevelXpRequired = 0;

    if (nextMilestone.level > currentMilestone.level) {
      const xpInCurrentLevel = row.totalXp - currentMilestone.minXp;
      const levelSpan = nextMilestone.minXp - currentMilestone.minXp;
      levelProgressPercent = Math.min(100, Math.max(0, Math.round((xpInCurrentLevel / levelSpan) * 100)));
      nextLevelXpRequired = nextMilestone.minXp - row.totalXp;
    }

    return {
      userId: row.userId,
      fluencyXp: row.fluencyXp,
      lexicalXp: row.lexicalXp,
      acousticXp: row.acousticXp,
      interactionXp: row.interactionXp,
      totalXp: row.totalXp,
      level: currentMilestone.level,
      rankTitle: currentMilestone.rankTitle,
      freezeTokens: row.freezeTokens,
      levelProgressPercent,
      nextLevelXpRequired,
      perk: currentMilestone.perk,
    };
  }
}
