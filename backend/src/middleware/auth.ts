import type { NextFunction, Request, Response } from 'express';

import type { AppEnv } from '../config/env.js';
import { AppError } from '../lib/http.js';
import { verifyAccessToken } from '../lib/tokens.js';

declare global {
  namespace Express {
    interface Request {
      auth?: { userId: string; email: string };
    }
  }
}

export function requireAuth(env: AppEnv) {
  return (request: Request, _response: Response, next: NextFunction): void => {
    const authorization = request.header('authorization');
    if (!authorization?.startsWith('Bearer ')) {
      next(new AppError(401, 'UNAUTHORIZED', 'A bearer access token is required.'));
      return;
    }

    request.auth = verifyAccessToken(authorization.slice('Bearer '.length), env);
    next();
  };
}

export function authenticatedUserId(request: Request): string {
  if (!request.auth) {
    throw new AppError(401, 'UNAUTHORIZED', 'A bearer access token is required.');
  }
  return request.auth.userId;
}
