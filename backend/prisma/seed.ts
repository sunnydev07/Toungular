import { prisma } from '../src/lib/prisma.js';

const courses = [
  { id: 'clear-start', title: 'Clear Start', description: 'Build calm, useful English for daily introductions and requests.', level: 'beginner', position: 1 },
  { id: 'steady-conversation', title: 'Steady Conversation', description: 'Keep everyday conversations moving with detail and follow-up questions.', level: 'elementary', position: 2 },
  { id: 'confident-expression', title: 'Confident Expression', description: 'Explain opinions, plans, and experiences with more precise language.', level: 'intermediate', position: 3 },
];

const lessons = [
  ['clear-start-01', 'clear-start', 'Introduce yourself with one detail', 'Say your name, where you are from, and one thing you enjoy.', 'Name + place + interest. Keep each part short and clear.', 6, 1],
  ['clear-start-02', 'clear-start', 'Ask for everyday help', 'Make a polite request and respond when someone helps.', 'Use “Could you…?” and “Thank you, that helps.”', 7, 2],
  ['clear-start-03', 'clear-start', 'Talk about your routine', 'Describe a normal weekday in time order.', 'Start with morning, then midday, then evening.', 7, 3],
  ['clear-start-04', 'clear-start', 'Choose the right question word', 'Ask clear questions about people, places, time, and reasons.', 'Match who, where, when, and why to the missing information.', 6, 4],
  ['clear-start-05', 'clear-start', 'Give simple directions', 'Help someone find a nearby place.', 'Use landmarks and one instruction at a time.', 7, 5],
  ['clear-start-06', 'clear-start', 'Make a friendly plan', 'Invite someone and agree on a time.', 'Offer a time, ask if it works, then confirm.', 7, 6],
  ['steady-conversation-01', 'steady-conversation', 'Add useful detail', 'Expand a short answer with a reason or example.', 'Use “because,” “for example,” and one concrete detail.', 8, 1],
  ['steady-conversation-02', 'steady-conversation', 'Show that you are listening', 'Respond to another person before adding your view.', 'Reflect one key word, then ask a follow-up.', 8, 2],
  ['steady-conversation-03', 'steady-conversation', 'Describe a recent experience', 'Tell a short story with a beginning, change, and result.', 'Use past-time markers so the listener can follow.', 9, 3],
  ['steady-conversation-04', 'steady-conversation', 'Compare two choices', 'Explain which option you prefer and why.', 'Name one benefit and one trade-off.', 8, 4],
  ['steady-conversation-05', 'steady-conversation', 'Solve a small misunderstanding', 'Clarify what you meant without sounding defensive.', 'Pause, restate your point, and check understanding.', 8, 5],
  ['steady-conversation-06', 'steady-conversation', 'End a conversation warmly', 'Close a conversation and leave a clear next step.', 'Thank the person, mention the next action, and say goodbye.', 6, 6],
  ['confident-expression-01', 'confident-expression', 'Explain an opinion', 'State a view, support it, and acknowledge another view.', 'Use a reason, an example, and a respectful contrast.', 10, 1],
  ['confident-expression-02', 'confident-expression', 'Talk through a challenge', 'Describe a problem and the action you took.', 'Focus on the situation, choice, and result.', 10, 2],
  ['confident-expression-03', 'confident-expression', 'Present a practical idea', 'Propose an improvement to a familiar situation.', 'Make the benefit specific and invite a response.', 10, 3],
  ['confident-expression-04', 'confident-expression', 'Use precise connectors', 'Link ideas without repeating the same transition.', 'Practice contrast, result, addition, and sequence connectors.', 9, 4],
  ['confident-expression-05', 'confident-expression', 'Handle a polite disagreement', 'Disagree clearly while keeping the conversation constructive.', 'Recognize the other point before presenting yours.', 10, 5],
  ['confident-expression-06', 'confident-expression', 'Reflect on progress', 'Describe what has improved and what you will practice next.', 'Use one past example and one realistic next step.', 9, 6],
] as const;

