import assert from 'node:assert/strict';
import test from 'node:test';

import { AppError } from '../lib/http.js';
import { VocabularyService } from './vocabulary-service.js';

type Item = {
  id: string;
  word: string;
  partOfSpeech: string;
  definition: string;
  example: string;
  level: string;
  tier: number;
};

function item(id: string, word: string, tier: number): Item {
  return {
    id,
    word,
    partOfSpeech: 'noun',
    definition: `${word} definition`,
    example: `An example with ${word}.`,
    level: 'intermediate',
    tier,
  };
}

function createDatabase(items: Item[]) {
  const schedules: Array<Record<string, unknown>> = [];
  const database = {
    reviewSchedule: {
      findMany: async () => schedules.map((schedule) => ({
        ...schedule,
        vocabulary: items.find((candidate) => candidate.id === schedule.vocabularyId)!,
      })),
      findUnique: async ({ where }: { where: { userId_vocabularyId: { userId: string; vocabularyId: string } } }) =>
        schedules.find(
          (schedule) => schedule.userId === where.userId_vocabularyId.userId
            && schedule.vocabularyId === where.userId_vocabularyId.vocabularyId,
        ) ?? null,
      createMany: async ({ data }: { data: Array<Record<string, unknown>> }) => {
        schedules.push(...data);
        return { count: data.length };
      },
      create: async ({ data }: { data: Record<string, unknown> }) => {
        schedules.push(data);
        return { ...data, dueAt: data.dueAt as Date, intervalDays: 0, repetitions: 0, easeFactor: 2.5, lapses: 0, lastGrade: null };
      },
      upsert: async ({ create }: { create: Record<string, unknown> }) => ({
        ...create,
        dueAt: create.dueAt as Date,
        intervalDays: create.intervalDays as number,
        repetitions: create.repetitions as number,
        easeFactor: create.easeFactor as number,
        lapses: create.lapses as number,
        lastGrade: create.lastGrade as string | null,
      }),
    },
    vocabularyItem: {
      findMany: async ({ where, take }: { where: { id?: { in: string[] }; word?: { in: string[] }; schedules?: unknown }; take?: number }) => {
        const matches = where.id?.in
          ? items.filter((candidate) => where.id!.in.includes(candidate.id))
          : where.word?.in
            ? items.filter((candidate) => where.word!.in.includes(candidate.word))
            : items;
        return take ? matches.slice(0, take) : matches;
      },
      findUnique: async ({ where }: { where: { id?: string; word?: string } }) =>
        items.find((candidate) => candidate.id === where.id || candidate.word === where.word) ?? null,
      create: async ({ data }: { data: Item }) => data,
    },
    lesson: { findUnique: async () => null },
    $transaction: async (callback: (transaction: unknown) => Promise<unknown>) => callback(database),
  };
  return { database: database as never, schedules };
}

test('getDue fills the remaining slots with unseen items in tier order', async () => {
  const items = [
    item('c', 'gamma', 3),
    item('a', 'alpha', 1),
    item('b', 'beta', 2),
  ];
  const { database } = createDatabase(items);
  const service = new VocabularyService(database);

  const due = await service.getDue('user-1', new Date('2026-11-13T10:00:00Z'), false);

  // Tier 2 is prioritized, then tier 1, then tier 3.
  assert.deepEqual(due.map((review) => review.item.word), ['beta', 'alpha', 'gamma']);
});

test('recordReview rejects a vocabulary item that does not exist', async () => {
  const { database } = createDatabase([]);
  const service = new VocabularyService(database);

  await assert.rejects(
    service.recordReview('user-1', 'missing', 'good', undefined, new Date(), false),
    (error: unknown) => error instanceof AppError && error.status === 404,
  );
});

test('scheduleEncounterWords schedules at most three catalog words per encounter', async () => {
  const items = [item('a', 'alpha', 1), item('b', 'beta', 2), item('c', 'gamma', 3), item('d', 'delta', 2)];
  const { database, schedules } = createDatabase(items);
  const service = new VocabularyService(database);
  const now = new Date('2026-11-13T10:00:00Z');

  const count = await service.scheduleEncounterWords('user-1', 'alpha beta gamma delta alpha', 'coach', now);

  assert.equal(count, 3);
  assert.equal(schedules.length, 3);
  assert.equal(schedules.every((schedule) => schedule.userId === 'user-1' && schedule.source === 'coach'), true);

  const again = await service.scheduleEncounterWords('user-1', 'alpha beta gamma delta', 'coach', now);
  assert.equal(again, 0);
});
