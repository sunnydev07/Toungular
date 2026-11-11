import type { PrismaClient, VocabularyItem as PrismaVocabularyItem } from '@prisma/client';
import { randomUUID } from 'node:crypto';

import type { RecallMode, ReviewGrade, VocabularyReview, VocabularyTier } from '../contracts.js';
import { AppError } from '../lib/http.js';
import { buildCloze, nextSchedule, recallModeFor, tierOrder } from './srs.js';

const DUE_LIMIT = 20;
const NEW_ITEM_POOL = 80;

type ScheduleRecord = {
  dueAt: Date;
  intervalDays: number;
  repetitions: number;
  easeFactor: number;
  lapses: number;
  lastGrade: string | null;
  source: string;
};

type ManualWordInput = {
  word: string;
  partOfSpeech: string;
  definition: string;
  example: string;
  level: string;
  tier?: number | undefined;
};

function emptySchedule(now: Date): ScheduleRecord {
  return {
    dueAt: now,
    intervalDays: 0,
    repetitions: 0,
    easeFactor: 2.5,
    lapses: 0,
    lastGrade: null,
    source: 'catalog',
  };
}

function toTier(value: number): VocabularyTier {
  return value === 1 || value === 3 ? value : 2;
}

function toReview(item: PrismaVocabularyItem, schedule: ScheduleRecord, ttsAvailable: boolean): VocabularyReview {
  const requested = recallModeFor(schedule.repetitions, ttsAvailable);
  const cloze = requested === 'cloze' ? buildCloze(item.example, item.word) : null;
  const recallMode: RecallMode = requested === 'cloze' && !cloze ? 'definition' : requested;
  return {
    item: {
      id: item.id,
      word: item.word,
      partOfSpeech: item.partOfSpeech,
      definition: item.definition,
      example: item.example,
      level: item.level,
      tier: toTier(item.tier),
    },
    dueAt: schedule.dueAt,
    intervalDays: schedule.intervalDays,
    repetitions: schedule.repetitions,
    easeFactor: schedule.easeFactor,
    lapses: schedule.lapses,
    lastGrade: schedule.lastGrade as ReviewGrade | null,
    recallMode,
    cloze,
    source: schedule.source,
  };
}

function tierForLevel(level: string): number {
  if (level === 'beginner' || level === 'elementary') return 1;
  if (level === 'advanced') return 3;
  return 2;
}

export class VocabularyService {
  public constructor(private readonly database: PrismaClient) {}

  public async getDue(userId: string, now: Date, ttsAvailable: boolean): Promise<VocabularyReview[]> {
    const scheduled = await this.database.reviewSchedule.findMany({
      where: { userId, dueAt: { lte: now } },
      orderBy: { dueAt: 'asc' },
      take: DUE_LIMIT,
      include: { vocabulary: true },
    });
    const remaining = DUE_LIMIT - scheduled.length;
    const candidates = remaining > 0
      ? await this.database.vocabularyItem.findMany({
        where: { schedules: { none: { userId } } },
        orderBy: { word: 'asc' },
        take: NEW_ITEM_POOL,
      })
      : [];
    const newItems = candidates
      .sort((left, right) => tierOrder(toTier(left.tier)) - tierOrder(toTier(right.tier)) || left.word.localeCompare(right.word))
      .slice(0, remaining);

    return [
      ...scheduled.map((schedule) => toReview(schedule.vocabulary, schedule, ttsAvailable)),
      ...newItems.map((item) => toReview(item, emptySchedule(now), ttsAvailable)),
    ];
  }

  public async recordReview(
    userId: string,
    itemId: string,
    grade: ReviewGrade,
    mode: RecallMode | undefined,
    now: Date,
    ttsAvailable: boolean,
  ): Promise<VocabularyReview> {
    const item = await this.database.vocabularyItem.findUnique({ where: { id: itemId } });
    if (!item) {
      throw new AppError(404, 'VOCABULARY_NOT_FOUND', 'The requested vocabulary item was not found.');
    }
    const current = await this.database.reviewSchedule.findUnique({
      where: { userId_vocabularyId: { userId, vocabularyId: itemId } },
    });
    const next = nextSchedule(
      {
        intervalDays: current?.intervalDays ?? 0,
        repetitions: current?.repetitions ?? 0,
        easeFactor: current?.easeFactor ?? 2.5,
        lapses: current?.lapses ?? 0,
      },
      grade,
      { now, mode, contextual: (current?.source ?? 'catalog') !== 'catalog' },
    );
    const schedule = next;
    const persisted = await this.database.reviewSchedule.upsert({
      where: { userId_vocabularyId: { userId, vocabularyId: itemId } },
      update: {
        ...schedule,
        lastGrade: grade,
        lastRecallMode: mode ?? null,
        lastReviewedAt: now,
      },
      create: {
        userId,
        vocabularyId: itemId,
        ...schedule,
        source: current?.source ?? 'catalog',
        context: current?.context ?? null,
        lastGrade: grade,
        lastRecallMode: mode ?? null,
        lastReviewedAt: now,
      },
    });
    return toReview(item, persisted, ttsAvailable);
  }

