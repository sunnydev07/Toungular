import type { PrismaClient } from '@prisma/client';

import { AppError } from '../lib/http.js';
import type { PronunciationAssessor } from '../providers/voice.js';
import type { DecisionService } from './decision-service.js';
import type { MasteryService } from './mastery-service.js';

export type PhonemeItem = {
  word: string;
  ipa: string;
  meaning: string;
  audioSampleText: string;
};

export type ArticulatoryGuide = {
  tonguePlacement: string;
  lipShape: string;
  voicing: string;
  commonPitfall: string;
};

export type MinimalPairSet = {
  id: string;
  title: string;
  phoneticContrast: string;
  category: 'consonant' | 'vowel';
  level: 'A1' | 'A2' | 'B1' | 'B2' | 'C1';
  wordA: PhonemeItem;
  wordB: PhonemeItem;
  articulatoryGuide: ArticulatoryGuide;
  sentenceDrill: string;
};

export type PhonemeAnalysisResult = {
  pairId: string;
  targetChoice: 'A' | 'B';
  targetWord: string;
  spokenTranscript: string;
  accuracyScore: number;
  isAccurate: boolean;
  confusedWithCounterpart: boolean;
  phonemeFeedback: string;
  articulatoryTip: string;
  awardedXp: number;
  acousticAssessment?: {
    accuracyScore: number;
    fluencyScore?: number | undefined;
    completenessScore?: number | undefined;
    pronScore: number;
    phonemes?: Array<{
      phoneme: string;
      accuracyScore: number;
    }> | undefined;
  } | undefined;
};

