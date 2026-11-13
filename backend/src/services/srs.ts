import type { RecallMode, ReviewGrade, VocabularyTier } from '../contracts.js';

const DAY_MS = 86_400_000;
const MIN_EASE = 1.3;
const MAX_EASE = 3.0;

// SM-2 quality values for the four Toungular grades.
const QUALITY: Record<ReviewGrade, number> = { again: 0, hard: 3, good: 4, easy: 5 };
// Harder recall modes earn a slightly larger ease bonus because retrieval was effortful.
const MODE_BONUS: Record<RecallMode, number> = { definition: 0.1, cloze: 0.05, audio: 0.08, sentence: 0.12 };

// FSRS-5 Grade Mapping: 1 = again, 2 = hard, 3 = good, 4 = easy
export const FSRS_GRADE_MAP: Record<ReviewGrade, number> = { again: 1, hard: 2, good: 3, easy: 4 };

// FSRS-5 Default Initial Stability S0(G)
const FSRS_S0: Record<number, number> = {
  1: 0.40,
  2: 1.18,
  3: 3.17,
  4: 15.69,
};

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}

export function computeInitialDifficulty(gradeNum: number): number {
  return clamp(7.19 - Math.exp(0.53 * (gradeNum - 1)) + 1, 1.0, 10.0);
}

export function computeRetrievability(elapsedDays: number, stability: number): number {
  if (stability <= 0) return 0;
  return Math.pow(1 + (19 / 81) * (Math.max(1, elapsedDays) / stability), -0.5);
}

export function computeNextDifficulty(currentDifficulty: number, gradeNum: number): number {
  const d0_3 = computeInitialDifficulty(3); // ~5.30
  const dRaw = currentDifficulty - 0.8 * (gradeNum - 3);
  const dReverted = 0.1 * d0_3 + 0.9 * dRaw;
  return clamp(Number(dReverted.toFixed(2)), 1.0, 10.0);
}

export type SrsState = {
  intervalDays: number;
  repetitions: number;
  easeFactor: number;
  stability?: number;
  difficulty?: number;
  lapses: number;
};

export type SrsNext = SrsState & {
  stability: number;
  difficulty: number;
  retrievability: number;
  dueAt: Date;
};

export function nextSchedule(
  state: SrsState,
  grade: ReviewGrade,
  options: {
    now: Date;
    mode?: RecallMode | undefined;
    contextual?: boolean | undefined;
    elapsedDays?: number | undefined;
  },
): SrsNext {
  const mode = options.mode ?? 'definition';
  const quality = QUALITY[grade];
  const G = FSRS_GRADE_MAP[grade];

  // Active recall mode multiplier
  let modeMultiplier = 1.0;
  if (mode === 'sentence') modeMultiplier = 1.12;
  else if (mode === 'audio') modeMultiplier = 1.08;
  if (options.contextual) modeMultiplier *= 1.05;

  // Track ease factor for SM-2 compatibility
  let easeFactor = state.easeFactor;
  if (grade === 'again') {
    easeFactor = Math.max(MIN_EASE, Number((state.easeFactor - 0.2).toFixed(2)));
  } else {
    easeFactor = state.easeFactor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
    easeFactor += MODE_BONUS[mode];
    if (options.contextual) easeFactor += 0.05;
    easeFactor = Math.min(MAX_EASE, Math.max(MIN_EASE, Number(easeFactor.toFixed(2))));
  }

  // FSRS-5 calculation
  let nextStability: number;
  let nextDifficulty: number;
  let retrievability: number;
  let intervalDays: number;
  const useFsrs = state.stability !== undefined;

  if (state.repetitions === 0 || (state.stability !== undefined && state.stability <= 0)) {
    // Initial review
    const baseS = FSRS_S0[G] ?? 3.17;
    nextStability = Number((baseS * modeMultiplier).toFixed(2));
    nextDifficulty = Number(computeInitialDifficulty(G).toFixed(2));
    retrievability = 1.0;

    if (grade === 'again') {
      intervalDays = 1;
    } else if (useFsrs) {
      intervalDays = Math.max(1, Math.min(365, Math.round(nextStability)));
    } else {
      intervalDays = grade === 'easy' ? 2 : 1;
    }
  } else {
    // Subsequent review
    const currentStability = (state.stability && state.stability > 0) ? state.stability : state.intervalDays || 3.0;
    const currentDifficulty = state.difficulty && state.difficulty > 0 ? state.difficulty : 5.0;
    const elapsedDays = Math.max(1, options.elapsedDays ?? state.intervalDays);
    retrievability = Number(computeRetrievability(elapsedDays, currentStability).toFixed(2));

    nextDifficulty = computeNextDifficulty(currentDifficulty, G);

    if (grade === 'again') {
      // Lapse stability
      const lapseS = Math.min(
        currentStability,
        Math.max(
          0.40,
          0.40 *
            Math.pow(currentDifficulty, -0.28) *
            (Math.pow(currentStability + 1, 0.44) - 1) *
            Math.exp((1 - retrievability) * 0.44),
        ),
      );
      nextStability = Number(lapseS.toFixed(2));
      intervalDays = 1;
    } else {
      // Recall stability
      const gradeBonus = G === 2 ? 0.29 : G === 4 ? 2.61 : 1.0;
      const recallS =
        currentStability *
        (1 +
          Math.exp(1.54) *
            (11 - currentDifficulty) *
            Math.pow(currentStability, -0.14) *
            (Math.exp((1 - retrievability) * 0.94) - 1) *
            gradeBonus) *
        modeMultiplier;
      nextStability = Number(recallS.toFixed(2));
      if (useFsrs) {
        intervalDays = Math.max(1, Math.min(365, Math.round(nextStability)));
      } else {
        // SM-2 interval fallback for pure legacy state
        if (state.repetitions === 1) {
          intervalDays = grade === 'hard' ? 2 : grade === 'easy' ? 5 : 3;
        } else if (grade === 'hard') {
          intervalDays = Math.max(2, Math.round(state.intervalDays * 1.2));
        } else if (grade === 'good') {
          intervalDays = Math.max(3, Math.round(state.intervalDays * easeFactor));
        } else {
          intervalDays = Math.max(4, Math.round(state.intervalDays * easeFactor * 1.3));
        }
        intervalDays = Math.min(365, intervalDays);
      }
    }
  }

  if (grade === 'again') {
    return {
      intervalDays: 1,
      repetitions: 0,
      easeFactor,
      stability: nextStability,
      difficulty: nextDifficulty,
      retrievability,
      lapses: state.lapses + 1,
      dueAt: addDays(options.now, 1),
    };
  }

  return {
    intervalDays,
    repetitions: state.repetitions + 1,
    easeFactor,
    stability: nextStability,
    difficulty: nextDifficulty,
    retrievability,
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
