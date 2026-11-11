import type { PrismaClient } from '@prisma/client';

import type { AppEnv } from '../config/env.js';
import { AppError } from '../lib/http.js';

export type CoachScenario = {
  id: string;
  title: string;
  description: string;
  opening: string;
  cue: string;
  category: 'social' | 'travel' | 'work' | 'interview' | 'exam';
  targetTier2Words: string[];
};

const scenarioCatalog: CoachScenario[] = [
  {
    id: 'daily-introduction',
    title: 'Meet someone new',
    description: 'Introduce yourself and keep a first conversation moving.',
    opening: 'Hello! It is great to meet you. To get us started, could you share your name and one hobby or activity you really enjoy?',
    cue: 'Add one reason or example so your listener can picture it.',
    category: 'social',
    targetTier2Words: ['describe', 'routine', 'frequent', 'flexible'],
  },
  {
    id: 'travel-check-in',
    title: 'Check in for a trip',
    description: 'Practice clear, polite travel questions.',
    opening: 'Welcome to Grand Azure Hotel! I see your booking in our system. Before I hand over your key, do you have any questions about breakfast or hotel amenities?',
    cue: 'Ask one follow-up question about a practical detail.',
    category: 'travel',
    targetTier2Words: ['confirm', 'schedule', 'arrange', 'available'],
  },
  {
    id: 'workplace-update',
    title: 'Share a work update',
    description: 'Explain progress, a challenge, and a next step.',
    opening: 'Hi there! Thanks for joining our weekly sync. Could you give a quick update on what you have been working on and any progress made this week?',
    cue: 'Mention one specific result and what you will do next.',
    category: 'work',
    targetTier2Words: ['approach', 'progress', 'effective', 'priority'],
  },
  {
    id: 'job-interview',
    title: 'Answer an interview question',
    description: 'Organize an example into a clear answer.',
    opening: 'Welcome to our interview. We value problem-solving skills here. Could you describe a challenging situation you encountered in the past and how you resolved it?',
    cue: 'Add the action you took and what changed because of it.',
    category: 'interview',
    targetTier2Words: ['tackle', 'strategy', 'justify', 'contribute'],
  },
  {
    id: 'ielts-discussion',
    title: 'Develop an IELTS-style answer',
    description: 'Support an opinion with reasons and examples.',
    opening: 'In Part 3 of the Speaking test, we discuss broader issues. Do you believe individuals learn more effectively when working in teams or when studying independently?',
    cue: 'Acknowledge another view, then explain your own with an example.',
    category: 'exam',
    targetTier2Words: ['perspective', 'benefit', 'trade-off', 'consider'],
  },
];

export class CoachService {
  public constructor(
    private readonly database: PrismaClient,
    private readonly env?: AppEnv,
  ) {}

  public scenarios() {
    return scenarioCatalog.map(({ id, title, description, opening, cue, category }) => ({
      id,
      title,
      description,
      opening,
      cue,
      category,
    }));
  }

  public async start(userId: string, scenarioId: string) {
    const scenario = this.findScenario(scenarioId);
    const conversation = await this.database.conversation.create({
      data: { userId, scenarioId },
      select: { id: true, scenarioId: true, status: true, createdAt: true },
    });

    // Seed the conversation with the coach's opening prompt
    const openingTurn = await this.database.conversationTurn.create({
      data: {
        conversationId: conversation.id,
        role: 'assistant',
        text: scenario.opening,
        transcript: scenario.opening,
      },
      select: { id: true, role: true, text: true, transcript: true, createdAt: true },
    });

    return { ...conversation, scenario, openingTurn };
  }

