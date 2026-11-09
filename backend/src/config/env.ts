import { z } from 'zod';

const DEFAULT_DATABASE_URL = 'file:../storage/toungular.db';
const DEFAULT_MOBILE_ORIGIN = 'http://localhost:3000';

const environmentSchema = z.object({
  PORT: z.coerce.number().int().min(1).max(65_535).default(3000),
  DATABASE_URL: z
    .string()
    .min(1)
    .default(DEFAULT_DATABASE_URL)
    .refine(
      (value) => value.startsWith('file:') || value.startsWith('postgres://') || value.startsWith('postgresql://'),
      'DATABASE_URL must be a SQLite file URL or PostgreSQL connection URL',
    ),
  JWT_SECRET: z.string().min(32, 'JWT_SECRET must be at least 32 characters'),
  MOBILE_ORIGIN: z.string().url().default(DEFAULT_MOBILE_ORIGIN),
});

export type AppEnv = {
  port: number;
  databaseUrl: string;
  jwtSecret: string;
  mobileOrigin: string;
};

export function loadEnv(source: NodeJS.ProcessEnv = process.env): AppEnv {
  const parsed = environmentSchema.safeParse(source);

  if (!parsed.success) {
    const details = parsed.error.issues.map((issue) => `${issue.path.join('.')}: ${issue.message}`).join('; ');
    throw new Error(`Invalid Toungular API environment: ${details}`);
  }

  const { PORT, DATABASE_URL, JWT_SECRET, MOBILE_ORIGIN } = parsed.data;
  return {
    port: PORT,
    databaseUrl: DATABASE_URL,
    jwtSecret: JWT_SECRET,
    mobileOrigin: MOBILE_ORIGIN,
  };
}
