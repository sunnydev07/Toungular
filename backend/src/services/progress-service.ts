import type { PrismaClient } from '@prisma/client';

function dayKey(value: Date, timezone: string): string {
  try {
    const parts = new Intl.DateTimeFormat('en-CA', {
      timeZone: timezone,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    }).formatToParts(value);
    const values = Object.fromEntries(parts.map((part) => [part.type, part.value]));
    return `${values.year}-${values.month}-${values.day}`;
  } catch {
    return value.toISOString().slice(0, 10);
  }
}

function countStreaks(dates: Date[], timezone: string) {
  const keys = [...new Set(dates.map((date) => dayKey(date, timezone)))].sort().reverse();
  if (keys.length === 0) return { currentDays: 0, longestDays: 0, lastActivityOn: null as string | null };
  const active = new Set(keys);
  const mostRecent = new Date(`${keys[0]}T00:00:00.000Z`);
  const today = new Date(`${dayKey(new Date(), timezone)}T00:00:00.000Z`);
  const age = Math.round((today.getTime() - mostRecent.getTime()) / 86_400_000);
  let currentDays = 0;
  if (age <= 1) {
    let cursor = mostRecent;
    while (active.has(cursor.toISOString().slice(0, 10))) {
      currentDays++;
      cursor = new Date(cursor.getTime() - 86_400_000);
    }
  }
  let longestDays = 0;
  let run = 0;
  let previous: Date | null = null;
  for (const key of [...keys].reverse()) {
    const date = new Date(`${key}T00:00:00.000Z`);
    run = previous && date.getTime() - previous.getTime() === 86_400_000 ? run + 1 : 1;
    longestDays = Math.max(longestDays, run);
    previous = date;
  }
  return { currentDays, longestDays, lastActivityOn: keys[0] ?? null };
}

function average(values: Array<{ value: number | null }>): number | null {
  const present = values.flatMap((item) => item.value == null ? [] : [item.value]);
  return present.length === 0 ? null : Math.round(present.reduce((total, value) => total + value, 0) / present.length);
}

function standardDeviation(values: number[]): number | null {
  if (values.length < 2) return null;
  const mean = values.reduce((total, value) => total + value, 0) / values.length;
  return Number(Math.sqrt(values.reduce((total, value) => total + (value - mean) ** 2, 0) / values.length).toFixed(1));
}

export class ProgressService {
  public constructor(private readonly database: PrismaClient) {}

  public async summary(userId: string) {
    const [lessons, reviews, speaking, recent, vocabularySnapshots, fluencyBaseline, fluencyFollowUps, fluencySessions] = await Promise.all([
      this.database.lessonProgress.count({ where: { userId } }),
      this.database.reviewSchedule.aggregate({ where: { userId }, _sum: { repetitions: true }, _count: { _all: true } }),
      this.database.speakingSession.count({ where: { userId, status: 'completed', deletedAt: null } }),
      this.database.speakingSession.findMany({
        where: { userId, deletedAt: null },
        orderBy: { startedAt: 'desc' },
        take: 5,
        select: { id: true, prompt: true, status: true, startedAt: true, completedAt: true },
      }),
      this.database.skillSnapshot.findMany({
        where: { userId, skill: 'vocabulary', source: { in: ['placement-baseline', 'placement-follow-up'] } },
        orderBy: { recordedAt: 'desc' },
        take: 20,
        select: { value: true, source: true, recordedAt: true },
      }),
      this.database.skillSnapshot.findMany({
        where: { userId, skill: 'fluency', source: 'speaking-baseline' },
        orderBy: { recordedAt: 'asc' },
        take: 2,
        select: { value: true },
      }),
      this.database.skillSnapshot.findMany({
        where: { userId, skill: 'fluency', source: 'speaking-follow-up' },
        orderBy: { recordedAt: 'desc' },
        take: 2,
        select: { value: true },
      }),
      this.database.skillSnapshot.findMany({
        where: { userId, skill: 'fluency', source: 'speaking-session' },
        orderBy: { recordedAt: 'desc' },
        take: 10,
        select: { value: true },
      }),
    ]);
    const streak = await this.streak(userId);
    const baseline = [...vocabularySnapshots].reverse().find((snapshot) => snapshot.source === 'placement-baseline');
    const latest = vocabularySnapshots[0];
    const fluencyPoints = fluencySessions.flatMap((item) => item.value == null ? [] : [item.value]).reverse();
    const fluencyBaselineWpm = fluencyBaseline.length >= 2
      ? average(fluencyBaseline)
      : fluencyPoints.length > 0
        ? Math.round(fluencyPoints[0]!)
        : null;
    const fluencyLatestWpm = fluencyFollowUps.length > 0
      ? average(fluencyFollowUps)
      : fluencyPoints.length > 0
        ? Math.round(fluencyPoints[fluencyPoints.length - 1]!)
        : fluencyBaselineWpm;
    const fluencyScoreChange = fluencyBaselineWpm != null && fluencyLatestWpm != null && (fluencyFollowUps.length > 0 || fluencyPoints.length >= 2)
      ? fluencyLatestWpm - fluencyBaselineWpm
      : null;
    return {
      lessonsCompleted: lessons,
      vocabularyItemsReviewed: reviews._count._all,
      vocabularyRecallRepetitions: reviews._sum.repetitions ?? 0,
      speakingSessionsCompleted: speaking,
      vocabularyBaselineScore: baseline?.value ?? null,
      vocabularyLatestScore: latest?.value ?? null,
      vocabularyScoreChange: baseline && latest ? latest.value! - baseline.value! : null,
      fluencyBaselineWpm,
      fluencyLatestWpm,
      fluencyScoreChange,
      fluencyBaselineSessions: fluencyBaseline.length,
      fluencyTrend: fluencyPoints.map((value) => Math.round(value)),
      fluencyWpmVariance: standardDeviation(fluencyPoints),
      currentStreak: streak.currentDays,
      longestStreak: streak.longestDays,
      recentSpeakingSessions: recent,
      note: 'Practice estimates are based on completed learning actions; pronunciation and certified proficiency scores are unavailable.',
    };
  }

