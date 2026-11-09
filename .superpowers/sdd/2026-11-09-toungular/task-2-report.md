# Task 2 report — backend foundation and learning data contracts

## Delivered

- Added SQLite-first Prisma models for users, profiles, refresh tokens, courses, lessons, progress, vocabulary/review schedules, speaking sessions, conversations, IELTS attempts, skill snapshots, streak state, referrals, and purchase entitlements.
- Added an equivalent PostgreSQL Prisma schema and documented separate provider-specific migration histories. Service and route contracts remain Prisma-client based and unchanged across providers.
- Added validated `PORT`, `DATABASE_URL`, `JWT_SECRET`, and `MOBILE_ORIGIN` loading; a singleton Prisma client; JSON error responses; origin handling; scrypt password hashing; HS256 bearer access tokens; opaque hashed refresh-token rotation.
- Added the required auth, profile, curriculum, lesson, roadmap, vocabulary-due, and review routes with Zod request validation.
- Added original Toungular seed material: three English courses, 18 lessons, and 80 vocabulary entries. Initial vocabulary is presented as unseen; a learner-specific review schedule is created on the first submitted grade.
- Added `backend/README.md` with the JSON envelope, route contracts, scheduler policy, local setup, and PostgreSQL setup.

## Static self-review

- Reviewed the scoped diff and ran `git diff --check`; it reported no whitespace errors. Git printed existing CRLF conversion warnings for touched tracked files.
- Removed duplicated dependency declarations found during the review.

## Verification

Not run, by instruction: no automated tests, TypeScript build, Prisma generation/migration, seed run, or runtime smoke check.

## Concerns

- Prisma client generation and the provider-specific migrations must be performed in the target environment before startup; they were intentionally not run here.
- The seed has 80 vocabulary entries, below the design document’s rough 100–150 Phase 1 target; the task brief required original vocabulary seeding but did not set a count. A later content task should expand the catalog.

## Fix round 1

- Corrected the SQLite initial migration so every relation declared by `schema.prisma` has its corresponding foreign key and every declared secondary index is created.
- Added concrete PostgreSQL initial migration SQL with matching tables, foreign keys, unique constraints, and indexes. `prisma:migrate:postgres` now applies that provider-specific asset with `prisma db execute`; the README describes the same command.
- Static review only: no Prisma generation/migration command, build, test, or runtime check was run under the active instruction.

## Fix round 2

- Moved the PostgreSQL Prisma schema to `prisma/postgresql/schema.prisma` and its initial SQL to the standard sibling `prisma/postgresql/migrations/` layout, including a PostgreSQL migration lock file.
- Restored `prisma:migrate:postgres` to `prisma migrate deploy --schema prisma/postgresql/schema.prisma`; Prisma now records the initial schema in `_prisma_migrations` and repeated deployment checks that history rather than rerunning non-idempotent `CREATE TABLE` statements.
- Updated PostgreSQL generation and README commands to the same provider-specific layout. No tests, builds, database migrations, generation, or runtime checks were run.
