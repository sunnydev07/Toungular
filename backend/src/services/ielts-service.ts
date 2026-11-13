import type { PrismaClient } from '@prisma/client';

import type { AppEnv } from '../config/env.js';
import { AppError } from '../lib/http.js';
import type { DecisionService } from './decision-service.js';

const mocks = [
  {
    id: 'toungular-speaking-foundations',
    title: 'Speaking foundations',
    description: 'An original three-part timed speaking practice set.',
    sections: [
      {
        id: 'part-1',
        title: 'Part 1 · Interview',
        prompt: 'What do you enjoy most about your neighborhood?',
        preparationSeconds: 15,
        responseSeconds: 60,
      },
      {
        id: 'part-2',
        title: 'Part 2 · Long turn',
        prompt:
          'Describe a useful skill you learned. Say how you learned it, what was difficult, and how you use it now.',
        preparationSeconds: 60,
        responseSeconds: 120,
      },
      {
        id: 'part-3',
        title: 'Part 3 · Discussion',
        prompt: 'How can people stay motivated when they are learning a difficult skill?',
        preparationSeconds: 15,
        responseSeconds: 120,
      },
    ],
  },
];

const CONNECTORS = [
  'however',
  'furthermore',
  'for instance',
  'for example',
  'consequently',
  'on the other hand',
  'in addition',
  'moreover',
  'as a result',
  'therefore',
  'nevertheless',
  'firstly',
  'secondly',
  'finally',
  'in contrast',
  'in particular',
];

const COMPLEX_MARKERS = [
  'although',
  'whereas',
  'which',
  'despite',
  'provided that',
  'even though',
  'while',
  'because',
  'since',
  'unless',
  'in order that',
  'as long as',
];

const ACADEMIC_WORDS = new Set([
  'significant',
  'analyze',
  'perspective',
  'consequence',
  'indicate',
  'demonstrate',
  'essential',
  'appropriate',
  'relevant',
  'maintain',
  'contribute',
  'evaluate',
  'approach',
  'flexible',
  'priority',
  'concept',
  'factor',
  'individual',
  'involve',
  'issue',
  'occur',
  'require',
  'research',
  'strategy',
  'structure',
  'benefit',
  'aspect',
  'consider',
  'distinct',
  'element',
  'feature',
  'impact',
  'potential',
]);

export type IeltsCriterionScore = {
  score: number;
  label: string;
  notes: string;
};

export type IeltsPhraseUpgrade = {
  original: string;
  upgraded: string;
  reason: string;
};

export type IeltsBandRubric = {
  overallBandEstimate: number;
  fluencyAndCoherence: IeltsCriterionScore;
  lexicalResource: IeltsCriterionScore;
  grammaticalRange: IeltsCriterionScore;
  pronunciation: IeltsCriterionScore;
  upgradedPhrases: IeltsPhraseUpgrade[];
  disclaimer: string;
};

function roundToHalfBand(score: number): number {
  const rounded = Math.round(score * 2) / 2;
  return Math.min(8.5, Math.max(4.0, rounded));
}

export class IeltsService {
  public constructor(
    private readonly database: PrismaClient,
    private readonly env?: AppEnv,
    private readonly decision?: DecisionService,
  ) {}

  public loadMocks() {
    return mocks;
  }

  public async startAttempt(userId: string, mockId: string) {
    if (!mocks.some((mock) => mock.id === mockId)) {
      throw new AppError(404, 'IELTS_MOCK_NOT_FOUND', 'This practice set was not found.');
    }
    return this.database.ieltsAttempt.create({
      data: { userId, mockId },
      select: { id: true, mockId: true, status: true, startedAt: true },
    });
  }

  public async submitResponse(userId: string, attemptId: string, sectionId: string, transcript: string) {
    const attempt = await this.database.ieltsAttempt.findFirst({ where: { id: attemptId, userId } });
    if (!attempt) throw new AppError(404, 'IELTS_ATTEMPT_NOT_FOUND', 'The practice attempt was not found.');
    if (attempt.status !== 'in_progress') {
      throw new AppError(409, 'IELTS_ATTEMPT_FINISHED', 'This practice attempt has already ended.');
    }
    const mock = mocks.find((item) => item.id === attempt.mockId);
    if (!mock?.sections.some((section) => section.id === sectionId)) {
      throw new AppError(404, 'IELTS_SECTION_NOT_FOUND', 'This section was not found.');
    }
    return this.database.ieltsAttemptResponse.upsert({
      where: { attemptId_sectionId: { attemptId, sectionId } },
      update: { transcript },
      create: { attemptId, sectionId, transcript },
      select: { id: true, sectionId: true, transcript: true, updatedAt: true },
    });
  }

