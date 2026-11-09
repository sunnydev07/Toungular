# Toungular Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: After the user chooses an execution approach, use `superpowers:executing-plans` for native execution or `superpowers:subagent-driven-development` for subagent-driven execution. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a new Android-first English-learning app named Toungular with original services and broad learner-facing feature parity with Stimuler.

**Architecture:** Flutter mobile client communicates with a Toungular-owned TypeScript/Express API. The API uses Prisma with SQLite for local development and PostgreSQL through `DATABASE_URL` for production, and keeps speech/AI, ad, and purchase integrations behind provider interfaces. Ship an APK configured for a caller-supplied API URL; production AI, ad, and billing credentials remain server/account configuration.

**Tech Stack:** Flutter 3.47.5 / Dart 3.13.4; Flutter Riverpod, GoRouter, Dio, `record`, `speech_to_text`, `just_audio`, `flutter_secure_storage`, `shared_preferences`, `flutter_local_notifications`, `in_app_purchase`, and `google_mobile_ads`; Node.js/TypeScript, Express, Zod, Prisma, SQLite (development), PostgreSQL (production).

**Spec:** [2026-11-09-toungular-design.md](../specs/2026-11-09-toungular-design.md)

## Global Constraints

- Android-first and English-first.
- Use new Toungular branding, code, learning copy, course content, service configuration, analytics, ad account, and purchase verification.
- Do not copy Stimuler assets, branding, API credentials, private endpoints, account data, prompts, or server implementation.
- Speaking/recording sessions must not be interrupted by ads.
- Do not state that app-generated feedback is an official IELTS score or certified fluency result.
- Keep AI, speech, ad, and purchase secrets out of the mobile bundle.
- Handle unavailable providers explicitly; do not fabricate AI replies or pronunciation scores.
- No automated tests are added or run unless the user requests testing or verification. The requested Android APK is a build deliverable, not evidence that every live provider integration is configured.

## Review Focus

- Microphone permission denied: preserve non-speaking learning paths and explain how to re-enable recording (Task 5).
- Backend offline or provider unconfigured: preserve saved progress and show actionable unavailable states without invented analyses (Tasks 2, 5, 6, and 9).
- Long, interrupted, or corrupt audio: recover the speaking session without losing its prompt or transcript (Task 5).
- Stale or unverifiable purchase: do not grant paid entitlements until backend verification succeeds (Task 9).
- Ad response during recording or voice conversation: suppress/dismiss the placement and retain the active session (Task 9).

## File Map

### Flutter client (`mobile/`)

- `mobile/pubspec.yaml`: client dependencies and assets.
- `mobile/android/app/build.gradle.kts`, `mobile/android/app/src/main/AndroidManifest.xml`, `mobile/android/app/src/main/kotlin/com/toungular/app/MainActivity.kt`: package ID, label, platform setup, and required permission declarations.
- `mobile/lib/main.dart`, `mobile/lib/app/app.dart`, `mobile/lib/app/router.dart`: app startup, provider scope, and routes.
- `mobile/lib/core/config/app_environment.dart`, `mobile/lib/core/network/api_client.dart`, `mobile/lib/core/storage/session_store.dart`: environment, authenticated API requests, and secure session storage.
- `mobile/lib/core/sync/offline_action_queue.dart`: queued lesson completion and vocabulary review actions for later sync.
- `mobile/lib/core/theme/`: Toungular design tokens and reusable widgets.
- `mobile/lib/features/auth/`: sign-in, registration, profile setup, and onboarding state.
- `mobile/lib/features/home/`: daily plan, roadmap summary, and navigation entry points.
- `mobile/lib/features/courses/`, `mobile/lib/features/vocabulary/`: course, lesson, and spaced-review flows.
- `mobile/lib/features/speaking/`: prompt selection, permission, recording, transcript editing, result, and history.
- `mobile/lib/features/coach/`: coach session, role-play scenarios, turns, and conversation summary.
- `mobile/lib/features/ielts/`: timed speaking sections, attempts, and review.
- `mobile/lib/features/progress/`, `mobile/lib/features/habits/`: skill history, streaks, reminders, and weekly summary.
- `mobile/lib/features/monetization/`: ad slots, paywall, purchase restore, entitlements, and referral entry.
- `mobile/lib/shared/models/`: typed API and domain models shared across feature modules.

