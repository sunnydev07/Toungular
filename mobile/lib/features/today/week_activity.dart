class WeekActivity {
  const WeekActivity({
    required this.sessions,
    required this.target,
    required this.days,
    required this.todayIndex,
  });

  final int sessions;
  final int target;

  /// Monday..Sunday flags for days holding at least one completed session.
  final List<bool> days;
  final int todayIndex;
}

/// Counts completed sessions in the local Monday–Sunday week containing [now].
/// Sessions, not minutes: minutes need a backend aggregate (see P0 plan §11).
WeekActivity weekActivity(
  Iterable<DateTime?> completedAt,
  DateTime now, {
  int target = 5,
}) {
  final local = now.toLocal();
  final weekStart = DateTime(
    local.year,
    local.month,
    local.day,
  ).subtract(Duration(days: local.weekday - 1));
  final weekEnd = weekStart.add(const Duration(days: 7));

  var sessions = 0;
  final days = List<bool>.filled(7, false);
  for (final raw in completedAt) {
    if (raw == null) continue;
    final at = raw.toLocal();
    if (at.isBefore(weekStart) || at.isAfter(local) || !at.isBefore(weekEnd))
      continue;
    sessions++;
    days[at.weekday - 1] = true;
  }
  return WeekActivity(
    sessions: sessions,
    target: target,
    days: days,
    todayIndex: local.weekday - 1,
  );
}
