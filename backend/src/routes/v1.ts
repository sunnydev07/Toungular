import express, { Router } from 'express';
import { z } from 'zod';

import type { AppEnv } from '../config/env.js';
import type { LoginInput, ProfilePatch, RecallMode, RegisterInput, ReviewGrade } from '../contracts.js';
import { AppError, asyncRoute } from '../lib/http.js';
import { authenticatedUserId, requireAuth } from '../middleware/auth.js';
import { AuthService } from '../services/auth-service.js';
import { CoachService } from '../services/coach-service.js';
import { ContentService } from '../services/content-service.js';
import { CurriculumService } from '../services/curriculum-service.js';
import { DecisionService } from '../services/decision-service.js';
import { ExposureService } from '../services/exposure-service.js';
import { IeltsService } from '../services/ielts-service.js';
import { MasteryService } from '../services/mastery-service.js';
import { MonetizationService } from '../services/monetization-service.js';
import { ProfileService } from '../services/profile-service.js';
import { PlacementService } from '../services/placement-service.js';
import { ProgressService } from '../services/progress-service.js';
import { PronunciationService } from '../services/pronunciation-service.js';
import { ShadowService } from '../services/shadow-service.js';
import { SpeakingService } from '../services/speaking-service.js';
import { VoiceService } from '../services/voice-service.js';
import { VocabularyService } from '../services/vocabulary-service.js';

const proficiencySchema = z.enum(['beginner', 'elementary', 'intermediate', 'upperIntermediate', 'advanced']);
const profilePatchSchema = z.object({
  goals: z.array(z.string().trim().min(1).max(80)).max(8).optional(),
  proficiency: proficiencySchema.optional(),
  dailyMinutes: z.number().int().min(5).max(180).optional(),
  timezone: z.string().trim().min(1).max(80).optional(),
  ieltsIntent: z.boolean().optional(),
});
const registerSchema = z.object({
  email: z.string().trim().email().max(254),
  password: z.string().min(8).max(128),
  profile: profilePatchSchema.optional(),
});
const loginSchema = z.object({
  email: z.string().trim().email().max(254),
  password: z.string().min(8).max(128),
});
const refreshSchema = z.object({ refreshToken: z.string().min(32).max(256) });
const logoutSchema = z.object({
  refreshToken: z.string().min(32).max(256).optional(),
  allSessions: z.boolean().optional(),
});
const historyQuerySchema = z.object({
  limit: z.coerce.number().int().min(1).max(100).default(30),
  offset: z.coerce.number().int().min(0).default(0),
});
const reviewSchema = z.object({
  grade: z.enum(['again', 'hard', 'good', 'easy']),
  mode: z.enum(['definition', 'cloze', 'audio', 'sentence']).optional(),
});
const speakingStartSchema = z.object({
  type: z.string().trim().regex(/^(prompt|ielts|baseline|anonymous|exposure-[1-7])$/).default('prompt'),
  prompt: z.string().trim().min(1).max(1000),
});
const transcriptSchema = z.object({ transcript: z.string().trim().min(1).max(12_000) });
const analyzeSchema = z.object({
  durationSeconds: z.number().int().min(1).max(600),
  transcript: z.string().trim().min(1).max(12_000).optional(),
  pauses: z.array(z.number().min(0).max(120)).max(100).optional(),
});
const manualWordSchema = z.object({
  word: z.string().trim().min(1).max(80),
  partOfSpeech: z.string().trim().min(1).max(40),
  definition: z.string().trim().min(1).max(400),
  example: z.string().trim().min(1).max(400),
  level: proficiencySchema,
  tier: z.number().int().min(1).max(3).optional(),
});
const encounterSchema = z.object({
  word: z.string().trim().min(1).max(80),
  source: z.enum(['lesson', 'coach', 'manual']),
  context: z.string().trim().max(500).optional(),
});
const voiceConfigSchema = z.object({
  provider: z.string().trim().min(1).max(40).optional(),
  voiceId: z.string().trim().min(1).max(120).optional(),
  language: z.string().trim().min(2).max(20).optional(),
  speed: z.number().min(0.5).max(2).optional(),
});
const ttsSchema = voiceConfigSchema.extend({ text: z.string().trim().min(1).max(2000) });
const sttQuerySchema = voiceConfigSchema.pick({ provider: true }).extend({
  contentType: z.string().trim().min(3).max(80).optional(),
});
const conversationStartSchema = z.object({ scenarioId: z.string().trim().min(1).max(80) });
const turnSchema = z.object({ transcript: z.string().trim().min(1).max(4000) });
const ieltsStartSchema = z.object({ mockId: z.string().trim().min(1).max(80) });
const ieltsResponseSchema = z.object({ sectionId: z.string().trim().min(1).max(80), transcript: z.string().trim().min(1).max(12_000) });
const reminderSchema = z.object({ time: z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/).nullable(), days: z.array(z.number().int().min(0).max(6)).max(7) });
const billingReceiptSchema = z.object({ productId: z.string().trim().min(1).max(120), purchaseToken: z.string().trim().min(8).max(4096) });
const restoreSchema = z.object({ receipts: z.array(billingReceiptSchema).max(20) });
const referralRedeemSchema = z.object({ code: z.string().trim().min(4).max(32) });
const placementAnswersSchema = z.object({
  answers: z.array(z.object({ itemId: z.string().min(1), word: z.string().trim().min(1).max(80) })).length(20),
});

