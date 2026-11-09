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
    const profile = await this.database.profile.upsert({
      where: { userId },
      update: {},
      create: { userId },
      include: { user: { select: { email: true } } },
    });
    return toProfile(profile);
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
}
