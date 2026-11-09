import { PrismaClient } from '@prisma/client';

const globalForPrisma = globalThis as typeof globalThis & { toungularPrisma?: PrismaClient };

export const prisma = globalForPrisma.toungularPrisma ?? new PrismaClient();

if (process.env.NODE_ENV !== 'production') {
  globalForPrisma.toungularPrisma = prisma;
}