  public async streak(userId: string) {
    const [lessons, reviews, speaking, conversations, attempts, preferences, profile] = await Promise.all([
      this.database.lessonProgress.findMany({ where: { userId }, select: { completedAt: true } }),
      this.database.reviewSchedule.findMany({ where: { userId, lastReviewedAt: { not: null } }, select: { lastReviewedAt: true } }),
      this.database.speakingSession.findMany({ where: { userId, completedAt: { not: null }, deletedAt: null }, select: { completedAt: true } }),
      this.database.conversation.findMany({ where: { userId, finishedAt: { not: null } }, select: { finishedAt: true } }),
      this.database.ieltsAttempt.findMany({ where: { userId, finishedAt: { not: null } }, select: { finishedAt: true } }),
      this.database.streakState.findUnique({ where: { userId } }),
      this.database.profile.findUnique({ where: { userId }, select: { timezone: true } }),
    ]);
    const dates = [
      ...lessons.map((item) => item.completedAt),
      ...reviews.flatMap((item) => item.lastReviewedAt ? [item.lastReviewedAt] : []),
      ...speaking.flatMap((item) => item.completedAt ? [item.completedAt] : []),
      ...conversations.flatMap((item) => item.finishedAt ? [item.finishedAt] : []),
      ...attempts.flatMap((item) => item.finishedAt ? [item.finishedAt] : []),
    ];
    const calculated = countStreaks(dates, profile?.timezone ?? 'UTC');
    return {
      ...calculated,
      longestDays: Math.max(calculated.longestDays, preferences?.longestDays ?? 0),
      reminderTime: preferences?.reminderTime ?? null,
      reminderDays: this.parseDays(preferences?.reminderDays ?? '[]'),
    };
  }

  public async updateReminder(userId: string, time: string | null, days: number[]) {
    const state = await this.database.streakState.upsert({
      where: { userId },
      update: { reminderTime: time, reminderDays: JSON.stringify(days) },
      create: { userId, reminderTime: time, reminderDays: JSON.stringify(days) },
      select: { reminderTime: true, reminderDays: true },
    });
    return { reminderTime: state.reminderTime, reminderDays: this.parseDays(state.reminderDays) };
  }

  private parseDays(value: string): number[] {
    try {
      const parsed: unknown = JSON.parse(value);
      return Array.isArray(parsed) ? parsed.filter((day): day is number => Number.isInteger(day) && day >= 0 && day <= 6) : [];
    } catch {
      return [];
    }
  }
}
