import type { ErrorRequestHandler, RequestHandler } from 'express';
import { ZodError } from 'zod';

import { logger } from './logger.js';

export class AppError extends Error {
  public constructor(
    public readonly status: number,
    public readonly code: string,
    message: string,
  ) {
    super(message);
  }
}

export function isPrismaCode(error: unknown, code: string): boolean {
  return (
    typeof error === 'object' &&
    error !== null &&
    'code' in error &&
    (error as { code?: unknown }).code === code
  );
}

export function asyncRoute(handler: RequestHandler): RequestHandler {
  return (request, response, next) => {
    Promise.resolve(handler(request, response, next)).catch(next);
  };
}

function requestId(response: Parameters<ErrorRequestHandler>[2]): string | undefined {
  const value = response.locals?.requestId;
  return typeof value === 'string' && value.length > 0 ? value : undefined;
}

export const jsonErrorHandler: ErrorRequestHandler = (error: unknown, _request, response, _next) => {
  const id = requestId(response);
  const correlation = id ? { requestId: id } : {};

  if (error instanceof ZodError) {
    response.status(400).json({
      error: {
        code: 'VALIDATION_ERROR',
        message: 'Request data is invalid.',
        details: error.flatten(),
        ...correlation,
      },
    });
    return;
  }

  if (error instanceof AppError) {
    response.status(error.status).json({ error: { code: error.code, message: error.message, ...correlation } });
    return;
  }

  const parserError = error as { status?: unknown; type?: unknown };
  if (error instanceof SyntaxError && parserError.status === 400) {
    response.status(400).json({
      error: { code: 'INVALID_JSON', message: 'Request body is not valid JSON.', ...correlation },
    });
    return;
  }
  if (parserError.type === 'entity.too.large') {
    response.status(413).json({
      error: { code: 'PAYLOAD_TOO_LARGE', message: 'Request body is too large.', ...correlation },
    });
    return;
  }

  if (isPrismaCode(error, 'P2002')) {
    response.status(409).json({
      error: { code: 'CONFLICT', message: 'This record already exists.', ...correlation },
    });
    return;
  }

  logger.error({ requestId: id, err: error }, 'unhandled api error');
  response.status(500).json({
    error: { code: 'INTERNAL_ERROR', message: 'An unexpected server error occurred.', ...correlation },
  });
};