  public async addTurn(userId: string, id: string, transcript: string) {
    const conversation = await this.findConversation(userId, id);
    if (conversation.status !== 'active') {
      throw new AppError(409, 'CONVERSATION_FINISHED', 'This practice conversation has already ended.');
    }

    // Save learner turn
    const learnerTurn = await this.database.conversationTurn.create({
      data: { conversationId: id, role: 'learner', transcript, text: transcript },
      select: { id: true, role: true, text: true, transcript: true, createdAt: true },
    });

    const previousTurns = await this.database.conversationTurn.findMany({
      where: { conversationId: id },
      orderBy: { createdAt: 'asc' },
      select: { role: true, text: true },
    });

    const scenario = this.findScenario(conversation.scenarioId);
    const { replyText, recast, provider } = await this.generateCoachReply(scenario, previousTurns, transcript);

    // Save assistant reply turn
    const replyTurn = await this.database.conversationTurn.create({
      data: { conversationId: id, role: 'assistant', transcript: replyText, text: replyText },
      select: { id: true, role: true, text: true, transcript: true, createdAt: true },
    });

    const totalCount = await this.database.conversationTurn.count({ where: { conversationId: id } });

    return {
      turn: learnerTurn,
      replyTurn,
      turnsCount: totalCount,
      provider,
      recast,
      practiceCue: scenario.cue,
    };
  }

  public async load(userId: string, id: string) {
    const conversation = await this.database.conversation.findFirst({
      where: { id, userId },
      include: { turns: { orderBy: { createdAt: 'asc' } } },
    });
    if (!conversation) throw new AppError(404, 'CONVERSATION_NOT_FOUND', 'The practice conversation was not found.');
    return { ...conversation, scenario: this.findScenario(conversation.scenarioId) };
  }

  public async finish(userId: string, id: string) {
    const conversation = await this.findConversation(userId, id);
    const turns = await this.database.conversationTurn.findMany({
      where: { conversationId: id },
      orderBy: { createdAt: 'asc' },
    });

    const learnerTurns = turns.filter((t) => t.role === 'learner');
    const totalWords = learnerTurns.reduce((acc, t) => acc + (t.text.match(/\S+/g)?.length ?? 0), 0);
    const avgWordsPerTurn = learnerTurns.length > 0 ? Math.round(totalWords / learnerTurns.length) : 0;

    const scenario = this.findScenario(conversation.scenarioId);
    const summary = `Completed ${learnerTurns.length} spoken responses in "${scenario.title}" with an average of ${avgWordsPerTurn} words per turn. Great effort building real conversational momentum!`;

    const finishedAt = new Date();
    return this.database.conversation.update({
      where: { id },
      data: {
        status: 'completed',
        finishedAt,
        summary,
      },
      select: { id: true, status: true, summary: true, finishedAt: true },
    });
  }

  public async remove(userId: string, id: string): Promise<void> {
    const result = await this.database.conversation.deleteMany({ where: { id, userId } });
    if (result.count === 0) throw new AppError(404, 'CONVERSATION_NOT_FOUND', 'The practice conversation was not found.');
  }

  private async findConversation(userId: string, id: string) {
    const conversation = await this.database.conversation.findFirst({ where: { id, userId } });
    if (!conversation) throw new AppError(404, 'CONVERSATION_NOT_FOUND', 'The practice conversation was not found.');
    return conversation;
  }

  private findScenario(scenarioId: string): CoachScenario {
    const scenario = scenarioCatalog.find((item) => item.id === scenarioId);
    if (!scenario) throw new AppError(404, 'SCENARIO_NOT_FOUND', 'The requested practice scenario was not found.');
    return scenario;
  }

  private async generateCoachReply(
    scenario: CoachScenario,
    turns: Array<{ role: string; text: string }>,
    latestTranscript: string,
  ): Promise<{ replyText: string; recast: string | null; provider: { status: string; name: string } }> {
    // 1. Google Gemini 3.5 Flash-Lite (Primary System Two Generative LLM)
    if (this.env?.googleApiKey) {
      try {
        const result = await this.callGeminiChat(scenario, turns);
        if (result) {
          return {
            ...result,
            provider: {
              status: 'active',
              name: `Google Gemini (${this.env.geminiModel || 'gemini-3.5-flash-lite'})`,
            },
          };
        }
      } catch {
        // Fall back gracefully to secondary provider or heuristics
      }
    }

    // 2. OpenAI GPT (Secondary Generative LLM fallback)
    if (this.env?.openAiApiKey) {
      try {
        const result = await this.callOpenAiChat(scenario, turns);
        if (result) return { ...result, provider: { status: 'active', name: 'OpenAI GPT' } };
      } catch {
        // Fall back gracefully to contextual dialogue engine
      }
    }

    // 3. Heuristic contextual conversational engine (Deterministic offline fallback)
    return this.generateHeuristicReply(scenario, turns, latestTranscript);
  }

