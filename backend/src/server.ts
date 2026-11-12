import { createApp } from './app.js';
import { loadEnv } from './config/env.js';
import { startRetentionLoop } from './jobs/retention.js';
import { logger } from './lib/logger.js';
import { prisma } from './lib/prisma.js';

const env = loadEnv();
const app = createApp(env);

const server = app.listen(env.port, () => {
  logger.info({ port: env.port }, 'Toungular API listening');
});

const stopRetention = startRetentionLoop(prisma);

let shuttingDown = false;

async function shutdown(signal: NodeJS.Signals): Promise<void> {
  if (shuttingDown) return;
  shuttingDown = true;
  logger.info({ signal }, 'shutting down');

  const forcedExit = setTimeout(() => {
    logger.error('graceful shutdown timed out; exiting');
    process.exit(1);
  }, 10_000);
  forcedExit.unref();

  stopRetention();
  await new Promise<void>((resolve) => {
    server.close(() => resolve());
  });
  try {
    await prisma.$disconnect();
  } catch (error) {
    logger.error({ err: error }, 'failed to disconnect prisma');
  }
  clearTimeout(forcedExit);
  process.exit(0);
}

process.on('SIGTERM', (signal) => {
  void shutdown(signal);
});
process.on('SIGINT', (signal) => {
  void shutdown(signal);
});
