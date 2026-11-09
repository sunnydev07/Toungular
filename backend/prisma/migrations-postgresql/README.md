# PostgreSQL migration history

Prisma does not apply SQLite migrations to PostgreSQL. The initial PostgreSQL SQL is kept beside this README and applied by `npm run prisma:migrate:postgres`; it uses the same tables, foreign keys, unique constraints, and indexes as `schema.postgresql.prisma`.
