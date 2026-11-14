
import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class AlarmNotificationService {
  AlarmNotificationService._();

  static final AlarmNotificationService instance =
  AlarmNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  static const String _channelId = 'attentio_alarm_channel';

  Future<void> initialize({
    void Function(NotificationResponse)? onNotificationTap,
  }) async {
    if (_initialized) return;

    tz_data.initializeTimeZones();

    final timezoneInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: onNotificationTap,
    );

    _initialized = true;
  }

  Future<NotificationAppLaunchDetails?> getLaunchDetails() async {
    await initialize();
    return _plugin.getNotificationAppLaunchDetails();
  }

  Future<bool> requestPermissions() async {
    await initialize();

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (android == null) return false;

    final notificationPermission =
        await android.requestNotificationsPermission() ?? true;

    if (!notificationPermission) return false;

    final exactAlarmPermission =
        await android.requestExactAlarmsPermission() ?? true;

    await android.requestFullScreenIntentPermission();

    return exactAlarmPermission;
  }

  Future<void> scheduleAlarm({
    required int alarmId,
    required int hour,
    required int minute,
    required String label,
    required List<int> repeatDays,
    required String domain,
    required String soundId,
    String? customSoundPath,
  }) async {
    await initialize();
    await cancelAlarm(alarmId);

    final payload = jsonEncode({
      'alarmId': alarmId,
      'label': label,
      'domain': domain,
      'soundId': soundId,
      'customSoundPath': customSoundPath,
    });

    final title = 'AttentioClock';
    final body = label.isEmpty ? 'Time to wake up and learn.' : label;

    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        'AttentioClock Alarms',
        channelDescription: 'Wake-up alarms and learning sessions',
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
        fullScreenIntent: true,
        ongoing: false,
        autoCancel: true,
        playSound: true,
        enableVibration: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      ),
    );

    if (repeatDays.isEmpty) {
      final now = tz.TZDateTime.now(tz.local);

      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      if (!scheduledDate.isAfter(now)) {
        scheduledDate = scheduledDate.add(
          const Duration(days: 1),
        );
      }

      await _plugin.zonedSchedule(
        id: alarmId * 10,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );

      return;
    }

    for (final day in repeatDays) {
      if (day < 0 || day > 6) continue;

      final now = tz.TZDateTime.now(tz.local);
      final targetWeekday = day + 1;

      var daysUntil = (targetWeekday - now.weekday + 7) % 7;

      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day + daysUntil,
        hour,
        minute,
      );

      if (!scheduledDate.isAfter(now)) {
        daysUntil += 7;

        scheduledDate = tz.TZDateTime(
          tz.local,
          now.year,
          now.month,
          now.day + daysUntil,
          hour,
          minute,
        );
      }

      await _plugin.zonedSchedule(
        id: alarmId * 10 + day + 1,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: payload,
      );
    }
  }

  Future<void> cancelAlarm(int alarmId) async {
    await initialize();

    for (int i = 0; i <= 7; i++) {
      await _plugin.cancel(id: alarmId * 10 + i);
    }
  }

  Future<List<PendingNotificationRequest>> getPendingAlarms() async {
    await initialize();
    return _plugin.pendingNotificationRequests();
  }
}
