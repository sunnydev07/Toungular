import type { PrismaClient } from '@prisma/client';

import type { AppEnv } from '../config/env.js';
import { AppError } from '../lib/http.js';

export type CefrLevel = 'A1' | 'A2' | 'B1' | 'B2' | 'C1' | 'C2';

export type VocabularyItem = {
  word: string;
  definition: string;
  partOfSpeech: string;
  sampleSentence: string;
};

export type ComprehensionQuestion = {
  id: string;
  question: string;
  options: string[];
  correctIndex: number;
  explanation: string;
};

export type ContentArticle = {
  id: string;
  title: string;
  level: CefrLevel;
  topic: string;
  readingTimeMin: number;
  wordCount: number;
  summary: string;
  content: string;
  vocabulary: VocabularyItem[];
  questions: ComprehensionQuestion[];
  outputPrompt: {
    instruction: string;
    requiredWordCount: number;
    recommendedTargetWords: string[];
    sampleResponse: string;
  };
};

export type OutputEvaluationResult = {
  articleId: string;
  wordCount: number;
  sentenceCount: number;
  targetWordsUsed: string[];
  targetWordsMissing: string[];
  grammarScore: number;
  vocabularyScore: number;
  overallScore: number;
  strengths: string[];
  suggestions: string[];
  recast: string;
};