### Backend (`backend/`)

- `backend/package.json`, `backend/tsconfig.json`: server tooling and scripts.
- `backend/.env.example`: non-secret configuration names and local defaults.
- `backend/prisma/schema.prisma`, `backend/prisma/seed.ts`: user, profile, curriculum, review, speaking, conversation, progress, habit, referral, and entitlement data.
- `backend/src/app.ts`, `backend/src/server.ts`: Express composition and startup.
- `backend/src/config/env.ts`, `backend/src/db/prisma.ts`, `backend/src/http/`: validated configuration, persistence, auth middleware, and error handling.
- `backend/src/modules/auth/`, `profile/`, `curriculum/`, `vocabulary/`, `speaking/`, `coach/`, `ielts/`, `progress/`, `habits/`, `billing/`, `referrals/`: route, schema, and service files for each API boundary.
- `backend/src/providers/speech/`, `coach/`, `tts/`, `billing/`: provider interfaces, unconfigured implementations, and configured adapters.
- `backend/storage/.gitkeep`: local audio upload directory; production storage comes from provider configuration.
- `README.md`: run instructions, environment variables, build instructions, provider setup, and feature limitations.

---

### Task 1: Establish Toungular project skeleton

**Files:** Create `mobile/` Flutter project and `backend/` TypeScript service structure from the file map; create root `README.md` and ignore rules for build output, local databases, audio, and secrets.

**Interfaces:**

- Produces: Flutter application ID `com.toungular.app`, app label `Toungular`, API base URL compile-time variable `API_BASE_URL`; server startup entry `backend/src/server.ts` and configuration contract in `backend/.env.example`.

- [x] Create Flutter app scaffolding and set Android ID/label to `com.toungular.app` / `Toungular`.
- [x] Add only dependencies listed in the Tech Stack that are used by the first implementation tasks.
- [x] Create TypeScript Express service package with strict TypeScript settings and Prisma SQLite development configuration.
- [x] Add `.env.example` with `PORT`, `DATABASE_URL`, `JWT_SECRET`, `MOBILE_ORIGIN`, and optional provider configuration names; put no real secrets in source.
- [x] Add README setup commands for Flutter, Android SDK, backend, local API URL, and environment configuration.

**Deliverable:** Separate Flutter and backend source trees, with no dependency on the Stimuler package at runtime.

### Task 2: Implement backend foundation and learning data contracts

**Files:** Create backend config, Prisma schema, migrations, seed entry, Express middleware, and route/service modules listed in the file map.

**Interfaces:**

- `AuthService.register(input: RegisterInput): Promise<AuthResult>` and `AuthService.login(input: LoginInput): Promise<AuthResult>`.
- `AuthService.refresh(refreshToken: string): Promise<AuthResult>`.
- `ProfileService.get(userId: string): Promise<Profile>` and `ProfileService.update(userId: string, patch: ProfilePatch): Promise<Profile>`.
- `CurriculumService.getRoadmap(userId: string): Promise<Roadmap>` and `CurriculumService.completeLesson(userId: string, lessonId: string): Promise<LessonProgress>`.
- `VocabularyService.getDue(userId: string, now: Date): Promise<VocabularyReview[]>` and `VocabularyService.recordReview(userId: string, itemId: string, grade: ReviewGrade, now: Date): Promise<VocabularyReview>`.
- API routes: `/v1/auth/register`, `/v1/auth/login`, `/v1/auth/refresh`, `/v1/me`, `/v1/roadmap`, `/v1/courses`, `/v1/lessons/:lessonId`, `/v1/lessons/:lessonId/complete`, `/v1/vocabulary/due`, `/v1/vocabulary/:itemId/review`.

