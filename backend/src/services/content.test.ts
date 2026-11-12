import assert from 'node:assert/strict';
import test from 'node:test';

import { ContentService } from './content-service.js';

const mockPrisma = {
  skillSnapshot: {
    create: async () => ({ id: 'snap-1' }),
  },
} as any;

test('content service returns articles and filters by CEFR level', () => {
  const service = new ContentService(mockPrisma);
  const allArticles = service.getArticles();
  assert.equal(allArticles.length, 6);

  const a1Articles = service.getArticles('A1');
  assert.equal(a1Articles.length, 1);
  assert.equal(a1Articles[0]?.id, 'article-a1-market-morning');

  const b2Articles = service.getArticles('b2');
  assert.equal(b2Articles.length, 1);
  assert.equal(b2Articles[0]?.level, 'B2');
});

test('content service retrieves specific article details and handles 404', () => {
  const service = new ContentService(mockPrisma);
  const article = service.getArticle('article-b1-science-of-deep-work');

  assert.equal(article.title, 'The Science of Deep Work');
  assert.ok(article.vocabulary.length >= 4);
  assert.ok(article.questions.length >= 2);
  assert.ok(article.outputPrompt.requiredWordCount > 0);

  assert.throws(() => service.getArticle('non-existent-id'), {
    message: /not found/i,
  });
});

test('content service evaluates learner output text with target vocabulary and scoring', async () => {
  const service = new ContentService(mockPrisma);
  const result = await service.evaluateOutput(
    'user-1',
    'article-a1-market-morning',
    'I love visiting the food stalls every Saturday morning. They always sell fresh vegetables and delicious bread for breakfast.',
  );

  assert.equal(result.articleId, 'article-a1-market-morning');
  assert.ok(result.wordCount >= 15);
  assert.ok(result.sentenceCount >= 2);
  assert.ok(result.targetWordsUsed.includes('stall'));
  assert.ok(result.targetWordsUsed.includes('fresh'));
  assert.ok(result.targetWordsUsed.includes('delicious'));
  assert.ok(result.vocabularyScore >= 80);
  assert.ok(result.mechanicsScore >= 80);
  assert.ok(result.overallScore >= 80);
  assert.ok(result.strengths.length > 0);
  assert.equal(result.recast, null);
});
