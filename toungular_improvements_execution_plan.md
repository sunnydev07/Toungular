# Toungular Feature & Architecture Improvements — Sequential Execution Plan for Gemini CLI Agent

## 1. Execution Strategy & Gemini CLI Kickoff Prompt

This plan is designed for a single **Gemini CLI Agent (`gemini`)** executing sequentially from the repository root (`Toungular-main/`). Each phase builds one complete vertical capability from **Prisma Schema $\rightarrow$ Backend Provider/Service $\rightarrow$ Express Route $\rightarrow$ Flutter Domain Model/Repository $\rightarrow$ Flutter UI Screen $\rightarrow$ Automated Tests**, grounded in empirical Second-Language Acquisition (SLA) and speech-science specifications:

1. **Phase 1 — FSRS-5 Spaced Repetition & Recall Latency Grading**: Upgrades the modified SM-2 scheduler in `srs.ts` to the Three-Component Model of Memory (Difficulty $D$, Stability $S$, Retrievability $R$) from the [Free Spaced Repetition Scheduler (FSRS) Specification](https://github.com/open-spaced-repetition/awesome-fsrs/wiki/The-Algorithm), which reduces review workload by 20–30% at equal retention in [FSRS vs. SM-2 Benchmarks](https://github.com/open-spaced-repetition/awesome-fsrs/wiki/ABC-of-FSRS), and wires `DecisionService.predictSrsGrade()` to card recall latency (`responseTimeMs`).
2. **Phase 2 — End-to-End Jev Decision Gating & Adaptive Affective/CEFR UI**: Wires the unused System 1 (`JevClient` / `DecisionService`) methods (`gateCoachTurn`, `calibrateCefrLevel`, `assessAffectiveState`) into `CoachService` and `SpeakingService`, and adds interactive scaffolding and CEFR $i+1$ action cards in `SpeakingFeedbackView`.
3. **Phase 3 — 4-Criterion IELTS Speaking Band Estimator & Phrase Upgrades**: Upgrades `IeltsService.finishAttempt()` and `IeltsScreen` to evaluate all 3 mock parts across the four official [IELTS Speaking Band Descriptors](https://ielts.org/cdn/ielts-guides/ielts-speaking-band-descriptors.pdf) (**Fluency & Coherence**, **Lexical Resource**, **Grammatical Range & Accuracy**, and **Pronunciation**, 25% each per the [IELTS IDP Assessment Guide](https://ieltsidpindia.com/information/ielts-band-scores/speaking)).
4. **Phase 4 — Acoustic Phoneme GOP Scoring, Syntactic Pause Alignment & Hands-Free VAD Coach Mode**: Adds phoneme-level Goodness of Pronunciation (GOP) and word-boundary timestamps modeled on [Azure AI Speech Pronunciation Assessment](https://learn.microsoft.com/en-us/azure/ai-services/speech-service/how-to-pronunciation-assessment) and [OpenPronounce (Wav2Vec2 + DTW)](https://github.com/Halleck45/OpenPronounce) (inspired by [Hierarchical Transformer GOP Scoring](https://techcommunity.microsoft.com/blog/azure-ai-foundry-blog/speech-service-update-%E2%80%93-hierarchical-transformer-for-pronunciation-assessment/3740866)), plus a hands-free Voice Activity Detection (VAD) call loop in `CoachConversationScreen` inspired by [OpenAI WebRTC Voice Agents](https://developers.openai.com/api/docs/guides/voice-agents) and [Realtime WebRTC Streaming](https://developers.openai.com/api/docs/guides/voice-webrtc).

### Windows PowerShell Kickoff Command

Run this command from the repository root (`Toungular-main/`):

```powershell
gemini "Read toungular-improvements-execution-plan.md and execute Phase 1 through Phase 4 sequentially from the repository root. After completing each phase across backend/ and mobile/, run the phase verification commands ('npm test' in backend/ and 'flutter analyze && flutter test' in mobile/) before advancing to the next phase."
```

## 2. Phase 1: FSRS-5 Spaced Repetition & Recall Latency Grading

### Step 1.1: Add FSRS Memory State Columns to `ReviewSchedule` (`backend/prisma/`)

- [x] In both `backend/prisma/schema.prisma` and `backend/prisma/postgresql/schema.prisma`, add `stability` and `difficulty` to `model ReviewSchedule`:
  ```prisma
  model ReviewSchedule {
    id             String         @id @default(cuid())
    userId         String
    vocabularyId   String
    dueAt          DateTime
    intervalDays   Int            @default(0)
    repetitions    Int            @default(0)
    easeFactor     Float          @default(2.5)
    stability      Float          @default(0)
    difficulty     Float          @default(5.0)
    lapses         Int            @default(0)
    lastGrade      String?
    lastRecallMode String?
    source         String         @default("catalog")
    context        String?
    lastReviewedAt DateTime?
    createdAt      DateTime       @default(now())
    updatedAt      DateTime       @updatedAt
    user           User           @relation(fields: [userId], references: [id], onDelete: Cascade)
    vocabulary     VocabularyItem @relation(fields: [vocabularyId], references: [id], onDelete: Cascade)

    @@unique([userId, vocabularyId])
    @@index([userId, dueAt])
    @@index([userId, lastReviewedAt])
  }
  ```
- [x] Add migration SQL in `backend/prisma/migrations/` and `backend/prisma/postgresql/migrations/`:
  ```sql
  ALTER TABLE "ReviewSchedule" ADD COLUMN "stability" REAL NOT NULL DEFAULT 0;
  ALTER TABLE "ReviewSchedule" ADD COLUMN "difficulty" REAL NOT NULL DEFAULT 5.0;
  ```

### Step 1.2: Implement FSRS-5 DSR Equations in `backend/src/services/srs.ts`

- [x] Extend `SrsState` and `SrsNext` in `backend/src/services/srs.ts` with optional `stability?: number`, `difficulty?: number`, and `retrievability?: number` per the [FSRS-5 Algorithm](https://github.com/open-spaced-repetition/awesome-fsrs/wiki/The-Algorithm):
  1. Map grades to $G \in \{1=\text{again}, 2=\text{hard}, 3=\text{good}, 4=\text{easy}\}$.
  2. Compute initial stability on first review ($S_0(G) \in \{0.40, 1.18, 3.17, 15.69\}$) and initial difficulty $D_0(G) = \text{clamp}(7.19 - e^{0.53(G - 1)} + 1, 1.0, 10.0)$.
  3. On subsequent reviews, compute elapsed days $t = \max(1, \text{elapsedDays})$ and retrievability $R(t, S) = \left(1 + \frac{19}{81} \cdot \frac{t}{S}\right)^{-0.5}$.
  4. Update difficulty $D' = \text{clamp}(D - 0.8 \cdot (G - 3), 1.0, 10.0)$ with mean reversion toward $D_0(3)$.
  5. Update stability $S'$ on recall ($G \ge 2$) vs. lapse ($G = 1$), apply active recall mode multiplier (`sentence`: `1.12`, `audio`: `1.08`), and set `intervalDays = Math.max(1, Math.min(365, Math.round(S')))` for target retention $R_{\text{target}} = 0.90$.
- [x] Update `backend/src/services/vocabulary-service.ts` (`getDue` and `recordReview`) and `backend/src/contracts.ts` to expose `stability`, `difficulty`, and `retrievability` on `VocabularyReview`.
- [x] In `backend/src/routes/v1.ts` (`POST /v1/vocabulary/:itemId/review`), accept optional `responseTimeMs: z.number().int().min(0).max(120_000).optional()` in `reviewSchema`, call `dependencies.decision.predictSrsGrade(...)` when `responseTimeMs` is supplied, and return `prediction` alongside the updated review schedule.

### Step 1.3: Add Recall Stopwatch & Stability Badge in Flutter (`mobile/lib/features/vocabulary/`)

- [x] In `mobile/lib/shared/models/learning_models.dart`, add `stability` (`double`), `difficulty` (`double`), and `retrievability` (`double`) to `VocabularyReview`.
- [x] In `mobile/lib/features/vocabulary/vocabulary_repository.dart`, add optional `int? responseTimeMs` to `submitReview(String itemId, String grade, {String? mode, int? responseTimeMs})`.
- [x] In `mobile/lib/features/vocabulary/vocabulary_screen.dart`:
  1. Add `final Stopwatch _cardStopwatch = Stopwatch();` and restart it whenever a card is displayed (`initState`, `_grade`, `_refresh`).
  2. Stop `_cardStopwatch` when the learner taps **Reveal**.
  3. Display a `"Suggested"` badge on the grade button matching recall latency (`< 3500 ms` $\rightarrow$ `easy`, `3500–8000 ms` $\rightarrow$ `good`, `> 8000 ms` $\rightarrow$ `hard`) and display a subtle memory stability chip (`Stability: ${review.stability.toStringAsFixed(1)}d`).
  4. Pass `responseTimeMs: _cardStopwatch.elapsedMilliseconds` to `submitReview(...)`.
- [x] **Phase 1 Verification**: Run `cd backend && npm test` and `cd ../mobile && flutter analyze && flutter test`.

## 3. Phase 2: End-to-End Jev Decision Gating & Adaptive Affective/CEFR UI

### Step 2.1: Wire `DecisionService` into `CoachService` and `SpeakingService` (`backend/src/`)

- [x] In `backend/src/app.ts`, inject `decision` (`DecisionService`) into `new CoachService(prisma, env, decision)` and `new SpeakingService(prisma, decision)`.
- [x] In `backend/src/services/coach-service.ts` (`addTurn`):
  1. Call `const turnGate = this.decision ? await this.decision.gateCoachTurn({ scenarioTitle: scenario.title, previousTurns, learnerTurn: transcript }) : null;`.
  2. Append `turnGate` guidance to the LLM system prompt in `callGeminiChat()` and `callOpenAiChat()` (`If needsRecast is true, recast the learner's ${turnGate.errorCategory} error naturally; if isOffTopic is true, gently steer back to ${scenario.title}`).
  3. Return `turnGate` in the `addTurn()` response object.
- [x] In `backend/src/services/speaking-service.ts` (`analyze`):
  1. When `this.decision` is available, run `assessAffectiveState({ transcript, durationSeconds: duration, pauseCount: analysis.pauseCount, wpm: analysis.wordsPerMinute })` and `calibrateCefrLevel({ transcript })` in parallel via `Promise.all`.
  2. Attach `affective` and `cefrCalibration` directly to the returned `result` object (and stored `feedback` JSON) so the mobile client receives them in a single round-trip.

### Step 2.2: Render Interactive Affective Scaffolding & CEFR Cards in Flutter (`mobile/lib/features/speaking/`)

- [x] In `mobile/lib/shared/models/learning_models.dart`:
  1. Parse optional `affective` (`AffectiveAssessmentResult?`) and `cefrCalibration` (`CefrCalibrationResult?`) inside `SpeakingFeedback.fromJson()`.
  2. Parse optional `turnGate` (`CoachTurnGate?`) inside `CoachTurnReceipt.fromJson()`.
- [x] In `mobile/lib/features/speaking/speaking_feedback_view.dart`:
  1. Add an optional `ValueChanged<String>? onOpenCefrContent;` callback and `VoidCallback? onStepDownToWhisper;`.
  2. When `effectiveAffective` (`affective ?? feedback.affective`) has `shouldScaffold == true`, render an **Affective Support Card** showing `intervention`:
     * If `intervention == 'step_down_to_whisper'`, render a button that opens `/exposure` (Comfort Path).
     * If `intervention == 'provide_sentence_starter'`, display a starter prompt cue and pass it into `onRetryWithTip`.
  3. When `feedback.cefrCalibration != null`, render a **CEFR Calibration Card** displaying the detected level (`A1`–`C2`), syntactic complexity percentage, lexical range percentage, and a button to open `/content` filtered to that CEFR level.
- [x] **Phase 2 Verification**: Run `cd backend && npm test` and `cd ../mobile && flutter analyze && flutter test`.

## 4. Phase 3: 4-Criterion IELTS Speaking Band Estimator & Phrase Upgrades

### Step 3.1: Build the 4-Criterion IELTS Rubric Engine (`backend/src/services/ielts-service.ts`)

- [x] In `backend/src/app.ts`, pass `env` and `decision` into `new IeltsService(prisma, env, decision)`.
- [x] In `backend/src/services/ielts-service.ts`, implement `evaluateAttemptRubric(responses)` aligned with the four official [IELTS Speaking Band Descriptors](https://ielts.org/cdn/ielts-guides/ielts-speaking-band-descriptors.pdf) (25% weight each per the [IELTS IDP Scoring Guide](https://ieltsidpindia.com/information/ielts-band-scores/speaking)):
  1. **Fluency & Coherence**: Score based on response completeness across Parts 1–3, discourse connector variety (`however`, `furthermore`, `for instance`, `consequently`, `on the other hand`), and low repetition.
  2. **Lexical Resource**: Score using type-token ratio, academic/Tier-2 word density, and `DecisionService.calibrateCefrLevel()` `lexicalRange`.
  3. **Grammatical Range & Accuracy**: Score using complex/subordinate clause markers (`although`, `whereas`, `which`, `despite`, `provided that`), sentence length variance, and `syntacticComplexity`.
  4. **Pronunciation (Intelligibility & Rhythm Proxy)**: Score from transcript clarity and syllable/phonological complexity, clearly noting whether acoustic GOP was used.
  5. Round each criterion and `overallBandEstimate` to the nearest `0.5` band (`4.0` to `8.5`), generate 2 concrete `upgradedPhrases` (`{ original, upgraded, reason }`), and include the mandatory non-affiliation disclaimer (`"Practice estimate only — not an official IELTS band score."`).
- [x] Return `rubric` alongside `feedback` in `POST /v1/ielts/attempts/:id/finish` and parse stored JSON rubrics in `GET /v1/ielts/attempts`.

### Step 3.2: Build the IELTS Band Scorecard UI in Flutter (`mobile/lib/features/ielts/`)

- [x] In `mobile/lib/shared/models/learning_models.dart`, add `IeltsCriterionScore`, `IeltsPhraseUpgrade`, and `IeltsBandRubric`, and include `IeltsBandRubric? rubric` on `IeltsAttemptRecord`.
- [x] In `mobile/lib/features/ielts/ielts_repository.dart`, update `finishAttempt(String attemptId)` to return `IeltsAttemptRecord` (containing both `feedback` and `rubric`).
- [x] In `mobile/lib/features/ielts/ielts_screen.dart`, render `_IeltsBandScorecard` upon completing an attempt and inside expandable history cards, showing the 4 criterion band scores (`Fluency & Coherence`, `Lexical Resource`, `Grammatical Range`, `Pronunciation`), diagnostic notes, and `upgradedPhrases` cards.
- [x] **Phase 3 Verification**: Run `cd backend && npm test` and `cd ../mobile && flutter analyze && flutter test`.

## 5. Phase 4: Acoustic Phoneme GOP Scoring & Hands-Free VAD Coach Mode

### Step 4.1: Add Acoustic GOP Pronunciation & Word Timestamps (`backend/src/providers/voice.ts` & `pronunciation-service.ts`)

- [x] In `backend/src/config/env.ts`, add optional `AZURE_SPEECH_KEY: z.string().min(8).optional()` and `AZURE_SPEECH_REGION: z.string().min(2).default('centralindia')`.
- [x] In `backend/src/providers/voice.ts`:
  1. Extend `SttProvider.transcribe()` to return optional `words?: Array<{ word: string; start: number; end: number; confidence?: number }>` and extract word timings + acoustic confidence from `DeepgramStt`.
  2. Add an optional `PronunciationAssessor` provider supporting [Azure AI Speech Pronunciation Assessment](https://learn.microsoft.com/en-us/azure/ai-services/speech-service/how-to-pronunciation-assessment) (`GradingSystem: HundredMark`, `Granularity: Phoneme`) so when configured, phoneme-level GOP scores are returned.
- [x] In `backend/src/services/fluency.ts`, accept optional `wordTimings` in `analyzeTranscript()` to classify pauses occurring mid-clause vs. at punctuation boundaries.

### Step 4.2: Add Hands-Free VAD Voice Call Mode to `CoachConversationScreen` (`mobile/lib/features/coach/coach_conversation_screen.dart`)

- [x] In `mobile/lib/features/coach/coach_conversation_screen.dart`:
  1. Add a `bool _handsFreeCall = false;` toggle action (`Icons.spatial_audio_off` / `Icons.headset_mic`) in the `AppBar` when `_sttAvailable` is true.
  2. Subscribe to `_recorder.onAmplitudeChanged(const Duration(milliseconds: 200))` during recording: track `_speechDetected` (amplitude `> -35.0 dBFS` for at least `400 ms`) and auto-trigger `_toggleRecording()` $\rightarrow$ STT $\rightarrow$ `_send()` when silence (`< -40.0 dBFS`) persists for `1,500 ms` after speech, matching modern [Voice Agent Turn-Taking Architectures](https://developers.openai.com/api/docs/guides/voice-agents).
  3. In `_send()`, when `_handsFreeCall` is active and `receipt.replyTurn != null`, automatically play the AI Coach's reply via `_toggleTts(receipt.replyTurn!)`, and upon playback completion, automatically start the next recording turn if the conversation is still active.
  4. Render the `turnGate.errorCategory` badge on the **Natural phrasing tip** card whenever `receipt.turnGate?.needsRecast == true`.
- [x] **Phase 4 Final Verification**:
  ```powershell
  cd backend && npm run prisma:generate && npm run schema:check && npm test && npm run build
  cd ../mobile && flutter analyze && flutter test
  ```