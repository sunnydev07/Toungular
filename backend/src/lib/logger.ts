import type { RequestHandler } from 'express';
import { pino } from 'pino';

export const logger = pino({
  level: process.env.LOG_LEVEL ?? 'info',
  base: { service: 'toungular-api' },
  redact: {
    paths: [
      'req.headers.authorization',
      'req.headers.cookie',
      'res.headers["set-cookie"]',
    ],
    censor: '[redacted]',
  },
});

export type Logger = typeof logger;

/**
 * Logs every completed request with its correlation id and duration. Request
 * ids are attached by the earlier request-id middleware; the user id is only
 * present once authentication has run.
 */
export function requestLogger(log: Logger = logger): RequestHandler {
  return (request, response, next) => {
    const startedAt = process.hrtime.bigint();
    response.on('finish', () => {
      const durationMs = Number(process.hrtime.bigint() - startedAt) / 1_000_000;
      const payload: Record<string, unknown> = {
        requestId: response.locals?.requestId,
        method: request.method,
        path: request.originalUrl,
        status: response.statusCode,
        durationMs: Math.round(durationMs),
      };
      if (request.auth?.userId) payload.userId = request.auth.userId;
      if (response.statusCode >= 500) {
        log.error(payload, 'request failed');
      } else if (response.statusCode >= 400) {
        log.warn(payload, 'request rejected');
      } else {
        log.info(payload, 'request completed');
      }
    });
    next();
  };
}
