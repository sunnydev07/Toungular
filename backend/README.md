# Toungular API contracts

The API serves Toungular's original English-learning data and user-owned profile/practice records. It has no configured speech, pronunciation, AI, or Play Billing provider. Those operations return clear unavailable states; the API does not fabricate provider output.

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
| DELETE | `/v1/me` | — | permanently deletes the authenticated account and its learning/practice records |
| GET | `/v1/roadmap` | — | ordered courses, lesson completion, total completion |
| GET | `/v1/courses` | — | ordered courses and learner completion state |
| GET | `/v1/lessons/:lessonId` | — | lesson content and learner completion state |
| POST | `/v1/lessons/:lessonId/complete` | — | lesson id and completion timestamp |
| GET | `/v1/vocabulary/due` | — | up to 20 due or unseen vocabulary reviews |
| POST | `/v1/vocabulary/:itemId/review` | `grade`: `again`, `hard`, `good`, or `easy` | updated due date and interval |
| GET | `/v1/placement/questions` | — | fixed 20-item vocabulary recall check |
| POST | `/v1/placement/vocabulary` | 20 `{itemId, word}` answers | score, initial-baseline/follow-up flag, and change from the first check |
| POST | `/v1/speaking-sessions` | `type`, `prompt` | created speaking session |
| PUT | `/v1/speaking-sessions/:id/transcript` | `transcript` | saved learner transcript |
| POST | `/v1/speaking-sessions/:id/analyze` | `durationSeconds` | transparent word-count, pace, filler, and vocabulary-variety estimates; pronunciation unavailable |
| GET | `/v1/speaking-sessions` | — | last 30 practice sessions |
| GET | `/v1/coach/scenarios` | — | original practice scenario catalog |
| POST | `/v1/conversations` | `scenarioId` | created text practice conversation |
| POST | `/v1/conversations/:id/turns` | `transcript` | saved learner turn and a static practice cue; no AI response |
| GET | `/v1/conversations/:id` | — | conversation and saved turns |
| POST | `/v1/conversations/:id/finish` | — | completed conversation summary |
| DELETE | `/v1/conversations/:id` | — | permanently deletes that user's conversation and turns |
| GET | `/v1/ielts/mocks` | — | original timed IELTS-style prompt sets |
| POST | `/v1/ielts/attempts` | `mockId` | created timed practice attempt |
| POST | `/v1/ielts/attempts/:id/responses` | `sectionId`, `transcript` | saved section response |
| POST | `/v1/ielts/attempts/:id/finish` | — | practice-complete summary; no official band score |
| GET | `/v1/ielts/attempts` | — | learner's attempt history |
| GET | `/v1/progress` | — | lesson/review/speaking totals and streak summary |
| GET | `/v1/streak` | — | current/longest activity streak and saved reminder schedule |
| PUT | `/v1/reminders` | `time` (`HH:mm` or null), `days` (0 Sunday through 6 Saturday) | saved account reminder preference |
| GET | `/v1/entitlements` | — | active Toungular Plus entitlement, or free plan |
| POST | `/v1/billing/verify` | `productId`, `purchaseToken` | explicit `BILLING_NOT_CONFIGURED` until a Toungular verifier is supplied |
| POST | `/v1/billing/restore` | `receipts` | explicit unavailable response until a Toungular verifier is supplied |
| GET | `/v1/referrals/me` | — | Toungular referral code and count |
| POST | `/v1/referrals/redeem` | `code` | associates one referral code with this account; no reward is configured |

The review scheduler uses day intervals: `again` resets to 1 day, `hard` increases slowly, `good` advances 1 → 3 → doubled intervals, and `easy` starts at 3 days then triples. Refresh tokens are opaque, stored only as hashes, and revoked when rotated. Raw speaking audio is not uploaded or stored by this API; the client stores temporary local recordings and sends an editable transcript for estimate generation.

Account deletion is available to a signed-in learner through `DELETE /v1/me` and the client account screen. The API cascades the account's profile and learning/practice records and unlinks referrals that point to the deleted account. A public account-deletion request URL and Toungular privacy policy still need to be published before release.
