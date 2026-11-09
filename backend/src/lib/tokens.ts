import { createHash, randomBytes } from 'node:crypto';
import jwt, { type JwtPayload } from 'jsonwebtoken';

import type { AppEnv } from '../config/env.js';
import { AppError } from './http.js';

const ACCESS_TOKEN_TTL_SECONDS = 15 * 60;
const REFRESH_TOKEN_TTL_MS = 30 * 24 * 60 * 60 * 1000;

export type AccessTokenClaims = { userId: string; email: string };
export type IssuedRefreshToken = { token: string; tokenHash: string; expiresAt: Date };

export function issueAccessToken(user: AccessTokenClaims, env: AppEnv): string {
  return jwt.sign({ email: user.email, type: 'access' }, env.jwtSecret, {
    algorithm: 'HS256',
    subject: user.userId,
    expiresIn: ACCESS_TOKEN_TTL_SECONDS,
  });
}

export function verifyAccessToken(token: string, env: AppEnv): AccessTokenClaims {
  try {
    const claims = jwt.verify(token, env.jwtSecret, { algorithms: ['HS256'] }) as JwtPayload;
    if (claims.type !== 'access' || typeof claims.sub !== 'string' || typeof claims.email !== 'string') {
      throw new Error('Unexpected token claims');
    }
    return { userId: claims.sub, email: claims.email };
  } catch {
    throw new AppError(401, 'UNAUTHORIZED', 'A valid access token is required.');
  }
}

export function issueRefreshToken(now = new Date()): IssuedRefreshToken {
  const token = randomBytes(48).toString('base64url');
  return {
    token,
    tokenHash: hashRefreshToken(token),
    expiresAt: new Date(now.getTime() + REFRESH_TOKEN_TTL_MS),
  };
}

export function hashRefreshToken(token: string): string {
  return createHash('sha256').update(token).digest('base64url');
}
