import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class ReminderNotifications {
  ReminderNotifications._();

  static final ReminderNotifications instance = ReminderNotifications._();
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<bool> configure({
    required String? time,
    required List<int> days,
  }) async {
    try {
      await _initialize();
      if (days.isEmpty || time == null) {
        await _notifications.cancelAll();
        return true;
      }
      await _notifications.cancelAll();
      final permission = await _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      if (permission == false) return false;

      final zoneInfo = await FlutterTimezone.getLocalTimezone();
      tz_data.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation(zoneInfo.identifier));
      final parts = time.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final now = tz.TZDateTime.now(tz.local);
      for (final sundayBasedDay in days.toSet()) {
        if (sundayBasedDay < 0 || sundayBasedDay > 6) continue;
        final weekday = sundayBasedDay == 0 ? DateTime.sunday : sundayBasedDay;
        var daysUntil = (weekday - now.weekday + 7) % 7;
        var scheduled = tz.TZDateTime(
          tz.local,
          now.year,
          now.month,
          now.day + daysUntil,
          hour,
          minute,
        );
        if (!scheduled.isAfter(now)) {
          daysUntil += 7;
          scheduled = tz.TZDateTime(
            tz.local,
            now.year,
            now.month,
            now.day + daysUntil,
            hour,
            minute,
          );
        }
        await _notifications.zonedSchedule(
          id: 2400 + sundayBasedDay,
          title: 'A little English practice?',
          body: 'Take a few minutes for your Toungular learning path today.',
          scheduledDate: scheduled,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'toungular_daily_practice',
              'Daily practice',
              channelDescription:
                  'Reminders chosen by the learner to practice English.',
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _initialize() async {
    if (_initialized) return;
    await _notifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('toungular_notification'),
      ),
    );
    _initialized = true;
  }
}
