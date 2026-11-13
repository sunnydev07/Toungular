import { createHash } from 'node:crypto';
import { mkdir, readdir, readFile, stat, unlink, writeFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';

import type { AppEnv } from '../config/env.js';
import { AppError } from '../lib/http.js';
import {
  createVoiceProviders,
  type SttProvider,
  type TtsProvider,
  type VoiceConfig,
} from '../providers/voice.js';

export type VoiceRequest = VoiceConfig & { provider?: string | undefined };

const CACHE_MAX_FILES = 500;
const CACHE_MAX_AGE_MS = 30 * 24 * 60 * 60 * 1000;

export class VoiceService {
  private readonly ttsProviders: Map<string, TtsProvider>;
  private readonly sttProviders: Map<string, SttProvider>;

  public constructor(private readonly env: AppEnv) {
    const providers = createVoiceProviders(env);
    this.ttsProviders = new Map(providers.tts.map((provider) => [provider.id, provider]));
    this.sttProviders = new Map(providers.stt.map((provider) => [provider.id, provider]));
  }

  public status() {
    return {
      tts: {
        available: this.ttsProviders.size > 0,
        providers: [...this.ttsProviders.keys()],
      },
      stt: {
        available: this.sttProviders.size > 0,
        providers: [...this.sttProviders.keys()],
      },
    };
  }

  public async synthesize(text: string, request: VoiceRequest) {
    const provider = this.pick(this.ttsProviders, request.provider, 'text-to-speech');
    const config = this.config(request);
    const cacheKey = createHash('sha256')
      .update(`${provider.id}|${text}|${config.voiceId ?? ''}|${config.language ?? ''}|${config.speed ?? 1}`)
      .digest('hex');
    const cachePath = join(this.env.voiceCacheDir, `${cacheKey}.mp3`);

    try {
      return {
        audio: await readFile(cachePath),
        contentType: 'audio/mpeg',
        provider: provider.id,
        cached: true,
      };
    } catch (error) {
      if (!isNotFound(error)) throw error;
    }

    const result = await provider.synthesize(text, config);
    await mkdir(dirname(cachePath), { recursive: true });
    await writeFile(cachePath, result.audio);
    // Keep the shared cache from growing without bound; the request does not
    // wait for housekeeping.
    void this.pruneCache().catch(() => undefined);
    return { ...result, provider: provider.id, cached: false };
  }

  private async pruneCache(): Promise<void> {
    const directory = this.env.voiceCacheDir;
    let names: string[];
    try {
      names = (await readdir(directory)).filter((name) => name.endsWith('.mp3'));
    } catch {
      return;
    }
    if (names.length === 0) return;

    const now = Date.now();
    const entries: Array<{ path: string; modified: number }> = [];
    for (const name of names) {
      const path = join(directory, name);
      try {
        const info = await stat(path);
        if (now - info.mtimeMs > CACHE_MAX_AGE_MS) {
          await unlink(path);
          continue;
        }
        entries.push({ path, modified: info.mtimeMs });
      } catch {
        // A file may disappear between readdir and stat; ignore it.
      }
    }

    if (entries.length <= CACHE_MAX_FILES) return;
    entries.sort((left, right) => left.modified - right.modified);
    for (const entry of entries.slice(0, entries.length - CACHE_MAX_FILES)) {
      try {
        await unlink(entry.path);
      } catch {
        // Best-effort eviction.
      }
    }
  }

  public async transcribe(audio: Buffer, contentType: string, providerName?: string) {
    const provider = this.pick(this.sttProviders, providerName, 'speech-to-text');
    const result = await provider.transcribe(audio, contentType);
    if (!result.text) {
      throw new AppError(422, 'TRANSCRIPTION_EMPTY', 'No speech was recognized in this recording. Try again in a quieter place.');
    }
    return { text: result.text, words: result.words, provider: provider.id };
  }

  private config(request: VoiceRequest): VoiceConfig {
    const config: VoiceConfig = {};
    if (request.voiceId) config.voiceId = request.voiceId;
    if (request.language) config.language = request.language;
    if (request.speed !== undefined) config.speed = request.speed;
    return config;
  }

  private pick<T extends { id: string }>(providers: Map<string, T>, name: string | undefined, kind: string): T {
    if (name) {
      const configured = providers.get(name);
      if (configured) return configured;
      throw new AppError(503, 'VOICE_PROVIDER_UNAVAILABLE', `The requested ${kind} provider is not configured.`);
    }
    const first = providers.values().next().value as T | undefined;
    if (!first) {
      throw new AppError(503, 'VOICE_PROVIDER_UNAVAILABLE', `${kind === 'text-to-speech' ? 'Text-to-speech' : 'Speech recognition'} is not configured yet.`);
    }
    return first;
  }
}

function isNotFound(error: unknown): boolean {
  return typeof error === 'object'
    && error !== null
    && 'code' in error
    && (error as { code?: string }).code === 'ENOENT';
}
