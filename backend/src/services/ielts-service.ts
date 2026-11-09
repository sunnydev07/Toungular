import type { PrismaClient } from '@prisma/client';

import { AppError } from '../lib/http.js';

const mocks = [{
  id: 'toungular-speaking-foundations',
  title: 'Speaking foundations',
  description: 'An original three-part timed speaking practice set.',
  sections: [
    { id: 'part-1', title: 'Part 1 · Interview', prompt: 'What do you enjoy most about your neighborhood?', preparationSeconds: 15, responseSeconds: 60 },
    { id: 'part-2', title: 'Part 2 · Long turn', prompt: 'Describe a useful skill you learned. Say how you learned it, what was difficult, and how you use it now.', preparationSeconds: 60, responseSeconds: 120 },
    { id: 'part-3', title: 'Part 3 · Discussion', prompt: 'How can people stay motivated when they are learning a difficult skill?', preparationSeconds: 15, responseSeconds: 120 },
  ],
}];

export class IeltsService {
  public constructor(private readonly database: PrismaClient) {}

  public loadMocks() { return mocks; }

  public async startAttempt(userId: string, mockId: string) {
    if (!mocks.some((mock) => mock.id === mockId)) throw new AppError(404, 'IELTS_MOCK_NOT_FOUND', 'This practice set was not found.');
    return this.database.ieltsAttempt.create({
      data: { userId, mockId },
      select: { id: true, mockId: true, status: true, startedAt: true },
    });
  }

  public async submitResponse(userId: string, attemptId: string, sectionId: string, transcript: string) {
    const attempt = await this.database.ieltsAttempt.findFirst({ where: { id: attemptId, userId } });
    if (!attempt) throw new AppError(404, 'IELTS_ATTEMPT_NOT_FOUND', 'The practice attempt was not found.');
    if (attempt.status !== 'in_progress') throw new AppError(409, 'IELTS_ATTEMPT_FINISHED', 'This practice attempt has already ended.');
    const mock = mocks.find((item) => item.id === attempt.mockId);
    if (!mock?.sections.some((section) => section.id === sectionId)) throw new AppError(404, 'IELTS_SECTION_NOT_FOUND', 'This section was not found.');
    return this.database.ieltsAttemptResponse.upsert({
      where: { attemptId_sectionId: { attemptId, sectionId } },
      update: { transcript },
      create: { attemptId, sectionId, transcript },
      select: { id: true, sectionId: true, transcript: true, updatedAt: true },
    });
  }

  public async finishAttempt(userId: string, attemptId: string) {
    const attempt = await this.database.ieltsAttempt.findFirst({ where: { id: attemptId, userId } });
    if (!attempt) throw new AppError(404, 'IELTS_ATTEMPT_NOT_FOUND', 'The practice attempt was not found.');
    const count = await this.database.ieltsAttemptResponse.count({ where: { attemptId } });
    const finishedAt = new Date();
    return this.database.ieltsAttempt.update({
      where: { id: attemptId },
      data: {
        status: 'completed',
        finishedAt,
        feedback: `Saved ${count} section response${count === 1 ? '' : 's'}. No official band score is provided.`,
      },
      select: { id: true, status: true, feedback: true, finishedAt: true },
    });
  }

  public async history(userId: string) {
    return this.database.ieltsAttempt.findMany({
      where: { userId },
      orderBy: { startedAt: 'desc' },
      take: 20,
      include: { responses: { orderBy: { createdAt: 'asc' } } },
    });
  }
}
