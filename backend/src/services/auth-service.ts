import type { PrismaClient } from '@prisma/client';

import type { AppEnv } from '../config/env.js';
import type { AuthResult, LoginInput, RegisterInput } from '../contracts.js';
import { AppError } from '../lib/http.js';
import { hashPassword, verifyPassword } from '../lib/password.js';
import { hashRefreshToken, issueAccessToken, issueRefreshToken } from '../lib/tokens.js';
import { ProfileService } from './profile-service.js';

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
    return this.createAuthResult(user);
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
    if (!current || current.revokedAt || current.expiresAt <= new Date()) {
      throw new AppError(401, 'INVALID_REFRESH_TOKEN', 'The refresh token is invalid or expired.');
    }

    const replacement = issueRefreshToken();
    const rotated = await this.database.$transaction(async (transaction) => {
      const revoked = await transaction.refreshToken.updateMany({
        where: { id: current.id, revokedAt: null },
        data: { revokedAt: new Date() },
      });
      if (revoked.count !== 1) {
        throw new AppError(401, 'INVALID_REFRESH_TOKEN', 'The refresh token has already been used.');
      }
      await transaction.refreshToken.create({
        data: { userId: current.userId, tokenHash: replacement.tokenHash, expiresAt: replacement.expiresAt },
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

  private async createAuthResult(user: { id: string; email: string }): Promise<AuthResult> {
    const refresh = issueRefreshToken();
    await this.database.refreshToken.create({
      data: { userId: user.id, tokenHash: refresh.tokenHash, expiresAt: refresh.expiresAt },
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
