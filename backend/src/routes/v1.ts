import { Router } from 'express';
import { z } from 'zod';

import type { AppEnv } from '../config/env.js';
import type { LoginInput, ProfilePatch, RegisterInput, ReviewGrade } from '../contracts.js';
import { asyncRoute } from '../lib/http.js';
import { authenticatedUserId, requireAuth } from '../middleware/auth.js';
import { AuthService } from '../services/auth-service.js';
import { CoachService } from '../services/coach-service.js';
import { CurriculumService } from '../services/curriculum-service.js';
import { IeltsService } from '../services/ielts-service.js';
import { MonetizationService } from '../services/monetization-service.js';
import { ProfileService } from '../services/profile-service.js';
import { PlacementService } from '../services/placement-service.js';
import { ProgressService } from '../services/progress-service.js';
import { SpeakingService } from '../services/speaking-service.js';
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
const reviewSchema = z.object({ grade: z.enum(['again', 'hard', 'good', 'easy']) });
const speakingStartSchema = z.object({
  type: z.enum(['prompt', 'ielts', 'baseline']).default('prompt'),
  prompt: z.string().trim().min(1).max(1000),
});
const transcriptSchema = z.object({ transcript: z.string().trim().min(1).max(12_000) });
const analyzeSchema = z.object({ durationSeconds: z.number().int().min(1).max(600) });
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
    response.status(200).json({ data: await dependencies.curriculum.completeLesson(authenticatedUserId(request), paramString(request.params.lessonId)) });
  }));

  router.get('/vocabulary/due', authenticate, asyncRoute(async (request, response) => {
    response.status(200).json({ data: await dependencies.vocabulary.getDue(authenticatedUserId(request), new Date()) });
  }));
  router.post('/vocabulary/:itemId/review', authenticate, asyncRoute(async (request, response) => {
    const { grade } = reviewSchema.parse(request.body);
    response.status(200).json({
      data: await dependencies.vocabulary.recordReview(
        authenticatedUserId(request),
        paramString(request.params.itemId),
        grade as ReviewGrade,
        new Date(),
      ),
    });
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
    response.status(200).json({ data: await dependencies.speaking.analyze(authenticatedUserId(request), paramString(request.params.id), input.durationSeconds) });
  }));
  router.get('/speaking-sessions', authenticate, asyncRoute(async (request, response) => {
    response.status(200).json({ data: await dependencies.speaking.history(authenticatedUserId(request)) });
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
    response.status(201).json({ data: await dependencies.coach.addTurn(authenticatedUserId(request), paramString(request.params.id), input.transcript) });
  }));
  router.post('/conversations/:id/finish', authenticate, asyncRoute(async (request, response) => {
    response.status(200).json({ data: await dependencies.coach.finish(authenticatedUserId(request), paramString(request.params.id)) });
  }));
  router.get('/conversations/:id', authenticate, asyncRoute(async (request, response) => {
    response.status(200).json({ data: await dependencies.coach.load(authenticatedUserId(request), paramString(request.params.id)) });
  }));
  router.delete('/conversations/:id', authenticate, asyncRoute(async (request, response) => {
    await dependencies.coach.remove(authenticatedUserId(request), paramString(request.params.id));
    response.status(204).end();
  }));

  router.get('/ielts/mocks', authenticate, asyncRoute(async (_request, response) => {
    response.status(200).json({ data: dependencies.ielts.loadMocks() });
  }));
  router.get('/ielts/attempts', authenticate, asyncRoute(async (request, response) => {
    response.status(200).json({ data: await dependencies.ielts.history(authenticatedUserId(request)) });
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

  return router;
}
