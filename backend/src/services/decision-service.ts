import type { JevClient, JevDecisionValue } from '../providers/jev-client.js';

export type AffectiveAssessmentResult = {
  anxietyState: 'calm' | 'mild_hesitation' | 'high_anxiety' | 'panic_freeze';
  shouldScaffold: boolean;
  intervention: 'none' | 'provide_sentence_starter' | 'step_down_to_whisper' | 'praise_effort';
  confidenceScore: number;
  latencyMs: number;
  provider: string;
};

export type CefrCalibrationResult = {
  calibratedCefr: 'A1' | 'A2' | 'B1' | 'B2' | 'C1' | 'C2';
  syntacticComplexity: number;
  lexicalRange: number;
  adaptiveAction: 'promote_higher' | 'maintain_level' | 'simplify_input';
  latencyMs: number;
  provider: string;
};

export type CoachTurnGateResult = {
  isOffTopic: boolean;
  needsRecast: boolean;
  errorCategory: string;
  sentiment: string;
  latencyMs: number;
  provider: string;
};

export type SrsGradePredictionResult = {
  predictedGrade: 'again' | 'hard' | 'good' | 'easy';
  lapseRisk: number;
  latencyMs: number;
  provider: string;
};

export class DecisionService {
  public constructor(private readonly jev: JevClient) {}

  public isJevConfigured(): boolean {
    return this.jev.isLive();
  }

  public async assessAffectiveState(params: {
    transcript: string;
    durationSeconds: number;
    pauseCount: number;
    wpm: number;
  }): Promise<AffectiveAssessmentResult> {
    const response = await this.jev.query({
      state: `Learner speech transcript: "${params.transcript}". Duration: ${params.durationSeconds}s, Pauses: ${params.pauseCount}, Speaking rate: ${params.wpm} WPM.`,
      questions: [
        {
          id: 'anxiety_state',
          type: 'choice',
          description: 'Classify learner speaking anxiety state based on pauses, pace, and hesitation.',
          options: ['calm', 'mild_hesitation', 'high_anxiety', 'panic_freeze'],
        },
        {
          id: 'should_scaffold',
          type: 'noul',
          description: 'Does the learner need scaffolding or encouragement to prevent affective filter blockage?',
        },
        {
          id: 'intervention',
          type: 'choice',
          description: 'What immediate pedagogical intervention is recommended?',
          options: ['none', 'provide_sentence_starter', 'step_down_to_whisper', 'praise_effort'],
        },
        {
          id: 'confidence_score',
          type: 'score',
          description: 'Learner confidence and composure score from 0.0 to 1.0',
          scale: { min: 0, max: 1 },
        },
      ],
    });

    const anxietyState = (this.getChoice(response.decisions['anxiety_state']) ?? 'calm') as AffectiveAssessmentResult['anxietyState'];
    const shouldScaffold = this.getNoul(response.decisions['should_scaffold']) ?? false;
    const intervention = (this.getChoice(response.decisions['intervention']) ?? 'none') as AffectiveAssessmentResult['intervention'];
    const confidenceScore = this.getScore(response.decisions['confidence_score']) ?? 0.8;

    return {
      anxietyState,
      shouldScaffold,
      intervention,
      confidenceScore,
      latencyMs: response.latencyMs,
      provider: response.provider,
    };
  }

  public async calibrateCefrLevel(params: {
    transcript: string;
    targetWordsUsed?: string[] | undefined;
  }): Promise<CefrCalibrationResult> {
    const response = await this.jev.query({
      state: `Utterance: "${params.transcript}". Key words used: ${params.targetWordsUsed?.join(', ') ?? 'none'}.`,
      questions: [
        {
          id: 'calibrated_cefr',
          type: 'choice',
          description: 'What CEFR level of communicative competency does this utterance demonstrate?',
          options: ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'],
        },
        {
          id: 'syntactic_complexity',
          type: 'score',
          description: 'Syntactic depth score from 0.0 to 1.0',
          scale: { min: 0, max: 1 },
        },
        {
          id: 'lexical_range',
          type: 'score',
          description: 'Lexical sophistication score from 0.0 to 1.0',
          scale: { min: 0, max: 1 },
        },
        {
          id: 'adaptive_action',
          type: 'choice',
          description: 'Action for Krashen i+1 calibration',
          options: ['promote_higher', 'maintain_level', 'simplify_input'],
        },
      ],
    });

    const calibratedCefr = (this.getChoice(response.decisions['calibrated_cefr']) ?? 'B1') as CefrCalibrationResult['calibratedCefr'];
    const syntacticComplexity = this.getScore(response.decisions['syntactic_complexity']) ?? 0.7;
    const lexicalRange = this.getScore(response.decisions['lexical_range']) ?? 0.7;
    const adaptiveAction = (this.getChoice(response.decisions['adaptive_action']) ?? 'maintain_level') as CefrCalibrationResult['adaptiveAction'];

    return {
      calibratedCefr,
      syntacticComplexity,
      lexicalRange,
      adaptiveAction,
      latencyMs: response.latencyMs,
      provider: response.provider,
    };
  }

