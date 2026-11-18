import 'package:flutter/material.dart';
import '../models/alarm_model.dart';
import '../services/alarm_storage_service.dart';
import '../services/notification_service.dart';
import 'alarm_editor_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final storage = AlarmStorageService();
  List<AlarmModel> alarms = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await storage.loadAlarms();
    setState(() => alarms = data.map((e) => AlarmModel.fromMap(e)).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text("Alarms", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.black)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: CircleAvatar(
              backgroundColor: Colors.black,
              radius: 22,
              child: IconButton(
                icon: const Icon(Icons.add, color: Colors.white),
                onPressed: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const AlarmEditorScreen()));
                  _load(); // Refresh when returning
                },
              ),
            ),
          )
        ],
      ),
      body: alarms.isEmpty
          ? const Center(child: Text("No alarms yet. Tap + to add.", style: TextStyle(color: Colors.grey)))
          : ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: alarms.length,
        itemBuilder: (context, i) {
          final a = alarms[i];
          return GestureDetector(
            onTap: () async {
              // Edit option on tap
              await Navigator.push(context, MaterialPageRoute(builder: (_) => AlarmEditorScreen(existingAlarm: a)));
              _load();
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200)
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.formattedTime, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w500, color: Colors.black)),
                        const SizedBox(height: 4),
                        Text("${a.domain} • ${a.label}", style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  Switch(
                    value: a.enabled,
                    activeThumbColor: const Color(0xFF1E3A8A),
                    activeTrackColor: const Color(0xFFDBEAFE),
                    onChanged: (v) async {
                      setState(() => a.enabled = v);
                      await storage.saveAlarms(alarms.map((e) => e.toMap()).toList());
                      if (v) {
                        await NotificationService.instance.schedule(id: a.id, hour: a.time.hour, minute: a.time.minute, domain: a.domain, soundId: a.soundId, label: a.label);
                      } else {
                        await NotificationService.instance.cancel(a.id);
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  // Delete Option
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: Colors.grey),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        builder: (context) => SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                leading: const Icon(Icons.delete, color: Colors.red),
                                title: const Text('Delete Alarm', style: TextStyle(color: Colors.red)),
                                onTap: () async {
                                  Navigator.pop(context);
                                  setState(() => alarms.removeAt(i));
                                  await storage.saveAlarms(alarms.map((e) => e.toMap()).toList());
                                  await NotificationService.instance.cancel(a.id);
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}