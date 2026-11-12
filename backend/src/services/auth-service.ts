import { randomUUID } from 'node:crypto';

import type { PrismaClient } from '@prisma/client';

import type { AppEnv } from '../config/env.js';
import type { AuthResult, LoginInput, RegisterInput } from '../contracts.js';
import { AppError, isPrismaCode } from '../lib/http.js';
import { hashPassword, verifyPassword } from '../lib/password.js';
import { hashRefreshToken, issueAccessToken, issueRefreshToken } from '../lib/tokens.js';
import { ProfileService } from './profile-service.js';

const INVALID_REFRESH = 'The refresh token is invalid or expired.';
const USED_REFRESH = 'The refresh token has already been used.';

export class AuthService {
  private readonly profiles: ProfileService;

  public constructor(
    private readonly database: PrismaClient,
    private readonly env: AppEnv,
  ) {
    this.profiles = new ProfileService(database);
  }

  public async register(input: RegisterInput): Promise<AuthResult> {
    const email = input.email.trim().toLowerCase();
    const existing = await this.database.user.findUnique({ where: { email }, select: { id: true } });
    if (existing) {
      throw new AppError(409, 'EMAIL_IN_USE', 'An account already exists for this email address.');
    }

    const passwordHash = await hashPassword(input.password);
    try {
      const user = await this.database.user.create({
        data: {
          email,
          passwordHash,
          profile: {
            create: {
              ...(input.profile?.goals === undefined ? {} : { goals: JSON.stringify(input.profile.goals) }),
              ...(input.profile?.proficiency === undefined ? {} : { proficiency: input.profile.proficiency }),
              ...(input.profile?.dailyMinutes === undefined ? {} : { dailyMinutes: input.profile.dailyMinutes }),
              ...(input.profile?.timezone === undefined ? {} : { timezone: input.profile.timezone }),
              ...(input.profile?.ieltsIntent === undefined ? {} : { ieltsIntent: input.profile.ieltsIntent }),
            },
          },
        },
      });
      return await this.createAuthResult(user);
    } catch (error) {
      // Two concurrent registrations can both pass the lookup above; the unique
      // index is the real guard, so report the conflict instead of a 500.
      if (isPrismaCode(error, 'P2002')) {
        throw new AppError(409, 'EMAIL_IN_USE', 'An account already exists for this email address.');
      }
      throw error;
    }
  }

  public async login(input: LoginInput): Promise<AuthResult> {
    const email = input.email.trim().toLowerCase();
    const user = await this.database.user.findUnique({ where: { email } });
    if (!user || !(await verifyPassword(input.password, user.passwordHash))) {
      throw new AppError(401, 'INVALID_CREDENTIALS', 'Email or password is incorrect.');
    }
    return this.createAuthResult(user);
  }

  public async refresh(refreshToken: string): Promise<AuthResult> {
    const tokenHash = hashRefreshToken(refreshToken);
    const current = await this.database.refreshToken.findUnique({
      where: { tokenHash },
      include: { user: true },
    });
    if (!current) {
      throw new AppError(401, 'INVALID_REFRESH_TOKEN', INVALID_REFRESH);
    }
    if (current.revokedAt) {
      // A rotated token was presented again: assume theft and revoke every
      // descendant in the family, including the one the thief may hold.
      await this.revokeFamily(current.userId, current.familyId ?? current.id);
      throw new AppError(401, 'INVALID_REFRESH_TOKEN', USED_REFRESH);
    }
    if (current.expiresAt <= new Date()) {
      throw new AppError(401, 'INVALID_REFRESH_TOKEN', INVALID_REFRESH);
    }

    // Tokens issued before families existed adopt their own id as the root.
    const familyId = current.familyId ?? current.id;
    const replacement = issueRefreshToken();
    const rotated = await this.database.$transaction(async (transaction) => {
      const revoked = await transaction.refreshToken.updateMany({
        where: { id: current.id, revokedAt: null },
        data: { revokedAt: new Date(), familyId },
      });
      if (revoked.count !== 1) {
        // Lost a race with another rotation: treat it as reuse so a stolen
        // token cannot survive the race.
        await transaction.refreshToken.updateMany({
          where: { userId: current.userId, familyId, revokedAt: null },
          data: { revokedAt: new Date() },
        });
        throw new AppError(401, 'INVALID_REFRESH_TOKEN', USED_REFRESH);
      }
      await transaction.refreshToken.create({
        data: {
          userId: current.userId,
          tokenHash: replacement.tokenHash,
          familyId,
          expiresAt: replacement.expiresAt,
        },
      });
      return current.user;
    });

    const profile = await this.profiles.get(rotated.id);
    return {
      user: { id: rotated.id, email: rotated.email },
      profile,
      accessToken: issueAccessToken({ userId: rotated.id, email: rotated.email }, this.env),
      refreshToken: replacement.token,
    };
  }

  public async logout(userId: string, refreshToken?: string, allSessions = false): Promise<void> {
    if (!allSessions && refreshToken) {
      const token = await this.database.refreshToken.findUnique({
        where: { tokenHash: hashRefreshToken(refreshToken) },
        select: { id: true, userId: true, familyId: true },
      });
      if (token && token.userId === userId) {
        // Revoke the whole chain, not just the presented link: a client may
        // have rotated the token just before signing out.
        const familyId = token.familyId ?? token.id;
        await this.revokeFamily(userId, familyId);
        if (token.familyId === null) {
          await this.database.refreshToken.updateMany({
            where: { id: token.id, revokedAt: null },
            data: { revokedAt: new Date() },
          });
        }
        return;
      }
      // A stale or unknown token must still end this account's sessions rather
      // than leaving a usable refresh token behind after sign-out.
    }
    await this.database.refreshToken.updateMany({
      where: { userId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
  }

  private async revokeFamily(userId: string, familyId: string): Promise<void> {
    await this.database.refreshToken.updateMany({
      where: { userId, familyId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
  }

  private async createAuthResult(user: { id: string; email: string }): Promise<AuthResult> {
    const refresh = issueRefreshToken();
    await this.database.refreshToken.create({
      data: {
        userId: user.id,
        tokenHash: refresh.tokenHash,
        familyId: randomUUID(),
        expiresAt: refresh.expiresAt,
      },
    });
    const profile = await this.profiles.get(user.id);
    return {
      user: { id: user.id, email: user.email },
      profile,
      accessToken: issueAccessToken({ userId: user.id, email: user.email }, this.env),
      refreshToken: refresh.token,
    };
  }
}