const MINIMAL_PAIRS: MinimalPairSet[] = [
  {
    id: 'pair-r-vs-l',
    title: 'Right vs. Light',
    phoneticContrast: '/r/ vs /l/',
    category: 'consonant',
    level: 'A1',
    wordA: {
      word: 'Right',
      ipa: '/raɪt/',
      meaning: 'Correct or opposite of left',
      audioSampleText: 'Turn to the right at the corner.',
    },
    wordB: {
      word: 'Light',
      ipa: '/laɪt/',
      meaning: 'Illumination or not heavy',
      audioSampleText: 'The morning light fills the room.',
    },
    articulatoryGuide: {
      tonguePlacement: 'For /r/, curl the tongue tip backward without touching the roof. For /l/, press the tongue tip firmly against the alveolar ridge behind upper teeth.',
      lipShape: 'For /r/, slightly round lips. For /l/, keep lips neutral and relaxed.',
      voicing: 'Both /r/ and /l/ are voiced sonorants; vocal cords vibrate continuously.',
      commonPitfall: 'Letting the tongue touch the ridge during /r/, producing a tapped flap or /l/ sound.',
    },
    sentenceDrill: 'Turn to the right under the street light.',
  },
  {
    id: 'pair-th-vs-s',
    title: 'Think vs. Sink',
    phoneticContrast: '/θ/ vs /s/',
    category: 'consonant',
    level: 'A2',
    wordA: {
      word: 'Think',
      ipa: '/θɪŋk/',
      meaning: 'To have a conscious thought',
      audioSampleText: 'I think we should start now.',
    },
    wordB: {
      word: 'Sink',
      ipa: '/sɪŋk/',
      meaning: 'A basin with a water supply',
      audioSampleText: 'Wash the dishes in the kitchen sink.',
    },
    articulatoryGuide: {
      tonguePlacement: 'For /θ/, place the tongue tip lightly between the upper and lower teeth (interdental). For /s/, keep the tongue tip behind the upper teeth without protruding.',
      lipShape: 'Keep lips slightly parted in a neutral relaxed smile.',
      voicing: 'Both are voiceless fricatives; airflow creates audible friction without vocal cord vibration.',
      commonPitfall: 'Retracting the tongue during /θ/, which converts the sound to /s/ or /t/.',
    },
    sentenceDrill: 'I think the water is overflowing in the kitchen sink.',
  },
  {
    id: 'pair-ee-vs-ih',
    title: 'Sheep vs. Ship',
    phoneticContrast: '/iː/ vs /ɪ/',
    category: 'vowel',
    level: 'A1',
    wordA: {
      word: 'Sheep',
      ipa: '/ʃiːp/',
      meaning: 'A woolly ruminant animal',
      audioSampleText: 'The white sheep grazed in the green meadow.',
    },
    wordB: {
      word: 'Ship',
      ipa: '/ʃɪp/',
      meaning: 'A large seafaring vessel',
      audioSampleText: 'The cargo ship sailed into port.',
    },
    articulatoryGuide: {
      tonguePlacement: 'For /iː/, tongue is high and front with tense facial muscles. For /ɪ/, tongue is slightly lower and facial muscles are completely lax.',
      lipShape: 'For /iː/, stretch lips wide in an intentional smile. For /ɪ/, relax lips loosely.',
      voicing: 'Both are voiced vowels.',
      commonPitfall: 'Failing to relax tongue tension during /ɪ/, making words like "ship" sound like "sheep".',
    },
    sentenceDrill: 'The large ship carried twenty white sheep across the sea.',
  },
  {
    id: 'pair-v-vs-w',
    title: 'Vine vs. Wine',
    phoneticContrast: '/v/ vs /w/',
    category: 'consonant',
    level: 'B1',
    wordA: {
      word: 'Vine',
      ipa: '/vaɪn/',
      meaning: 'A climbing grape plant',
      audioSampleText: 'Grapes grow abundantly on the vine.',
    },
    wordB: {
      word: 'Wine',
      ipa: '/waɪn/',
      meaning: 'An alcoholic drink made from grapes',
      audioSampleText: 'They shared a bottle of red wine.',
    },
    articulatoryGuide: {
      tonguePlacement: 'For /v/, the tongue rests neutrally while top teeth touch lower lip. For /w/, tongue back raises toward the soft palate.',
      lipShape: 'For /v/, upper front teeth make light contact with inner lower lip. For /w/, round lips tightly into a small O shape without teeth touching.',
      voicing: 'Both /v/ and /w/ are voiced sounds.',
      commonPitfall: 'Touching teeth to lip during /w/, or failing to make teeth-to-lip contact during /v/.',
    },
    sentenceDrill: 'The sweet wine was pressed from grapes fresh on the vine.',
  },
  {
    id: 'pair-p-vs-b',
    title: 'Pack vs. Back',
    phoneticContrast: '/p/ vs /b/',
    category: 'consonant',
    level: 'A2',
    wordA: {
      word: 'Pack',
      ipa: '/pæk/',
      meaning: 'To put things into a bag or suitcase',
      audioSampleText: 'Please pack your luggage tonight.',
    },
    wordB: {
      word: 'Back',
      ipa: '/bæk/',
      meaning: 'The rear part of the body or opposite of front',
      audioSampleText: 'He stood at the back of the line.',
    },
    articulatoryGuide: {
      tonguePlacement: 'Tongue rests in low front position for /æ/.',
      lipShape: 'Both start with lips pressed firmly together to build air pressure.',
      voicing: 'For /p/, release is voiceless with an audible puff of aspiration air. For /b/, vocal cords vibrate upon release with minimal aspiration.',
      commonPitfall: 'Releasing /p/ without aspiration puff, causing native listeners to hear /b/.',
    },
    sentenceDrill: 'Please pack your gear and place the backpack on your back.',
  },
  {
    id: 'pair-sh-vs-ch',
    title: 'Share vs. Chair',
    phoneticContrast: '/ʃ/ vs /tʃ/',
    category: 'consonant',
    level: 'B1',
    wordA: {
      word: 'Share',
      ipa: '/ʃeər/',
      meaning: 'To distribute or participate in jointly',
      audioSampleText: 'We can share the umbrella in the rain.',
    },
    wordB: {
      word: 'Chair',
      ipa: '/tʃeər/',
      meaning: 'A separate seat for one person',
      audioSampleText: 'Pull up a comfortable wooden chair.',
    },
    articulatoryGuide: {
      tonguePlacement: 'For /ʃ/, tongue blade raises near alveolar ridge producing continuous friction. For /tʃ/, tongue tip stops airflow completely at the ridge before explosive release.',
      lipShape: 'Slightly flared lips for both sounds.',
      voicing: 'Both are voiceless consonants.',
      commonPitfall: 'Omitting the stop /t/ closure in /tʃ/, turning "chair" into "share".',
    },
    sentenceDrill: 'Please share that comfortable wooden chair with our guest.',
  },
];

export class PronunciationService {
  public constructor(
    private readonly database: PrismaClient,
    private readonly decision: DecisionService,
    private readonly mastery: MasteryService,
    private readonly assessor?: PronunciationAssessor,
  ) {}