  public async gateCoachTurn(params: {
    scenarioTitle: string;
    previousTurns: Array<{ role: string; text: string }>;
    learnerTurn: string;
  }): Promise<CoachTurnGateResult> {
    const context = params.previousTurns.slice(-2).map((t) => `${t.role}: ${t.text}`).join(' | ');
    const response = await this.jev.query({
      state: `Scenario: "${params.scenarioTitle}". Recent conversation: "${context}". Learner said: "${params.learnerTurn}".`,
      questions: [
        {
          id: 'is_off_topic',
          type: 'noul',
          description: 'Is the learner utterance completely off-topic from the conversational scenario?',
        },
        {
          id: 'needs_recast',
          type: 'noul',
          description: 'Does the learner utterance contain notable grammatical or lexical errors warranting a recast?',
        },
        {
          id: 'error_category',
          type: 'choice',
          description: 'Primary linguistic error category if any',
          options: ['none', 'verb_tense', 'preposition', 'plural_agreement', 'word_order', 'lexical_choice'],
        },
        {
          id: 'dialogue_sentiment',
          type: 'choice',
          description: 'Engagement tone of the learner response',
          options: ['enthusiastic', 'cooperative', 'minimal_effort', 'confused'],
        },
      ],
    });

    const isOffTopic = this.getNoul(response.decisions['is_off_topic']) ?? false;
    const needsRecast = this.getNoul(response.decisions['needs_recast']) ?? false;
    const errorCategory = this.getChoice(response.decisions['error_category']) ?? 'none';
    const sentiment = this.getChoice(response.decisions['dialogue_sentiment']) ?? 'cooperative';

    return {
      isOffTopic,
      needsRecast,
      errorCategory,
      sentiment,
      latencyMs: response.latencyMs,
      provider: response.provider,
    };
  }

  public async predictSrsGrade(params: {
    intervalDays: number;
    repetitions: number;
    responseTimeMs: number;
    isCorrect: boolean;
  }): Promise<SrsGradePredictionResult> {
    const response = await this.jev.query({
      state: `Flashcard review: interval=${params.intervalDays} days, reps=${params.repetitions}, latency=${params.responseTimeMs}ms, correct=${params.isCorrect}.`,
      questions: [
        {
          id: 'predicted_grade',
          type: 'choice',
          description: 'Predict optimal SuperMemo SM-2 grade',
          options: ['again', 'hard', 'good', 'easy'],
        },
        {
          id: 'lapse_risk',
          type: 'score',
          description: 'Memory trace decay risk score from 0.0 to 1.0',
          scale: { min: 0, max: 1 },
        },
      ],
    });

    const predictedGrade = (this.getChoice(response.decisions['predicted_grade']) ?? (params.isCorrect ? 'good' : 'again')) as SrsGradePredictionResult['predictedGrade'];
    const lapseRisk = this.getScore(response.decisions['lapse_risk']) ?? (params.isCorrect ? 0.2 : 0.85);

    return {
      predictedGrade,
      lapseRisk,
      latencyMs: response.latencyMs,
      provider: response.provider,
    };
  }

  private getChoice(val: JevDecisionValue | undefined): string | null {
    if (!val || val.type !== 'choice') return null;
    return val.value;
  }

  private getNoul(val: JevDecisionValue | undefined): boolean | null {
    if (!val || val.type !== 'noul') return null;
    return val.value;
  }

  private getScore(val: JevDecisionValue | undefined): number | null {
    if (!val || val.type !== 'score') return null;
    return val.value;
  }
}
