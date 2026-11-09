import type { PrismaClient } from '@prisma/client';

import { AppError } from '../lib/http.js';

const scenarioCatalog = [
  { id: 'daily-introduction', title: 'Meet someone new', description: 'Introduce yourself and keep a first conversation moving.', opening: 'Start with your name and one detail about something you enjoy.', cue: 'Add one reason or example so your listener can picture it.' },
  { id: 'travel-check-in', title: 'Check in for a trip', description: 'Practice clear, polite travel questions.', opening: 'You have arrived at a hotel. Ask about checking in and breakfast.', cue: 'Ask one follow-up question about a practical detail.' },
  { id: 'workplace-update', title: 'Share a work update', description: 'Explain progress, a challenge, and a next step.', opening: 'Give a short update about a task you are working on.', cue: 'Mention one specific result and what you will do next.' },
  { id: 'job-interview', title: 'Answer an interview question', description: 'Organize an example into a clear answer.', opening: 'Tell the interviewer about a time you solved a difficult problem.', cue: 'Add the action you took and what changed because of it.' },
  { id: 'ielts-discussion', title: 'Develop an IELTS-style answer', description: 'Support an opinion with reasons and examples.', opening: 'Do people learn more from working in a team or working alone?', cue: 'Acknowledge another view, then explain your own with an example.' },
] as const;

export class CoachService {
  public constructor(private readonly database: PrismaClient) {}

  public scenarios() {
    return scenarioCatalog.map(({ id, title, description, opening }) => ({ id, title, description, opening }));
  }

  public async start(userId: string, scenarioId: string) {
    const scenario = this.findScenario(scenarioId);
    const conversation = await this.database.conversation.create({
      data: { userId, scenarioId },
      select: { id: true, scenarioId: true, status: true, createdAt: true },
    });
    return { ...conversation, scenario };
  }

  public async addTurn(userId: string, id: string, transcript: string) {
    const conversation = await this.findConversation(userId, id);
    if (conversation.status !== 'active') throw new AppError(409, 'CONVERSATION_FINISHED', 'This practice conversation has already ended.');
    const turn = await this.database.conversationTurn.create({
      data: { conversationId: id, role: 'learner', transcript, text: transcript },
      select: { id: true, role: true, text: true, transcript: true, createdAt: true },
    });
    const count = await this.database.conversationTurn.count({ where: { conversationId: id } });
    const scenario = this.findScenario(conversation.scenarioId);
    return {
      turn,
      turnsCount: count,
      provider: { status: 'unavailable', message: 'Live AI replies are not configured. Your practice response is saved.' },
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
    await this.findConversation(userId, id);
    const turns = await this.database.conversationTurn.count({ where: { conversationId: id } });
    const finishedAt = new Date();
    return this.database.conversation.update({
      where: { id },
      data: {
        status: 'completed',
        finishedAt,
        summary: `${turns} learner response${turns === 1 ? '' : 's'} saved. Live AI feedback is not configured.`,
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

  private findScenario(scenarioId: string) {
    const scenario = scenarioCatalog.find((item) => item.id === scenarioId);
    if (!scenario) throw new AppError(404, 'SCENARIO_NOT_FOUND', 'The requested practice scenario was not found.');
    return scenario;
  }
}
