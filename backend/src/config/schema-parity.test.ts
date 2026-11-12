import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const backendRoot = join(dirname(fileURLToPath(import.meta.url)), '..', '..');

function read(relativePath: string): string {
  return readFileSync(join(backendRoot, relativePath), 'utf8');
}

function schemaModels(schema: string): Set<string> {
  return new Set([...schema.matchAll(/^\s*model\s+(\w+)\s*\{/gm)].map((match) => match[1]!));
}

function migrationTables(directory: string): Set<string> {
  const tables = new Set<string>();
  for (const entry of readdirSync(join(backendRoot, directory), { withFileTypes: true })) {
    if (!entry.isDirectory()) continue;
    const sql = read(join(directory, entry.name, 'migration.sql'));
    for (const match of sql.matchAll(/CREATE TABLE\s+"(\w+)"/g)) {
      tables.add(match[1]!);
    }
  }
  return tables;
}

const sqliteSchema = read('prisma/schema.prisma');
const postgresSchema = read('prisma/postgresql/schema.prisma');
const sqliteModels = schemaModels(sqliteSchema);
const postgresModels = schemaModels(postgresSchema);

test('SQLite and PostgreSQL schemas declare the same models', () => {
  assert.deepEqual([...postgresModels].sort(), [...sqliteModels].sort());
});

test('every declared model has a table in both migration histories', () => {
  for (const directory of ['prisma/migrations', 'prisma/postgresql/migrations']) {
    const tables = migrationTables(directory);
    const missing = [...sqliteModels].filter((model) => !tables.has(model));
    assert.deepEqual(missing, [], `${directory} is missing tables for: ${missing.join(', ')}`);
  }
});

test('model declarations are multi-line, as Prisma requires', () => {
  for (const [provider, schema] of [
    ['sqlite', sqliteSchema],
    ['postgresql', postgresSchema],
  ] as const) {
    assert.doesNotMatch(
      schema,
      /^\s*model\s+\w+\s*\{.*\}\s*$/m,
      `${provider} schema declares a model body on a single line; Prisma rejects this format`,
    );
  }
});

test('each schema uses its own datasource provider', () => {
  assert.match(sqliteSchema, /datasource\s+db\s*\{[^}]*provider\s*=\s*"sqlite"/s);
  assert.match(postgresSchema, /datasource\s+db\s*\{[^}]*provider\s*=\s*"postgresql"/s);
});

test('MasteryXp is related to User in both schemas', () => {
  for (const [provider, schema] of [
    ['sqlite', sqliteSchema],
    ['postgresql', postgresSchema],
  ] as const) {
    assert.match(
      schema,
      /model\s+User\s*\{[^}]*\bmastery\s+MasteryXp\?/s,
      `${provider} User model is missing the mastery relation`,
    );
    assert.match(
      schema,
      /model\s+MasteryXp\s*\{[^}]*\buser\s+User\s+@relation/s,
      `${provider} MasteryXp model is missing the user relation`,
    );
  }
});
