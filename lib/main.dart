import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/passage.dart';
import 'screens/alarm_session_screen.dart';
import 'services/alarm_notification_service.dart';
import 'services/alarm_storage_service.dart';
import 'services/passage_service.dart';

// GLOBAL NAVIGATION
final GlobalKey<NavigatorState> appNavigatorKey =
    GlobalKey<NavigatorState>();

String? pendingAlarmPayload;
bool _isProcessingAlarmPayload = false;
int? _activeAlarmSessionId;
Future<void> Function(int alarmId)? alarmCompletionHandler;

// APP STARTUP
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final notifications = AlarmNotificationService.instance;

  await notifications.initialize(
    onNotificationTap: handleNotificationTap,
  );

  // Read the notification that launched the app from a terminated state.
  final launchDetails = await notifications.getLaunchDetails();

  runApp(const AttentioClockApp());

  if (launchDetails?.didNotificationLaunchApp ?? false) {
    final payload = launchDetails?.notificationResponse?.payload;
    if (payload != null && payload.isNotEmpty) {
      // Queue it immediately. The navigator may need a moment to attach.
      openAlarmSessionFromPayload(payload);
    }
  }
}

// CALLED WHEN THE USER TAPS AN ALARM NOTIFICATION WHILE THE APP IS RUNNING
// OR RESUMED FROM THE BACKGROUND.
void handleNotificationTap(NotificationResponse response) {
  debugPrint('ATTENTIO: notification tap received');
  debugPrint('ATTENTIO: notification payload = ${response.payload}');
  openAlarmSessionFromPayload(response.payload);
}

// QUEUE AND OPEN THE LEARNING SESSION.
// We wait briefly for MaterialApp's Navigator to become available instead of
// dropping the tap when currentState is temporarily null during app startup.
void openAlarmSessionFromPayload(String? payload) {
  if (payload == null || payload.trim().isEmpty) {
    debugPrint('ATTENTIO: notification has no payload');
    return;
  }

  pendingAlarmPayload = payload;
  _processPendingAlarmPayload();
}

Future<void> _processPendingAlarmPayload() async {
  if (_isProcessingAlarmPayload) return;
  _isProcessingAlarmPayload = true;

  try {
    for (var attempt = 0; attempt < 40; attempt++) {
      final navigator = appNavigatorKey.currentState;
      final payload = pendingAlarmPayload;

      if (payload == null) return;

      if (navigator == null) {
        await Future<void>.delayed(const Duration(milliseconds: 150));
        continue;
      }

      Map<String, dynamic> decoded;
      try {
        final value = jsonDecode(payload);
        if (value is! Map) {
          debugPrint('ATTENTIO: invalid notification payload format');
          pendingAlarmPayload = null;
          return;
        }
        decoded = Map<String, dynamic>.from(value);
      } catch (error) {
        debugPrint('ATTENTIO: payload JSON could not be decoded: $error');
        pendingAlarmPayload = null;
        return;
      }

      final alarmIdValue = decoded['alarmId'];
      final int? alarmId = alarmIdValue is int
          ? alarmIdValue
          : int.tryParse(alarmIdValue?.toString() ?? '');

      if (alarmId == null) {
        debugPrint('ATTENTIO: notification payload has no valid alarmId');
        pendingAlarmPayload = null;
        return;
      }

      // Avoid opening the same alarm twice if Android delivers both a launch
      // callback and a notification-response callback for the same tap.
      if (_activeAlarmSessionId == alarmId) {
        pendingAlarmPayload = null;
        return;
      }

      final label = decoded['label']?.toString() ?? '';
      final domain = decoded['domain']?.toString() ?? 'Islamic';
      final soundId = decoded['soundId']?.toString() ?? 'gentle_chimes';
      final customSoundPath = decoded['customSoundPath']?.toString();

      pendingAlarmPayload = null;
      _activeAlarmSessionId = alarmId;
      debugPrint('ATTENTIO: opening learning session for alarm $alarmId');

      navigator
          .push(
        MaterialPageRoute<void>(
          builder: (_) => AlarmSessionScreen(
            alarmId: alarmId,
            label: label,
            domain: domain,
            soundId: soundId,
            customSoundPath: customSoundPath,
            onCompleted: () async {
              await alarmCompletionHandler?.call(alarmId);
            },
          ),
        ),
      )
          .whenComplete(() {
        if (_activeAlarmSessionId == alarmId) {
          _activeAlarmSessionId = null;
        }
      });
      return;
    }

    debugPrint('ATTENTIO: navigator did not become ready; alarm session not opened');
  } finally {
    _isProcessingAlarmPayload = false;
    // If a new tap arrived while the previous payload was being processed,
    // process the newest payload now.
    if (pendingAlarmPayload != null) {
      _processPendingAlarmPayload();
    }
  }
}