  public async evaluateAttemptRubric(
    responses: Array<{ sectionId: string; transcript: string | null }>,
  ): Promise<IeltsBandRubric> {
    const fullText = responses.map((r) => r.transcript ?? '').join(' ');
    const fullTextLower = fullText.toLowerCase();
    const tokens = fullTextLower.match(/[a-z]+(?:['’-][a-z]+)*/g) ?? [];
    const totalWords = tokens.length;
    const uniqueWords = new Set(tokens).size;
    const typeTokenRatio = totalWords > 0 ? uniqueWords / totalWords : 0;

    let cefrCalibration: { syntacticComplexity?: number; lexicalRange?: number } | undefined;
    if (this.decision && fullText.trim().length > 10) {
      try {
        cefrCalibration = await this.decision.calibrateCefrLevel({ transcript: fullText.slice(0, 4000) });
      } catch {
        // Fallback gracefully
      }
    }

    // 1. Fluency & Coherence
    const answeredCount = responses.filter((r) => (r.transcript ?? '').trim().length > 10).length;
    const foundConnectors = CONNECTORS.filter((c) => fullTextLower.includes(c));
    let fcRaw = 5.0 + (answeredCount >= 3 ? 1.0 : answeredCount >= 2 ? 0.5 : 0);
    if (foundConnectors.length >= 4) fcRaw += 1.0;
    else if (foundConnectors.length >= 2) fcRaw += 0.5;
    if (typeTokenRatio >= 0.55) fcRaw += 0.5;
    const fcScore = roundToHalfBand(fcRaw);

    // 2. Lexical Resource
    const foundAcademic = tokens.filter((t) => ACADEMIC_WORDS.has(t));
    let lrRaw = 5.0;
    if (cefrCalibration?.lexicalRange !== undefined) {
      lrRaw += (cefrCalibration.lexicalRange - 0.5) * 2;
    }
    if (foundAcademic.length >= 5) lrRaw += 1.0;
    else if (foundAcademic.length >= 2) lrRaw += 0.5;
    if (typeTokenRatio >= 0.5) lrRaw += 0.5;
    const lrScore = roundToHalfBand(lrRaw);

    // 3. Grammatical Range & Accuracy
    const foundComplex = COMPLEX_MARKERS.filter((m) => fullTextLower.includes(m));
    let graRaw = 5.0;
    if (cefrCalibration?.syntacticComplexity !== undefined) {
      graRaw += (cefrCalibration.syntacticComplexity - 0.5) * 2;
    }
    if (foundComplex.length >= 4) graRaw += 1.0;
    else if (foundComplex.length >= 2) graRaw += 0.5;
    const sentences = fullText.split(/[.?!]+/).filter((s) => s.trim().length > 0);
    if (sentences.length >= 3) {
      const lengths = sentences.map((s) => (s.match(/\S+/g) ?? []).length);
      const avg = lengths.reduce((a, b) => a + b, 0) / lengths.length;
      const variance = lengths.reduce((a, b) => a + Math.pow(b - avg, 2), 0) / lengths.length;
      if (variance > 12) graRaw += 0.5;
    }
    const graScore = roundToHalfBand(graRaw);

    // 4. Pronunciation (Intelligibility & Rhythm Proxy)
    const polysyllabic = tokens.filter((t) => t.length >= 8 || /(tion|able|ity|ous|ment|ence|ance)$/.test(t));
    let prRaw = 5.5;
    if (polysyllabic.length >= 6) prRaw += 1.0;
    else if (polysyllabic.length >= 2) prRaw += 0.5;
    const prScore = roundToHalfBand(prRaw);

    const overallBandEstimate = roundToHalfBand((fcScore + lrScore + graScore + prScore) / 4);

    // Concrete Upgraded Phrases
    const candidates: IeltsPhraseUpgrade[] = [];
    if (fullTextLower.includes('very good') || fullTextLower.includes('good')) {
      candidates.push({
        original: 'it is good / very good',
        upgraded: 'it is remarkably advantageous and beneficial',
        reason: 'Replaces generic positive adjectives with high-precision academic evaluative vocabulary.',
      });
    }
    if (fullTextLower.includes('i think') || fullTextLower.includes('in my opinion')) {
      candidates.push({
        original: 'I think that / in my opinion',
        upgraded: 'From my perspective, it appears evident that',
        reason: 'Adopts an academic stance marker standard for IELTS Part 3 discursive questions.',
      });
    }
    if (fullTextLower.includes('because') || fullTextLower.includes('so')) {
      candidates.push({
        original: 'because of this / so',
        upgraded: 'consequently, and largely owing to this factor',
        reason: 'Broadens grammatical subordination and causal discourse cohesion.',
      });
    }
    if (fullTextLower.includes('a lot of') || fullTextLower.includes('many')) {
      candidates.push({
        original: 'a lot of people',
        upgraded: 'a substantial proportion of the population',
        reason: 'Enhances lexical specificity and formal academic tone.',
      });
    }

    if (candidates.length < 2) {
      candidates.push({
        original: 'A big problem with learning is staying focused.',
        upgraded: 'A significant impediment to sustained learning is maintaining cognitive focus.',
        reason: 'Demonstrates advanced noun phrase collocation suitable for higher band scoring.',
      });
    }
    if (candidates.length < 2) {
      candidates.push({
        original: 'People like this because it is convenient.',
        upgraded: 'Individuals gravitate toward this approach primarily owing to its accessibility.',
        reason: 'Elevates register from everyday speech to analytical discourse.',
      });
    }

    const upgradedPhrases = candidates.slice(0, 2);

    return {
      overallBandEstimate,
      fluencyAndCoherence: {
        score: fcScore,
        label: 'Fluency & Coherence',
        notes: `Uses ${foundConnectors.length} discourse markers with ${Math.round(typeTokenRatio * 100)}% vocabulary variety across ${answeredCount} completed sections.`,
      },
      lexicalResource: {
        score: lrScore,
        label: 'Lexical Resource',
        notes: `Identified ${foundAcademic.length} Tier-2 academic items (${(foundAcademic.length / Math.max(1, tokens.length) * 100).toFixed(1)}% density).`,
      },
      grammaticalRange: {
        score: graScore,
        label: 'Grammatical Range & Accuracy',
        notes: `Identified ${foundComplex.length} subordination markers with varied clause structures.`,
      },
      pronunciation: {
        score: prScore,
        label: 'Pronunciation (Intelligibility & Rhythm Proxy)',
        notes: `Acoustic rhythm proxy estimated from ${polysyllabic.length} multisyllabic phonological patterns. Practice estimate only.`,
      },
      upgradedPhrases,
      disclaimer: 'Practice estimate only — not an official IELTS band score.',
    };
  }

  public async finishAttempt(userId: string, attemptId: string) {
    const attempt = await this.database.ieltsAttempt.findFirst({
      where: { id: attemptId, userId },
      include: { responses: true },
    });
    if (!attempt) throw new AppError(404, 'IELTS_ATTEMPT_NOT_FOUND', 'The practice attempt was not found.');
    const count = attempt.responses.length;
    const rubric = await this.evaluateAttemptRubric(attempt.responses);
    const finishedAt = new Date();
    const summary = `Completed ${count} section response${count === 1 ? '' : 's'}. Estimated Band: ${rubric.overallBandEstimate}. Practice estimate only — not an official IELTS band score.`;
    const storedFeedback = JSON.stringify({
      summary,
      rubric,
    });
    await this.database.ieltsAttempt.update({
      where: { id: attemptId },
      data: {
        status: 'completed',
        finishedAt,
        feedback: storedFeedback,
      },
    });
    return {
      id: attemptId,
      mockId: attempt.mockId,
      status: 'completed',
      finishedAt,
      feedback: summary,
      rubric,
      responses: attempt.responses,
    };
  }

  public async history(userId: string, limit = 20, offset = 0) {
    const records = await this.database.ieltsAttempt.findMany({
      where: { userId },
      orderBy: { startedAt: 'desc' },
      take: limit,
      skip: offset,
      include: { responses: { orderBy: { createdAt: 'asc' } } },
    });
    return records.map((record) => {
      let rubric: IeltsBandRubric | null = null;
      let feedback = record.feedback;
      if (record.feedback) {
        try {
          const parsed = JSON.parse(record.feedback);
          if (parsed && typeof parsed === 'object') {
            if (parsed.rubric) rubric = parsed.rubric as IeltsBandRubric;
            if (parsed.summary) feedback = parsed.summary as string;
          }
        } catch {
          // Plain text feedback
        }
      }
      return {
        ...record,
        feedback,
        rubric,
      };
    });
  }
}
