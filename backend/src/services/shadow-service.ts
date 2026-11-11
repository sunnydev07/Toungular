import type { PrismaClient } from '@prisma/client';

import { AppError } from '../lib/http.js';

export type ShadowPassage = {
  id: string;
  title: string;
  level: 'beginner' | 'elementary' | 'intermediate' | 'upperIntermediate' | 'advanced';
  targetWpm: number;
  durationEstimateSec: number;
  text: string;
  focus: string;
  chunks: string[];
};

export type ShadowAnalysisResult = {
  passageId: string;
  passageTitle: string;
  level: string;
  targetWpm: number;
  actualWpm: number;
  durationSeconds: number;
  wordCount: number;
  wordMatchPercent: number;
  paceAlignmentPercent: number;
  rhythmScore: number;
  overallScore: number;
  feedback: {
    paceDiagnosis: string;
    prosodyTip: string;
    nextStep: string;
  };
};

const PASSAGES: ShadowPassage[] = [
  {
    id: 'shadow-01-morning-routine',
    title: 'A Simple Morning Routine',
    level: 'beginner',
    targetWpm: 110,
    durationEstimateSec: 18,
    text: "Every morning, I wake up at seven o'clock. I make a cup of warm tea and sit by the window. It gives me ten quiet minutes before my busy day begins.",
    focus: 'Clear sentence boundaries and pausing at natural commas.',
    chunks: [
      "Every morning, / I wake up at seven o'clock.",
      'I make a cup of warm tea / and sit by the window.',
      'It gives me ten quiet minutes / before my busy day begins.',
    ],
  },
  {
    id: 'shadow-02-local-market',
    title: 'The Local Market',
    level: 'elementary',
    targetWpm: 120,
    durationEstimateSec: 20,
    text: 'There is an open-air market just around the corner from my house. Fresh fruit and vegetables are stacked in colorful wooden crates. The sellers greet everyone with a friendly smile.',
    focus: "Linking consonants smoothly, such as 'open-air' and 'stacked in'.",
    chunks: [
      'There is an open-air market / just around the corner from my house.',
      'Fresh fruit and vegetables / are stacked in colorful wooden crates.',
      'The sellers greet everyone / with a friendly smile.',
    ],
  },
  {
    id: 'shadow-03-mountain-train',
    title: 'Journey Through the Hills',
    level: 'intermediate',
    targetWpm: 135,
    durationEstimateSec: 24,
    text: 'Traveling by train through the mountain pass was an unforgettable experience. As the tracks climbed higher, clouds gathered along the green valleys below. The rhythmic sound of the wheels made the long journey feel surprisingly peaceful.',
    focus: 'Maintaining a steady rhythm across longer clauses without gasping.',
    chunks: [
      'Traveling by train through the mountain pass / was an unforgettable experience.',
      'As the tracks climbed higher, / clouds gathered along the green valleys below.',
      'The rhythmic sound of the wheels / made the long journey feel surprisingly peaceful.',
    ],
  },
  {
    id: 'shadow-04-team-collaboration',
    title: 'Effective Collaboration',
    level: 'intermediate',
    targetWpm: 145,
    durationEstimateSec: 22,
    text: 'When diverse perspectives come together, solutions become more resilient. Rather than avoiding disagreements, strong teams actively explore differing viewpoints to discover innovative paths forward.',
    focus: "Vocal emphasis on contrast words like 'diverse', 'resilient', and 'differing'.",
    chunks: [
      'When diverse perspectives come together, / solutions become more resilient.',
      'Rather than avoiding disagreements, / strong teams actively explore differing viewpoints',
      'to discover innovative paths forward.',
    ],
  },
  {
    id: 'shadow-05-digital-focus',
    title: 'Navigating Digital Overload',
    level: 'upperIntermediate',
    targetWpm: 155,
    durationEstimateSec: 24,
    text: 'In an age of relentless digital notifications, cultivating sustained attention has become a rare and valuable discipline. Stepping away from screens allows the mind to consolidate knowledge and think critically.',
    focus: 'Pacing complex academic vocabulary smoothly without breaking cadence.',
    chunks: [
      'In an age of relentless digital notifications, / cultivating sustained attention',
      'has become a rare and valuable discipline.',
      'Stepping away from screens / allows the mind to consolidate knowledge / and think critically.',
    ],
  },
  {
    id: 'shadow-06-constructive-dialogue',
    title: 'The Art of Constructive Discourse',
    level: 'advanced',
    targetWpm: 165,
    durationEstimateSec: 22,
    text: 'Persuasive communication relies not on rhetorical volume, but on structural clarity and empathetic listening. True leadership articulates a compelling vision while remaining receptive to pragmatic feedback.',
    focus: 'Pitch contour dropping naturally at terminal punctuation marks.',
    chunks: [
      'Persuasive communication relies not on rhetorical volume, / but on structural clarity and empathetic listening.',
      'True leadership articulates a compelling vision / while remaining receptive to pragmatic feedback.',
    ],
  },
];

