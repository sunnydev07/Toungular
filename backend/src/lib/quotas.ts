import { AppError } from './http.js';
import { logger, type Logger } from './logger.js';

export type QuotaKind = 'ai' | 'voice';

export type QuotaConfig = {
  aiDaily: number;
  voiceDaily: number;
  /** Share of failed provider calls (0-1) that triggers a logged alert. */
  failureAlertRate: number;
  /** Rolling window used for the provider failure-rate alert. */
  failureWindowMs: number;
  /** Minimum calls in a window before a failure-rate alert is considered. */
  failureAlertMinimumCalls: number;
};

export type ProviderMetrics = {
  calls: number;
  failures: number;
  totalLatencyMs: number;
  windowCalls: number;
  windowFailures: number;
  windowStartedAt: string;
};

type DayUsage = { day: string; count: number };

function utcDay(now: Date): string {
  return now.toISOString().slice(0, 10);
}

/**
 * Per-user daily quotas for the two paid-provider classes (generative AI and
 * voice). Counters live in process memory on purpose: they fail closed per
 * process and stay a safety valve rather than a billing ledger. Provider call
 * metrics are logged and exposed on the usage endpoint.
 */
export class QuotaService {
  private readonly usage = new Map<string, DayUsage>();
  private provider: ProviderMetrics;
  private alertLoggedForWindow = false;

  public constructor(
    private readonly config: QuotaConfig,
    private readonly log: Logger = logger,
  ) {
    this.provider = {
      calls: 0,
      failures: 0,
      totalLatencyMs: 0,
      windowCalls: 0,
      windowFailures: 0,
      windowStartedAt: new Date().toISOString(),
    };
  }

  public consume(userId: string, kind: QuotaKind, now: Date = new Date()): { used: number; limit: number } {
    const limit = kind === 'ai' ? this.config.aiDaily : this.config.voiceDaily;
    const key = `${kind}:${userId}`;
    const day = utcDay(now);
    const current = this.usage.get(key);
    const used = current && current.day === day ? current.count : 0;
    if (used >= limit) {
      this.log.warn({ userId, kind, used, limit }, 'daily provider quota exceeded');
      throw new AppError(
        429,
        'QUOTA_EXCEEDED',
        kind === 'ai'
          ? 'You have reached today\'s AI practice limit. Try again tomorrow.'
          : 'You have reached today\'s voice limit. Try again tomorrow.',
      );
    }
    this.usage.set(key, { day, count: used + 1 });
    return { used: used + 1, limit };
  }

  public usageFor(userId: string, now: Date = new Date()): { ai: { used: number; limit: number }; voice: { used: number; limit: number } } {
    const day = utcDay(now);
    const read = (kind: QuotaKind): number => {
      const entry = this.usage.get(`${kind}:${userId}`);
      return entry && entry.day === day ? entry.count : 0;
    };
    return {
      ai: { used: read('ai'), limit: this.config.aiDaily },
      voice: { used: read('voice'), limit: this.config.voiceDaily },
    };
  }

  public recordProviderCall(ok: boolean, latencyMs: number, now: Date = new Date()): void {
    this.provider.calls += 1;
    this.provider.totalLatencyMs += Math.max(0, latencyMs);
    this.provider.windowCalls += 1;
    if (!ok) {
      this.provider.failures += 1;
      this.provider.windowFailures += 1;
    }

    const windowAge = now.getTime() - new Date(this.provider.windowStartedAt).getTime();
    if (windowAge >= this.config.failureWindowMs) {
      this.provider.windowCalls = 1;
      this.provider.windowFailures = ok ? 0 : 1;
      this.provider.windowStartedAt = now.toISOString();
      this.alertLoggedForWindow = false;
      return;
    }

    if (this.alertLoggedForWindow || this.provider.windowCalls < this.config.failureAlertMinimumCalls) return;
    const rate = this.provider.windowFailures / this.provider.windowCalls;
    if (rate >= this.config.failureAlertRate) {
      this.alertLoggedForWindow = true;
      this.log.error(
        {
          providerFailureRate: Number(rate.toFixed(3)),
          windowCalls: this.provider.windowCalls,
          windowFailures: this.provider.windowFailures,
          windowStartedAt: this.provider.windowStartedAt,
        },
        'provider failure rate above alert threshold',
      );
    }
  }

  public metrics(): ProviderMetrics {
    return { ...this.provider };
  }
}
