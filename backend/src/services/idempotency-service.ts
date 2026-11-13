import type { PrismaClient } from '@prisma/client';

import { AppError, isPrismaCode } from '../lib/http.js';

const DEFAULT_MAX_AGE_MS = 24 * 60 * 60 * 1000;
const PENDING_SENTINEL = '__PENDING__';

export type IdempotentResult<T> = { value: T; replayed: boolean };

/**
 * Replays a previously stored response for the same (user, scope, key) tuple.
 * The key row is claimed with a pending sentinel before the handler runs, so a
 * concurrent duplicate either reads the finished response or is told the
 * original request is still in flight instead of double-charging quotas.
 */
export class IdempotencyService {
  public constructor(
    private readonly database: PrismaClient,
    private readonly maxAgeMs: number = DEFAULT_MAX_AGE_MS,
  ) {}

  public async run<T>(
    userId: string,
    scope: string,
    key: string,
    handler: () => Promise<T>,
  ): Promise<IdempotentResult<T>> {
    const where = { userId_scope_key: { userId, scope, key } };
    const existing = await this.database.idempotencyKey.findUnique({ where });
    if (existing) {
      if (existing.response === PENDING_SENTINEL) {
        throw new AppError(409, 'IDEMPOTENCY_IN_PROGRESS', 'A request with this Idempotency-Key is already in progress.');
      }
      return { value: JSON.parse(existing.response) as T, replayed: true };
    }

    try {
      await this.database.idempotencyKey.create({
        data: { userId, scope, key, response: PENDING_SENTINEL },
      });
    } catch (error) {
      if (isPrismaCode(error, 'P2002')) {
        const raced = await this.database.idempotencyKey.findUnique({ where });
        if (raced && raced.response !== PENDING_SENTINEL) {
          return { value: JSON.parse(raced.response) as T, replayed: true };
        }
        throw new AppError(409, 'IDEMPOTENCY_IN_PROGRESS', 'A request with this Idempotency-Key is already in progress.');
      }
      throw error;
    }

    try {
      const value = await handler();
      await this.database.idempotencyKey.update({
        where,
        data: { response: JSON.stringify(value) },
      });
      return { value, replayed: false };
    } catch (error) {
      // A failed handler must not poison the key: release the claim so a retry
      // can run instead of replaying an empty or stale response.
      await this.database.idempotencyKey
        .deleteMany({ where: { userId, scope, key, response: PENDING_SENTINEL } })
        .catch(() => undefined);
      throw error;
    }
  }

  public async prune(now: Date = new Date()): Promise<number> {
    const cutoff = new Date(now.getTime() - this.maxAgeMs);
    const result = await this.database.idempotencyKey.deleteMany({ where: { createdAt: { lt: cutoff } } });
    return result.count;
  }
}
