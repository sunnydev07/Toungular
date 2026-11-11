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
  GOOGLE_TTS_API_KEY: z.string().min(8).optional(),
  GOOGLE_API_KEY: z.string().min(8).optional(),
  GEMINI_API_KEY: z.string().min(8).optional(),
  GEMINI_MODEL: z.string().min(1).default('gemini-3.5-flash-lite'),
  ELEVENLABS_API_KEY: z.string().min(8).optional(),
  ELEVENLABS_VOICE_ID: z.string().min(1).optional(),
  OPENAI_API_KEY: z.string().min(8).optional(),
  DEEPGRAM_API_KEY: z.string().min(8).optional(),
  OPENCODE_ZEN_API_KEY: z.string().min(8).optional(),
  OPENCODE_ZEN_BASE_URL: z.string().url().default('https://api.opencode.ai/v1'),
  VOICE_CACHE_DIR: z.string().min(1).default('storage/audio-cache'),
});

export type AppEnv = {
  port: number;
  databaseUrl: string;
  jwtSecret: string;
  mobileOrigin: string;
  googleTtsApiKey: string | undefined;
  googleApiKey: string | undefined;
  geminiModel: string;
  elevenLabsApiKey: string | undefined;
  elevenLabsVoiceId: string | undefined;
  openAiApiKey: string | undefined;
  deepgramApiKey: string | undefined;
  opencodeZenApiKey: string | undefined;
  opencodeZenBaseUrl: string;
  voiceCacheDir: string;
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
    googleTtsApiKey: parsed.data.GOOGLE_TTS_API_KEY,
    googleApiKey: parsed.data.GOOGLE_API_KEY ?? parsed.data.GEMINI_API_KEY,
    geminiModel: parsed.data.GEMINI_MODEL,
    elevenLabsApiKey: parsed.data.ELEVENLABS_API_KEY,
    elevenLabsVoiceId: parsed.data.ELEVENLABS_VOICE_ID,
    openAiApiKey: parsed.data.OPENAI_API_KEY,
    deepgramApiKey: parsed.data.DEEPGRAM_API_KEY,
    opencodeZenApiKey: parsed.data.OPENCODE_ZEN_API_KEY,
    opencodeZenBaseUrl: parsed.data.OPENCODE_ZEN_BASE_URL,
    voiceCacheDir: parsed.data.VOICE_CACHE_DIR,
  };
}
