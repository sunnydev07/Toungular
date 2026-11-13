import type { RecallMode, ReviewGrade, VocabularyTier } from '../contracts.js';

const DAY_MS = 86_400_000;
const MIN_EASE = 1.3;
const MAX_EASE = 3.0;

// SM-2 quality values for the four Toungular grades.
const QUALITY: Record<ReviewGrade, number> = { again: 0, hard: 3, good: 4, easy: 5 };
// Harder recall modes earn a slightly larger ease bonus because retrieval was effortful.
const MODE_BONUS: Record<RecallMode, number> = { definition: 0.1, cloze: 0.05, audio: 0.08, sentence: 0.12 };

export type SrsState = {
  intervalDays: number;
  repetitions: number;
  easeFactor: number;
  lapses: number;
};

export type SrsNext = SrsState & {
  dueAt: Date;
};

export function nextSchedule(
  state: SrsState,
  grade: ReviewGrade,
  options: { now: Date; mode?: RecallMode | undefined; contextual?: boolean | undefined },
): SrsNext {
  const mode = options.mode ?? 'definition';
  const quality = QUALITY[grade];

  // A lapse is one penalty, not the SM-2 polynomial plus another hit: applying
  // both dropped ease by ~1.0 per "again" and made recovery take weeks.
  if (grade === 'again') {
    return {
      intervalDays: 1,
      repetitions: 0,
      easeFactor: Math.max(MIN_EASE, Number((state.easeFactor - 0.2).toFixed(2))),
      lapses: state.lapses + 1,
      dueAt: addDays(options.now, 1),
    };
  }

  let easeFactor = state.easeFactor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
  easeFactor += MODE_BONUS[mode];
  if (options.contextual) easeFactor += 0.05;
  easeFactor = Math.min(MAX_EASE, Math.max(MIN_EASE, Number(easeFactor.toFixed(2))));

  let intervalDays: number;
  if (state.repetitions === 0) {
    intervalDays = grade === 'easy' ? 2 : 1;
  } else if (state.repetitions === 1) {
    intervalDays = grade === 'hard' ? 2 : grade === 'easy' ? 5 : 3;
  } else if (grade === 'hard') {
    intervalDays = Math.max(2, Math.round(state.intervalDays * 1.2));
  } else if (grade === 'good') {
    intervalDays = Math.max(3, Math.round(state.intervalDays * easeFactor));
  } else {
    intervalDays = Math.max(4, Math.round(state.intervalDays * easeFactor * 1.3));
  }
  intervalDays = Math.min(365, intervalDays);

  return {
    intervalDays,
    repetitions: state.repetitions + 1,
    easeFactor,
    lapses: state.lapses,
    dueAt: addDays(options.now, intervalDays),
  };
}

export function recallModeFor(repetitions: number, ttsAvailable: boolean): RecallMode {
  const cycle: RecallMode[] = ttsAvailable
    ? ['definition', 'cloze', 'audio', 'sentence']
    : ['definition', 'cloze', 'sentence'];
  return cycle[repetitions % cycle.length] ?? 'definition';
}

export function buildCloze(example: string, word: string): string | null {
  const target = word.toLowerCase();
  const stem = target.length > 4 ? target.slice(0, -1) : target;
  const bareStem = stem.endsWith('e') ? stem.slice(0, -1) : stem;
  let replaced = false;
  const cloze = example
    .split(/(\s+)/)
    .map((part) => {
      if (replaced) return part;
      const token = part.toLowerCase().replace(/[^a-z'-]/g, '');
      if (token.length === 0) return part;
      const matches = token === target || token.startsWith(stem) || token.startsWith(bareStem);
      if (!matches) return part;
      replaced = true;
      return part.replace(/[A-Za-z'-]+/, '____');
    })
    .join('');
  return replaced ? cloze : null;
}

export function tierOrder(tier: VocabularyTier): number {
  // Tier 2 academic vocabulary is prioritized; Tier 3 specialist words come last.
  return tier === 2 ? 0 : tier === 1 ? 1 : 2;
}

function addDays(now: Date, days: number): Date {
  return new Date(now.getTime() + days * DAY_MS);
}
