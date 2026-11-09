import type { PrismaClient } from '@prisma/client';

import { AppError } from '../lib/http.js';

const assessmentIds = [
  'vocab-comfortable', 'vocab-describe', 'vocab-detail', 'vocab-benefit', 'vocab-clarify',
  'vocab-consistent', 'vocab-adapt', 'vocab-approach', 'vocab-example', 'vocab-focus',
  'vocab-improve', 'vocab-organize', 'vocab-prepare', 'vocab-respond', 'vocab-routine',
  'vocab-specific', 'vocab-strategy', 'vocab-support', 'vocab-reflect', 'vocab-opportunity',
];

export class PlacementService {
  public constructor(private readonly database: PrismaClient) {}

  public async questions() {
    const items = await this.database.vocabularyItem.findMany({ where: { id: { in: assessmentIds } } });
    const byId = new Map(items.map((item) => [item.id, item]));
    if (items.length !== assessmentIds.length) throw new AppError(503, 'PLACEMENT_UNAVAILABLE', 'The English placement content is incomplete.');
    return assessmentIds.map((id, index) => {
      const correct = byId.get(id)!;
      const choices = [...new Set([correct.word, ...[4, 8, 12].map((offset) => byId.get(assessmentIds[(index + offset) % assessmentIds.length]!)!.word)])];
      const rotation = index % choices.length;
      const rotatedChoices = [...choices.slice(rotation), ...choices.slice(0, rotation)];
      return { id, prompt: correct.definition, choices: rotatedChoices };
    });
  }

  public async submitVocabulary(userId: string, answers: Array<{ itemId: string; word: string }>) {
    if (answers.length !== assessmentIds.length || new Set(answers.map((answer) => answer.itemId)).size !== assessmentIds.length) {
      throw new AppError(400, 'PLACEMENT_ANSWERS_INVALID', 'Submit one answer for each of the 20 placement questions.');
    }
    if (answers.some((answer) => !assessmentIds.includes(answer.itemId))) {
      throw new AppError(400, 'PLACEMENT_ANSWERS_INVALID', 'One or more placement questions are not recognized.');
    }
    const items = await this.database.vocabularyItem.findMany({ where: { id: { in: assessmentIds } }, select: { id: true, word: true } });
    const correctById = new Map(items.map((item) => [item.id, item.word.toLowerCase()]));
    let score = 0;
    for (const answer of answers) {
      if (correctById.get(answer.itemId) === answer.word.trim().toLowerCase()) score++;
    }
    const previous = await this.database.skillSnapshot.findFirst({
      where: { userId, skill: 'vocabulary', source: { in: ['placement-baseline', 'placement-follow-up'] } },
      orderBy: { recordedAt: 'desc' },
      select: { value: true },
    });
    const baseline = previous == null;
    await this.database.skillSnapshot.create({
      data: {
        userId,
        skill: 'vocabulary',
        value: score,
        source: baseline ? 'placement-baseline' : 'placement-follow-up',
      },
    });
    return {
      score,
      total: assessmentIds.length,
      baseline,
      previousScore: previous?.value ?? null,
      change: previous ? score - previous.value! : null,
      label: 'Vocabulary recall practice check, not a certified proficiency result.',
    };
  }
}
