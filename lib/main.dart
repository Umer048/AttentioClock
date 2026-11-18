import 'dart:convert';
import 'package:flutter/material.dart';
import 'screens/welcome_screen.dart';
import 'screens/alarm_ringing_screen.dart';
import 'services/notification_service.dart';

final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await NotificationService.instance.init(onTap: (response) {
    if (response.payload != null) {
      _openAlarmScreen(response.payload!);
    }
  });

  // Check if app was launched by clicking notification or via Full Screen Intent
  final launchDetails = await NotificationService.instance.getLaunchDetails();

  runApp(const MyApp());

  if (launchDetails?.didNotificationLaunchApp ?? false) {
    final payload = launchDetails?.notificationResponse?.payload;
    if (payload != null) {
      // Delay for a second so navigator is ready
      Future.delayed(const Duration(milliseconds: 500), () {
        _openAlarmScreen(payload);
      });
    }
  }
}

void _openAlarmScreen(String payload) {
  try {
    final data = jsonDecode(payload);
    navKey.currentState?.push(MaterialPageRoute(
      builder: (_) => AlarmRingingScreen(
        alarmId: data['id'],
        domain: data['domain'],
        soundId: data['soundId'],
        label: data['label'],
      ),
    ));
  } catch (e) {
    debugPrint("Error parsing payload: $e");
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navKey,
      debugShowCheckedModeBanner: false,
      title: 'AttentioClock',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFAFAFA),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E3A8A)),
      ),
      home: const WelcomeScreen(),
    );
  }
}