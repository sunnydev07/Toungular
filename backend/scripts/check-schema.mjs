#!/usr/bin/env node
// Validates both Prisma schemas with a datasource URL matching each provider.
// Prisma validate reads DATABASE_URL from .env, which only points at SQLite, so the
// PostgreSQL schema must not depend on the developer's (or CI's) ambient environment.
import { spawnSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const backendRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const prismaCli = join(backendRoot, 'node_modules', 'prisma', 'build', 'index.js');

if (!existsSync(prismaCli)) {
  console.error(`Prisma CLI not found at ${prismaCli}. Run npm install first.`);
  process.exit(1);
}

const checks = [
  { schema: 'prisma/schema.prisma', url: 'file:./schema-check.db' },
  {
    schema: 'prisma/postgresql/schema.prisma',
    url: 'postgresql://schema:check@localhost:5432/schema_check',
  },
];

for (const { schema, url } of checks) {
  console.log(`Validating ${schema} ...`);
  const result = spawnSync(process.execPath, [prismaCli, 'validate', '--schema', schema], {
    cwd: backendRoot,
    stdio: 'inherit',
    env: { ...process.env, DATABASE_URL: url },
  });
  if (result.status !== 0) {
    process.exit(result.status ?? 1);
  }
}

console.log('Both Prisma schemas are valid.');