- [x] Define Prisma records for users, profiles, courses, lessons, lesson progress, vocabulary items, review schedule, speaking sessions, conversations, IELTS attempts, skill snapshots, streak state, referrals, and purchase entitlements.
- [x] Implement validated env loading, Prisma connection, JSON error responses, JWT bearer middleware, password hashing, and refresh-token rotation.
- [x] Implement registration/login/profile routes and persisted profile goals, proficiency, daily minutes, timezone, and IELTS intent.
- [x] Seed original English curriculum and vocabulary/review entries; do not reuse target copy or bundled sample payloads.
- [x] Implement roadmap, lesson detail/completion, due vocabulary, and review scheduling with a simple interval-based spaced repetition policy.
- [x] Configure local SQLite as default; accept PostgreSQL through `DATABASE_URL` without changing service-layer contracts.

**Deliverable:** Locally runnable API with persistent user/profile/course/progress data and documented JSON contracts.

### Task 3: Build the Toungular client shell, onboarding, and daily plan

**Files:** Create `mobile/lib/main.dart`, app/router, environment, API client, secure session store, design tokens, auth and home feature files.

**Interfaces:**

- `ApiClient.get<T>(path, decoder)` and `ApiClient.post<T>(path, body, decoder)` attach the session token and return typed server errors.
- `AuthRepository.register(...)`, `AuthRepository.login(...)`, and `AuthRepository.logout()` own authentication persistence.
- `RoadmapRepository.load()` returns the signed-in learner’s `Roadmap`.

- [ ] Implement Toungular visual tokens, app routing, loading/error/empty states, and session restoration.
- [ ] Implement sign-in and account creation UI connected to Task 2 routes.
- [ ] Implement onboarding for proficiency, goals, daily minutes, optional IELTS intent, and microphone permission explanation; request microphone permission only when the learner starts speaking.
- [ ] Implement home view with daily path, skill overview, streak state, and links to courses, speaking, coach, IELTS, and progress.
- [ ] Implement login expiry and backend-unavailable screens without discarding a valid local session or cached read-only learning content.

**Deliverable:** A user can create/sign into a Toungular account, set goals, and reach a personalized daily learning hub.

### Task 4: Implement courses, lessons, and vocabulary practice

**Files:** Create course/vocabulary feature screens and repositories; add content and review DTOs to shared models; extend backend curriculum seed and services.

**Interfaces:**

- `CurriculumRepository.loadRoadmap()`, `loadLesson(lessonId)`, and `completeLesson(lessonId)`.
- `VocabularyRepository.loadDueItems()` and `submitReview(itemId, grade)`.
- Lesson types: `vocabulary`, `grammar`, `pronunciation`, `integrated`; review grade: `again`, `hard`, `good`, `easy`.

- [ ] Build course/roadmap, lesson details, lesson activity, and completion screens with original Toungular copy.
- [ ] Implement vocabulary cards, example usage, recall response, review grading, and due queue.
- [ ] Implement grammar and pronunciation lesson activities using the same lesson progression contract.
- [ ] Persist completions and review schedule through the API; make offline read-only content usable and queue review/completion actions for later sync.
- [ ] Connect daily plan recommendations to due vocabulary and incomplete lessons.

**Deliverable:** A learner can follow and complete English lessons and review vocabulary on a spaced schedule.

### Task 5: Implement speaking recording, transcript, and honest feedback

**Files:** Create speaking screens, audio/transcript models, recording/transcription adapters, backend speaking routes/services, and local upload storage configuration.

**Interfaces:**

- `SpeakingRepository.createSession(promptId)`, `uploadAudio(sessionId, audioFile)`, `saveTranscript(sessionId, transcript)`, `analyze(sessionId)`, and `loadHistory()`.
- `SpeechCapture.start()`, `SpeechCapture.stop()`, and `SpeechCapture.cancel()` return the audio path plus elapsed duration; speech recognition is represented as an optional transcript source.
- `FeedbackProvider.analyze(input: FeedbackInput): Promise<FeedbackResult>`; unconfigured pronunciation analysis returns an explicit `unavailable` field, never a fabricated score.
- API routes: `POST /v1/speaking-sessions`, `POST /v1/speaking-sessions/:id/audio`, `PUT /v1/speaking-sessions/:id/transcript`, `POST /v1/speaking-sessions/:id/analyze`, `GET /v1/speaking-sessions/:id`, `GET /v1/speaking-sessions`.