  public getPairs(category?: string, level?: string): MinimalPairSet[] {
    return MINIMAL_PAIRS.filter((pair) => {
      if (category && category !== 'all' && pair.category !== category) return false;
      if (level && level !== 'all' && pair.level !== level) return false;
      return true;
    });
  }

  public getPair(id: string): MinimalPairSet {
    const found = MINIMAL_PAIRS.find((p) => p.id === id);
    if (!found) {
      throw new AppError(404, 'PAIR_NOT_FOUND', `Minimal pair '${id}' was not found.`);
    }
    return found;
  }

  public async analyzeAttempt(
    userId: string,
    pairId: string,
    targetChoice: 'A' | 'B',
    transcript: string,
    durationSeconds: number,
    audio?: Buffer,
    contentType?: string,
  ): Promise<PhonemeAnalysisResult> {
    const pair = this.getPair(pairId);
    const targetItem = targetChoice === 'A' ? pair.wordA : pair.wordB;
    const counterpartItem = targetChoice === 'A' ? pair.wordB : pair.wordA;

    const cleaned = transcript.trim().toLowerCase();
    const targetLower = targetItem.word.toLowerCase();
    const counterpartLower = counterpartItem.word.toLowerCase();

    // Whole-word matching keeps "alright" from satisfying a "right" drill.
    const escapeRegex = (value: string) => value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const hasTarget = new RegExp(`\\b${escapeRegex(targetLower)}\\b`, 'i').test(cleaned);
    const hasCounterpart = new RegExp(`\\b${escapeRegex(counterpartLower)}\\b`, 'i').test(cleaned);

    let isAccurate = false;
    let confusedWithCounterpart = false;
    let accuracyScore = 50;

    let acousticAssessment: PhonemeAnalysisResult['acousticAssessment'] | undefined;
    if (this.assessor && audio) {
      try {
        const assessed = await this.assessor.assess(audio, contentType ?? 'audio/wav', targetItem.word);
        accuracyScore = Math.round(assessed.accuracyScore);
        isAccurate = accuracyScore >= 60;
        confusedWithCounterpart = !isAccurate && hasCounterpart;
        acousticAssessment = {
          accuracyScore: assessed.accuracyScore,
          fluencyScore: assessed.fluencyScore,
          completenessScore: assessed.completenessScore,
          pronScore: assessed.pronScore,
          phonemes: assessed.words?.[0]?.phonemes?.map((p) => ({
            phoneme: p.phoneme,
            accuracyScore: p.accuracyScore,
          })),
        };
      } catch {
        // Fallback to transcript heuristic matching below
      }
    }

    if (!acousticAssessment) {
      if (hasTarget && !hasCounterpart) {
        isAccurate = true;
        accuracyScore = 95;
      } else if (hasCounterpart && !hasTarget) {
        isAccurate = false;
        confusedWithCounterpart = true;
        accuracyScore = 35;
      } else if (hasTarget && hasCounterpart) {
        isAccurate = true;
        accuracyScore = 75;
      } else {
        isAccurate = false;
        accuracyScore = 40;
      }
    }

    // Award XP
    const xpPoints = isAccurate ? 25 : 10;
    if (userId) {
      await this.mastery.awardXp(
        userId,
        'acoustic',
        xpPoints,
        `Minimal pair drill: ${pair.title} (${targetItem.word})`,
      );
    }

    let phonemeFeedback = '';
    if (isAccurate) {
      phonemeFeedback = `Excellent acoustic precision! You clearly distinguished the ${targetItem.ipa} phoneme in "${targetItem.word}".`;
    } else if (confusedWithCounterpart) {
      phonemeFeedback = `Noticeable phoneme substitution: you produced "${counterpartItem.word}" (${counterpartItem.ipa}) instead of "${targetItem.word}" (${targetItem.ipa}).`;
    } else {
      phonemeFeedback = `Try emphasizing the initial phoneme more clearly to distinguish "${targetItem.word}" (${targetItem.ipa}).`;
    }

    return {
      pairId: pair.id,
      targetChoice,
      targetWord: targetItem.word,
      spokenTranscript: transcript,
      accuracyScore,
      isAccurate,
      confusedWithCounterpart,
      phonemeFeedback,
      articulatoryTip: pair.articulatoryGuide.tonguePlacement,
      awardedXp: xpPoints,
      ...(acousticAssessment ? { acousticAssessment } : {}),
    };
  }
}
