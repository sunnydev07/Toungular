import type { PrismaClient } from '@prisma/client';

import { AppError } from '../lib/http.js';
import { analyzeTranscript, wpmTrend } from './fluency.js';

const FEEDBACK_LIMIT = 5;

export class SpeakingService {
  public constructor(private readonly database: PrismaClient) {}

  public async start(userId: string, input: { type: string; prompt: string }) {
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

  public async analyze(
    userId: string,
    id: string,
    input: { durationSeconds: number; transcript?: string | undefined; pauses?: number[] | undefined },
  ) {
    const session = await this.database.speakingSession.findFirst({ where: { id, userId, deletedAt: null } });
    if (!session) throw new AppError(404, 'SPEAKING_SESSION_NOT_FOUND', 'The speaking session was not found.');
    const transcript = (input.transcript ?? session.transcript ?? '').trim();
    if (!transcript) throw new AppError(400, 'TRANSCRIPT_REQUIRED', 'Add the words you said before viewing practice feedback.');

    const duration = Math.max(1, input.durationSeconds);
    const wordCount = (transcript.match(/[A-Za-z]+(?:['’-][A-Za-z]+)*/g) ?? []).length;
    // Roughly 300 WPM is the fastest plausible human speech; a shorter session
    // would inflate WPM and the fluency trend from client-supplied timing.
    if (wordCount > duration * 5) {
      throw new AppError(422, 'IMPLAUSIBLE_DURATION', 'The session length is too short for the submitted transcript. Record the full answer and try again.');
    }
    const pauses = input.pauses ?? [];
    const pauseSeconds = pauses
      .filter((pause) => Number.isFinite(pause) && pause > 0)
      .reduce((total, pause) => total + pause, 0);
    if (pauseSeconds > duration) {
      throw new AppError(422, 'IMPLAUSIBLE_PAUSES', 'The reported pauses do not fit inside the recording length.');
    }

    const analysis = analyzeTranscript(transcript, duration, pauses);
    const previous = await this.database.speakingSession.findMany({
      where: { userId, status: 'completed', deletedAt: null, feedback: { not: null }, id: { not: id } },
      orderBy: { completedAt: 'desc' },
      take: FEEDBACK_LIMIT,
      select: { feedback: true },
    });
    const previousWpm = previous
      .reverse()
      .flatMap((item) => {
        const value = this.parseFeedback(item.feedback)?.wordsPerMinute;
        return typeof value === 'number' ? [value] : [];
      });
    const trend = wpmTrend(previousWpm, analysis.wordsPerMinute);

    const result = {
      label: 'Practice estimate based on your transcript and session length',
      ...analysis,
      wpmTrend: {
        points: trend.points,
        average: trend.average,
        variance: trend.variance,
        change: trend.change,
        message: trend.message,
      },
      pronunciation: { status: 'unavailable', message: 'Pronunciation scoring is not configured yet.' },
    };

    if (session.type === 'anonymous') {
      await this.database.speakingSession.delete({ where: { id } });
      return result;
    }

    await this.database.speakingSession.update({
      where: { id },
      data: {
        transcript,
        feedback: JSON.stringify(result),
        status: 'completed',
        completedAt: new Date(),
      },
    });
    await this.recordFluencySnapshot(userId, session.type, analysis.wordsPerMinute);
    return result;
  }

  public async history(userId: string, limit = 30, offset = 0) {
    const sessions = await this.database.speakingSession.findMany({
      where: { userId, deletedAt: null, type: { not: 'anonymous' } },
      orderBy: { startedAt: 'desc' },
      take: limit,
      skip: offset,
      select: { id: true, type: true, status: true, prompt: true, transcript: true, feedback: true, startedAt: true, completedAt: true },
    });
    return sessions.map((session) => ({
      ...session,
      feedback: session.feedback ? this.parseFeedback(session.feedback) : null,
    }));
  }

  private async recordFluencySnapshot(userId: string, type: string, wordsPerMinute: number): Promise<void> {
    if (type === 'baseline') {
      const baselineCount = await this.database.skillSnapshot.count({
        where: { userId, skill: 'fluency', source: 'speaking-baseline' },
      });
      await this.database.skillSnapshot.create({
        data: {
          userId,
          skill: 'fluency',
          value: wordsPerMinute,
          source: baselineCount < 2 ? 'speaking-baseline' : 'speaking-follow-up',
        },
      });
      return;
    }
    await this.database.skillSnapshot.create({
      data: { userId, skill: 'fluency', value: wordsPerMinute, source: 'speaking-session' },
    });
  }

  private parseFeedback(value: string | null): { wordsPerMinute?: number } | null {
    if (!value) return null;
    try {
      const parsed: unknown = JSON.parse(value);
      return typeof parsed === 'object' && parsed !== null ? parsed as { wordsPerMinute?: number } : null;
    } catch {
      return null;
    }
  }
}