- [ ] Implement prompt selection, permission request, recording controls, playback, cancellation, and recoverable upload state.
- [ ] Support system speech recognition where available and editable transcripts; clearly show when transcription is unavailable.
- [ ] Calculate transparent baseline feedback from transcript/duration for pace, filler density, and vocabulary variety; mark these as practice estimates.
- [ ] Implement provider interface for advanced speech/pronunciation feedback; keep API keys on backend and show `not configured` state until Toungular supplies a provider.
- [ ] Show transcript, audio playback, available feedback dimensions, follow-up lesson, and session history.
- [ ] Save the prompt/transcript/session draft before upload so interruptions or network loss do not erase the attempt.

**Deliverable:** Prompt-based speaking sessions work with recording, transcript editing, history, and clearly labeled available/unavailable feedback.

### Task 6: Implement AI coach and role-play

**Files:** Create coach screens/models/repository; add conversation/session/turn Prisma data; add coach routes and provider interface.

**Interfaces:**

- `CoachRepository.start(scenarioId)`, `sendTurn(conversationId, turnInput)`, `loadConversation(conversationId)`, and `finish(conversationId)`.
- `CoachProvider.reply(context: CoachContext, learnerTurn: LearnerTurn): Promise<CoachTurn>`; an unconfigured provider returns a typed unavailable response.
- Each voice exchange is turn-based: the learner turn includes a transcript (from speech recognition or editing), and `CoachTurn` includes text plus optional generated `audioUrl` for TTS playback; streaming is outside this initial implementation.
- API routes: `GET /v1/coach/scenarios`, `POST /v1/conversations`, `POST /v1/conversations/:id/turns`, `POST /v1/conversations/:id/finish`, `GET /v1/conversations/:id`.

- [ ] Add original scenario catalog for open conversation, interview, travel, workplace, and IELTS speaking practice.
- [ ] Build turn-based chat/voice conversation UI with visible turn states, transcript, optional TTS playback, exit/finish, and session summary.
- [ ] Keep live AI/TTS optional via backend provider interfaces; when unconfigured, offer a non-AI prompt practice route rather than fake replies.
- [ ] Store conversation turns and feedback summary in Toungular’s own backend; allow the learner to delete a conversation.

**Deliverable:** Scenario-based practice and conversation history are available, with explicit graceful behavior when live AI/TTS is not configured.

### Task 7: Implement IELTS-style speaking practice

**Files:** Create IELTS feature screens/models/repository and backend attempt/session services.

**Interfaces:**

- `IeltsRepository.loadMocks()`, `startAttempt(mockId)`, `submitResponse(attemptId, sectionId, response)`, and `finishAttempt(attemptId)`.
- API routes: `GET /v1/ielts/mocks`, `POST /v1/ielts/attempts`, `POST /v1/ielts/attempts/:id/responses`, `POST /v1/ielts/attempts/:id/finish`.

- [ ] Create original timed speaking sections covering interview-style answers, a long-turn prompt, and follow-up discussion.
- [ ] Implement preparation timer, response timer, save/resume, and completion flow using the speaking capture contract.
- [ ] Show practice feedback and dimensions available from configured providers; label results as unofficial practice feedback.
- [ ] Save attempt history and link weaknesses to lessons and vocabulary reviews.

**Deliverable:** Learners can complete and review original timed IELTS-style speaking mocks.

### Task 8: Implement progress, streaks, and reminders

**Files:** Create progress/habits screens and services; extend backend skill snapshot/streak/reminder records and routes; add notification setup.

**Interfaces:**

- `ProgressRepository.loadSummary(range)` returns skill snapshots, sessions, lesson completion, and vocabulary review outcomes.
- `HabitRepository.loadStreak()`, `updateReminder(schedule)`, and `claimStreakRepair()` (the last only when the configured entitlement permits it).
- API routes: `GET /v1/progress`, `GET /v1/streak`, `PUT /v1/reminders`, `POST /v1/streak/repair`.

