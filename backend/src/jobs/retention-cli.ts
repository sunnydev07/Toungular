import { runRetention } from './retention.js';
import { logger } from '../lib/logger.js';
import { prisma } from '../lib/prisma.js';

const report = await runRetention(prisma);
logger.info(report, 'retention sweep completed');
await prisma.$disconnect();
