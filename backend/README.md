# Toungular API contracts

The API serves Toungular's original English-learning data and user-owned profile/practice records. No pronunciation, AI, or Play Billing provider is configured; those operations return clear unavailable states and the API does not fabricate provider output. Text-to-speech and speech-to-text are optional and activate only when their server-side credentials are present.

## Local data

Copy `.env.example` to `.env`, then run `npm run prisma:generate`, `npm run prisma:migrate:dev`, `npm run seed`, and `npm run dev`. The default `DATABASE_URL` is SQLite at `backend/storage/toungular.db`. `PORT`, `DATABASE_URL`, `JWT_SECRET` (at least 32 characters), and `MOBILE_ORIGIN` are validated at startup.

For PostgreSQL, use a `postgresql://` `DATABASE_URL`, generate with `npm run prisma:generate:postgres`, and deploy its provider-specific migration history with `npm run prisma:migrate:postgres`. Prisma records deployed migrations, so the command is safe to rerun. Application service and route contracts do not change.

Voice is optional. Set `GOOGLE_TTS_API_KEY`, `ELEVENLABS_API_KEY` plus `ELEVENLABS_VOICE_ID`, `OPENAI_API_KEY`, or `DEEPGRAM_API_KEY` to enable the matching TTS/STT provider; `GET /v1/voice/providers` reflects what is active. Synthesized MP3s are cached under `VOICE_CACHE_DIR` (default `backend/storage/audio-cache`).

## Operations

Requests are logged as structured JSON (pino) with the `X-Request-Id` correlation value, status, and duration; `LOG_LEVEL` controls verbosity. `GET /health` is a liveness check, and `GET /health/ready` probes the database and returns `503` while it is unreachable. The server runs a retention sweep at startup and every six hours: abandoned `draft`/`transcript_saved` speaking sessions older than 48 hours are deleted, `in_progress` IELTS attempts older than 24 hours are marked `abandoned`, and stored idempotency responses older than 24 hours are pruned. `SIGTERM`/`SIGINT` stop accepting requests, disconnect Prisma, and exit.

Paid provider calls are metered per user per UTC day (`AI_DAILY_QUOTA`, `VOICE_DAILY_QUOTA`; over-quota requests return `429 QUOTA_EXCEEDED`). Provider call counts, failures, and latency are aggregated in process and logged when the failure rate crosses `PROVIDER_FAILURE_ALERT_RATE` over `PROVIDER_ALERT_WINDOW_MS`. `GET /v1/usage` returns the caller's daily counters and the process provider metrics.

Coach turns and analysis routes accept an optional `Idempotency-Key` header (8–128 characters). Repeating a request with the same key for the same user and resource returns the stored response instead of re-running the provider, re-awarding XP, or scheduling duplicate vocabulary. Keys expire after 24 hours.

## JSON envelope and errors

Successful endpoints return `{ "data": ... }`. Errors return `{ "error": { "code": "...", "message": "..." } }`; invalid input includes an `error.details` object, and every error carries the `X-Request-Id` correlation value. Malformed JSON returns `400 INVALID_JSON`, oversized bodies `413 PAYLOAD_TOO_LARGE`, duplicate records `409 CONFLICT`, and throttled auth attempts `429 RATE_LIMITED`. Authenticated requests use `Authorization: Bearer <accessToken>`.

## Routes

