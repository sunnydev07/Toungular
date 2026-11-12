import type { PrismaClient } from '@prisma/client';

import { isPrismaCode } from '../lib/http.js';

const DEFAULT_MAX_AGE_MS = 24 * 60 * 60 * 1000;

export type IdempotentResult<T> = { value: T; replayed: boolean };

/**
 * Replays a previously stored response for the same (user, scope, key) tuple.
 * A concurrent duplicate loses the unique-index race and reads the winner's
 * response, so handlers run at most once per key.
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
      return { value: JSON.parse(existing.response) as T, replayed: true };
    }

    const value = await handler();
    try {
      await this.database.idempotencyKey.create({
        data: { userId, scope, key, response: JSON.stringify(value) },
      });
    } catch (error) {
      if (isPrismaCode(error, 'P2002')) {
        const raced = await this.database.idempotencyKey.findUnique({ where });
        if (raced) return { value: JSON.parse(raced.response) as T, replayed: true };
      }
      throw error;
    }
    return { value, replayed: false };
  }

  public async prune(now: Date = new Date()): Promise<number> {
    const cutoff = new Date(now.getTime() - this.maxAgeMs);
    const result = await this.database.idempotencyKey.deleteMany({ where: { createdAt: { lt: cutoff } } });
    return result.count;
  }
}
