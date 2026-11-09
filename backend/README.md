# Toungular API contracts

The API serves original English-learning data only. It has no configured speech, AI, advertising, billing, or purchase provider; later provider routes must return an explicit unavailable state rather than fabricated output.

## Local data

Copy `.env.example` to `.env`, then run `npm run prisma:generate`, `npm run prisma:migrate:dev`, `npm run seed`, and `npm run dev`. The default `DATABASE_URL` is SQLite at `backend/storage/toungular.db`. `PORT`, `DATABASE_URL`, `JWT_SECRET` (at least 32 characters), and `MOBILE_ORIGIN` are validated at startup.

For PostgreSQL, use a `postgresql://` `DATABASE_URL`, generate with `npm run prisma:generate:postgres`, and deploy its provider-specific migration history with `npm run prisma:migrate:postgres`. Prisma records deployed migrations, so the command is safe to rerun. Application service and route contracts do not change.

## JSON envelope and errors

Successful endpoints return `{ "data": ... }`. Errors return `{ "error": { "code": "...", "message": "..." } }`; invalid input includes an `error.details` object. Authenticated requests use `Authorization: Bearer <accessToken>`.

## Routes

| Method | Route | Request body | Response `data` |
| --- | --- | --- | --- |
| POST | `/v1/auth/register` | `email`, `password`, optional profile patch | user, profile, access and refresh tokens |
| POST | `/v1/auth/login` | `email`, `password` | user, profile, access and refresh tokens |
| POST | `/v1/auth/refresh` | `refreshToken` | rotated token pair and current profile |
| GET/PATCH | `/v1/me` | profile patch: `goals`, `proficiency`, `dailyMinutes`, `timezone`, `ieltsIntent` | persisted profile |
| GET | `/v1/roadmap` | — | ordered courses, lesson completion, total completion |
| GET | `/v1/courses` | — | ordered courses and learner completion state |
| GET | `/v1/lessons/:lessonId` | — | lesson content and learner completion state |
| POST | `/v1/lessons/:lessonId/complete` | — | lesson id and completion timestamp |
| GET | `/v1/vocabulary/due` | — | up to 20 due or unseen vocabulary reviews |
| POST | `/v1/vocabulary/:itemId/review` | `grade`: `again`, `hard`, `good`, or `easy` | updated due date and interval |

The review scheduler uses day intervals: `again` resets to 1 day, `hard` increases slowly, `good` advances 1 → 3 → doubled intervals, and `easy` starts at 3 days then triples. Refresh tokens are opaque, stored only as hashes, and revoked when rotated.
