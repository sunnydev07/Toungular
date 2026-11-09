import { randomBytes } from 'node:crypto';
import type { PrismaClient } from '@prisma/client';

import { AppError } from '../lib/http.js';

export type BillingReceipt = { productId: string; purchaseToken: string };
export type EntitlementResult = { premium: boolean; productId: string | null; expiresAt: Date | null };

export interface BillingProvider {
  verify(userId: string, receipt: BillingReceipt): Promise<EntitlementResult>;
  restore(userId: string, receipts: BillingReceipt[]): Promise<EntitlementResult>;
}

export class UnconfiguredBillingProvider implements BillingProvider {
  public async verify(_userId: string, _receipt: BillingReceipt): Promise<EntitlementResult> {
    throw new AppError(503, 'BILLING_NOT_CONFIGURED', 'Toungular Play Billing verification has not been configured. No purchase was charged.');
  }

  public async restore(_userId: string, _receipts: BillingReceipt[]): Promise<EntitlementResult> {
    throw new AppError(503, 'BILLING_NOT_CONFIGURED', 'Purchase restore is unavailable until Toungular configures Play Billing verification.');
  }
}

export class MonetizationService {
  public constructor(
    private readonly database: PrismaClient,
    private readonly billing: BillingProvider = new UnconfiguredBillingProvider(),
  ) {}

  public async entitlements(userId: string) {
    const now = new Date();
    const active = await this.database.purchaseEntitlement.findMany({
      where: {
        userId,
        status: 'active',
        AND: [
          { OR: [{ startsAt: null }, { startsAt: { lte: now } }] },
          { OR: [{ expiresAt: null }, { expiresAt: { gt: now } }] },
        ],
      },
      orderBy: { createdAt: 'desc' },
      select: { productId: true, expiresAt: true },
    });
    const entitlement = active[0];
    return {
      plan: entitlement ? 'plus' : 'free',
      premium: entitlement != null,
      productId: entitlement?.productId ?? null,
      expiresAt: entitlement?.expiresAt ?? null,
      features: {
        unlimitedPractice: entitlement != null,
        adsRemoved: entitlement != null,
        learningPath: true,
        vocabularyReview: true,
      },
    };
  }

  public verify(userId: string, receipt: BillingReceipt) { return this.billing.verify(userId, receipt); }
  public restore(userId: string, receipts: BillingReceipt[]) { return this.billing.restore(userId, receipts); }

  public async referral(userId: string) {
    const own = await this.ensureReferral(userId);
    const referrals = await this.database.referral.count({ where: { referredById: userId } });
    return { code: own.code, redeemed: own.referredById != null, referredCount: referrals, reward: 'Referral rewards are not configured yet.' };
  }

  public async redeemReferral(userId: string, code: string) {
    const sponsor = await this.database.referral.findUnique({ where: { code: code.trim().toUpperCase() } });
    if (!sponsor) throw new AppError(404, 'REFERRAL_NOT_FOUND', 'That referral code was not found.');
    if (sponsor.userId === userId) throw new AppError(400, 'REFERRAL_SELF_REDEEM', 'You cannot redeem your own referral code.');
    const own = await this.ensureReferral(userId);
    if (own.referredById) throw new AppError(409, 'REFERRAL_ALREADY_REDEEMED', 'A referral code has already been used on this account.');
    await this.database.referral.update({
      where: { userId },
      data: { referredById: sponsor.userId, redeemedAt: new Date() },
    });
    return { redeemed: true, reward: 'Referral tracking is saved. No reward is configured yet.' };
  }

  private async ensureReferral(userId: string) {
    const current = await this.database.referral.findUnique({ where: { userId } });
    if (current) return current;
    for (let attempt = 0; attempt < 3; attempt++) {
      const code = randomBytes(5).toString('hex').toUpperCase();
      try {
        return await this.database.referral.create({ data: { userId, code } });
      } catch {
        const raced = await this.database.referral.findUnique({ where: { userId } });
        if (raced) return raced;
      }
    }
    throw new AppError(503, 'REFERRAL_UNAVAILABLE', 'A referral code could not be created. Try again soon.');
  }
}