export class ShadowService {
  public constructor(private readonly database: PrismaClient) {}

  public passages(): ShadowPassage[] {
    return PASSAGES;
  }

  public passage(id: string): ShadowPassage {
    const found = PASSAGES.find((item) => item.id === id);
    if (!found) throw new AppError(404, 'PASSAGE_NOT_FOUND', 'The shadowing passage was not found.');
    return found;
  }

  public async analyze(
    userId: string,
    passageId: string,
    durationSeconds: number,
    transcript: string,
    pauses: number[] = [],
  ): Promise<ShadowAnalysisResult> {
    const passage = this.passage(passageId);
    const duration = Math.max(1, durationSeconds);

    const passageWords = normalizeWords(passage.text);
    const spokenWords = normalizeWords(transcript);

    const actualWpm = Math.round((spokenWords.length * 60) / duration);
    const targetWpm = passage.targetWpm;

    // Word match percentage based on token presence
    const passageSet = new Set(passageWords);
    const matchedTokens = spokenWords.filter((w) => passageSet.has(w)).length;
    const wordMatchPercent = passageWords.length > 0
      ? Math.min(100, Math.round((matchedTokens / passageWords.length) * 100))
      : 0;

    // Pace alignment: penalize divergence from target WPM
    const wpmDiff = Math.abs(actualWpm - targetWpm);
    const paceAlignmentPercent = Math.max(0, Math.min(100, Math.round(100 - wpmDiff * 1.6)));

    // Rhythm score based on pause distribution
    const validPauses = pauses.filter((p) => Number.isFinite(p) && p >= 0.4);
    const expectedChunkBreaks = passage.chunks.length - 1;
    const pauseDiff = Math.abs(validPauses.length - expectedChunkBreaks);
    const rhythmScore = Math.max(40, Math.min(100, 100 - pauseDiff * 15));

    // Overall composite score
    const overallScore = Math.round(
      wordMatchPercent * 0.45 + paceAlignmentPercent * 0.40 + rhythmScore * 0.15,
    );

    // Diagnostic feedback messages
    let paceDiagnosis: string;
    if (wpmDiff <= 8) {
      paceDiagnosis = `Excellent pacing! Your speech rate of ${actualWpm} WPM closely tracks the ${targetWpm} WPM model tempo.`;
    } else if (actualWpm > targetWpm) {
      paceDiagnosis = `You spoke at ${actualWpm} WPM, which is faster than the ${targetWpm} WPM model. Slow down slightly to match the native rhythm and clear vowel sounds.`;
    } else {
      paceDiagnosis = `You spoke at ${actualWpm} WPM, while the target is ${targetWpm} WPM. Try to maintain momentum without pausing between words in the same phrase.`;
    }

    const prosodyTip = passage.focus;
    const nextStep = overallScore >= 80
      ? 'Outstanding shadow attempt! Try the next higher CEFR level or practice blind shadowing without looking at the text.'
      : 'Practice one more round with text support, focusing on synchronizing your voice with the model at each phrase boundary.';

    // Record skill progress snapshot
    await this.database.skillSnapshot.create({
      data: {
        userId,
        skill: 'shadowing',
        value: overallScore,
        source: passage.id,
      },
    });

    return {
      passageId: passage.id,
      passageTitle: passage.title,
      level: passage.level,
      targetWpm,
      actualWpm,
      durationSeconds: duration,
      wordCount: spokenWords.length,
      wordMatchPercent,
      paceAlignmentPercent,
      rhythmScore,
      overallScore,
      feedback: {
        paceDiagnosis,
        prosodyTip,
        nextStep,
      },
    };
  }
}

function normalizeWords(text: string): string[] {
  return (text.toLowerCase().match(/[a-z]+(?:['’-][a-z]+)*/g) ?? []);
}
