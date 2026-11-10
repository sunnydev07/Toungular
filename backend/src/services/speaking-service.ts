import type { PrismaClient } from '@prisma/client';

import { AppError } from '../lib/http.js';

const fillerWords = new Set(['um', 'uh', 'erm', 'like', 'basically', 'actually']);

export class SpeakingService {
  public constructor(private readonly database: PrismaClient) {}

  public async start(userId: string, input: { type: 'prompt' | 'ielts' | 'baseline'; prompt: string }) {
    return this.database.speakingSession.create({
      data: { userId, type: input.type, prompt: input.prompt },
      select: { id: true, type: true, status: true, prompt: true, startedAt: true },
    });
  }

  public async saveTranscript(userId: string, id: string, transcript: string) {
    const session = await this.database.speakingSession.findFirst({ where: { id, userId, deletedAt: null } });
    if (!session) throw new AppError(404, 'SPEAKING_SESSION_NOT_FOUND', 'The speaking session was not found.');
    return this.database.speakingSession.update({
      where: { id },
      data: { transcript, status: 'transcript_saved' },
      select: { id: true, status: true, prompt: true, startedAt: true },
    });
  }

  public async analyze(userId: string, id: string, durationSeconds: number) {
    const session = await this.database.speakingSession.findFirst({ where: { id, userId, deletedAt: null } });
    if (!session) throw new AppError(404, 'SPEAKING_SESSION_NOT_FOUND', 'The speaking session was not found.');
    const transcript = session.transcript?.trim() ?? '';
    if (!transcript) throw new AppError(400, 'TRANSCRIPT_REQUIRED', 'Add the words you said before viewing practice feedback.');

    const words = transcript.match(/[A-Za-z]+(?:['’-][A-Za-z]+)*/g) ?? [];
    const normalized = words.map((word) => word.toLowerCase());
    const fillers = normalized.filter((word) => fillerWords.has(word));
    const vocabularyVariety = words.length === 0 ? 0 : new Set(normalized).size / words.length;
    const result = {
      label: 'Practice estimate based on your transcript and session length',
      wordCount: words.length,
      wordsPerMinute: Math.round((words.length * 60) / durationSeconds),
      fillerCount: fillers.length,
      vocabularyVariety: Number(vocabularyVariety.toFixed(2)),
      pronunciation: { status: 'unavailable', message: 'Pronunciation scoring is not configured yet.' },
      nextStep: fillers.length > 0
        ? 'Pause briefly instead of filling every gap. Try one more answer on the same prompt.'
        : 'Add one specific example to make your next answer easier to follow.',
    };
    await this.database.speakingSession.update({
      where: { id },
      data: { feedback: JSON.stringify(result), status: 'completed', completedAt: new Date() },
    });
    if (session.type === 'baseline') {
      const baselineCount = await this.database.skillSnapshot.count({
        where: { userId, skill: 'fluency', source: 'speaking-baseline' },
      });
      await this.database.skillSnapshot.create({
        data: {
          userId,
          skill: 'fluency',
          value: result.wordsPerMinute,
          source: baselineCount < 2 ? 'speaking-baseline' : 'speaking-follow-up',
        },
      });
    }
    return result;
  }

  public async history(userId: string) {
    const sessions = await this.database.speakingSession.findMany({
      where: { userId, deletedAt: null },
      orderBy: { startedAt: 'desc' },
      take: 30,
      select: { id: true, type: true, status: true, prompt: true, transcript: true, feedback: true, startedAt: true, completedAt: true },
    });
    return sessions.map((session) => ({
      ...session,
      feedback: session.feedback ? this.parseFeedback(session.feedback) : null,
    }));
  }

  private parseFeedback(value: string): unknown {
    try {
      return JSON.parse(value) as unknown;
    } catch {
      return { label: 'Feedback unavailable', nextStep: 'Try another practice session.' };
    }
  }
}