| Method | Route | Request body | Response `data` |
| --- | --- | --- | --- |
| GET | `/health` | — | liveness `{ service, status: "ok" }` |
| GET | `/health/ready` | — | readiness with a database probe; `503` when the database is unreachable |
| GET | `/v1/usage` | — | caller's daily AI/voice quota usage and process provider call metrics |
| POST | `/v1/auth/register` | `email`, `password`, optional profile patch | user, profile, access and refresh tokens |
| POST | `/v1/auth/login` | `email`, `password` | user, profile, access and refresh tokens |
| POST | `/v1/auth/refresh` | `refreshToken` | rotated token pair and current profile; replaying a rotated token revokes the whole token family |
| POST | `/v1/auth/logout` | optional `refreshToken`, optional `allSessions` | revokes the token family (or every session with `allSessions: true`); requires a bearer access token |
| GET/PATCH | `/v1/me` | profile patch: `goals`, `proficiency`, `dailyMinutes`, `timezone`, `ieltsIntent` | persisted profile |
| DELETE | `/v1/me` | — | permanently deletes the authenticated account and its learning/practice records |
| GET | `/v1/roadmap` | — | ordered courses, lesson completion, total completion |
| GET | `/v1/courses` | — | ordered courses and learner completion state |
| GET | `/v1/lessons/:lessonId` | — | lesson content and learner completion state |
| POST | `/v1/lessons/:lessonId/complete` | — | lesson id and completion timestamp |
| GET | `/v1/vocabulary/due` | — | up to 20 due or unseen vocabulary reviews with recall mode and cloze |
| POST | `/v1/vocabulary` | `word`, `partOfSpeech`, `definition`, `example`, `level`, optional `tier` | newly scheduled manual word |
| POST | `/v1/vocabulary/encounters` | `word`, `source` (`lesson`, `coach`, `manual`), optional `context` | schedules the word when it exists in the catalog |
| POST | `/v1/vocabulary/:itemId/review` | `grade`: `again`, `hard`, `good`, or `easy`; optional `mode` | updated due date, interval, ease factor, and lapses |
| GET | `/v1/placement/questions` | — | fixed 20-item vocabulary recall check |
| POST | `/v1/placement/vocabulary` | 20 `{itemId, word}` answers | score, initial-baseline/follow-up flag, and change from the first check |
| POST | `/v1/speaking-sessions` | `type`, `prompt` | created speaking session |
| PUT | `/v1/speaking-sessions/:id/transcript` | `transcript` | saved learner transcript |
| POST | `/v1/speaking-sessions/:id/analyze` | `durationSeconds`, optional `transcript`, optional `pauses` (seconds) | transparent word-count, pace, filler, pause, and vocabulary-variety estimates with WPM trend; pronunciation unavailable; durations too short for the transcript or pauses longer than the recording return `422` |
| GET | `/v1/speaking-sessions` | optional `limit` (1–100), `offset` | paginated practice history, newest first (default 30) |
| GET | `/v1/coach/scenarios` | — | original practice scenario catalog |
| POST | `/v1/conversations` | `scenarioId` | created text practice conversation |
| POST | `/v1/conversations/:id/turns` | `transcript` | saved learner turn and a static practice cue; no AI response |
| GET | `/v1/conversations/:id` | optional `limit` (1–100), `offset` | conversation plus a page of turns, oldest first, and `turnsTotal` (default 30) |
| POST | `/v1/conversations/:id/finish` | — | completed conversation summary |
| DELETE | `/v1/conversations/:id` | — | permanently deletes that user's conversation and turns |
| GET | `/v1/ielts/mocks` | — | original timed IELTS-style prompt sets |
| POST | `/v1/ielts/attempts` | `mockId` | created timed practice attempt |
| POST | `/v1/ielts/attempts/:id/responses` | `sectionId`, `transcript` | saved section response |
| POST | `/v1/ielts/attempts/:id/finish` | — | practice-complete summary; no official band score |
| GET | `/v1/ielts/attempts` | optional `limit` (1–100), `offset` | paginated attempt history, newest first (default 30) |
| GET | `/v1/progress` | — | lesson/review/speaking totals, fluency trend, and streak summary |
| GET | `/v1/streak` | — | current/longest activity streak and saved reminder schedule |
| PUT | `/v1/reminders` | `time` (`HH:mm` or null), `days` (0 Sunday through 6 Saturday) | saved account reminder preference |
| GET | `/v1/exposure` | — | seven comfort levels with session counts and unlock state |
| POST | `/v1/exposure/:level/complete` | — | records one session; requires the previous level to be complete |
| GET | `/v1/voice/providers` | — | whether TTS/STT are configured and which providers are active |
| POST | `/v1/voice/tts` | `text`, optional `provider`, `voiceId`, `language`, `speed` | MP3 audio bytes; `503` when no TTS provider is configured |
| POST | `/v1/voice/stt` | raw audio body; optional `provider`/`contentType` query | transcript text; `503` when no STT provider is configured |
| GET | `/v1/shadow/passages` | — | speech shadowing passage catalog with audio and pacing targets |
| GET | `/v1/shadow/passages/:id` | — | detailed passage for auditory-vocal shadowing |
| POST | `/v1/shadow/analyze` | `passageId`, `durationSeconds`, `transcript`, optional `pauses` | tempo alignment and vocabulary matching; pause composure is scored only when pause timings are supplied, and impossible duration/pause combinations return `422` |
| GET | `/v1/content/articles` | optional `level` query | authentic $i+1$ CEFR-graded articles |
| GET | `/v1/content/articles/:id` | — | full article text, key vocabulary, comprehension questions |
| POST | `/v1/content/articles/:id/evaluate` | `text` | output-forcing evaluation, whole-word target vocabulary usage, a mechanics score (capitalization/length, not grammar), and a model recast only when an AI provider is configured |
| POST | `/v1/decision/affective-state` | `transcript`, `durationSeconds`, `pauseCount`, `wpm` | Krashen affective anxiety triage, confidence score, scaffolding recommendation via Jev |
| POST | `/v1/decision/calibrate-level` | `transcript`, optional `targetWords` | adaptive $i+1$ CEFR calibration, lexical range, syntactic complexity via Jev |
| GET | `/v1/mastery/profile` | — | 4-axis skill XP (fluency, lexical, acoustic, interaction), rank tier, freeze tokens; XP is awarded only by server-verified practice events |
| POST | `/v1/mastery/freeze-token` | — | consumes 1 freeze token to safeguard daily streak without anxiety |
| GET | `/v1/pronunciation/pairs` | optional `category`, `level` queries | minimal pairs phonetics catalog with IPA and articulatory mechanics |
| GET | `/v1/pronunciation/pairs/:id` | — | detailed minimal pair with sentence drill and biomechanical guide |
| POST | `/v1/pronunciation/pairs/:id/analyze` | `targetChoice` ('A'/'B'), `transcript`, `durationSeconds` | acoustic accuracy, phoneme substitution confusion detection, articulatory correction tip, +XP |
| GET | `/v1/entitlements` | — | active Toungular Plus entitlement, or free plan |
| POST | `/v1/billing/verify` | `productId`, `purchaseToken` | explicit `BILLING_NOT_CONFIGURED` until a Toungular verifier is supplied |
| POST | `/v1/billing/restore` | `receipts` | explicit unavailable response until a Toungular verifier is supplied |
| GET | `/v1/referrals/me` | — | Toungular referral code and count |
| POST | `/v1/referrals/redeem` | `code` | associates one referral code with this account; no reward is configured |

The review scheduler is a modified SM-2: `again` resets repetitions, records a lapse, and returns in 1 day; `hard`, `good`, and `easy` grow the interval by ease factor, with harder recall modes earning a small ease bonus. Lesson completion schedules up to six mapped words, and coach turns schedule up to three known catalog words. Refresh tokens are opaque, stored only as hashes, rotated on use, and grouped into families so a replayed token revokes every descendant. Login and registration are rate-limited per client address, and API responses set standard security headers. Raw speaking audio is not stored by this API; without a configured STT provider the client sends an editable transcript, and with one the recording is forwarded for transcription only.

Account deletion is available to a signed-in learner through `DELETE /v1/me` and the client account screen. The API cascades the account's profile and learning/practice records and unlinks referrals that point to the deleted account. A public account-deletion request URL and Toungular privacy policy still need to be published before release.
