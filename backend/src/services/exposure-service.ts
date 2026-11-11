import type { PrismaClient } from '@prisma/client';

import { AppError } from '../lib/http.js';

const SESSIONS_REQUIRED = 3;

const levelCatalog = [
  { level: 1, title: 'Silent input', description: 'Read or listen without speaking. Notice three useful phrases.', available: true },
  { level: 2, title: 'Whisper practice', description: 'Repeat short lines quietly. No recording and no score.', available: true },
  { level: 3, title: 'Private recording', description: 'Record and play your answer back privately.', available: true },
  { level: 4, title: 'Gentle feedback', description: 'Record a short answer and get transcript-based estimates.', available: true },
  { level: 5, title: 'Shadow practice', description: 'Shadow a model voice and compare timing.', available: true },
  { level: 6, title: 'AI conversation', description: 'Hold a full dialogue with an AI coach.', available: true },
  { level: 7, title: 'Community share', description: 'Optionally share a recording with other learners.', available: false, reason: 'Community features are not available yet.' },
] as const;

export class ExposureService {
  public constructor(private readonly database: PrismaClient) {}

  public async summary(userId: string) {
    const rows = await this.database.exposureProgress.findMany({ where: { userId } });
    const sessions = new Map(rows.map((row) => [row.level, row.sessions]));
    return {
      sessionsRequired: SESSIONS_REQUIRED,
      levels: levelCatalog.map((level) => {
        const sessionsCompleted = sessions.get(level.level) ?? 0;
        const previousComplete = level.level === 1 || (sessions.get(level.level - 1) ?? 0) >= SESSIONS_REQUIRED;
        return {
          ...level,
          sessionsCompleted,
          sessionsRequired: SESSIONS_REQUIRED,
          complete: sessionsCompleted >= SESSIONS_REQUIRED,
          unlocked: level.available && previousComplete,
        };
      }),
    };
  }

  public async record(userId: string, level: number) {
    const catalog = levelCatalog.find((entry) => entry.level === level);
    if (!catalog) throw new AppError(404, 'EXPOSURE_LEVEL_NOT_FOUND', 'The requested comfort level was not found.');
    if (!catalog.available) {
      throw new AppError(409, 'EXPOSURE_LEVEL_UNAVAILABLE', catalog.reason);
    }
    const summary = await this.summary(userId);
    const current = summary.levels.find((entry) => entry.level === level);
    if (!current?.unlocked) {
      throw new AppError(409, 'EXPOSURE_LEVEL_LOCKED', `Complete ${SESSIONS_REQUIRED} sessions at the previous level to unlock this one.`);
    }
    await this.database.exposureProgress.upsert({
      where: { userId_level: { userId, level } },
      update: { sessions: { increment: 1 }, lastPracticedAt: new Date() },
      create: { userId, level, sessions: 1, lastPracticedAt: new Date() },
    });
    return this.summary(userId);
  }
}
