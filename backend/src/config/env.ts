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
  GEMINI_MODEL: z.string().min(1).default('gemini-2.5-flash-lite'),
  ELEVENLABS_API_KEY: z.string().min(8).optional(),
  ELEVENLABS_VOICE_ID: z.string().min(1).optional(),
  OPENAI_API_KEY: z.string().min(8).optional(),
  DEEPGRAM_API_KEY: z.string().min(8).optional(),
  OPENCODE_ZEN_API_KEY: z.string().min(8).optional(),
  OPENCODE_ZEN_BASE_URL: z.string().url().default('https://api.opencode.ai/v1'),
  AZURE_SPEECH_KEY: z.string().min(8).optional(),
  AZURE_SPEECH_REGION: z.string().min(2).default('centralindia'),
  VOICE_CACHE_DIR: z.string().min(1).default('storage/audio-cache'),
  AI_DAILY_QUOTA: z.coerce.number().int().min(1).max(100_000).default(200),
  VOICE_DAILY_QUOTA: z.coerce.number().int().min(1).max(100_000).default(500),
  PROVIDER_FAILURE_ALERT_RATE: z.coerce.number().min(0).max(1).default(0.25),
  PROVIDER_ALERT_WINDOW_MS: z.coerce.number().int().min(1_000).max(86_400_000).default(300_000),
  PROVIDER_ALERT_MIN_CALLS: z.coerce.number().int().min(1).max(10_000).default(20),
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
  azureSpeechKey: string | undefined;
  azureSpeechRegion: string;
  voiceCacheDir: string;
  aiDailyQuota: number;
  voiceDailyQuota: number;
  providerFailureAlertRate: number;
  providerAlertWindowMs: number;
  providerAlertMinimumCalls: number;
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
    azureSpeechKey: parsed.data.AZURE_SPEECH_KEY,
    azureSpeechRegion: parsed.data.AZURE_SPEECH_REGION,
    voiceCacheDir: parsed.data.VOICE_CACHE_DIR,
    aiDailyQuota: parsed.data.AI_DAILY_QUOTA,
    voiceDailyQuota: parsed.data.VOICE_DAILY_QUOTA,
    providerFailureAlertRate: parsed.data.PROVIDER_FAILURE_ALERT_RATE,
    providerAlertWindowMs: parsed.data.PROVIDER_ALERT_WINDOW_MS,
    providerAlertMinimumCalls: parsed.data.PROVIDER_ALERT_MIN_CALLS,
  };
}
