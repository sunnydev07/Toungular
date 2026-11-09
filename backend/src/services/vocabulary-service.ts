import type { PrismaClient } from '@prisma/client';

import type { ReviewGrade, VocabularyReview } from '../contracts.js';
import { AppError } from '../lib/http.js';

const DUE_LIMIT = 20;

function toReview(item: {
  id: string;
  word: string;
  partOfSpeech: string;
  definition: string;
  example: string;
  level: string;
}, schedule: {
  dueAt: Date;
  intervalDays: number;
  repetitions: number;
  lastGrade: string | null;
}): VocabularyReview {
  return {
    item,
    dueAt: schedule.dueAt,
    intervalDays: schedule.intervalDays,
    repetitions: schedule.repetitions,
    lastGrade: schedule.lastGrade as ReviewGrade | null,
  };
}

function nextSchedule(grade: ReviewGrade, intervalDays: number, repetitions: number, now: Date) {
  const nextInterval = (() => {
    if (grade === 'again') return 1;
    if (grade === 'hard') return Math.max(1, intervalDays + 1);
    if (grade === 'good') return repetitions === 0 ? 1 : repetitions === 1 ? 3 : intervalDays * 2;
    return repetitions === 0 ? 3 : Math.max(4, intervalDays * 3);
  })();
  return {
    intervalDays: nextInterval,
    repetitions: grade === 'again' ? 0 : repetitions + 1,
    dueAt: new Date(now.getTime() + nextInterval * 24 * 60 * 60 * 1000),
  };
}

export class VocabularyService {
  public constructor(private readonly database: PrismaClient) {}

  public async getDue(userId: string, now: Date): Promise<VocabularyReview[]> {
    const scheduled = await this.database.reviewSchedule.findMany({
      where: { userId, dueAt: { lte: now } },
      orderBy: { dueAt: 'asc' },
      take: DUE_LIMIT,
      include: { vocabulary: true },
    });
    const remaining = DUE_LIMIT - scheduled.length;
    const newItems = remaining > 0
      ? await this.database.vocabularyItem.findMany({
        where: { schedules: { none: { userId } } },
        orderBy: { word: 'asc' },
        take: remaining,
      })
      : [];

    return [
      ...scheduled.map((schedule) => toReview(schedule.vocabulary, schedule)),
      ...newItems.map((item) => toReview(item, {
        dueAt: now,
        intervalDays: 0,
        repetitions: 0,
        lastGrade: null,
      })),
    ];
  }

  public async recordReview(
    userId: string,
    itemId: string,
    grade: ReviewGrade,
    now: Date,
  ): Promise<VocabularyReview> {
    const item = await this.database.vocabularyItem.findUnique({ where: { id: itemId } });
    if (!item) {
      throw new AppError(404, 'VOCABULARY_NOT_FOUND', 'The requested vocabulary item was not found.');
    }
    const current = await this.database.reviewSchedule.findUnique({
      where: { userId_vocabularyId: { userId, vocabularyId: itemId } },
    });
    const scheduled = nextSchedule(grade, current?.intervalDays ?? 0, current?.repetitions ?? 0, now);
    const persisted = await this.database.reviewSchedule.upsert({
      where: { userId_vocabularyId: { userId, vocabularyId: itemId } },
      update: { ...scheduled, lastGrade: grade, lastReviewedAt: now },
      create: {
        userId,
        vocabularyId: itemId,
        ...scheduled,
        lastGrade: grade,
        lastReviewedAt: now,
      },
    });
    return toReview(item, persisted);
  }
}
