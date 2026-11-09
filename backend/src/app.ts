import express, { type Express, type RequestHandler } from 'express';

import { loadEnv, type AppEnv } from './config/env.js';
import { jsonErrorHandler } from './lib/http.js';
import { prisma } from './lib/prisma.js';
import { createV1Router } from './routes/v1.js';
import { AuthService } from './services/auth-service.js';
import { CoachService } from './services/coach-service.js';
import { CurriculumService } from './services/curriculum-service.js';
import { IeltsService } from './services/ielts-service.js';
import { MonetizationService } from './services/monetization-service.js';
import { ProfileService } from './services/profile-service.js';
import { PlacementService } from './services/placement-service.js';
import { ProgressService } from './services/progress-service.js';
import { SpeakingService } from './services/speaking-service.js';
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

export function createApp(env: AppEnv = loadEnv()): Express {
  const app = express();
  const profiles = new ProfileService(prisma);

  app.disable('x-powered-by');
  app.use(corsForMobile(env.mobileOrigin));
  app.use(express.json({ limit: '1mb' }));
  app.get('/health', (_request, response) => {
    response.status(200).json({ service: 'toungular-api', status: 'ok' });
  });
  app.use('/v1', createV1Router({
    env,
    auth: new AuthService(prisma, env),
    coach: new CoachService(prisma),
    profiles,
    placement: new PlacementService(prisma),
    progress: new ProgressService(prisma),
    curriculum: new CurriculumService(prisma),
    ielts: new IeltsService(prisma),
    monetization: new MonetizationService(prisma),
    speaking: new SpeakingService(prisma),
    vocabulary: new VocabularyService(prisma),
  }));
  app.use((_request, response) => {
    response.status(404).json({ error: { code: 'NOT_FOUND', message: 'The requested resource was not found.' } });
  });
  app.use(jsonErrorHandler);

  return app;
}
