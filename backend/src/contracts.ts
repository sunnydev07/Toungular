export type Proficiency = 'beginner' | 'elementary' | 'intermediate' | 'upperIntermediate' | 'advanced';
export type ReviewGrade = 'again' | 'hard' | 'good' | 'easy';
export type RecallMode = 'definition' | 'cloze' | 'audio' | 'sentence';
export type VocabularyTier = 1 | 2 | 3;

export type RegisterInput = {
  email: string;
  password: string;
  profile?: ProfilePatch;
};

export type LoginInput = { email: string; password: string };

export type ProfilePatch = {
  goals?: string[];
  proficiency?: Proficiency;
  dailyMinutes?: number;
  timezone?: string;
  ieltsIntent?: boolean;
};

export type Profile = {
  userId: string;
  email: string;
  goals: string[];
  proficiency: Proficiency;
  dailyMinutes: number;
  timezone: string;
  ieltsIntent: boolean;
};

export type AuthResult = {
  user: { id: string; email: string };
  profile: Profile;
  accessToken: string;
  refreshToken: string;
};

export type LessonProgress = { lessonId: string; completedAt: Date };

export type Roadmap = {
  courses: Array<{
    id: string;
    title: string;
    description: string;
    level: string;
    position: number;
    lessons: Array<{
      id: string;
      title: string;
      summary: string;
      durationMin: number;
      position: number;
      completedAt: Date | null;
    }>;
  }>;
  completedLessonCount: number;
};

export type VocabularyReview = {
  item: {
    id: string;
    word: string;
    partOfSpeech: string;
    definition: string;
    example: string;
    level: string;
    tier: VocabularyTier;
  };
  dueAt: Date;
  intervalDays: number;
  repetitions: number;
  easeFactor: number;
  stability?: number;
  difficulty?: number;
  retrievability?: number;
  lapses: number;
  lastGrade: ReviewGrade | null;
  recallMode: RecallMode;
  cloze: string | null;
  source: string;
};