const ARTICLES: ContentArticle[] = [
  {
    id: 'article-a1-market-morning',
    title: 'A Sunny Morning at the Market',
    level: 'A1',
    topic: 'Daily Life & Food',
    readingTimeMin: 2,
    wordCount: 88,
    summary: 'A simple walk through a lively outdoor market filled with fresh fruit and warm bread.',
    content: `Every Saturday morning, Maria walks to the outdoor market near her home. The sun is warm and the air smells like fresh oranges. 

She carries a small basket on her arm. First, she visits the fruit stall to choose five red apples. The farmer smiles and offers her a taste of sweet melon. "This is delicious," Maria says with a laugh. She pays with a five-euro coin and heads home to make breakfast.`,
    vocabulary: [
      { word: 'fresh', definition: 'Recently made or picked; not old.', partOfSpeech: 'adjective', sampleSentence: 'The bakery sells fresh bread every morning.' },
      { word: 'delicious', definition: 'Having a very pleasant taste.', partOfSpeech: 'adjective', sampleSentence: 'This home-cooked soup is absolutely delicious.' },
      { word: 'basket', definition: 'A container made of woven strips of wood or plastic.', partOfSpeech: 'noun', sampleSentence: 'He packed a basket full of apples for the picnic.' },
      { word: 'stall', definition: 'A large table or stand used to sell goods at an outdoor market.', partOfSpeech: 'noun', sampleSentence: 'The fruit stall was crowded with cheerful shoppers.' },
    ],
    questions: [
      {
        id: 'q1',
        question: 'When does Maria visit the outdoor market?',
        options: ['Every Friday evening', 'Every Saturday morning', 'On Sunday afternoon', 'Every Wednesday at lunch'],
        correctIndex: 1,
        explanation: 'The opening line states Maria visits every Saturday morning.',
      },
      {
        id: 'q2',
        question: 'What does the farmer offer Maria to taste?',
        options: ['Sweet melon', 'A warm pastry', 'A green apple', 'Fresh orange juice'],
        correctIndex: 0,
        explanation: 'The story notes the farmer offers a taste of sweet melon.',
      },
    ],
    outputPrompt: {
      instruction: 'Write 2-3 sentences about your favorite place to shop or buy food. Use at least two target words (fresh, delicious, basket, stall).',
      requiredWordCount: 15,
      recommendedTargetWords: ['fresh', 'delicious', 'stall'],
      sampleResponse: 'I love visiting the local vegetable stall on weekends. The carrots and tomatoes are always fresh, and my mother cooks a delicious dinner with them.',
    },
  },
  {
    id: 'article-a2-habit-of-curiosity',
    title: 'The Habit of Curiosity',
    level: 'A2',
    topic: 'Habits & Growth',
    readingTimeMin: 3,
    wordCount: 135,
    summary: 'How small daily observations can spark lifelong learning and natural fluency.',
    content: `Curiosity is like a muscle that grows stronger with practice. When children explore a park, they stop to examine every beetle, leaf, and pebble. As adults, we often walk too quickly, looking only at our phones.

Psychologists suggest building a daily habit of noticing new details. For example, when you walk to the station, try to spot three things you never saw before. It could be an old brick wall, a brightly painted bicycle, or a bird singing in a tree. 

When you stay curious, your mind stays active. You discover new words effortlessly because you actually want to know what things are called. Learning a language becomes an exciting journey rather than a chore.`,
    vocabulary: [
      { word: 'curious', definition: 'Eager to know or learn something new.', partOfSpeech: 'adjective', sampleSentence: 'Children are naturally curious about the world around them.' },
      { word: 'habit', definition: 'A settled or regular practice that is done frequently.', partOfSpeech: 'noun', sampleSentence: 'Reading ten pages before bed is a wonderful habit.' },
      { word: 'discover', definition: 'To find or become aware of something for the first time.', partOfSpeech: 'verb', sampleSentence: 'I discovered a quiet coffee shop near my office.' },
      { word: 'effortlessly', definition: 'In a manner requiring no apparent effort or struggle.', partOfSpeech: 'adverb', sampleSentence: 'She spoke so naturally that the words flowed effortlessly.' },
    ],
    questions: [
      {
        id: 'q1',
        question: 'According to psychologists in the text, what should we build as a daily habit?',
        options: ['Running five miles', 'Noticing new details around us', 'Reading dictionaries for an hour', 'Speaking only about work'],
        correctIndex: 1,
        explanation: 'The text suggests building a daily habit of noticing new details.',
      },
      {
        id: 'q2',
        question: 'Why does curiosity help language learners?',
        options: ['It lowers textbook prices', 'It makes learning feel like an exciting journey instead of a chore', 'It skips grammar rules entirely', 'It replaces sleep'],
        correctIndex: 1,
        explanation: 'Curiosity turns language acquisition into an exciting journey where words are discovered naturally.',
      },
    ],
    outputPrompt: {
      instruction: 'Describe one small thing you noticed today that made you curious. Use at least two target words (curious, habit, discover, effortlessly).',
      requiredWordCount: 20,
      recommendedTargetWords: ['curious', 'habit', 'discover'],
      sampleResponse: 'Today I tried to keep my habit of paying attention during my walk. I was curious about a small yellow flower growing through the pavement, and I discovered its name online.',
    },
  },
  {
    id: 'article-b1-science-of-deep-work',
    title: 'The Science of Deep Work',
    level: 'B1',
    topic: 'Focus & Cognitive Psychology',
    readingTimeMin: 4,
    wordCount: 192,
    summary: 'Why sustained focus without distraction is essential for mastering complex language skills.',
    content: `In our hyper-connected world, true concentration has become a rare superpower. Notifications, instant messages, and endless feeds create what neuroscientists call "attention residue." Every time you switch tasks, a fragment of your cognitive capacity remains stuck on the previous activity.

Author Cal Newport defines "deep work" as professional or intellectual activities performed in a state of distraction-free concentration that push your cognitive capabilities to their limit. These efforts create new value, sharpen your abilities, and are difficult to replicate.

When learning a foreign language, shallow multitasking—such as swiping flashcards while watching television—produces fleeting memory traces. In contrast, dedicating thirty minutes of undistracted immersion triggers myelin production around neural circuits. 

To cultivate this state, start with a simple ritual. Clear your desk, place your phone in another room, and set a timer for twenty-five minutes. With regular discipline, your ability to enter a flow state will expand dramatically.`,
    vocabulary: [
      { word: 'distraction', definition: 'A thing that prevents someone from giving full attention to something.', partOfSpeech: 'noun', sampleSentence: 'Putting your phone on silent eliminates a major distraction.' },
      { word: 'concentration', definition: 'The action or power of focusing one\'s attention or mental effort.', partOfSpeech: 'noun', sampleSentence: 'Deep listening requires undivided concentration.' },
      { word: 'replicate', definition: 'To reproduce or duplicate something accurately.', partOfSpeech: 'verb', sampleSentence: 'Unique creative skills are difficult for competitors to replicate.' },
      { word: 'immersion', definition: 'Deep mental involvement or complete exposure to an environment.', partOfSpeech: 'noun', sampleSentence: 'Complete immersion in English conversations speeds up comprehension.' },
      { word: 'discipline', definition: 'The practice of training people to obey rules or self-control.', partOfSpeech: 'noun', sampleSentence: 'Daily practice requires steady discipline over motivation.' },
    ],
    questions: [
      {
        id: 'q1',
        question: 'What is "attention residue"?',
        options: ['A chemical in tea', 'Cognitive capacity remaining stuck on a previous activity after switching tasks', 'Physical eye strain from screens', 'The final score of an exam'],
        correctIndex: 1,
        explanation: 'Attention residue occurs when fragments of cognitive focus remain tied to a prior task.',
      },
      {
        id: 'q2',
        question: 'What physical biological process is triggered by undistracted immersion?',
        options: ['Loss of balance', 'Myelin production around neural circuits', 'Immediate tooth decay', 'Decreased blood circulation'],
        correctIndex: 1,
        explanation: 'Deep immersion stimulates myelin production that strengthens neural circuits.',
      },
    ],
    outputPrompt: {
      instruction: 'Share your perspective on how you minimize distractions when studying or working. Use at least two target words (distraction, concentration, immersion, discipline).',
      requiredWordCount: 25,
      recommendedTargetWords: ['distraction', 'concentration', 'discipline'],
      sampleResponse: 'I eliminate every distraction by leaving my phone in another room before studying. It takes real discipline at first, but my concentration improves significantly and I absorb new vocabulary faster.',
    },
  },
  {
    id: 'article-b2-designing-cities',
    title: 'Designing Resilient Cities of Tomorrow',
    level: 'B2',
    topic: 'Urban Innovation & Sustainability',
    readingTimeMin: 4,
    wordCount: 228,
    summary: 'How architects and urban planners are reimagining metropolitan spaces for climate resilience and human wellbeing.',
    content: `Across the globe, 21st-century cities are confronting unprecedented pressures. Rapid urbanization, extreme climate events, and rising temperatures are forcing civil engineers to fundamentally reconsider urban design. The conventional philosophy of erecting steel and concrete barriers is giving way to ecological engineering.

Leading metropolises are prioritizing pedestrian-first infrastructure. By converting wide vehicular thoroughfares into green corridors lined with native trees, cities achieve multiple objectives simultaneously: they reduce the urban heat island effect, foster urban biodiversity, and encourage active transportation. In Copenhagen and Amsterdam, dedicated cycling highways have made two-wheeled commuting faster than driving.

Furthermore, sponge-city concepts—pioneered in Asian and Scandinavian urban centers—replace impermeable tarmac with bioswales and permeable pavements. During torrential downpours, these systems absorb excess rainfall rather than overwhelming municipal sewage networks. 

Transforming legacy infrastructure requires political resolve and substantial capital investment. However, forward-thinking urbanists argue that the cost of inaction far exceeds the price of modernization. A truly sustainable city must be both ecologically resilient and socially inclusive.`,
    vocabulary: [
      { word: 'unprecedented', definition: 'Never done or known before; without parallel.', partOfSpeech: 'adjective', sampleSentence: 'The storm brought an unprecedented volume of rainfall to the valley.' },
      { word: 'pedestrian', definition: 'Relating to people walking along a road or in an area.', partOfSpeech: 'adjective', sampleSentence: 'The city transformed the busy shopping avenue into a pedestrian zone.' },
      { word: 'biodiversity', definition: 'The variety of plant and animal life in a particular habitat.', partOfSpeech: 'noun', sampleSentence: 'Planting native trees helps restore urban biodiversity.' },
      { word: 'infrastructure', definition: 'The basic physical systems of a country or city, such as roads, bridges, and utilities.', partOfSpeech: 'noun', sampleSentence: 'Upgrading transportation infrastructure is critical for economic growth.' },
      { word: 'resilient', definition: 'Able to withstand or recover quickly from difficult conditions.', partOfSpeech: 'adjective', sampleSentence: 'The coastal town built resilient seawalls to protect against erosion.' },
    ],
    questions: [
      {
        id: 'q1',
        question: 'What is the primary objective of "sponge-city" design principles?',
        options: ['Building skyscrapers made of foam', 'Absorbing excess rainfall through permeable surfaces and bioswales', 'Eliminating all parks from downtown', 'Banning bicycles'],
        correctIndex: 1,
        explanation: 'Sponge cities use bioswales and permeable pavements to absorb rainwater rather than overwhelming sewers.',
      },
      {
        id: 'q2',
        question: 'What positive side effects occur when roads are converted to green pedestrian corridors?',
        options: ['Decreased fuel prices only', 'Reduced urban heat island effect, enhanced biodiversity, and increased active transport', 'Total loss of internet connection', 'Higher parking fees'],
        correctIndex: 1,
        explanation: 'Green corridors reduce heat, support local wildlife, and encourage walking and cycling.',
      },
    ],
    outputPrompt: {
      instruction: 'If you were mayor of your city for one month, what change would you make to improve public spaces? Use at least two target words (pedestrian, infrastructure, resilient, biodiversity, unprecedented).',
      requiredWordCount: 30,
      recommendedTargetWords: ['pedestrian', 'infrastructure', 'resilient'],
      sampleResponse: 'If I were mayor, I would invest heavily in pedestrian-friendly infrastructure by converting crowded downtown streets into leafy walkways. Creating resilient green corridors would reduce pollution and make community life much more vibrant.',
    },
  },
  {
    id: 'article-c1-how-memory-shapes-language',
    title: 'How Memory Consolidation Shapes Language Acquisition',
    level: 'C1',
    topic: 'Cognitive Neuroscience & SLA',
    readingTimeMin: 5,
    wordCount: 260,
    summary: 'The neurobiological mechanisms of spaced retrieval, synaptic plasticity, and automatic speech production.',
    content: `Second language acquisition is fundamentally an exercise in structural neuroplasticity. When a learner encounters a novel lexical item, the hippocampus acts as a temporary indexing buffer, encoding phonological and semantic representations. However, this nascent memory trace remains acutely vulnerable to interference and decay without systematic consolidation.

Cognitive psychology differentiates between passive exposure and active retrieval practice. As demonstrated by Karpicke and Roediger (2008), the act of retrieving an item from long-term memory produces significantly stronger retrieval pathways than repeated passive review. Each effortful recall event induces long-term potentiation at synaptic junctions, effectively migrating lexical knowledge from hippocampal dependence to distributed neocortical networks.

This consolidation process is intimately coupled with slow-wave sleep. During non-REM sleep phases, the brain replays neural firing sequences observed during daytime learning, integrating newly acquired syntax and idioms into existing semantic schema. Without sufficient sleep and properly spaced intervals, lexical access speed plateaus.

Ultimately, communicative fluency emerges when retrieval latency approaches zero. In psycholinguistics, this transition is termed automaticity: grammatical concord and phonological assembly occur beneath conscious working memory constraints, liberating attentional bandwidth for nuanced communicative intent.`,
    vocabulary: [
      { word: 'neuroplasticity', definition: 'The ability of the brain to form and reorganize synaptic connections, especially in response to learning.', partOfSpeech: 'noun', sampleSentence: 'Adult neuroplasticity allows individuals to acquire complex foreign languages at any age.' },
      { word: 'consolidation', definition: 'The neurobiological process of stabilizing a memory trace after initial acquisition.', partOfSpeech: 'noun', sampleSentence: 'Sleep plays an irreplaceable role in memory consolidation.' },
      { word: 'retrieval', definition: 'The cognitive act of recalling or accessing stored information from memory.', partOfSpeech: 'noun', sampleSentence: 'Active retrieval builds far more durable memories than passive rereading.' },
      { word: 'automaticity', definition: 'The ability to perform actions or process language without deliberate conscious effort.', partOfSpeech: 'noun', sampleSentence: 'Consistent shadowing accelerates speaking automaticity.' },
      { word: 'bandwidth', definition: 'Cognitive capacity or mental resources available for processing information.', partOfSpeech: 'noun', sampleSentence: 'Mastering grammar frees up mental bandwidth for expressive storytelling.' },
    ],
    questions: [
      {
        id: 'q1',
        question: 'Which brain region serves as the temporary indexing buffer before neocortical consolidation?',
        options: ['The cerebellum', 'The hippocampus', 'The occipital lobe', 'The pituitary gland'],
        correctIndex: 1,
        explanation: 'The hippocampus temporarily indexes and buffers new memories prior to neocortical migration.',
      },
      {
        id: 'q2',
        question: 'What defines the concept of "automaticity" in psycholinguistic speech production?',
        options: ['Speaking at 400 words per minute', 'Operating beneath conscious working memory constraints to free attentional bandwidth', 'Memorizing an entire dictionary', 'Only using slang'],
        correctIndex: 1,
        explanation: 'Automaticity allows speech mechanics to occur effortlessly without consuming working memory.',
      },
    ],
    outputPrompt: {
      instruction: 'Explain why cramming vocabulary right before an exam often fails compared to spaced practice. Use at least two target words (retrieval, consolidation, automaticity, bandwidth).',
      requiredWordCount: 35,
      recommendedTargetWords: ['retrieval', 'consolidation', 'automaticity'],
      sampleResponse: 'Cramming fails because memory consolidation requires distributed intervals and restorative sleep to stabilize neural pathways. Without repeated active retrieval over time, learners never attain speech automaticity, leaving their working memory overloaded during real conversation.',
    },
  },
  {
    id: 'article-c2-subtle-cadence-of-rhetoric',
    title: 'The Subtle Cadence of Rhetoric',
    level: 'C2',
    topic: 'Linguistic Philosophy & Stylistics',
    readingTimeMin: 5,
    wordCount: 295,
    summary: 'Examining the interplay between rhythm, syntactic parsimony, and emotional resonance in masterful discourse.',
    content: `True linguistic mastery transcends mere grammatical correctness; it resides in the elusive equilibrium between syntactic economy and emotive cadence. While novice communicators often equate eloquence with lexical grandiosity, the most enduring prose derives its power from disciplined restraint and deliberate architectural cadence.

Consider the acoustic architecture of speech. In spoken discourse, pauses are not vacuous lacunae; they are pregnant intervals that orchestrate anticipation and lend gravitas to preceding utterances. A master orator modulates pace with musical sensibility, alternating between crisp staccato assertions and undulating periodic sentences. This rhythmic variation engages the listener\'s phonological loop, preventing auditory fatigue and sustaining empathetic resonance.

Furthermore, masterful rhetoric demonstrates acute sensitivity to register and subtext. It exploits the inherent tension between denotation and connotation, deploying metaphor not as ornamental embellishment, but as an indispensable cognitive bridge between disparate conceptual domains. In the hands of a deft speaker, an unvarnished monosyllabic phrase can pierce through rhetorical noise with devastating clarity.

To cultivate this caliber of expression, learners must immerse themselves in high-fidelity stylistic models. By interrogating why certain phrases linger while others evaporate into insignificance, one begins to appreciate that language is neither a passive conduit of data nor a mechanical puzzle, but a dynamic acoustic sculpture shaped by human consciousness.`,
    vocabulary: [
      { word: 'cadence', definition: 'A rhythmic sequence or flow of sounds in language or poetry.', partOfSpeech: 'noun', sampleSentence: 'The hypnotic cadence of his voice captivated the entire auditorium.' },
      { word: 'gravitas', definition: 'Dignity, seriousness, or solemnity of manner.', partOfSpeech: 'noun', sampleSentence: 'Her thoughtful pauses endowed her argument with exceptional gravitas.' },
      { word: 'resonance', definition: 'The quality of evoking enduring emotions or sympathetic vibrations.', partOfSpeech: 'noun', sampleSentence: 'The speech achieved profound emotional resonance across diverse cultures.' },
      { word: 'parsimony', definition: 'Extreme economy or frugal precision in the use of resources or words.', partOfSpeech: 'noun', sampleSentence: 'Stylistic parsimony lends every single word unmistakable purpose.' },
      { word: 'ornamental', definition: 'Serving an aesthetic or decorative purpose rather than a functional one.', partOfSpeech: 'adjective', sampleSentence: 'Avoid ornamental jargon when plain language expresses the truth more vividly.' },
    ],
    questions: [
      {
        id: 'q1',
        question: 'According to the author, where does true linguistic mastery reside?',
        options: ['In using five-syllable Latinate words exclusively', 'In the equilibrium between syntactic economy and emotive cadence', 'In speaking as rapidly as possible without pausing', 'In strict compliance with 18th-century manuals'],
        correctIndex: 1,
        explanation: 'The opening paragraph articulates that mastery is found in the balance of syntactic economy and emotive cadence.',
      },
      {
        id: 'q2',
        question: 'What psychological function do deliberate pauses serve in spoken rhetoric?',
        options: ['They indicate memory loss', 'They allow the speaker to check their watch', 'They orchestrate anticipation, convey gravitas, and prevent listener fatigue', 'They encourage audience interruption'],
        correctIndex: 2,
        explanation: 'Pauses orchestrate anticipation, convey gravitas, and keep the listener\'s phonological loop engaged.',
      },
    ],
    outputPrompt: {
      instruction: 'Reflect upon a speaker or text that left an enduring impression on you. Analyze what gave their words such power. Use at least two target words (cadence, gravitas, resonance, parsimony, ornamental).',
      requiredWordCount: 40,
      recommendedTargetWords: ['cadence', 'resonance', 'gravitas'],
      sampleResponse: 'A keynote speaker I admired spoke with striking parsimony, avoiding ornamental filler entirely. Her deliberate cadence gave each insight weight, while the authentic gravitas of her delivery created an emotional resonance that lingered with me long after she concluded.',
    },
  },
];