  public async addManual(userId: string, input: ManualWordInput, now: Date, ttsAvailable: boolean): Promise<VocabularyReview> {
    const word = input.word.trim().toLowerCase();
    const existing = await this.database.vocabularyItem.findUnique({ where: { word } });
    if (existing) return this.scheduleNew(userId, existing, 'manual', null, now, ttsAvailable);

    const slug = word.replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '') || 'word';
    const item = await this.database.vocabularyItem.create({
      data: {
        id: `vocab-${slug}-${randomUUID().slice(0, 8)}`,
        word,
        partOfSpeech: input.partOfSpeech,
        definition: input.definition,
        example: input.example,
        level: input.level,
        tier: input.tier ?? tierForLevel(input.level),
      },
    });
    return this.scheduleNew(userId, item, 'manual', null, now, ttsAvailable);
  }

  public async recordEncounter(
    userId: string,
    word: string,
    source: string,
    context: string | null,
    now: Date,
    ttsAvailable: boolean,
  ) {
    const normalized = word.trim().toLowerCase();
    const item = await this.database.vocabularyItem.findUnique({ where: { word: normalized } });
    if (!item) {
      return { word: normalized, scheduled: false, reason: 'not_in_catalog' };
    }
    const review = await this.scheduleNew(userId, item, source, context, now, ttsAvailable);
    return { word: normalized, scheduled: true, review };
  }

  public async scheduleLessonWords(userId: string, lessonId: string, now: Date): Promise<number> {
    const lesson = await this.database.lesson.findUnique({
      where: { id: lessonId },
      select: { vocabularyIds: true },
    });
    const ids = this.parseIds(lesson?.vocabularyIds).slice(0, 6);
    if (ids.length === 0) return 0;
    return this.scheduleItems(userId, ids, 'lesson', null, now);
  }

  public async scheduleEncounterWords(
    userId: string,
    transcript: string,
    source: string,
    now: Date,
  ): Promise<number> {
    const tokens = [...new Set((transcript.toLowerCase().match(/[a-z][a-z'-]{2,}/g) ?? []))].slice(0, 80);
    if (tokens.length === 0) return 0;
    const items = await this.database.vocabularyItem.findMany({ where: { word: { in: tokens } }, take: 3 });
    if (items.length === 0) return 0;
    return this.scheduleItems(userId, items.map((item) => item.id), source, transcript.slice(0, 500), now);
  }

  private async scheduleItems(
    userId: string,
    itemIds: string[],
    source: string,
    context: string | null,
    now: Date,
  ): Promise<number> {
    const items = await this.database.vocabularyItem.findMany({ where: { id: { in: itemIds } } });
    let created = 0;
    for (const item of items) {
      const schedule = await this.database.reviewSchedule.findUnique({
        where: { userId_vocabularyId: { userId, vocabularyId: item.id } },
      });
      if (schedule) continue;
      await this.database.reviewSchedule.create({
        data: { userId, vocabularyId: item.id, dueAt: now, source, context },
      });
      created += 1;
    }
    return created;
  }

  private async scheduleNew(
    userId: string,
    item: PrismaVocabularyItem,
    source: string,
    context: string | null,
    now: Date,
    ttsAvailable: boolean,
  ): Promise<VocabularyReview> {
    const current = await this.database.reviewSchedule.findUnique({
      where: { userId_vocabularyId: { userId, vocabularyId: item.id } },
    });
    if (current) {
      return toReview(item, current, ttsAvailable);
    }
    const schedule = await this.database.reviewSchedule.create({
      data: { userId, vocabularyId: item.id, dueAt: now, source, context },
    });
    return toReview(item, schedule, ttsAvailable);
  }

  private parseIds(encoded: string | undefined): string[] {
    if (!encoded) return [];
    try {
      const parsed: unknown = JSON.parse(encoded);
      return Array.isArray(parsed) ? parsed.filter((value): value is string => typeof value === 'string') : [];
    } catch {
      return [];
    }
  }
}