const vocabulary = [
  ['adapt', 'verb', 'change to fit a new situation', 'I can adapt my plan when the meeting moves.', 'intermediate'],
  ['approach', 'noun', 'a way of dealing with a task or problem', 'Her approach to practice is short and regular.', 'intermediate'],
  ['arrange', 'verb', 'plan or organize something', 'We arranged a call for Friday afternoon.', 'elementary'],
  ['attentive', 'adjective', 'carefully listening or watching', 'The attentive listener noticed the main concern.', 'intermediate'],
  ['avoid', 'verb', 'keep away from something', 'Try to avoid rushing through your answer.', 'elementary'],
  ['benefit', 'noun', 'a helpful result or advantage', 'A benefit of walking is extra thinking time.', 'elementary'],
  ['brief', 'adjective', 'short in time or length', 'Give a brief example before your main point.', 'elementary'],
  ['clarify', 'verb', 'make an idea easier to understand', 'Could you clarify what you mean by flexible?', 'intermediate'],
  ['comfortable', 'adjective', 'relaxed and not worried', 'After practice, she felt comfortable speaking first.', 'beginner'],
  ['concern', 'noun', 'a worry or important matter', 'Cost was their main concern.', 'intermediate'],
  ['confirm', 'verb', 'say that something is correct or definite', 'Please confirm the time before you travel.', 'elementary'],
  ['connect', 'verb', 'join ideas or people together', 'Connect your example to your main opinion.', 'elementary'],
  ['consider', 'verb', 'think carefully about something', 'Consider both options before deciding.', 'intermediate'],
  ['consistent', 'adjective', 'happening in the same reliable way', 'Consistent practice builds confidence.', 'intermediate'],
  ['contribute', 'verb', 'give ideas, effort, or resources to help', 'Everyone can contribute one useful suggestion.', 'intermediate'],
  ['curious', 'adjective', 'wanting to know more', 'Stay curious and ask one follow-up question.', 'elementary'],
  ['decline', 'verb', 'politely say no to an offer', 'I had to decline because I was already busy.', 'intermediate'],
  ['describe', 'verb', 'say what someone or something is like', 'Describe the place using two clear details.', 'beginner'],
  ['detail', 'noun', 'a small but important piece of information', 'That detail makes your story easier to picture.', 'beginner'],
  ['discuss', 'verb', 'talk about something with another person', 'We discussed the plan after lunch.', 'elementary'],
  ['effective', 'adjective', 'producing the result you want', 'A simple outline is effective for a short talk.', 'intermediate'],
  ['encourage', 'verb', 'give someone support or confidence', 'Her teacher encouraged her to speak slowly.', 'elementary'],
  ['estimate', 'verb', 'make a careful rough judgment', 'Can you estimate how long the trip will take?', 'intermediate'],
  ['example', 'noun', 'something that shows what you mean', 'Give one example from your own week.', 'beginner'],
  ['exchange', 'noun', 'a short conversation where people share ideas', 'Their exchange ended with a clear decision.', 'intermediate'],
  ['flexible', 'adjective', 'able to change when needed', 'Our schedule is flexible this week.', 'intermediate'],
  ['focus', 'verb', 'give attention to one thing', 'Focus on one idea in each sentence.', 'beginner'],
  ['follow-up', 'noun', 'a later question or action after an earlier one', 'Ask a follow-up to keep the conversation going.', 'intermediate'],
  ['frequent', 'adjective', 'happening often', 'Frequent short reviews are easier to maintain.', 'intermediate'],
  ['goal', 'noun', 'something you are trying to achieve', 'My goal is to speak for two minutes clearly.', 'beginner'],
  ['gradual', 'adjective', 'happening slowly over time', 'Fluency usually comes through gradual improvement.', 'intermediate'],
  ['hesitate', 'verb', 'pause because you are unsure', 'Do not hesitate to ask for repetition.', 'intermediate'],
  ['identify', 'verb', 'recognize and name something', 'Identify the speaker’s main reason.', 'intermediate'],
  ['improve', 'verb', 'become better', 'You can improve by recording one answer each day.', 'beginner'],
  ['include', 'verb', 'make something part of a group or plan', 'Include one reason with your opinion.', 'elementary'],
  ['indicate', 'verb', 'show or point out', 'Her pause may indicate that she needs more time.', 'intermediate'],
  ['influence', 'verb', 'affect the way something develops', 'Sleep can influence how easily you concentrate.', 'intermediate'],
  ['informal', 'adjective', 'relaxed rather than official', 'An informal greeting works well with a friend.', 'elementary'],
  ['intend', 'verb', 'plan or mean to do something', 'I intend to finish the lesson tonight.', 'intermediate'],
  ['invite', 'verb', 'ask someone to join or attend', 'Invite your classmate to practice with you.', 'elementary'],
  ['justify', 'verb', 'give reasons that support a choice', 'Justify your choice with a real example.', 'advanced'],
  ['likely', 'adjective', 'probably going to happen', 'It is likely to rain this evening.', 'elementary'],
  ['maintain', 'verb', 'keep something at the same level or condition', 'Maintain eye contact when you speak.', 'intermediate'],
  ['manage', 'verb', 'succeed in doing something difficult', 'She managed to explain the problem calmly.', 'elementary'],
  ['mention', 'verb', 'say something briefly', 'Mention the date when you tell the story.', 'elementary'],
  ['notice', 'verb', 'see or become aware of something', 'Notice which words you repeat most often.', 'beginner'],
  ['observe', 'verb', 'watch carefully to learn something', 'Observe how the speaker connects each idea.', 'intermediate'],
  ['opportunity', 'noun', 'a useful chance to do something', 'The workshop is an opportunity to meet new people.', 'intermediate'],
  ['organize', 'verb', 'arrange things in a useful order', 'Organize your answer into three parts.', 'elementary'],
  ['participate', 'verb', 'take part in something', 'Everyone was invited to participate in the discussion.', 'intermediate'],
  ['patient', 'adjective', 'able to stay calm while waiting', 'Be patient while you search for the right word.', 'elementary'],
  ['perspective', 'noun', 'a particular way of seeing a situation', 'Try to understand the issue from her perspective.', 'advanced'],
  ['polite', 'adjective', 'showing respect and good manners', 'Use a polite question when you need help.', 'beginner'],
  ['prepare', 'verb', 'get ready for something', 'Prepare two points before the conversation.', 'beginner'],
  ['priority', 'noun', 'the thing that is most important', 'Clear communication is our first priority.', 'intermediate'],
  ['progress', 'noun', 'improvement over time', 'Small daily steps lead to visible progress.', 'beginner'],
  ['prompt', 'noun', 'a cue that tells you what to say or do', 'Use the prompt to begin your response.', 'intermediate'],
  ['provide', 'verb', 'give something that is needed', 'Please provide one detail about your plan.', 'elementary'],
  ['purpose', 'noun', 'the reason something is done', 'The purpose of the question is to learn more.', 'intermediate'],
  ['recommend', 'verb', 'suggest something as a good choice', 'I recommend starting with a short daily goal.', 'intermediate'],
  ['reflect', 'verb', 'think carefully about an experience', 'Reflect on what made the conversation easier.', 'intermediate'],
  ['relevant', 'adjective', 'connected to the topic being discussed', 'Choose an example that is relevant to your point.', 'intermediate'],
  ['reliable', 'adjective', 'able to be trusted to work well', 'A reliable routine is better than a perfect plan.', 'intermediate'],
  ['respond', 'verb', 'answer or react to someone', 'Respond to the question before adding a new idea.', 'beginner'],
  ['routine', 'noun', 'a regular way of doing things', 'Reading aloud is part of my evening routine.', 'beginner'],
  ['schedule', 'noun', 'a plan that shows times for activities', 'Check the schedule before you agree to meet.', 'elementary'],
  ['select', 'verb', 'choose from several options', 'Select the clearest example for your answer.', 'intermediate'],
  ['similar', 'adjective', 'almost the same', 'The two ideas are similar but not identical.', 'elementary'],
  ['specific', 'adjective', 'clear and exact', 'Be specific about what you want to practice.', 'intermediate'],
  ['strategy', 'noun', 'a careful plan for reaching a goal', 'Repeating the key point is a useful strategy.', 'intermediate'],
  ['suggest', 'verb', 'offer an idea for consideration', 'I suggest meeting ten minutes earlier.', 'elementary'],
  ['support', 'verb', 'help or give strength to an idea', 'Support your opinion with a short reason.', 'intermediate'],
  ['tackle', 'verb', 'try to deal with a difficult task', 'We can tackle one speaking habit at a time.', 'intermediate'],
  ['topic', 'noun', 'the subject being discussed', 'Stay on the topic until your point is complete.', 'beginner'],
  ['trade-off', 'noun', 'a balance where gaining one thing means losing another', 'The trade-off is speed versus detail.', 'advanced'],
  ['translate', 'verb', 'change words from one language into another', 'Do not translate every sentence in your head.', 'elementary'],
  ['useful', 'adjective', 'helpful for a practical purpose', 'Keep a list of useful phrases for calls.', 'beginner'],
  ['variety', 'noun', 'a range of different things', 'A variety of examples makes practice interesting.', 'intermediate'],
  ['verify', 'verb', 'check that something is true or correct', 'Verify the address before you send the message.', 'intermediate'],
  ['willing', 'adjective', 'ready to do something', 'She is willing to try a new conversation topic.', 'elementary'],
] as const;

async function seed(): Promise<void> {
  for (const course of courses) {
    await prisma.course.upsert({ where: { id: course.id }, update: course, create: course });
  }
  for (const [id, courseId, title, summary, content, durationMin, position] of lessons) {
    await prisma.lesson.upsert({
      where: { id },
      update: { courseId, title, summary, content, durationMin, position },
      create: { id, courseId, title, summary, content, durationMin, position },
    });
  }
  for (const [word, partOfSpeech, definition, example, level] of vocabulary) {
    const id = `vocab-${word.replaceAll(/[^a-z]/g, '-')}`;
    await prisma.vocabularyItem.upsert({
      where: { id },
      update: { word, partOfSpeech, definition, example, level },
      create: { id, word, partOfSpeech, definition, example, level },
    });
  }
}

seed()
  .then(() => console.info('Toungular curriculum and vocabulary seed completed.'))
  .catch((error: unknown) => {
    console.error('Toungular seed failed.', error);
    process.exitCode = 1;
  })
  .finally(async () => prisma.$disconnect());