export class ContentService {
  public constructor(
    private readonly database: PrismaClient,
    private readonly env?: AppEnv,
  ) {}

  public getArticles(level?: string): ContentArticle[] {
    if (!level || level === 'all') return ARTICLES;
    const normalized = level.toUpperCase();
    return ARTICLES.filter((article) => article.level === normalized);
  }

  public getArticle(id: string): ContentArticle {
    const found = ARTICLES.find((article) => article.id === id);
    if (!found) {
      throw new AppError(404, 'ARTICLE_NOT_FOUND', `Article with id '${id}' was not found.`);
    }
    return found;
  }

  public async evaluateOutput(userId: string, articleId: string, outputText: string): Promise<OutputEvaluationResult> {
    const article = this.getArticle(articleId);
    const cleaned = outputText.trim();
    if (cleaned.length < 5) {
      throw new AppError(400, 'OUTPUT_TOO_SHORT', 'Please provide a response of at least 5 characters.');
    }

    const words = cleaned.split(/\s+/).filter(Boolean);
    const wordCount = words.length;
    const sentences = cleaned.split(/[.!?]+/).map((s) => s.trim()).filter(Boolean);
    const sentenceCount = Math.max(1, sentences.length);

    // Identify target words used (matching lemma or prefix)
    const lowerText = cleaned.toLowerCase();
    const targetWordsUsed: string[] = [];
    const targetWordsMissing: string[] = [];

    for (const item of article.vocabulary) {
      const root = item.word.toLowerCase();
      // Match whole word or common inflected forms (e.g. fresh, freshly; curious, curiosity)
      const stem = root.length > 5 ? root.slice(0, -2) : root;
      if (lowerText.includes(stem)) {
        targetWordsUsed.push(item.word);
      } else {
        targetWordsMissing.push(item.word);
      }
    }

    // Vocabulary score: 0 to 100 based on target vocabulary and minimum length
    const minTargetRequired = Math.min(article.outputPrompt.recommendedTargetWords.length, 2);
    const targetRatio = Math.min(1.0, targetWordsUsed.length / minTargetRequired);
    const lengthRatio = Math.min(1.0, wordCount / article.outputPrompt.requiredWordCount);
    const vocabularyScore = Math.round(targetRatio * 60 + lengthRatio * 40);

    // Grammar score: sentence structure, variety, capitalization
    let grammarDeductions = 0;
    if (sentences.some((s) => s.length > 0 && s[0] !== s[0]?.toUpperCase())) {
      grammarDeductions += 10;
    }
    if (wordCount < article.outputPrompt.requiredWordCount) {
      grammarDeductions += 15;
    }
    if (sentenceCount < 2) {
      grammarDeductions += 10;
    }
    const grammarScore = Math.max(40, Math.min(100, 100 - grammarDeductions));

    const overallScore = Math.round(vocabularyScore * 0.6 + grammarScore * 0.4);

    const strengths: string[] = [];
    const suggestions: string[] = [];

    if (targetWordsUsed.length > 0) {
      strengths.push(`Successfully integrated ${targetWordsUsed.length} target vocabulary word(s): ${targetWordsUsed.join(', ')}.`);
    }
    if (wordCount >= article.outputPrompt.requiredWordCount) {
      strengths.push(`Met the target output length with ${wordCount} words across ${sentenceCount} complete sentence(s).`);
    } else {
      suggestions.push(`Expand your response slightly. Aim for at least ${article.outputPrompt.requiredWordCount} words to practice richer syntax.`);
    }

    if (targetWordsMissing.length > 0 && targetWordsUsed.length < minTargetRequired) {
      suggestions.push(`Try incorporating more target vocabulary, such as: ${targetWordsMissing.slice(0, 2).join(', ')}.`);
    }

    // Recast construction (Swain Output Hypothesis feedback via System Two Gemini 3.5 Flash-Lite)
    let recast = `Refined model: "${cleaned} This demonstrated clear engagement with the theme of ${article.topic.toLowerCase()}."`;
    if (this.env?.googleApiKey) {
      try {
        const liveRecast = await this.generateGeminiRecast(article, cleaned);
        if (liveRecast) recast = liveRecast;
      } catch {
        // Fall back gracefully
      }
    }

    // Optionally record skill progress in database if user exists
    if (userId) {
      try {
        await this.database.skillSnapshot.create({
          data: {
            userId,
            skill: 'comprehension_output',
            value: overallScore,
            source: article.id,
          },
        });
      } catch {
        // Non-blocking snapshot recording
      }
    }

    return {
      articleId: article.id,
      wordCount,
      sentenceCount,
      targetWordsUsed,
      targetWordsMissing,
      grammarScore,
      vocabularyScore,
      overallScore,
      strengths,
      suggestions,
      recast,
    };
  }

  private async generateGeminiRecast(article: ContentArticle, userText: string): Promise<string | null> {
    const apiKey = this.env?.googleApiKey;
    if (!apiKey) return null;
    const model = this.env?.geminiModel || 'gemini-3.5-flash-lite';
    const prompt = `You are a warm English linguistics coach.
The learner wrote an output response for the reading piece "${article.title}" (topic: ${article.topic}):
"${userText}"
Provide a single refined, natural-sounding recast sentence expressing their intended meaning with fluent phrasing and target vocabulary. Return ONLY the recast sentence.`;

    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [{ role: 'user', parts: [{ text: prompt }] }],
          generationConfig: { maxOutputTokens: 120, temperature: 0.6 },
        }),
        signal: AbortSignal.timeout(3000),
      },
    );

    if (response.ok) {
      const data = (await response.json()) as {
        candidates?: Array<{ content?: { parts?: Array<{ text?: string }> } }>;
      };
      const text = data.candidates?.[0]?.content?.parts?.[0]?.text?.trim();
      if (text) return `Refined model: "${text.replace(/^"|"$/g, '')}"`;
    }
    return null;
  }
}
