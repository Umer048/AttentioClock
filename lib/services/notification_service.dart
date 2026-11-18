import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final instance = NotificationService._();
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init({void Function(NotificationResponse)? onTap}) async {
    if (_initialized) return;
    tz_data.initializeTimeZones();

    final tzInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(tzInfo.identifier));

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: onTap,
    );
    _initialized = true;
  }

  // YEH NAYA FUNCTION HAI (App band state se open hone par check karega)
  Future<NotificationAppLaunchDetails?> getLaunchDetails() async {
    await init();
    return _plugin.getNotificationAppLaunchDetails();
  }

  Future<bool> requestPermissions() async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return false;

    await android.requestNotificationsPermission();
    await android.requestExactAlarmsPermission();
    await android.requestFullScreenIntentPermission();
    return true;
  }

  Future<void> schedule({
    required int id,
    required int hour,
    required int minute,
    required String domain,
    required String soundId,
    required String label
  }) async {
    await init();
    await cancel(id);

    final payload = jsonEncode({'id': id, 'domain': domain, 'soundId': soundId, 'label': label});

    const notifDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'attentio_alarm_channel_v2',
        'Attentio Alarms',
        channelDescription: 'Attentio Clock Alarm Notifications',
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true, // YEH SCREEN KHOLEGA
        playSound: true,
        enableVibration: true,
        visibility: NotificationVisibility.public,
      ),
    );

    final now = tz.TZDateTime.now(tz.local);
    var scheduleDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!scheduleDate.isAfter(now)) scheduleDate = scheduleDate.add(const Duration(days: 1));

    await _plugin.zonedSchedule(
      id,
      'AttentioClock',
      label.isEmpty ? 'Time to learn!' : label,
      scheduleDate,
      notifDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancel(int id) async => await _plugin.cancel(id);
}