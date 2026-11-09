import { Router } from 'express';
import { z } from 'zod';

import type { AppEnv } from '../config/env.js';
import type { LoginInput, ProfilePatch, RegisterInput, ReviewGrade } from '../contracts.js';
import { asyncRoute } from '../lib/http.js';
import { authenticatedUserId, requireAuth } from '../middleware/auth.js';
import { AuthService } from '../services/auth-service.js';
import { CurriculumService } from '../services/curriculum-service.js';
import { ProfileService } from '../services/profile-service.js';
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

type V1Dependencies = {
  env: AppEnv;
  auth: AuthService;
  profiles: ProfileService;
  curriculum: CurriculumService;
  vocabulary: VocabularyService;
};

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

  router.get('/roadmap', authenticate, asyncRoute(async (request, response) => {
    response.status(200).json({ data: await dependencies.curriculum.getRoadmap(authenticatedUserId(request)) });
  }));
  router.get('/courses', authenticate, asyncRoute(async (request, response) => {
    const roadmap = await dependencies.curriculum.getRoadmap(authenticatedUserId(request));
    response.status(200).json({ data: roadmap.courses });
  }));
  router.get('/lessons/:lessonId', authenticate, asyncRoute(async (request, response) => {
    response.status(200).json({ data: await dependencies.curriculum.getLesson(authenticatedUserId(request), request.params.lessonId) });
  }));
  router.post('/lessons/:lessonId/complete', authenticate, asyncRoute(async (request, response) => {
    response.status(200).json({ data: await dependencies.curriculum.completeLesson(authenticatedUserId(request), request.params.lessonId) });
  }));

  router.get('/vocabulary/due', authenticate, asyncRoute(async (request, response) => {
    response.status(200).json({ data: await dependencies.vocabulary.getDue(authenticatedUserId(request), new Date()) });
  }));
  router.post('/vocabulary/:itemId/review', authenticate, asyncRoute(async (request, response) => {
    const { grade } = reviewSchema.parse(request.body);
    response.status(200).json({
      data: await dependencies.vocabulary.recordReview(
        authenticatedUserId(request),
        request.params.itemId,
        grade as ReviewGrade,
        new Date(),
      ),
    });
  }));

  return router;
}
