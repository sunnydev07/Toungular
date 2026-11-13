import 'package:flutter_test/flutter_test.dart';
import 'package:toungular/shared/models/learning_models.dart';

void main() {
  test('CoachTurnReceipt parses turnGate and errorCategory for phrasing tips', () {
    final receipt = CoachTurnReceipt.fromJson(<String, Object?>{
      'turn': <String, Object?>{
        'id': 'turn-1',
        'role': 'user',
        'text': 'I have go to the store yesterday.',
        'createdAt': DateTime.now().toIso8601String(),
      },
      'replyTurn': <String, Object?>{
        'id': 'turn-2',
        'role': 'assistant',
        'text': 'I see! You went to the store yesterday. What did you buy?',
        'createdAt': DateTime.now().toIso8601String(),
      },
      'practiceCue': 'Describe what you bought.',
      'recast': 'I went to the store yesterday.',
      'turnGate': <String, Object?>{
        'needsRecast': true,
        'isOffTopic': false,
        'errorCategory': 'past tense irregular',
        'suggestedSteer': 'Ask about items purchased',
      },
    });

    expect(receipt.turn.text, 'I have go to the store yesterday.');
    expect(receipt.replyTurn?.text, contains('went to the store'));
    expect(receipt.recast, 'I went to the store yesterday.');
    expect(receipt.turnGate, isNotNull);
    expect(receipt.turnGate?.needsRecast, true);
    expect(receipt.turnGate?.isOffTopic, false);
    expect(receipt.turnGate?.errorCategory, 'past tense irregular');
  });
}