// APP COLOURS
class AppColors {
  static const burgundy = Color(0xFF35111F);
  static const burgundyLight = Color(0xFF512536);
  static const black = Color(0xFF171316);
  static const ivory = Color(0xFFF5F0ED);
  static const gold = Color(0xFFB68B62);
  static const mutedRose = Color(0xFFD9C9C8);
  static const grey = Color(0xFF77676C);
}

// MAIN APP
class AttentioClockApp extends StatelessWidget {
  const AttentioClockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'AttentioClock',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.ivory,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.burgundy,
          primary: AppColors.burgundy,
          secondary: AppColors.gold,
          surface: AppColors.ivory,
        ),
        fontFamily: 'Roboto',
      ),
      home: const MainScreen(),
    );
  }
}

// ALARM MODEL
class AlarmData {
  final int id;
  TimeOfDay time;
  String label;
  List<int> repeatDays;
  bool enabled;
  String domain;
  String soundId;
  String? customSoundPath;
  String? customSoundName;

  AlarmData({
    required this.id,
    required this.time,
    required this.label,
    required this.repeatDays,
    this.enabled = true,
    this.domain = 'Islamic',
    this.soundId = 'gentle_chimes',
    this.customSoundPath,
    this.customSoundName,
  });

  String get formattedTime {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String get repeatDescription {
    if (repeatDays.isEmpty) return 'Once';
    if (repeatDays.length == 7) return 'Every day';

    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return repeatDays.map((day) => days[day]).join(' · ');
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'hour': time.hour,
      'minute': time.minute,
      'label': label,
      'repeatDays': repeatDays,
      'enabled': enabled,
      'domain': domain,
      'soundId': soundId,
      'customSoundPath': customSoundPath,
      'customSoundName': customSoundName,
    };
  }

  factory AlarmData.fromMap(Map<String, dynamic> map) {
    final savedDomain = map['domain'] as String?;
    const validDomains = ['Islamic', 'Motivation', 'Sports'];

    return AlarmData(
      id: map['id'] as int,
      time: TimeOfDay(
        hour: map['hour'] as int,
        minute: map['minute'] as int,
      ),
      label: map['label'] as String? ?? '',
      repeatDays: List<int>.from(map['repeatDays'] ?? []),
      enabled: map['enabled'] as bool? ?? true,
      domain: validDomains.contains(savedDomain) ? savedDomain! : 'Islamic',
      soundId: map['soundId'] as String? ?? 'gentle_chimes',
      customSoundPath: map['customSoundPath'] as String?,
      customSoundName: map['customSoundName'] as String?,
    );
  }
}

