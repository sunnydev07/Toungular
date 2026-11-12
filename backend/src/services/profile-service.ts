import type { PrismaClient } from '@prisma/client';

import type { Profile, ProfilePatch, Proficiency } from '../contracts.js';

function parseGoals(storedGoals: string): string[] {
  try {
    const decoded: unknown = JSON.parse(storedGoals);
    return Array.isArray(decoded) && decoded.every((goal) => typeof goal === 'string') ? decoded : [];
  } catch {
    return [];
  }
}

function toProfile(record: {
  userId: string;
  goals: string;
  proficiency: string;
  dailyMinutes: number;
  timezone: string;
  ieltsIntent: boolean;
  user: { email: string };
}): Profile {
  return {
    userId: record.userId,
    email: record.user.email,
    goals: parseGoals(record.goals),
    proficiency: record.proficiency as Proficiency,
    dailyMinutes: record.dailyMinutes,
    timezone: record.timezone,
    ieltsIntent: record.ieltsIntent,
  };
}

export class ProfileService {
  public constructor(private readonly database: PrismaClient) {}

  public async get(userId: string): Promise<Profile> {
    // Read-only: an empty-update upsert wrote on every profile fetch.
    const existing = await this.database.profile.findUnique({
      where: { userId },
      include: { user: { select: { email: true } } },
    });
    if (existing) return toProfile(existing);

    try {
      const created = await this.database.profile.create({
        data: { userId },
        include: { user: { select: { email: true } } },
      });
      return toProfile(created);
    } catch (error) {
      // A concurrent first read may have created it already.
      const fallback = await this.database.profile.findUnique({
        where: { userId },
        include: { user: { select: { email: true } } },
      });
      if (fallback) return toProfile(fallback);
      throw error;
    }
  }

  public async update(userId: string, patch: ProfilePatch): Promise<Profile> {
    const profile = await this.database.profile.upsert({
      where: { userId },
      update: {
        ...(patch.goals === undefined ? {} : { goals: JSON.stringify(patch.goals) }),
        ...(patch.proficiency === undefined ? {} : { proficiency: patch.proficiency }),
        ...(patch.dailyMinutes === undefined ? {} : { dailyMinutes: patch.dailyMinutes }),
        ...(patch.timezone === undefined ? {} : { timezone: patch.timezone }),
        ...(patch.ieltsIntent === undefined ? {} : { ieltsIntent: patch.ieltsIntent }),
      },
      create: {
        userId,
        ...(patch.goals === undefined ? {} : { goals: JSON.stringify(patch.goals) }),
        ...(patch.proficiency === undefined ? {} : { proficiency: patch.proficiency }),
        ...(patch.dailyMinutes === undefined ? {} : { dailyMinutes: patch.dailyMinutes }),
        ...(patch.timezone === undefined ? {} : { timezone: patch.timezone }),
        ...(patch.ieltsIntent === undefined ? {} : { ieltsIntent: patch.ieltsIntent }),
      },
      include: { user: { select: { email: true } } },
    });
    return toProfile(profile);
  }

  public async deleteAccount(userId: string): Promise<void> {
    await this.database.$transaction(async (transaction) => {
      await transaction.referral.updateMany({ where: { referredById: userId }, data: { referredById: null } });
      await transaction.user.delete({ where: { id: userId } });
    });
  }
}
