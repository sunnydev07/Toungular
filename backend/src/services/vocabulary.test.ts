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
  createdByUserId?: string | null;
};

function item(id: string, word: string, tier: number, createdByUserId?: string): Item {
  return {
    id,
    word,
    partOfSpeech: 'noun',
    definition: `${word} definition`,
    example: `An example with ${word}.`,
    level: 'intermediate',
    tier,
    createdByUserId: createdByUserId ?? null,
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
      findMany: async ({ where, take }: { where: { id?: { in: string[] }; word?: { in: string[] }; OR?: Array<{ createdByUserId: string | null }> }; take?: number }) => {
        let matches = items;
        if (where.OR) {
          matches = matches.filter((candidate) => where.OR!.some(
            (clause) => (candidate.createdByUserId ?? null) === clause.createdByUserId,
          ));
        }
        matches = where.id?.in
          ? matches.filter((candidate) => where.id!.in.includes(candidate.id))
          : where.word?.in
            ? matches.filter((candidate) => where.word!.in.includes(candidate.word))
            : matches;
        return take ? matches.slice(0, take) : matches;
      },
      findUnique: async ({ where }: { where: { id?: string; word?: string } }) =>
        items.find((candidate) => candidate.id === where.id || candidate.word === where.word) ?? null,
      create: async ({ data }: { data: Item }) => {
        items.push(data);
        return data;
      },
      update: async ({ where, data }: { where: { id: string }; data: Partial<Item> }) => {
        const found = items.find((candidate) => candidate.id === where.id)!;
        Object.assign(found, data);
        return found;
      },
    },
    lesson: { findUnique: async () => null },
    $transaction: async (callback: (transaction: unknown) => Promise<unknown>) => callback(database),
  };
  return { database: database as never, schedules, items };
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

test('another learner\'s manual word never appears in the due queue', async () => {
  const items = [
    item('a', 'alpha', 2),
    item('b', 'private', 2, 'user-a'),
  ];
  const { database } = createDatabase(items);
  const service = new VocabularyService(database);
  const now = new Date('2026-11-13T10:00:00Z');

  const forB = await service.getDue('user-b', now, false);
  const forA = await service.getDue('user-a', now, false);

  assert.deepEqual(forB.map((review) => review.item.word), ['alpha']);
  assert.deepEqual(forA.map((review) => review.item.word), ['alpha', 'private']);
});

test('addManual tags a new word with its creator', async () => {
  const { database, items } = createDatabase([]);
  const service = new VocabularyService(database);

  await service.addManual(
    'user-a',
    {
      word: 'Serendipity',
      partOfSpeech: 'noun',
      definition: 'A fortunate discovery.',
      example: 'Finding the cafe was pure serendipity.',
      level: 'advanced',
    },
    new Date('2026-11-13T10:00:00Z'),
    false,
  );

  const created = items.find((candidate) => candidate.word === 'serendipity');
  assert.equal(created?.createdByUserId, 'user-a');
});

test('addManual overwrites the definition only for the owner and keeps others\' wording on the schedule', async () => {
  const { database, items, schedules } = createDatabase([item('a', 'alpha', 2, 'user-a')]);
  const service = new VocabularyService(database);
  const now = new Date('2026-11-13T10:00:00Z');

  await service.addManual(
    'user-a',
    { word: 'alpha', partOfSpeech: 'adjective', definition: 'Owner wording.', example: 'Owner example.', level: 'advanced' },
    now,
    false,
  );
  assert.equal(items[0]?.definition, 'Owner wording.');

  await service.addManual(
    'user-b',
    { word: 'alpha', partOfSpeech: 'adjective', definition: 'B wording.', example: 'B example.', level: 'advanced' },
    now,
    false,
  );
  assert.equal(items[0]?.definition, 'Owner wording.');
  assert.equal(
    schedules.find((schedule) => schedule.userId === 'user-b')?.context,
    JSON.stringify({ definition: 'B wording.', example: 'B example.' }),
  );
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