const shadowAnalyzeSchema = z.object({
  passageId: z.string().trim().min(1).max(80),
  durationSeconds: z.number().min(1).max(300),
  transcript: z.string().trim().min(1).max(5000),
  pauses: z.array(z.number().min(0).max(60)).max(50).optional(),
});

const contentEvaluateSchema = z.object({
  text: z.string().trim().min(5).max(4000),
});

const affectiveStateSchema = z.object({
  transcript: z.string().trim().min(1).max(5000),
  durationSeconds: z.number().min(1).max(600),
  pauseCount: z.number().int().min(0).max(100),
  wpm: z.number().min(0).max(350),
});

const calibrateLevelSchema = z.object({
  transcript: z.string().trim().min(1).max(5000),
  targetWords: z.array(z.string().trim().min(1).max(80)).optional(),
});

const pronunciationAnalyzeSchema = z.object({
  targetChoice: z.enum(['A', 'B']),
  transcript: z.string().trim().min(1).max(1000),
  durationSeconds: z.number().min(0.5).max(120).optional(),
});

type V1Dependencies = {
  env: AppEnv;
  auth: AuthService;
  coach: CoachService;
  ielts: IeltsService;
  monetization: MonetizationService;
  profiles: ProfileService;
  placement: PlacementService;
  progress: ProgressService;
  curriculum: CurriculumService;
  speaking: SpeakingService;
  vocabulary: VocabularyService;
  exposure: ExposureService;
  voice: VoiceService;
  shadow: ShadowService;
  content: ContentService;
  decision: DecisionService;
  mastery: MasteryService;
  pronunciation: PronunciationService;
};

function paramString(param: string | string[] | undefined): string {
  if (Array.isArray(param)) return param[0] ?? '';
  return param ?? '';
}