// MAIN NAVIGATION AND HOME
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int selectedTab = 0;

  final List<AlarmData> alarms = [];

  final AlarmStorageService _storage = AlarmStorageService();

  final AlarmNotificationService _notifications =
      AlarmNotificationService.instance;

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    alarmCompletionHandler = handleAlarmCompleted;
    loadSavedAlarms();
  }

  @override
  void dispose() {
    alarmCompletionHandler = null;
    super.dispose();
  }

  // A one-time alarm is automatically disabled after its learning session.
  // Repeating alarms remain enabled for their next scheduled day.
  Future<void> handleAlarmCompleted(int alarmId) async {
    final index = alarms.indexWhere((item) => item.id == alarmId);
    if (index < 0) return;

    final alarm = alarms[index];
    if (alarm.repeatDays.isEmpty) {
      alarm.enabled = false;
      await _notifications.cancelAlarm(alarmId);
      await saveAllAlarms();
    }

    // Refresh the home/progress UI after every completed learning session.
    if (mounted) setState(() {});
  }

  // LOAD SAVED ALARMS
  Future<void> loadSavedAlarms() async {
    try {
      final savedAlarms = await _storage.loadAlarms();

      final loaded = savedAlarms
          .map((item) => AlarmData.fromMap(item))
          .toList();

      if (!mounted) return;

      setState(() {
        alarms
          ..clear()
          ..addAll(loaded);
        isLoading = false;
      });

      // Restore enabled notification schedules.
      for (final alarm in loaded) {
        if (alarm.enabled) {
          try {
            await _notifications.scheduleAlarm(
              alarmId: alarm.id,
              hour: alarm.time.hour,
              minute: alarm.time.minute,
              label: alarm.label,
              repeatDays: alarm.repeatDays,
              domain: alarm.domain,
              soundId: alarm.soundId,
              customSoundPath: alarm.customSoundPath,
            );
          } catch (e) {
            debugPrint('Could not restore alarm ${alarm.id}: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading alarms: $e');

      if (mounted) {
        setState(() => isLoading = false);
        showMessage('Could not load saved alarms.');
      }
    }
  }

  // SAVE ALL ALARMS
  Future<void> saveAllAlarms() async {
    await _storage.saveAlarms(
      alarms.map((alarm) => alarm.toMap()).toList(),
    );
  }

  // GENERATE UNIQUE ANDROID-SAFE ALARM ID
  int generateAlarmId() {
    int id = DateTime.now().millisecondsSinceEpoch % 100000000;

    while (alarms.any((alarm) => alarm.id == id)) {
      id = (id + 1) % 100000000;
    }

    return id;
  }

  // REQUEST PERMISSIONS
  Future<bool> checkPermissions() async {
    try {
      return await _notifications.requestPermissions();
    } catch (e) {
      debugPrint('Permission error: $e');
      showMessage('Could not obtain alarm permissions.');
      return false;
    }
  }

  // SHOW MESSAGE
  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // CALCULATE NEXT OCCURRENCE
  DateTime nextOccurrence(AlarmData alarm) {
    final now = DateTime.now();

    if (alarm.repeatDays.isEmpty) {
      var result = DateTime(
        now.year,
        now.month,
        now.day,
        alarm.time.hour,
        alarm.time.minute,
      );

      if (!result.isAfter(now)) {
        result = result.add(const Duration(days: 1));
      }

      return result;
    }

    for (int i = 0; i < 7; i++) {
      final date = now.add(Duration(days: i));

      if (alarm.repeatDays.contains(date.weekday - 1)) {
        final result = DateTime(
          date.year,
          date.month,
          date.day,
          alarm.time.hour,
          alarm.time.minute,
        );

        if (result.isAfter(now)) return result;
      }
    }

    return now.add(const Duration(days: 7));
  }

  // NEXT ALARM
  AlarmData? get nextAlarm {
    final enabled = alarms.where((alarm) => alarm.enabled).toList();

    if (enabled.isEmpty) return null;

    enabled.sort(
      (a, b) => nextOccurrence(a).compareTo(nextOccurrence(b)),
    );

    return enabled.first;
  }

  // ADD OR EDIT ALARM
  Future<void> openAlarmEditor({AlarmData? alarm}) async {
    final result = await showModalBottomSheet<AlarmData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.ivory,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      builder: (_) => AlarmEditor(
        alarm: alarm,
        newAlarmId: alarm == null ? generateAlarmId() : null,
      ),
    );

    if (result == null || !mounted) return;

    // Permissions are required only for enabled alarms.
    if (result.enabled) {
      final permitted = await checkPermissions();

      if (!permitted) {
        showMessage(
          'Alarm was not saved. Please allow notifications and exact alarms.',
        );
        return;
      }
    }

    try {
      if (alarm == null) {
        alarms.add(result);
      } else {
        final index = alarms.indexWhere((a) => a.id == alarm.id);

        if (index != -1) {
          alarms[index] = result;
        }
      }

      await saveAllAlarms();

      if (result.enabled) {
        await _notifications.scheduleAlarm(
          alarmId: result.id,
          hour: result.time.hour,
          minute: result.time.minute,
          label: result.label,
          repeatDays: result.repeatDays,
          domain: result.domain,
          soundId: result.soundId,
          customSoundPath: result.customSoundPath,
        );
      } else {
        await _notifications.cancelAlarm(result.id);
      }

      if (mounted) {
        setState(() {});
        showMessage(
          alarm == null ? 'Alarm saved successfully' : 'Alarm updated',
        );
      }
    } catch (e) {
      debugPrint('Error saving alarm: $e');

      showMessage(
        'Alarm saved, but notification scheduling failed. Check permissions.',
      );
    }
  }

  // ENABLE OR DISABLE ALARM
  Future<void> toggleAlarm(AlarmData alarm, bool value) async {
    if (value) {
      final permitted = await checkPermissions();

      if (!permitted) {
        showMessage('Please allow alarm permissions first.');
        return;
      }
    }

    final oldValue = alarm.enabled;

    setState(() => alarm.enabled = value);

    try {
      if (value) {
        await _notifications.scheduleAlarm(
          alarmId: alarm.id,
          hour: alarm.time.hour,
          minute: alarm.time.minute,
          label: alarm.label,
          repeatDays: alarm.repeatDays,
          domain: alarm.domain,
          soundId: alarm.soundId,
          customSoundPath: alarm.customSoundPath,
        );
      } else {
        await _notifications.cancelAlarm(alarm.id);
      }

      await saveAllAlarms();

      if (mounted) {
        showMessage(value ? 'Alarm enabled' : 'Alarm disabled');
      }
    } catch (e) {
      alarm.enabled = oldValue;

      if (mounted) {
        setState(() {});
        showMessage('Could not update alarm: $e');
      }
    }
  }

  // DELETE ALARM
  Future<void> deleteAlarm(AlarmData alarm) async {
    try {
      await _notifications.cancelAlarm(alarm.id);

      setState(() {
        alarms.removeWhere((a) => a.id == alarm.id);
      });

      await saveAllAlarms();

      showMessage('Alarm deleted');
    } catch (e) {
      showMessage('Could not delete alarm: $e');
    }
  }

  // CURRENT DATE
  String get currentDate {
    final now = DateTime.now();

    const months = [
      'January', 'February', 'March', 'April',
      'May', 'June', 'July', 'August',
      'September', 'October', 'November', 'December'
    ];

    const weekdays = [
      'Monday', 'Tuesday', 'Wednesday',
      'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];

    return '${weekdays[now.weekday - 1]}, '
        '${now.day} ${months[now.month - 1]} ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      buildHomePage(),
      const PassageLibraryPage(),
      const ProgressPage(),
      SettingsPage(
        onRequestPermissions: checkPermissions,
        onShowMessage: showMessage,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.burgundy,
                ),
              )
            : pages[selectedTab],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: Colors.white,
        indicatorColor: AppColors.mutedRose.withValues(alpha: 0.55),
        selectedIndex: selectedTab,
        onDestinationSelected: (index) {
          setState(() => selectedTab = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.alarm_outlined),
            selectedIcon: Icon(Icons.alarm),
            label: 'Alarms',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Passages',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Progress',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  // HOME PAGE
  Widget buildHomePage() {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 30),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // HEADER
              Row(
                children: [
                  Container(
                    height: 43,
                    width: 43,
                    decoration: BoxDecoration(
                      color: AppColors.burgundy,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.alarm,
                      color: AppColors.gold,
                      size: 25,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ATTENTIOCLOCK',
                        style: TextStyle(
                          color: AppColors.burgundy,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                        ),
                      ),
                      Text(
                        'WAKE UP WITH PURPOSE',
                        style: TextStyle(
                          color: AppColors.grey,
                          fontSize: 9,
                          letterSpacing: 1.7,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => setState(() => selectedTab = 2),
                    icon: const Icon(
                      Icons.settings_outlined,
                      color: AppColors.burgundy,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 35),

              // GREETING
              const Text(
                'Good day,',
                style: TextStyle(
                  fontSize: 17,
                  color: AppColors.grey,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Make today count.',
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                  color: AppColors.black,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                currentDate,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.grey,
                ),
              ),

              const SizedBox(height: 28),

              // NEXT ALARM CARD
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: AppColors.burgundy,
                  borderRadius: BorderRadius.circular(23),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.burgundy.withValues(alpha: 0.16),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.wb_twilight_rounded,
                          color: AppColors.gold,
                          size: 20,
                        ),
                        const SizedBox(width: 9),
                        const Text(
                          'UPCOMING ALARM',
                          style: TextStyle(
                            color: AppColors.mutedRose,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            nextAlarm == null ? 'NO ALARM' : 'ACTIVE',
                            style: const TextStyle(
                              color: AppColors.gold,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 17),
                    Text(
                      nextAlarm?.formattedTime ?? '--:-- --',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 43,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      nextAlarm?.label.isNotEmpty == true
                          ? nextAlarm!.label
                          : nextAlarm == null
                              ? 'No upcoming alarm'
                              : 'Your next reminder',
                      style: const TextStyle(
                        color: AppColors.mutedRose,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 17),
                    Container(height: 1, color: Colors.white24),
                    const SizedBox(height: 13),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          color: AppColors.gold,
                          size: 15,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            nextAlarm?.repeatDescription ??
                                'Create an alarm to get started',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: AppColors.gold,
                          size: 14,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // ALARM LIST HEADER
              Row(
                children: [
                  const Text(
                    'Your alarms',
                    style: TextStyle(
                      color: AppColors.black,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${alarms.length} ${alarms.length == 1 ? 'alarm' : 'alarms'}',
                    style: const TextStyle(
                      color: AppColors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 15),

              if (alarms.isEmpty)
                buildEmptyState()
              else
                ...alarms.map(buildAlarmCard),

              const SizedBox(height: 18),

              // ADD BUTTON
              SizedBox(
                height: 55,
                child: FilledButton.icon(
                  onPressed: () => openAlarmEditor(),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text(
                    'Add new alarm',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.burgundy,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              const Center(
                child: Text(
                  'A better morning begins the night before.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.grey,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  // EMPTY STATE
  Widget buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: 28,
        horizontal: 20,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: AppColors.mutedRose.withValues(alpha: 0.5),
        ),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.alarm_add_rounded,
            color: AppColors.gold,
            size: 38,
          ),
          SizedBox(height: 12),
          Text(
            'No alarms yet',
            style: TextStyle(
              color: AppColors.burgundy,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Create your first alarm and start building a better routine.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ALARM CARD
  Widget buildAlarmCard(AlarmData alarm) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(
        horizontal: 17,
        vertical: 15,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.mutedRose.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => openAlarmEditor(alarm: alarm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alarm.formattedTime,
                    style: TextStyle(
                      color: alarm.enabled
                          ? AppColors.burgundy
                          : AppColors.grey,
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    alarm.label.isEmpty ? 'Alarm' : alarm.label,
                    style: const TextStyle(
                      color: AppColors.black,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    alarm.repeatDescription,
                    style: const TextStyle(
                      color: AppColors.grey,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Learning: ${alarm.domain}',
                    style: const TextStyle(
                      color: AppColors.burgundyLight,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Switch(
            value: alarm.enabled,
            activeThumbColor: AppColors.burgundy,
            onChanged: (value) => toggleAlarm(alarm, value),
          ),
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert,
              color: AppColors.grey,
            ),
            onSelected: (value) {
              if (value == 'edit') {
                openAlarmEditor(alarm: alarm);
              } else if (value == 'delete') {
                deleteAlarm(alarm);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'edit',
                child: Text('Edit alarm'),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text('Delete alarm'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ADD / EDIT ALARM FORM
class AlarmEditor extends StatefulWidget {
  final AlarmData? alarm;
  final int? newAlarmId;

  const AlarmEditor({
    super.key,
    this.alarm,
    this.newAlarmId,
  });

  @override
  State<AlarmEditor> createState() => _AlarmEditorState();
}

class _AlarmEditorState extends State<AlarmEditor> {
  late TimeOfDay selectedTime;
  late TextEditingController labelController;
  late List<int> selectedDays;
  late String selectedDomain;
  late String selectedSoundId;

  String? customSoundPath;
  String? customSoundName;

  final AudioPlayer _previewPlayer = AudioPlayer();
  StreamSubscription<void>? _previewCompleteSubscription;

  bool isPreviewing = false;

  static const Map<String, String> _builtInSounds = {
    'classic_buzzer': 'Classic Buzzer',
    'gentle_chimes': 'Gentle Chimes',
    'loud_siren': 'Loud Siren',
    'morning_birds': 'Morning Birds',
  };

  final List<String> dayNames = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
  ];

  @override
  void initState() {
    super.initState();

    selectedTime = widget.alarm?.time ??
        const TimeOfDay(hour: 7, minute: 0);

    labelController = TextEditingController(
      text: widget.alarm?.label ?? '',
    );

    selectedDays = List<int>.from(
      widget.alarm?.repeatDays ?? [],
    );

    selectedDomain = widget.alarm?.domain ?? 'Islamic';
    selectedSoundId = widget.alarm?.soundId ?? 'gentle_chimes';

    customSoundPath = widget.alarm?.customSoundPath;
    customSoundName = widget.alarm?.customSoundName;

    if (selectedSoundId == 'custom' &&
        (customSoundPath == null ||
            !File(customSoundPath!).existsSync())) {
      selectedSoundId = 'gentle_chimes';
    } else if (selectedSoundId != 'custom' &&
        !_builtInSounds.containsKey(selectedSoundId)) {
      selectedSoundId = 'gentle_chimes';
    }

    _previewCompleteSubscription =
        _previewPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() => isPreviewing = false);
      }
    });
  }

  @override
  void dispose() {
    labelController.dispose();
    _previewCompleteSubscription?.cancel();
    _previewPlayer.dispose();
    super.dispose();
  }

  // CHOOSE TIME
  Future<void> chooseTime() async {
    final result = await showTimePicker(
      context: context,
      initialTime: selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.burgundy,
              onPrimary: Colors.white,
              surface: AppColors.ivory,
            ),
          ),
          child: child!,
        );
      },
    );

    if (result != null) {
      setState(() => selectedTime = result);
    }
  }

  // PICK A CUSTOM WAV OR MP3 FILE AND COPY IT INTO APP STORAGE.
  Future<void> chooseCustomSound() async {
    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['wav', 'mp3'],
      );

      if (picked == null) return;

      final sourcePath = picked.path;

      if (sourcePath == null || sourcePath.isEmpty) {
        showEditorMessage(
          'Could not access the selected audio file. Please try another file.',
        );
        return;
      }

      final extension = picked.extension?.toLowerCase();

      if (extension != 'wav' && extension != 'mp3') {
        showEditorMessage('Please select a WAV or MP3 file.');
        return;
      }

      final appDirectory = await getApplicationDocumentsDirectory();

      final soundsDirectory = Directory(
        '${appDirectory.path}/custom_sounds',
      );

      if (!await soundsDirectory.exists()) {
        await soundsDirectory.create(recursive: true);
      }

      final safeName = picked.name.replaceAll(
        RegExp(r'[^A-Za-z0-9._-]'),
        '_',
      );

      final savedName =
          '${DateTime.now().millisecondsSinceEpoch}_$safeName';

      final destination = '${soundsDirectory.path}/$savedName';

      await File(sourcePath).copy(destination);

      await _previewPlayer.stop();

      if (!mounted) return;

      setState(() {
        customSoundPath = destination;
        customSoundName = picked.name;
        selectedSoundId = 'custom';
        isPreviewing = false;
      });

      showEditorMessage(
        'Custom sound added. Preview it before saving.',
      );
    } catch (error) {
      showEditorMessage('Could not import sound: $error');
    }
  }

  // PLAY OR STOP A SHORT PREVIEW OF THE SELECTED SOUND.
  Future<void> previewSelectedSound() async {
    try {
      if (isPreviewing) {
        await _previewPlayer.stop();

        if (mounted) {
          setState(() => isPreviewing = false);
        }

        return;
      }

      await _previewPlayer.stop();

      if (selectedSoundId == 'custom') {
        final path = customSoundPath;

        if (path == null || !await File(path).exists()) {
          showEditorMessage('Choose a custom sound file first.');
          return;
        }

        await _previewPlayer.play(DeviceFileSource(path));
      } else {
        final assetFile = '$selectedSoundId.wav';

        await _previewPlayer.play(
          AssetSource('sounds/$assetFile'),
        );
      }

      if (mounted) {
        setState(() => isPreviewing = true);
      }
    } catch (error) {
      if (mounted) {
        setState(() => isPreviewing = false);
      }

      showEditorMessage('Could not preview this sound: $error');
    }
  }

  void showEditorMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // SAVE ALARM
  void saveAlarm() {
    final alarm = AlarmData(
      id: widget.alarm?.id ?? widget.newAlarmId!,
      time: selectedTime,
      label: labelController.text.trim(),
      repeatDays: List<int>.from(selectedDays),
      enabled: widget.alarm?.enabled ?? true,
      domain: selectedDomain,
      soundId: selectedSoundId,
      customSoundPath: customSoundPath,
      customSoundName: customSoundName,
    );

    Navigator.pop(context, alarm);
  }

  @override
  Widget build(BuildContext context) {
    final hour = selectedTime.hourOfPeriod == 0
        ? 12
        : selectedTime.hourOfPeriod;

    final minute = selectedTime.minute.toString().padLeft(2, '0');

    final period =
        selectedTime.period == DayPeriod.am ? 'AM' : 'PM';

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          22,
          12,
          22,
          MediaQuery.of(context).viewInsets.bottom + 22,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  height: 4,
                  width: 42,
                  decoration: BoxDecoration(
                    color: AppColors.mutedRose,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              const SizedBox(height: 25),

              Text(
                widget.alarm == null ? 'Create alarm' : 'Edit alarm',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.burgundy,
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                'Set a time for your next purposeful morning.',
                style: TextStyle(
                  color: AppColors.grey,
                  fontSize: 13,
                ),
              ),

              const SizedBox(height: 25),

              // TIME PICKER
              InkWell(
                onTap: chooseTime,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 23),
                  decoration: BoxDecoration(
                    color: AppColors.burgundy,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$hour:$minute $period',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 39,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 7),
                      const Text(
                        'TAP TO CHANGE TIME',
                        style: TextStyle(
                          color: AppColors.gold,
                          fontSize: 10,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 25),

              const Text(
                'Alarm label',
                style: TextStyle(
                  color: AppColors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 9),

              TextField(
                controller: labelController,
                decoration: InputDecoration(
                  hintText: 'e.g. Morning routine',
                  filled: true,
                  fillColor: Colors.white,
                  prefixIcon: const Icon(
                    Icons.edit_outlined,
                    color: AppColors.burgundy,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'Learning domain',
                style: TextStyle(
                  color: AppColors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 9),

              DropdownButtonFormField<String>(
                initialValue: selectedDomain,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  prefixIcon: const Icon(
                    Icons.menu_book_rounded,
                    color: AppColors.burgundy,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Islamic',
                    child: Text('Islamic'),
                  ),
                  DropdownMenuItem(
                    value: 'Motivation',
                    child: Text('Motivation'),
                  ),
                  DropdownMenuItem(
                    value: 'Sports',
                    child: Text('Sports'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => selectedDomain = value);
                  }
                },
              ),

              const SizedBox(height: 24),

              const Text(
                'Alarm sound',
                style: TextStyle(
                  color: AppColors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 9),

              DropdownButtonFormField<String>(
                initialValue: selectedSoundId,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  prefixIcon: const Icon(
                    Icons.music_note_rounded,
                    color: AppColors.burgundy,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: [
                  ..._builtInSounds.entries.map(
                    (entry) => DropdownMenuItem<String>(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                  ),
                  if (customSoundPath != null &&
                      File(customSoundPath!).existsSync())
                    DropdownMenuItem<String>(
                      value: 'custom',
                      child: Text(
                        customSoundName ?? 'Custom sound',
                      ),
                    ),
                ],
                onChanged: (value) async {
                  if (value == null) return;

                  await _previewPlayer.stop();

                  if (!mounted) return;

                  setState(() {
                    selectedSoundId = value;
                    isPreviewing = false;
                  });
                },
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: chooseCustomSound,
                      icon: const Icon(Icons.upload_file_rounded),
                      label: const Text('Upload WAV / MP3'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.burgundy,
                        side: const BorderSide(
                          color: AppColors.mutedRose,
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 13,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 9),

                  Expanded(
                    child: FilledButton.icon(
                      onPressed: previewSelectedSound,
                      icon: Icon(
                        isPreviewing
                            ? Icons.stop_rounded
                            : Icons.play_arrow_rounded,
                      ),
                      label: Text(
                        isPreviewing ? 'Stop preview' : 'Preview',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.burgundy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              if (selectedSoundId == 'custom' &&
                  customSoundName != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Selected: $customSoundName',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.grey,
                    fontSize: 11,
                  ),
                ),
              ],

              const SizedBox(height: 24),

              const Text(
                'Repeat',
                style: TextStyle(
                  color: AppColors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 5),

              const Text(
                'Select the days on which this alarm should repeat.',
                style: TextStyle(
                  color: AppColors.grey,
                  fontSize: 11,
                ),
              ),

              const SizedBox(height: 12),

              Wrap(
                spacing: 7,
                runSpacing: 8,
                children: List.generate(7, (index) {
                  final selected = selectedDays.contains(index);

                  return ChoiceChip(
                    label: Text(dayNames[index]),
                    selected: selected,
                    selectedColor: AppColors.burgundy,
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(
                      color: selected
                          ? Colors.white
                          : AppColors.burgundy,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (value) {
                      setState(() {
                        if (value) {
                          selectedDays.add(index);
                        } else {
                          selectedDays.remove(index);
                        }

                        selectedDays.sort();
                      });
                    },
                  );
                }),
              ),

              const SizedBox(height: 28),

              SizedBox(
                height: 54,
                width: double.infinity,
                child: FilledButton(
                  onPressed: saveAlarm,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.burgundy,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: Text(
                    widget.alarm == null
                        ? 'Save alarm'
                        : 'Update alarm',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}


// PASSAGE LIBRARY
class PassageLibraryPage extends StatefulWidget {
  const PassageLibraryPage({super.key});

  @override
  State<PassageLibraryPage> createState() => _PassageLibraryPageState();
}

class _PassageLibraryPageState extends State<PassageLibraryPage> {
  String _domain = 'Islamic';
  late Future<List<Passage>> _passagesFuture;

  @override
  void initState() {
    super.initState();
    _passagesFuture = PassageService().loadPassages(_domain);
  }

  void _changeDomain(String value) {
    setState(() {
      _domain = value;
      _passagesFuture = PassageService().loadPassages(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const Text(
                'Reading library',
                style: TextStyle(
                  color: AppColors.burgundy,
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Explore the passages used in your learning alarms.',
                style: TextStyle(color: AppColors.grey),
              ),
              const SizedBox(height: 22),
              DropdownButtonFormField<String>(
                initialValue: _domain,
                decoration: InputDecoration(
                  labelText: 'Learning domain',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 'Islamic', child: Text('Islamic')),
                  DropdownMenuItem(value: 'Motivation', child: Text('Motivation')),
                  DropdownMenuItem(value: 'Sports', child: Text('Sports')),
                ],
                onChanged: (value) {
                  if (value != null) _changeDomain(value);
                },
              ),
              const SizedBox(height: 18),
              FutureBuilder<List<Passage>>(
                future: _passagesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(35),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.burgundy,
                        ),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return const Text(
                      'Could not load passages. Please try again.',
                      style: TextStyle(color: Colors.red),
                    );
                  }
                  final passages = snapshot.data ?? [];
                  return Column(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${passages.length} passages',
                          style: const TextStyle(
                            color: AppColors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...passages.map(
                        (passage) => Container(
                          margin: const EdgeInsets.only(bottom: 11),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(17),
                            border: Border.all(
                              color: AppColors.mutedRose.withValues(alpha: .55),
                            ),
                          ),
                          child: ExpansionTile(
                            iconColor: AppColors.burgundy,
                            collapsedIconColor: AppColors.gold,
                            title: Text(
                              passage.title,
                              style: const TextStyle(
                                color: AppColors.burgundy,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              '${passage.questions.length} comprehension question(s)',
                              style: const TextStyle(
                                color: AppColors.grey,
                                fontSize: 12,
                              ),
                            ),
                            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 17),
                            children: [
                              Text(
                                passage.body,
                                style: const TextStyle(
                                  color: AppColors.black,
                                  height: 1.7,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

// PROGRESS
class ProgressPage extends StatelessWidget {
  const ProgressPage({super.key});

  Future<Map<String, int>> _loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'sessions': prefs.getInt('attentio_total_sessions') ?? 0,
      'attempts': prefs.getInt('attentio_total_attempts') ?? 0,
      'correct': prefs.getInt('attentio_total_correct') ?? 0,
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, int>>(
      future: _loadStats(),
      builder: (context, snapshot) {
        final stats = snapshot.data ?? {
          'sessions': 0,
          'attempts': 0,
          'correct': 0,
        };
        final attempts = stats['attempts'] ?? 0;
        final correct = stats['correct'] ?? 0;
        final accuracy = attempts == 0 ? 0 : (correct * 100 / attempts).round();

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 25, 20, 30),
          children: [
            const Text(
              'Your progress',
              style: TextStyle(
                color: AppColors.burgundy,
                fontSize: 27,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Every morning is a chance to learn something new.',
              style: TextStyle(color: AppColors.grey),
            ),
            const SizedBox(height: 24),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Center(child: CircularProgressIndicator())
            else
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.25,
                children: [
                  _ProgressCard(
                    icon: Icons.wb_sunny_outlined,
                    label: 'Sessions completed',
                    value: '${stats['sessions']}',
                  ),
                  _ProgressCard(
                    icon: Icons.quiz_outlined,
                    label: 'Quiz attempts',
                    value: '$attempts',
                  ),
                  _ProgressCard(
                    icon: Icons.check_circle_outline,
                    label: 'Correct answers',
                    value: '$correct',
                  ),
                  _ProgressCard(
                    icon: Icons.track_changes_outlined,
                    label: 'Accuracy',
                    value: '$accuracy%',
                  ),
                ],
              ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.burgundy,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text(
                'Small, consistent steps build lasting knowledge. Keep showing up.',
                style: TextStyle(
                  color: Colors.white,
                  height: 1.6,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProgressCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.mutedRose.withValues(alpha: .55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: AppColors.gold, size: 25),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.burgundy,
              fontSize: 25,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.grey,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// SETTINGS
class SettingsPage extends StatelessWidget {
  final Future<bool> Function() onRequestPermissions;
  final void Function(String) onShowMessage;

  const SettingsPage({
    super.key,
    required this.onRequestPermissions,
    required this.onShowMessage,
  });

  Future<void> _resetPassages() async {
    try {
      final service = PassageService();
      await service.resetDomain('Islamic');
      await service.resetDomain('Motivation');
      await service.resetDomain('Sports');
      onShowMessage('Passage rotation has been reset for all domains.');
    } catch (error) {
      onShowMessage('Could not reset passage rotation: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 25, 20, 30),
      children: [
        const Text(
          'Settings',
          style: TextStyle(
            color: AppColors.burgundy,
            fontSize: 27,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'Manage your alarm and learning preferences.',
          style: TextStyle(color: AppColors.grey),
        ),
        const SizedBox(height: 22),
        _SettingsTile(
          icon: Icons.notifications_active_outlined,
          title: 'Alarm permissions',
          subtitle: 'Allow notifications, exact alarms and full-screen alerts.',
          onTap: () async {
            final allowed = await onRequestPermissions();
            onShowMessage(
              allowed
                  ? 'Alarm permissions checked.'
                  : 'Please enable notification and exact-alarm permissions in Android settings.',
            );
          },
        ),
        _SettingsTile(
          icon: Icons.shuffle_rounded,
          title: 'Reset passage rotation',
          subtitle: 'Start a fresh no-repeat cycle for all learning domains.',
          onTap: _resetPassages,
        ),
        _SettingsTile(
          icon: Icons.music_note_outlined,
          title: 'Alarm sounds',
          subtitle: 'Choose and preview sounds while creating or editing an alarm.',
          onTap: () => onShowMessage(
            'Open an alarm and use the Alarm sound section to select or upload a sound.',
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.burgundy,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ATTENTIOCLOCK',
                style: TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Wake up with purpose. Read, reflect, and learn before starting your day.',
                style: TextStyle(
                  color: Colors.white,
                  height: 1.6,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Version 1.0.0',
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.mutedRose.withValues(alpha: .55),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: AppColors.burgundy),
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.burgundy,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            color: AppColors.grey,
            fontSize: 12,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.gold),
      ),
    );
  }
}
