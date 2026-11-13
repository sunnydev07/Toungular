export type FillerCategory = 'hesitation' | 'discourse';

export type FillerUse = {
  word: string;
  count: number;
  category: FillerCategory;
};

export type WordTiming = {
  word: string;
  start: number;
  end: number;
  confidence?: number | undefined;
};

export type PauseClassification = {
  midClausePauses: number;
  boundaryPauses: number;
};

export type TranscriptAnalysis = {
  wordCount: number;
  uniqueWordCount: number;
  wordsPerMinute: number;
  articulationRate: number;
  vocabularyVariety: number;
  fillerCount: number;
  fillers: FillerUse[];
  pauseCount: number;
  longPauseCount: number;
  pauseSeconds: number;
  pauseRatio: number;
  pauseNote: string;
  nextStep: string;
  pauseClassification?: PauseClassification;
};

const FILLERS: Array<{ word: string; category: FillerCategory }> = [
  { word: 'um', category: 'hesitation' },
  { word: 'uh', category: 'hesitation' },
  { word: 'erm', category: 'hesitation' },
  { word: 'you know', category: 'discourse' },
  { word: 'like', category: 'discourse' },
  { word: 'basically', category: 'discourse' },
  { word: 'actually', category: 'discourse' },
];

const LONG_PAUSE_SECONDS = 2;

export function analyzeTranscript(
  transcript: string,
  durationSeconds: number,
  pauses: number[] = [],
  wordTimings: WordTiming[] = [],
): TranscriptAnalysis {
  const words = transcript.match(/[A-Za-z]+(?:['’-][A-Za-z]+)*/g) ?? [];
  const normalized = words.map((word) => word.toLowerCase());
  const duration = Math.max(1, durationSeconds);
  const uniqueWordCount = new Set(normalized).size;
  const fillers = FILLERS.map((filler) => ({
    ...filler,
    count: countPhrase(transcript, filler.word),
  })).filter((filler) => filler.count > 0);
  const fillerCount = fillers.reduce((total, filler) => total + filler.count, 0);

  const validPauses = pauses.filter((pause) => Number.isFinite(pause) && pause > 0).slice(0, 100);
  const pauseSeconds = Number(validPauses.reduce((total, pause) => total + pause, 0).toFixed(1));
  const longPauseCount = validPauses.filter((pause) => pause >= LONG_PAUSE_SECONDS).length;
  const speechSeconds = Math.max(1, duration - pauseSeconds);
  const wordsPerMinute = Math.round((words.length * 60) / duration);
  const articulationRate = Math.round((words.length * 60) / speechSeconds);
  const vocabularyVariety = words.length === 0 ? 0 : Number((uniqueWordCount / words.length).toFixed(2));
  const pauseRatio = Number(Math.min(1, pauseSeconds / duration).toFixed(2));

  let pauseClassification: PauseClassification | undefined;
  if (wordTimings.length >= 2) {
    let boundaryPauses = 0;
    let midClausePauses = 0;
    const CLAUSE_BOUNDARIES = new Set([
      'and', 'but', 'or', 'so', 'because', 'although', 'however', 'moreover',
      'furthermore', 'therefore', 'while', 'when', 'if', 'that', 'which',
      'who', 'whose', 'where', 'since', 'as', 'though', 'whereas', 'unless',
      'despite', 'besides', 'meanwhile', 'yet',
    ]);
    for (let i = 0; i < wordTimings.length - 1; i++) {
      const cur = wordTimings[i]!;
      const next = wordTimings[i + 1]!;
      const gap = next.start - cur.end;
      if (gap >= 0.4) {
        const hasPunctuation = /[.,!?;:]$/.test(cur.word);
        const cleanNext = next.word.toLowerCase().replace(/[^a-z]/g, '');
        const isClauseWord = CLAUSE_BOUNDARIES.has(cleanNext);
        if (hasPunctuation || isClauseWord) {
          boundaryPauses++;
        } else {
          midClausePauses++;
        }
      }
    }
    if (boundaryPauses > 0 || midClausePauses > 0) {
      pauseClassification = { boundaryPauses, midClausePauses };
    }
  }

  return {
    wordCount: words.length,
    uniqueWordCount,
    wordsPerMinute,
    articulationRate,
    vocabularyVariety,
    fillerCount,
    fillers,
    pauseCount: validPauses.length,
    longPauseCount,
    pauseSeconds,
    pauseRatio,
    pauseNote: pauseNote(validPauses.length, longPauseCount, pauseClassification),
    nextStep: nextStep(fillerCount, longPauseCount, vocabularyVariety),
    ...(pauseClassification ? { pauseClassification } : {}),
  };
}

export function wpmTrend(previousValues: number[], current: number) {
  const present = previousValues.filter((value) => Number.isFinite(value) && value > 0);
  const points = [...present, current].slice(-6);
  const previous = present.length > 0 ? present[present.length - 1]! : null;
  const average = Math.round(points.reduce((total, value) => total + value, 0) / points.length);
  const variance = Number(
    Math.sqrt(points.reduce((total, value) => total + (value - average) ** 2, 0) / points.length).toFixed(1),
  );
  const change = previous == null ? null : current - previous;
  const message = change == null
    ? 'This is your first pace point. Complete another session to see a trend.'
    : change >= 3
      ? `You spoke ${change} words per minute faster than your last session.`
      : change <= -3
        ? `You spoke ${Math.abs(change)} words per minute slower than last time. Steady clarity matters more than speed.`
        : 'Your pace is steady compared with your last session.';
  return { points, average, variance, change, message };
}

function countPhrase(text: string, phrase: string): number {
  const escaped = phrase.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  return (text.match(new RegExp(`\\b${escaped}\\b`, 'gi')) ?? []).length;
}

function pauseNote(count: number, longCount: number, classification?: PauseClassification): string {
  if (count === 0 && !classification) return 'No pauses of half a second or more were detected in this recording.';
  if (classification && (classification.boundaryPauses > 0 || classification.midClausePauses > 0)) {
    const { boundaryPauses, midClausePauses } = classification;
    const clauseBreakdown = `${boundaryPauses} at natural phrasing boundaries, ${midClausePauses} mid-clause`;
    const totalPauses = Math.max(count, boundaryPauses + midClausePauses);
    if (longCount === 0) {
      return `${totalPauses} short pause${totalPauses === 1 ? '' : 's'} (${clauseBreakdown}) — a natural thinking rhythm.`;
    }
    return `${longCount} long pause${longCount === 1 ? '' : 's'} over ${LONG_PAUSE_SECONDS} seconds (${clauseBreakdown}).`;
  }
  if (count === 0) return 'No pauses of half a second or more were detected in this recording.';
  if (longCount === 0) return `${count} short pause${count === 1 ? '' : 's'} — a natural thinking rhythm.`;
  return `${longCount} long pause${longCount === 1 ? '' : 's'} over ${LONG_PAUSE_SECONDS} seconds. Word-boundary checks need speech-recognition timestamps, so this counts the pause, not its grammar position.`;
}

function nextStep(fillerCount: number, longPauseCount: number, variety: number): string {
  if (fillerCount > 0) return 'Replace one filler with a one-second silent pause. Silence sounds more confident than a filled gap.';
  if (longPauseCount > 0) return 'Plan one short opening sentence before you start, then keep each sentence moving.';
  if (variety > 0 && variety < 0.45) return 'Choose two repeated words and swap one of them for a more precise word in your next answer.';
  return 'Add one specific example to make your next answer easier to follow.';
}
