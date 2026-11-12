import assert from 'node:assert/strict';
import { once } from 'node:events';

import { createApp } from '../dist/app.js';
import { loadEnv } from '../dist/config/env.js';
import { prisma } from '../dist/lib/prisma.js';

const env = loadEnv();
const app = createApp(env);
const server = app.listen(0);
await once(server, 'listening');
const address = server.address();
assert.ok(address && typeof address === 'object');
const base = `http://127.0.0.1:${address.port}`;
const email = `smoke-${Date.now()}@toungular.test`;
const password = 'smoke-password-123';

try {
  const ready = await fetch(`${base}/health/ready`);
  assert.equal(ready.status, 200, 'readiness probe should report the database as ready');

  const unauthenticated = await fetch(`${base}/v1/mastery/profile`);
  assert.equal(unauthenticated.status, 401, 'protected routes must reject anonymous requests');

  const register = await fetch(`${base}/v1/auth/register`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email, password }),
  });
  assert.equal(register.status, 201, `registration failed with ${register.status}`);
  const { data: auth } = await register.json();

  const profile = await fetch(`${base}/v1/mastery/profile`, {
    headers: { authorization: `Bearer ${auth.accessToken}` },
  });
  assert.equal(profile.status, 200, 'mastery profile should load for the new account');
  const { data: mastery } = await profile.json();
  assert.equal(mastery.userId, auth.user.id);
  assert.equal(typeof mastery.totalXp, 'number');

  console.log('PostgreSQL smoke test passed: readiness, authorization, registration, and mastery profile.');
} finally {
  await prisma.user.deleteMany({ where: { email } }).catch(() => undefined);
  await new Promise((resolve) => server.close(resolve));
  await prisma.$disconnect();
}
