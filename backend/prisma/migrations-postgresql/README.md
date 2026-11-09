# PostgreSQL migration history

Prisma does not apply SQLite migrations to PostgreSQL. Create and retain this separate history from `schema.postgresql.prisma` using Toungular's PostgreSQL database and `prisma migrate dev`; deploy it with `npm run prisma:migrate:postgres`.
