import { randomUUID } from 'node:crypto';

import express, { type Express, type RequestHandler } from 'express';
import { rateLimit } from 'express-rate-limit';
import helmet from 'helmet';

import { loadEnv, type AppEnv } from './config/env.js';
import { asyncRoute, jsonErrorHandler } from './lib/http.js';
import { logger, requestLogger } from './lib/logger.js';
import { prisma } from './lib/prisma.js';
import { QuotaService } from './lib/quotas.js';
import { JevClient } from './providers/jev-client.js';
import { createVoiceProviders } from './providers/voice.js';
import { createV1Router } from './routes/v1.js';
import { AuthService } from './services/auth-service.js';
import { CoachService } from './services/coach-service.js';
import { IdempotencyService } from './services/idempotency-service.js';
import { ContentService } from './services/content-service.js';
import { CurriculumService } from './services/curriculum-service.js';
import { DecisionService } from './services/decision-service.js';
import { ExposureService } from './services/exposure-service.js';
import { IeltsService } from './services/ielts-service.js';
import { MasteryService } from './services/mastery-service.js';
import { MonetizationService } from './services/monetization-service.js';
import { ProfileService } from './services/profile-service.js';
import { PlacementService } from './services/placement-service.js';
import { ProgressService } from './services/progress-service.js';
import { PronunciationService } from './services/pronunciation-service.js';
import { ShadowService } from './services/shadow-service.js';
import { SpeakingService } from './services/speaking-service.js';
import { VoiceService } from './services/voice-service.js';
import { VocabularyService } from './services/vocabulary-service.js';

function corsForMobile(origin: string): RequestHandler {
  return (request, response, next) => {
    const requestOrigin = request.header('origin');
    if (!requestOrigin || requestOrigin === origin) {
      response.header('Access-Control-Allow-Origin', origin);
      response.header('Vary', 'Origin');
      response.header('Access-Control-Allow-Headers', 'Authorization, Content-Type');
      response.header('Access-Control-Allow-Methods', 'DELETE, GET, POST, PUT, PATCH, OPTIONS');
      if (request.method === 'OPTIONS') {
        response.sendStatus(204);
        return;
      }
      next();
      return;
    }
    response.status(403).json({ error: { code: 'ORIGIN_NOT_ALLOWED', message: 'This origin is not allowed.' } });
  };
}

function requestId(): RequestHandler {
  return (request, response, next) => {
    const incoming = request.header('x-request-id');
    const id = incoming && /^[\w.-]{1,64}$/.test(incoming) ? incoming : randomUUID();
    response.locals.requestId = id;
    response.setHeader('X-Request-Id', id);
    next();
  };
}

function authLimiter(limit: number, windowMs: number): RequestHandler {
  return rateLimit({
    windowMs,
    limit,
    standardHeaders: 'draft-7',
    legacyHeaders: false,
    // The API may run behind a proxy we do not control; keying on the socket
    // address avoids trusting arbitrary X-Forwarded-For values.
    validate: { xForwardedForHeader: false },
    handler: (_request, response) => {
      response.status(429).json({
        error: { code: 'RATE_LIMITED', message: 'Too many attempts. Please wait and try again.' },
      });
    },
  });
}

export function createApp(env: AppEnv = loadEnv()): Express {
  const app = express();
  const profiles = new ProfileService(prisma);
  const jev = new JevClient(env.opencodeZenApiKey, env.opencodeZenBaseUrl);
  const decision = new DecisionService(jev);
  const mastery = new MasteryService(prisma);
  const voiceProviders = createVoiceProviders(env);
  const pronunciation = new PronunciationService(prisma, decision, mastery, voiceProviders.assessor);
  const quotas = new QuotaService({
    aiDaily: env.aiDailyQuota,
    voiceDaily: env.voiceDailyQuota,
    failureAlertRate: env.providerFailureAlertRate,
    failureWindowMs: env.providerAlertWindowMs,
    failureAlertMinimumCalls: env.providerAlertMinimumCalls,
  });

  app.disable('x-powered-by');
  app.use(requestId());
  app.use(requestLogger());
  app.use(helmet());
  app.use(corsForMobile(env.mobileOrigin));

  const credentialLimiter = authLimiter(10, 15 * 60 * 1000);
  const refreshLimiter = authLimiter(120, 15 * 60 * 1000);
  app.use('/v1/auth/login', credentialLimiter);
  app.use('/v1/auth/register', credentialLimiter);
  app.use('/v1/auth/refresh', refreshLimiter);

  app.use(express.json({ limit: '1mb' }));
  app.get('/health', (_request, response) => {
    response.status(200).json({ service: 'toungular-api', status: 'ok' });
  });
  app.get('/health/ready', asyncRoute(async (_request, response) => {
    try {
      await prisma.$queryRaw`SELECT 1`;
      response.status(200).json({
        service: 'toungular-api',
        status: 'ready',
        checks: { database: 'ok' },
      });
    } catch (error) {
      logger.error({ err: error }, 'readiness probe failed');
      response.status(503).json({
        service: 'toungular-api',
        status: 'degraded',
        checks: { database: 'unavailable' },
      });
    }
  }));
  app.use('/v1', createV1Router({
    env,
    auth: new AuthService(prisma, env),
    coach: new CoachService(prisma, env, decision),
    profiles,
    placement: new PlacementService(prisma),
    progress: new ProgressService(prisma),
    curriculum: new CurriculumService(prisma),
    ielts: new IeltsService(prisma, env, decision),
    monetization: new MonetizationService(prisma),
    speaking: new SpeakingService(prisma, decision),
    vocabulary: new VocabularyService(prisma),
    exposure: new ExposureService(prisma),
    voice: new VoiceService(env),
    shadow: new ShadowService(prisma),
    content: new ContentService(prisma, env),
    decision,
    mastery,
    pronunciation,
    quotas,
    idempotency: new IdempotencyService(prisma),
  }));
  app.use((_request, response) => {
    response.status(404).json({ error: { code: 'NOT_FOUND', message: 'The requested resource was not found.' } });
  });
  app.use(jsonErrorHandler);

  return app;
}