export function createV1Router(dependencies: V1Dependencies): Router {
  const router = Router();
  const authenticate = requireAuth(dependencies.env);

  router.post('/auth/register', asyncRoute(async (request, response) => {
    const input = registerSchema.parse(request.body) as RegisterInput;
    const result = await dependencies.auth.register(input);
    response.status(201).json({ data: result });
  }));
  router.post('/auth/login', asyncRoute(async (request, response) => {
    const input = loginSchema.parse(request.body) as LoginInput;
    response.status(200).json({ data: await dependencies.auth.login(input) });
  }));
  router.post('/auth/refresh', asyncRoute(async (request, response) => {
    const { refreshToken } = refreshSchema.parse(request.body);
    response.status(200).json({ data: await dependencies.auth.refresh(refreshToken) });
  }));
  router.post('/auth/logout', authenticate, asyncRoute(async (request, response) => {
    const input = logoutSchema.parse(request.body ?? {});
    await dependencies.auth.logout(authenticatedUserId(request), input.refreshToken, input.allSessions ?? false);
    response.status(200).json({ data: { revoked: true } });
  }));

  router.get('/me', authenticate, asyncRoute(async (request, response) => {
    response.status(200).json({ data: await dependencies.profiles.get(authenticatedUserId(request)) });
  }));
  router.patch('/me', authenticate, asyncRoute(async (request, response) => {
    const patch = profilePatchSchema.parse(request.body) as ProfilePatch;
    response.status(200).json({ data: await dependencies.profiles.update(authenticatedUserId(request), patch) });
  }));
  router.delete('/me', authenticate, asyncRoute(async (request, response) => {
    await dependencies.profiles.deleteAccount(authenticatedUserId(request));
    response.status(204).end();
  }));

  router.get('/roadmap', authenticate, asyncRoute(async (request, response) => {
    response.status(200).json({ data: await dependencies.curriculum.getRoadmap(authenticatedUserId(request)) });
  }));
  router.get('/courses', authenticate, asyncRoute(async (request, response) => {
    const roadmap = await dependencies.curriculum.getRoadmap(authenticatedUserId(request));
    response.status(200).json({ data: roadmap.courses });
  }));
  router.get('/lessons/:lessonId', authenticate, asyncRoute(async (request, response) => {
    response.status(200).json({ data: await dependencies.curriculum.getLesson(authenticatedUserId(request), paramString(request.params.lessonId)) });
  }));
  router.post('/lessons/:lessonId/complete', authenticate, asyncRoute(async (request, response) => {
    const userId = authenticatedUserId(request);
    const progress = await dependencies.curriculum.completeLesson(userId, paramString(request.params.lessonId));
    await dependencies.vocabulary.scheduleLessonWords(userId, paramString(request.params.lessonId), new Date());
    response.status(200).json({ data: progress });
  }));

  router.get('/vocabulary/due', authenticate, asyncRoute(async (request, response) => {
    response.status(200).json({
      data: await dependencies.vocabulary.getDue(
        authenticatedUserId(request),
        new Date(),
        dependencies.voice.status().tts.available,
      ),
    });
  }));
  router.post('/vocabulary', authenticate, asyncRoute(async (request, response) => {
    const input = manualWordSchema.parse(request.body);
    response.status(201).json({
      data: await dependencies.vocabulary.addManual(
        authenticatedUserId(request),
        input,
        new Date(),
        dependencies.voice.status().tts.available,
      ),
    });
  }));
  router.post('/vocabulary/encounters', authenticate, asyncRoute(async (request, response) => {
    const input = encounterSchema.parse(request.body);
    response.status(200).json({
      data: await dependencies.vocabulary.recordEncounter(
        authenticatedUserId(request),
        input.word,
        input.source,
        input.context ?? null,
        new Date(),
        dependencies.voice.status().tts.available,
      ),
    });
  }));
  router.post('/vocabulary/:itemId/review', authenticate, asyncRoute(async (request, response) => {
    const { grade, mode } = reviewSchema.parse(request.body);
    const userId = authenticatedUserId(request);
    const data = await dependencies.vocabulary.recordReview(
      userId,
      paramString(request.params.itemId),
      grade as ReviewGrade,
      mode as RecallMode | undefined,
      new Date(),
      dependencies.voice.status().tts.available,
    );
    await dependencies.mastery.awardXp(userId, 'lexical', 15, 'Spaced repetition recall');
    response.status(200).json({ data });
  }));

  router.post('/speaking-sessions', authenticate, asyncRoute(async (request, response) => {
    const input = speakingStartSchema.parse(request.body);
    response.status(201).json({ data: await dependencies.speaking.start(authenticatedUserId(request), input) });
  }));
  router.put('/speaking-sessions/:id/transcript', authenticate, asyncRoute(async (request, response) => {
    const input = transcriptSchema.parse(request.body);
    response.status(200).json({ data: await dependencies.speaking.saveTranscript(authenticatedUserId(request), paramString(request.params.id), input.transcript) });
  }));
  router.post('/speaking-sessions/:id/analyze', authenticate, asyncRoute(async (request, response) => {
    const input = analyzeSchema.parse(request.body);
    const userId = authenticatedUserId(request);
    const data = await dependencies.speaking.analyze(userId, paramString(request.params.id), input);
    await dependencies.mastery.awardXp(userId, 'fluency', 20, 'Speaking practice session');
    response.status(200).json({ data });
  }));
  router.get('/speaking-sessions', authenticate, asyncRoute(async (request, response) => {
    const { limit, offset } = historyQuerySchema.parse(request.query);
    response.status(200).json({
      data: await dependencies.speaking.history(authenticatedUserId(request), limit, offset),
    });
  }));

  router.get('/coach/scenarios', authenticate, asyncRoute(async (_request, response) => {
    response.status(200).json({ data: dependencies.coach.scenarios() });
  }));
  router.post('/conversations', authenticate, asyncRoute(async (request, response) => {
    const input = conversationStartSchema.parse(request.body);
    response.status(201).json({ data: await dependencies.coach.start(authenticatedUserId(request), input.scenarioId) });
  }));
  router.post('/conversations/:id/turns', authenticate, asyncRoute(async (request, response) => {
    const input = turnSchema.parse(request.body);
    const userId = authenticatedUserId(request);
    const result = await dependencies.coach.addTurn(userId, paramString(request.params.id), input.transcript);
    await dependencies.vocabulary.scheduleEncounterWords(userId, input.transcript, 'coach', new Date());
    await dependencies.mastery.awardXp(userId, 'interaction', 25, 'AI conversational exchange');
    response.status(201).json({ data: result });
  }));
  router.post('/conversations/:id/finish', authenticate, asyncRoute(async (request, response) => {
    response.status(200).json({ data: await dependencies.coach.finish(authenticatedUserId(request), paramString(request.params.id)) });
  }));
  router.get('/conversations/:id', authenticate, asyncRoute(async (request, response) => {
    const { limit, offset } = historyQuerySchema.parse(request.query);
    response.status(200).json({
      data: await dependencies.coach.load(authenticatedUserId(request), paramString(request.params.id), limit, offset),
    });
  }));
  router.delete('/conversations/:id', authenticate, asyncRoute(async (request, response) => {
    await dependencies.coach.remove(authenticatedUserId(request), paramString(request.params.id));
    response.status(204).end();
  }));

  router.get('/ielts/mocks', authenticate, asyncRoute(async (_request, response) => {
    response.status(200).json({ data: dependencies.ielts.loadMocks() });
  }));
  router.get('/ielts/attempts', authenticate, asyncRoute(async (request, response) => {
    const { limit, offset } = historyQuerySchema.parse(request.query);
    response.status(200).json({
      data: await dependencies.ielts.history(authenticatedUserId(request), limit, offset),
    });
  }));
  router.post('/ielts/attempts', authenticate, asyncRoute(async (request, response) => {
    const input = ieltsStartSchema.parse(request.body);
    response.status(201).json({ data: await dependencies.ielts.startAttempt(authenticatedUserId(request), input.mockId) });
  }));
  router.post('/ielts/attempts/:id/responses', authenticate, asyncRoute(async (request, response) => {
    const input = ieltsResponseSchema.parse(request.body);
    response.status(201).json({ data: await dependencies.ielts.submitResponse(authenticatedUserId(request), paramString(request.params.id), input.sectionId, input.transcript) });
  }));
  router.post('/ielts/attempts/:id/finish', authenticate, asyncRoute(async (request, response) => {
    response.status(200).json({ data: await dependencies.ielts.finishAttempt(authenticatedUserId(request), paramString(request.params.id)) });
  }));

  router.get('/progress', authenticate, asyncRoute(async (request, response) => {
    response.status(200).json({ data: await dependencies.progress.summary(authenticatedUserId(request)) });
  }));
  router.get('/streak', authenticate, asyncRoute(async (request, response) => {
    response.status(200).json({ data: await dependencies.progress.streak(authenticatedUserId(request)) });
  }));
  router.put('/reminders', authenticate, asyncRoute(async (request, response) => {
    const input = reminderSchema.parse(request.body);
    response.status(200).json({ data: await dependencies.progress.updateReminder(authenticatedUserId(request), input.time, [...new Set(input.days)]) });
  }));

  router.get('/entitlements', authenticate, asyncRoute(async (request, response) => {
    response.status(200).json({ data: await dependencies.monetization.entitlements(authenticatedUserId(request)) });
  }));
  router.get('/placement/questions', authenticate, asyncRoute(async (_request, response) => {
    response.status(200).json({ data: await dependencies.placement.questions() });
  }));
  router.post('/placement/vocabulary', authenticate, asyncRoute(async (request, response) => {
    const input = placementAnswersSchema.parse(request.body);
    response.status(200).json({ data: await dependencies.placement.submitVocabulary(authenticatedUserId(request), input.answers) });
  }));
  router.post('/billing/verify', authenticate, asyncRoute(async (request, response) => {
    const input = billingReceiptSchema.parse(request.body);
    response.status(200).json({ data: await dependencies.monetization.verify(authenticatedUserId(request), input) });
  }));
  router.post('/billing/restore', authenticate, asyncRoute(async (request, response) => {
    const input = restoreSchema.parse(request.body);
    response.status(200).json({ data: await dependencies.monetization.restore(authenticatedUserId(request), input.receipts) });
  }));
  router.get('/referrals/me', authenticate, asyncRoute(async (request, response) => {
    response.status(200).json({ data: await dependencies.monetization.referral(authenticatedUserId(request)) });
  }));
  router.post('/referrals/redeem', authenticate, asyncRoute(async (request, response) => {
    const input = referralRedeemSchema.parse(request.body);
    response.status(200).json({ data: await dependencies.monetization.redeemReferral(authenticatedUserId(request), input.code) });
  }));

  router.get('/exposure', authenticate, asyncRoute(async (request, response) => {
    response.status(200).json({ data: await dependencies.exposure.summary(authenticatedUserId(request)) });
  }));
  router.post('/exposure/:level/complete', authenticate, asyncRoute(async (request, response) => {
    const level = z.coerce.number().int().min(1).max(7).parse(request.params.level);
    response.status(200).json({ data: await dependencies.exposure.record(authenticatedUserId(request), level) });
  }));

  router.get('/voice/providers', authenticate, asyncRoute(async (_request, response) => {
    response.status(200).json({ data: dependencies.voice.status() });
  }));
  router.post('/voice/tts', authenticate, asyncRoute(async (request, response) => {
    const input = ttsSchema.parse(request.body);
    const result = await dependencies.voice.synthesize(input.text, input);
    response
      .status(200)
      .type(result.contentType)
      .set('Cache-Control', result.cached ? 'private, max-age=86400' : 'private, max-age=3600')
      .set('X-Toungular-Voice', result.provider)
      .send(result.audio);
  }));
  router.post(
    '/voice/stt',
    authenticate,
    express.raw({ type: ['audio/*', 'application/octet-stream'], limit: '12mb' }),
    asyncRoute(async (request, response) => {
      const audio = request.body as unknown;
      if (!Buffer.isBuffer(audio) || audio.length === 0) {
        throw new AppError(400, 'AUDIO_REQUIRED', 'Send an audio recording to transcribe.');
      }
      const query = sttQuerySchema.parse(request.query);
      const contentType = query.contentType ?? request.header('content-type') ?? 'audio/mp4';
      response.status(200).json({
        data: await dependencies.voice.transcribe(audio, contentType, query.provider),
      });
    }),
  );

  router.get('/shadow/passages', authenticate, asyncRoute(async (_request, response) => {
    response.status(200).json({ data: dependencies.shadow.passages() });
  }));
  router.get('/shadow/passages/:id', authenticate, asyncRoute(async (request, response) => {
    response.status(200).json({ data: dependencies.shadow.passage(paramString(request.params.id)) });
  }));
  router.post('/shadow/analyze', authenticate, asyncRoute(async (request, response) => {
    const input = shadowAnalyzeSchema.parse(request.body);
    const userId = authenticatedUserId(request);
    const result = await dependencies.shadow.analyze(
      userId,
      input.passageId,
      input.durationSeconds,
      input.transcript,
      input.pauses ?? [],
    );
    await dependencies.vocabulary.scheduleEncounterWords(userId, input.transcript, 'shadow', new Date());
    await dependencies.mastery.awardXp(userId, 'acoustic', 20, 'Shadowing speech drill');
    response.status(200).json({ data: result });
  }));

  router.get('/content/articles', authenticate, asyncRoute(async (request, response) => {
    const level = typeof request.query.level === 'string' ? request.query.level : undefined;
    response.status(200).json({ data: dependencies.content.getArticles(level) });
  }));
  router.get('/content/articles/:id', authenticate, asyncRoute(async (request, response) => {
    response.status(200).json({ data: dependencies.content.getArticle(paramString(request.params.id)) });
  }));
  router.post('/content/articles/:id/evaluate', authenticate, asyncRoute(async (request, response) => {
    const input = contentEvaluateSchema.parse(request.body);
    const userId = authenticatedUserId(request);
    const result = await dependencies.content.evaluateOutput(userId, paramString(request.params.id), input.text);
    await dependencies.vocabulary.scheduleEncounterWords(userId, input.text, 'article_output', new Date());
    await dependencies.mastery.awardXp(userId, 'lexical', 20, 'Authentic content comprehension output');
    response.status(200).json({ data: result });
  }));

  router.post('/decision/affective-state', authenticate, asyncRoute(async (request, response) => {
    const input = affectiveStateSchema.parse(request.body);
    const result = await dependencies.decision.assessAffectiveState(input);
    response.status(200).json({ data: result });
  }));

  router.post('/decision/calibrate-level', authenticate, asyncRoute(async (request, response) => {
    const input = calibrateLevelSchema.parse(request.body);
    const result = await dependencies.decision.calibrateCefrLevel({
      transcript: input.transcript,
      targetWordsUsed: input.targetWords,
    });
    response.status(200).json({ data: result });
  }));

  router.get('/mastery/profile', authenticate, asyncRoute(async (request, response) => {
    const profile = await dependencies.mastery.getProfile(authenticatedUserId(request));
    response.status(200).json({ data: profile });
  }));

  router.post('/mastery/freeze-token', authenticate, asyncRoute(async (request, response) => {
    const profile = await dependencies.mastery.useFreezeToken(authenticatedUserId(request));
    response.status(200).json({ data: profile });
  }));

  router.get('/pronunciation/pairs', authenticate, asyncRoute(async (request, response) => {
    const category = typeof request.query.category === 'string' ? request.query.category : undefined;
    const level = typeof request.query.level === 'string' ? request.query.level : undefined;
    const pairs = dependencies.pronunciation.getPairs(category, level);
    response.status(200).json({ data: pairs });
  }));

  router.get('/pronunciation/pairs/:id', authenticate, asyncRoute(async (request, response) => {
    const pair = dependencies.pronunciation.getPair(paramString(request.params.id));
    response.status(200).json({ data: pair });
  }));

  router.post('/pronunciation/pairs/:id/analyze', authenticate, asyncRoute(async (request, response) => {
    const input = pronunciationAnalyzeSchema.parse(request.body);
    const userId = authenticatedUserId(request);
    const result = await dependencies.pronunciation.analyzeAttempt(
      userId,
      paramString(request.params.id),
      input.targetChoice,
      input.transcript,
      input.durationSeconds ?? 3,
    );
    response.status(200).json({ data: result });
  }));

  return router;
}
