import assert from 'node:assert/strict';
import test from 'node:test';

import { AppError } from './http.js';
import { logger } from './logger.js';
import { QuotaService } from './quotas.js';

function createQuotas(overrides: Partial<ConstructorParameters<typeof QuotaService>[0]> = {}) {
  return new QuotaService({
    aiDaily: 2,
    voiceDaily: 1,
    failureAlertRate: 0.5,
    failureWindowMs: 60_000,
    failureAlertMinimumCalls: 4,
    ...overrides,
  }, logger);
}

test('daily AI quota rejects the request after the limit is reached', () => {
  const quotas = createQuotas();
  const now = new Date('2026-11-13T10:00:00Z');

  assert.deepEqual(quotas.consume('user-1', 'ai', now), { used: 1, limit: 2 });
  assert.deepEqual(quotas.consume('user-1', 'ai', now), { used: 2, limit: 2 });
  assert.throws(
    () => quotas.consume('user-1', 'ai', now),
    (error: unknown) => error instanceof AppError && error.status === 429 && error.code === 'QUOTA_EXCEEDED',
  );
  // A different user keeps their own allowance.
  assert.deepEqual(quotas.consume('user-2', 'ai', now), { used: 1, limit: 2 });
});

test('counters reset on the next UTC day', () => {
  const quotas = createQuotas();
  const monday = new Date('2026-11-13T23:59:00Z');
  const tuesday = new Date('2026-11-14T00:01:00Z');

  quotas.consume('user-1', 'voice', monday);
  assert.deepEqual(quotas.usageFor('user-1', monday).voice, { used: 1, limit: 1 });
  assert.deepEqual(quotas.usageFor('user-1', tuesday).voice, { used: 0, limit: 1 });
  assert.deepEqual(quotas.consume('user-1', 'voice', tuesday), { used: 1, limit: 1 });
});

test('provider metrics track failures and total latency', () => {
  const quotas = createQuotas();
  const now = new Date('2026-11-13T10:00:00Z');

  quotas.recordProviderCall(true, 120, now);
  quotas.recordProviderCall(false, 80, now);

  const metrics = quotas.metrics();
  assert.equal(metrics.calls, 2);
  assert.equal(metrics.failures, 1);
  assert.equal(metrics.totalLatencyMs, 200);
  assert.equal(metrics.windowCalls, 2);
  assert.equal(metrics.windowFailures, 1);
});