- [ ] Build progress overview with separate fluency, vocabulary, pronunciation, grammar, and consistency trends.
- [ ] Build session/course history, weekly summary, streak state, and optional reminder scheduling.
- [ ] Make aggregate scores traceable to underlying sessions and label estimated/provider-unavailable dimensions.
- [ ] Implement achievement/referral/buddy-streak entry points using Toungular-owned rules and data.

**Deliverable:** Learners can see longitudinal progress and use streak/reminder features without overstating score precision.

### Task 9: Implement Toungular monetization and ad controls

**Files:** Create monetization/ads feature files and backend billing/ads/referral modules; add Android SDK application configuration using development test configuration only.

**Interfaces:**

- `EntitlementRepository.load()`, `purchase(productId)`, and `restore()`.
- `AdPlacementPolicy.canShow(placement: AdPlacement, appState: AppInteractionState): bool` suppresses all ad requests while recording or voice conversation is active. Allowed slots are home banner, lesson native, and optional rewarded lesson unlock.
- `BillingProvider.verifyPurchase(receipt): Promise<EntitlementResult>` (backend) and `ToungularAdsClient.load(placement, appState): Future<AdResult>` (Flutter); production IDs and credentials are Toungular-account-owned.
- API routes: `GET /v1/entitlements`, `POST /v1/billing/verify`, `POST /v1/billing/restore`, `GET /v1/referrals/me`, `POST /v1/referrals/redeem`.

- [ ] Implement free-tier paywall UI, subscription entitlements, restore purchases, and backend verification boundary.
- [ ] Implement home banner, lesson native, and optional rewarded-unlock placements only when `AdPlacementPolicy` allows them; use official development test IDs and production IDs only from Toungular-owned configuration.
- [ ] Ensure premium entitlement suppresses ads and exposes the features defined by Toungular’s own product policy.
- [ ] Implement referral code display/redeem path and event tracking without Stimuler identifiers.
- [ ] Document the required Toungular Play Console and ad account setup; keep live monetization disabled until those accounts/products are configured.

**Deliverable:** Monetization paths are implemented and safe by default; production purchases and ads activate only with Toungular-owned account configuration.

### Task 10: Connect, document, and package the Android app

**Files:** Modify `README.md`, client environment configuration, Android app icon/metadata, and backend run/deployment documentation.

**Interfaces:**

- Debug build accepts `--dart-define=API_BASE_URL=<Toungular API URL>`.
- Release build requires a non-placeholder HTTPS API URL and Toungular signing configuration supplied outside source control.

- [ ] Connect every feature route to the backend modules defined in earlier tasks and provide consistent loading/error/empty states.
- [ ] Add Toungular app icon/name and ensure generated package metadata contains no Stimuler branding or identifiers.
- [ ] Document local backend startup, supported provider environment variables, data/audio storage, and production account dependencies.
- [ ] Produce a debug APK at `mobile/build/app/outputs/flutter-apk/app-debug.apk` using the configured API URL; do not represent this as a production-signed or live-provider-ready release.
- [ ] Leave production signing, provider credentials, and deployment to Toungular-owned accounts/configuration.

**Deliverable:** Toungular source, backend source, setup documentation, and a buildable Android debug APK.

---

## Plan Self-Review

- **Spec coverage:** Onboarding/home (Task 3); courses/vocabulary/grammar/pronunciation (Task 4); speaking and feedback (Task 5); AI coach/role-play (Task 6); IELTS (Task 7); progress/streaks/reminders/referral (Task 8); ads/subscriptions/restore (Task 9); app/backend independence and setup (Tasks 1, 2, and 10).
- **Step scan:** Each checkbox creates a bounded implementation slice or configuration contract; unresolved production service account details remain environment setup, not source literals.
- **Type consistency:** Feature repositories consume the API client from Task 3 and use the typed domain/API models produced in Tasks 2 and 4-9.
- **Review focus:** Risk conditions are assigned to the tasks that implement their handling; automated test work is intentionally absent under the current instruction.
- **Proportion:** Ten sequential tasks cover one connected Android product and one API. The backend and client deliver incrementally through shared route/model contracts.
