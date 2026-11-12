import type { PrismaClient } from '@prisma/client';

import { logger, type Logger } from '../lib/logger.js';

/** Draft speaking sessions that never reached analysis are removed after this age. */
export const DRAFT_MAX_AGE_MS = 48 * 60 * 60 * 1000;
/** IELTS attempts left in progress are abandoned after this age. */
export const IELTS_ATTEMPT_MAX_AGE_MS = 24 * 60 * 60 * 1000;
export const RETENTION_INTERVAL_MS = 6 * 60 * 60 * 1000;

export type RetentionReport = {
  draftsDeleted: number;
  attemptsAbandoned: number;
  idempotencyKeysPruned: number;
};

export async function runRetention(
  database: PrismaClient,
  now: Date = new Date(),
): Promise<RetentionReport> {
  const drafts = await database.speakingSession.deleteMany({
    where: {
      status: { in: ['draft', 'transcript_saved'] },
      deletedAt: null,
      startedAt: { lt: new Date(now.getTime() - DRAFT_MAX_AGE_MS) },
    },
  });

  const attempts = await database.ieltsAttempt.updateMany({
    where: {
      status: 'in_progress',
      startedAt: { lt: new Date(now.getTime() - IELTS_ATTEMPT_MAX_AGE_MS) },
    },
    data: {
      status: 'abandoned',
      finishedAt: now,
      feedback: 'This attempt expired after 24 hours without being finished. No band score is provided.',
    },
  });

  const keys = await database.idempotencyKey.deleteMany({
    where: { createdAt: { lt: new Date(now.getTime() - 24 * 60 * 60 * 1000) } },
  });

  return {
    draftsDeleted: drafts.count,
    attemptsAbandoned: attempts.count,
    idempotencyKeysPruned: keys.count,
  };
}

/**
 * Runs the retention sweep immediately and then on a fixed interval. The timer
 * is unref'd so it never keeps the process alive on its own.
 */
export function startRetentionLoop(database: PrismaClient, log: Logger = logger): () => void {
  const run = (): void => {
    void runRetention(database)
      .then((report) => {
        if (report.draftsDeleted || report.attemptsAbandoned || report.idempotencyKeysPruned) {
          log.info(report, 'retention sweep completed');
        }
      })
      .catch((error: unknown) => log.error({ err: error }, 'retention sweep failed'));
  };

  run();
  const timer = setInterval(run, RETENTION_INTERVAL_MS);
  timer.unref();
  return () => clearInterval(timer);
}