  private async callGeminiChat(
    scenario: CoachScenario,
    turns: Array<{ role: string; text: string }>,
  ): Promise<{ replyText: string; recast: string | null } | null> {
    const apiKey = this.env?.googleApiKey;
    if (!apiKey) return null;
    const model = this.env?.geminiModel || 'gemini-3.5-flash-lite';

    const systemPrompt = `You are a supportive, warm English Fluency Coach in Toungular named Luna.
Scenario: "${scenario.title}" (${scenario.description}).
Target learning words: ${scenario.targetTier2Words.join(', ')}.
Rules:
1. Advance the conversation naturally with 2-3 sentences.
2. If the user made a grammar error, subtly recast the correct phrasing into your response without saying "you made a mistake".
3. Always ask one open-ended question to keep the dialogue going.
4. Keep responses encouraging and conversational (max 50 words).`;

    // Try Google Gemini native generateContent API
    try {
      const contents = turns.map((t) => ({
        role: t.role === 'assistant' ? 'model' : 'user',
        parts: [{ text: t.text }],
      }));

      const formattedContents = contents.length > 0 ? contents : [{ role: 'user', parts: [{ text: scenario.opening }] }];

      const response = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            systemInstruction: {
              parts: [{ text: systemPrompt }],
            },
            contents: formattedContents,
            generationConfig: {
              temperature: 0.7,
              maxOutputTokens: 180,
            },
          }),
          signal: AbortSignal.timeout(3500),
        },
      );

      if (response.ok) {
        const data = (await response.json()) as {
          candidates?: Array<{ content?: { parts?: Array<{ text?: string }> } }>;
        };
        const text = data.candidates?.[0]?.content?.parts?.[0]?.text?.trim();
        if (text) {
          return { replyText: text, recast: null };
        }
      }
    } catch {
      // Fall through to OpenAI-compatible endpoint
    }

    // Fallback: Google OpenAI-compatible endpoint
    try {
      const messages = [
        { role: 'system', content: systemPrompt },
        ...turns.map((t) => ({
          role: t.role === 'assistant' ? 'assistant' : 'user',
          content: t.text,
        })),
      ];

      const response = await fetch('https://generativelanguage.googleapis.com/v1beta/openai/chat/completions', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${apiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model,
          messages,
          max_tokens: 180,
          temperature: 0.7,
        }),
        signal: AbortSignal.timeout(3500),
      });

      if (response.ok) {
        const data = (await response.json()) as { choices?: Array<{ message?: { content?: string } }> };
        const content = data.choices?.[0]?.message?.content?.trim();
        if (content) {
          return { replyText: content, recast: null };
        }
      }
    } catch {
      // Allow fallback
    }

    return null;
  }

  private async callOpenAiChat(
    scenario: CoachScenario,
    turns: Array<{ role: string; text: string }>,
  ): Promise<{ replyText: string; recast: string | null } | null> {
    const systemPrompt = `You are a supportive, warm English Fluency Coach in Toungular named Luna.
Scenario: "${scenario.title}" (${scenario.description}).
Target learning words: ${scenario.targetTier2Words.join(', ')}.
Rules:
1. Advance the conversation naturally with 2-3 sentences.
2. If the user made a grammar error, subtly recast the correct phrasing without saying "you made a mistake".
3. Always ask one open-ended question to keep the dialogue going.
4. Keep responses encouraging and conversational (max 50 words).`;

    const messages = [
      { role: 'system', content: systemPrompt },
      ...turns.map((t) => ({
        role: t.role === 'assistant' ? 'assistant' : 'user',
        content: t.text,
      })),
    ];

    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${this.env?.openAiApiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'gpt-4o-mini',
        messages,
        max_tokens: 150,
        temperature: 0.7,
      }),
    });

    if (!response.ok) return null;
    const data = await response.json() as { choices?: Array<{ message?: { content?: string } }> };
    const content = data.choices?.[0]?.message?.content?.trim();
    if (!content) return null;

    return {
      replyText: content,
      recast: null,
    };
  }

  private generateHeuristicReply(
    scenario: CoachScenario,
    turns: Array<{ role: string; text: string }>,
    latestTranscript: string,
  ): { replyText: string; recast: string | null; provider: { status: string; name: string } } {
    const learnerTurnCount = turns.filter((t) => t.role === 'learner').length;
    const lower = latestTranscript.toLowerCase();

    // Check for common ESL phrasing to offer a gentle recast
    let recast: string | null = null;
    if (lower.includes('i am agree')) {
      recast = 'Quick tip: Native speakers say "I agree" rather than "I am agree".';
    } else if (lower.includes('more better')) {
      recast = 'Quick tip: You can say "much better" instead of "more better".';
    }

    const repliesByScenario: Record<string, string[]> = {
      'daily-introduction': [
        "That sounds fascinating! What inspired you to take up that interest in the first place?",
        "I love that. Having a reliable routine for things you enjoy makes such a big difference. How often do you find time for it during the week?",
        "That gives me a vivid picture! If you had to recommend it to a beginner, what is one piece of practical advice you would give them?",
        "You articulated that with great clarity. It has been a pleasure getting to know your perspective!",
      ],
      'travel-check-in': [
        "Certainly! Our breakfast buffet is served on the second floor from 6:30 to 10:00 AM. We also have high-speed Wi-Fi throughout the hotel. Would you like a quiet room facing the courtyard or a city view?",
        "Courtyard room arranged! We also offer an express airport shuttle every half hour. Would you like me to reserve a seat for your departure day?",
        "All noted! Here is your key card on the fifth floor. Elevators are just past the lounge on your right. Enjoy your stay!",
        "You are all set! Have a wonderful and relaxing visit.",
      ],
      'workplace-update': [
        "Thanks for the clear summary. It sounds like the core objectives are progressing well. Did you encounter any unexpected trade-offs or hurdles along the way?",
        "Good strategic thinking on handling that. What is your primary milestone for the coming week to keep the momentum going?",
        "Sounds like an effective plan. Do you anticipate needing any cross-functional collaboration to ensure smooth execution?",
        "Excellent update. Your communication was structured, concise, and easy to follow!",
      ],
      'job-interview': [
        "Thank you for sharing that experience. What specific action did you personally take to turn the situation around?",
        "That demonstrates strong initiative and resilience. Looking back, what was the most valuable lesson you took away from that challenge?",
        "Insightful reflection. How does that lesson inform the way you collaborate with your colleagues today?",
        "Thank you for that thorough and convincing answer. You presented your skills and problem-solving process very effectively.",
      ],
      'ielts-discussion': [
        "That is a thoughtful viewpoint. Some argue that collaborative work fosters interpersonal skills, while independent study sharpens deep analytical focus. How do you weigh those two aspects?",
        "Very well reasoned. In your observation, how has modern remote technology influenced the balance between teamwork and independent work?",
        "A compelling perspective. If you look ahead to the next decade, do you anticipate education shifting even further toward collaborative models?",
        "Outstanding discussion! You supported your arguments with concrete reasoning and nuanced vocabulary.",
      ],
    };

    const scenarioReplies = repliesByScenario[scenario.id] ?? repliesByScenario['daily-introduction']!;
    const index = Math.min(learnerTurnCount - 1, scenarioReplies.length - 1);
    const replyText = scenarioReplies[index] ?? "That's a very interesting point! Could you elaborate on what you mean by that?";

    return {
      replyText,
      recast,
      provider: { status: 'active', name: 'Toungular Coach' },
    };
  }
}
