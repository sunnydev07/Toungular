import type { AppEnv } from '../config/env.js';
import { AppError } from '../lib/http.js';

const PROVIDER_TIMEOUT_MS = 20_000;

export type VoiceConfig = {
  voiceId?: string | undefined;
  language?: string | undefined;
  speed?: number | undefined;
};

export type AudioResult = {
  audio: Buffer;
  contentType: string;
};

export interface TtsProvider {
  readonly id: string;
  synthesize(text: string, config: VoiceConfig): Promise<AudioResult>;
}

export interface SttProvider {
  readonly id: string;
  transcribe(audio: Buffer, contentType: string): Promise<{ text: string }>;
}

export class GoogleCloudTts implements TtsProvider {
  public readonly id = 'google';

  public constructor(private readonly apiKey: string) {}

  public async synthesize(text: string, config: VoiceConfig): Promise<AudioResult> {
    const response = await fetch(`https://texttospeech.googleapis.com/v1/text:synthesize?key=${encodeURIComponent(this.apiKey)}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        input: { text },
        voice: {
          languageCode: config.language ?? 'en-US',
          name: config.voiceId ?? 'en-US-Neural2-F',
        },
        audioConfig: { audioEncoding: 'MP3', speakingRate: speed(config.speed) },
      }),
      signal: AbortSignal.timeout(PROVIDER_TIMEOUT_MS),
    });
    await ensureOk(response, 'Google Cloud TTS');
    const payload = await response.json() as { audioContent?: string };
    if (!payload.audioContent) throw providerError('Google Cloud TTS');
    return { audio: Buffer.from(payload.audioContent, 'base64'), contentType: 'audio/mpeg' };
  }
}

export class ElevenLabsTts implements TtsProvider {
  public readonly id = 'elevenlabs';

  public constructor(
    private readonly apiKey: string,
    private readonly defaultVoiceId: string,
  ) {}

  public async synthesize(text: string, config: VoiceConfig): Promise<AudioResult> {
    const voiceId = config.voiceId ?? this.defaultVoiceId;
    const response = await fetch(
      `https://api.elevenlabs.io/v1/text-to-speech/${encodeURIComponent(voiceId)}?output_format=mp3_44100_128`,
      {
        method: 'POST',
        headers: {
          'xi-api-key': this.apiKey,
          'Content-Type': 'application/json',
          Accept: 'audio/mpeg',
        },
        body: JSON.stringify({
          text,
          model_id: 'eleven_multilingual_v2',
          voice_settings: { stability: 0.5, similarity_boost: 0.75 },
        }),
        signal: AbortSignal.timeout(PROVIDER_TIMEOUT_MS),
      },
    );
    await ensureOk(response, 'ElevenLabs');
    return { audio: Buffer.from(await response.arrayBuffer()), contentType: 'audio/mpeg' };
  }
}

export class OpenAiTts implements TtsProvider {
  public readonly id = 'openai';

  public constructor(private readonly apiKey: string) {}

  public async synthesize(text: string, config: VoiceConfig): Promise<AudioResult> {
    const response = await fetch('https://api.openai.com/v1/audio/speech', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${this.apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'tts-1',
        voice: config.voiceId ?? 'alloy',
        input: text,
        response_format: 'mp3',
        speed: speed(config.speed),
      }),
      signal: AbortSignal.timeout(PROVIDER_TIMEOUT_MS),
    });
    await ensureOk(response, 'OpenAI TTS');
    return { audio: Buffer.from(await response.arrayBuffer()), contentType: 'audio/mpeg' };
  }
}

export class WhisperStt implements SttProvider {
  public readonly id = 'whisper';

  public constructor(private readonly apiKey: string) {}

  public async transcribe(audio: Buffer, contentType: string): Promise<{ text: string }> {
    const form = new FormData();
    form.append('model', 'whisper-1');
    form.append('file', new Blob([new Uint8Array(audio)], { type: contentType }), fileNameFor(contentType));
    const response = await fetch('https://api.openai.com/v1/audio/transcriptions', {
      method: 'POST',
      headers: { Authorization: `Bearer ${this.apiKey}` },
      body: form,
      signal: AbortSignal.timeout(PROVIDER_TIMEOUT_MS),
    });
    await ensureOk(response, 'Whisper');
    const payload = await response.json() as { text?: string };
    return { text: payload.text?.trim() ?? '' };
  }
}

export class DeepgramStt implements SttProvider {
  public readonly id = 'deepgram';

  public constructor(private readonly apiKey: string) {}

  public async transcribe(audio: Buffer, contentType: string): Promise<{ text: string }> {
    const response = await fetch('https://api.deepgram.com/v1/listen?model=nova-2&smart_format=true&language=en', {
      method: 'POST',
      headers: {
        Authorization: `Token ${this.apiKey}`,
        'Content-Type': contentType,
      },
      body: new Uint8Array(audio),
      signal: AbortSignal.timeout(PROVIDER_TIMEOUT_MS),
    });
    await ensureOk(response, 'Deepgram');
    const payload = await response.json() as {
      results?: { channels?: Array<{ alternatives?: Array<{ transcript?: string }> }> };
    };
    const text = payload.results?.channels?.[0]?.alternatives?.[0]?.transcript?.trim() ?? '';
    return { text };
  }
}

export function createVoiceProviders(env: AppEnv): { tts: TtsProvider[]; stt: SttProvider[] } {
  const tts: TtsProvider[] = [];
  if (env.googleTtsApiKey) tts.push(new GoogleCloudTts(env.googleTtsApiKey));
  if (env.elevenLabsApiKey && env.elevenLabsVoiceId) {
    tts.push(new ElevenLabsTts(env.elevenLabsApiKey, env.elevenLabsVoiceId));
  }
  if (env.openAiApiKey) tts.push(new OpenAiTts(env.openAiApiKey));
  const stt: SttProvider[] = [];
  if (env.openAiApiKey) stt.push(new WhisperStt(env.openAiApiKey));
  if (env.deepgramApiKey) stt.push(new DeepgramStt(env.deepgramApiKey));
  return { tts, stt };
}

function speed(value: number | undefined): number {
  return Math.min(1.5, Math.max(0.7, value ?? 1));
}

function fileNameFor(contentType: string): string {
  if (contentType.includes('wav')) return 'answer.wav';
  if (contentType.includes('mpeg') || contentType.includes('mp3')) return 'answer.mp3';
  if (contentType.includes('ogg')) return 'answer.ogg';
  return 'answer.m4a';
}

async function ensureOk(response: Response, provider: string): Promise<void> {
  if (response.ok) return;
  if (response.status === 401 || response.status === 403) {
    throw new AppError(503, 'VOICE_PROVIDER_UNAVAILABLE', `${provider} credentials are not accepted.`);
  }
  throw providerError(provider);
}

function providerError(provider: string): AppError {
  return new AppError(502, 'VOICE_PROVIDER_ERROR', `${provider} could not process this request.`);
}
