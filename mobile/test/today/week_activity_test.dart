import 'package:flutter_test/flutter_test.dart';
import 'package:toungular/features/today/week_activity.dart';

void main() {
  // Wednesday 11 November 2026, 15:30 local.
  final now = DateTime(2026, 11, 11, 15, 30);

  group('weekActivity', () {
    test('counts sessions inside the current Monday-Sunday week only', () {
      final result = weekActivity(<DateTime?>[
        DateTime(2026, 11, 9, 9), // Monday, this week
        DateTime(2026, 11, 9, 18), // second session on the same day
        DateTime(2026, 11, 8, 12), // Sunday of the previous week
        DateTime(2026, 11, 11, 9), // earlier today, Wednesday
        null,
      ], now);

      expect(result.sessions, 3);
      expect(result.days, <bool>[
        true,
        false,
        true,
        false,
        false,
        false,
        false,
      ]);
    });

    test('marks today and reports its index', () {
      final result = weekActivity(<DateTime?>[DateTime(2026, 11, 11, 8)], now);

      expect(result.todayIndex, 2); // Wednesday
      expect(result.days[2], isTrue);
    });

    test('ignores timestamps after now', () {
      final result = weekActivity(<DateTime?>[
        DateTime(2026, 11, 11, 20), // later today
        DateTime(2026, 11, 14, 10), // later this week
      ], now);

      expect(result.sessions, 0);
      expect(result.days, List<bool>.filled(7, false));
    });

    test('keeps sessions from a single day counted individually', () {
      final result = weekActivity(<DateTime?>[
        DateTime(2026, 11, 10, 9),
        DateTime(2026, 11, 10, 13),
        DateTime(2026, 11, 10, 19),
      ], now);

      expect(result.sessions, 3);
      expect(result.days.where((done) => done).length, 1);
    });

    test('returns an empty week for no input', () {
      final result = weekActivity(const <DateTime?>[], now);

      expect(result.sessions, 0);
      expect(result.target, 5);
      expect(result.days, List<bool>.filled(7, false));
    });

    test('honours a custom target', () {
      expect(weekActivity(const <DateTime?>[], now, target: 3).target, 3);
    });
  });
}
