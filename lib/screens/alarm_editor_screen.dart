import 'package:flutter/material.dart';
import '../models/alarm_model.dart';
import '../services/alarm_storage_service.dart';
import '../services/notification_service.dart';
import 'sound_selection_screen.dart';

class AlarmEditorScreen extends StatefulWidget {
  final AlarmModel? existingAlarm;
  const AlarmEditorScreen({super.key, this.existingAlarm});
  @override
  State<AlarmEditorScreen> createState() => _AlarmEditorScreenState();
}

class _AlarmEditorScreenState extends State<AlarmEditorScreen> {
  TimeOfDay time = const TimeOfDay(hour: 6, minute: 30);
  String domain = 'Islamic';
  String label = 'Morning Reflection';
  String soundId = 'gentle_chimes';
  String? customSoundPath, customSoundName;
  List<int> repeatDays = [];

  final storage = AlarmStorageService();

  @override
  void initState() {
    super.initState();
    if (widget.existingAlarm != null) {
      time = widget.existingAlarm!.time;
      domain = widget.existingAlarm!.domain;
      label = widget.existingAlarm!.label;
      soundId = widget.existingAlarm!.soundId;
      customSoundPath = widget.existingAlarm!.customSoundPath;
      customSoundName = widget.existingAlarm!.customSoundName;
      repeatDays = List.from(widget.existingAlarm!.repeatDays);
    }
  }

  Future<void> _save() async {
    await NotificationService.instance.requestPermissions();
    final alarms = await storage.loadAlarms();

    final newAlarm = AlarmModel(
      id: widget.existingAlarm?.id ?? DateTime.now().millisecondsSinceEpoch % 100000,
      time: time, label: label, repeatDays: repeatDays,
      domain: domain, soundId: soundId, customSoundPath: customSoundPath, customSoundName: customSoundName,
    );

    if (widget.existingAlarm != null) {
      int index = alarms.indexWhere((e) => e['id'] == newAlarm.id);
      if (index != -1) alarms[index] = newAlarm.toMap();
    } else {
      alarms.add(newAlarm.toMap());
    }

    await storage.saveAlarms(alarms);

    await NotificationService.instance.schedule(
      id: newAlarm.id, hour: time.hour, minute: time.minute, domain: domain, soundId: soundId, label: label,
    );

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text(widget.existingAlarm == null ? "New alarm" : "Edit alarm", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.transparent, elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Set time", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            // TIME PICKER BOX
            GestureDetector(
              onTap: () async {
                final t = await showTimePicker(context: context, initialTime: time);
                if (t != null) setState(() => time = t);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20)
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Column(
                      children: [
                        Text(time.hourOfPeriod == 0 ? '12' : time.hourOfPeriod.toString().padLeft(2, '0'), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text(":", style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold)),
                    ),
                    Column(
                      children: [
                        Text(time.minute.toString().padLeft(2, '0'), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(width: 20),
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          decoration: BoxDecoration(
                            color: time.period == DayPeriod.am ? const Color(0xFFDBEAFE) : Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text("AM", style: TextStyle(fontWeight: FontWeight.bold, color: time.period == DayPeriod.am ? const Color(0xFF1E3A8A) : Colors.grey)),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          decoration: BoxDecoration(
                            color: time.period == DayPeriod.pm ? const Color(0xFFDBEAFE) : Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text("PM", style: TextStyle(fontWeight: FontWeight.bold, color: time.period == DayPeriod.pm ? const Color(0xFF1E3A8A) : Colors.grey)),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),
            const Text("Domain", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            // DOMAIN GRID
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10, mainAxisSpacing: 10,
              childAspectRatio: 2.5,
              children: [
                _domainBtn('Islamic', Icons.nightlight_round),
                _domainBtn('Motivation', Icons.bolt),
                _domainBtn('Sports', Icons.sports_basketball),
                _domainBtn('More', Icons.more_horiz),
              ],
            ),

            const SizedBox(height: 30),
            const Text("Repeat", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (i) {
                final days = ['M','T','W','T','F','S','S'];
                final isSel = repeatDays.contains(i);
                return GestureDetector(
                  onTap: () => setState(() { isSel ? repeatDays.remove(i) : repeatDays.add(i); }),
                  child: CircleAvatar(
                    radius: 20, backgroundColor: isSel ? const Color(0xFFDBEAFE) : Colors.white,
                    child: Text(days[i], style: TextStyle(color: isSel ? const Color(0xFF1E3A8A) : Colors.black, fontWeight: FontWeight.bold)),
                  ),
                );
              }),
            ),

            const SizedBox(height: 30),
            const Text("Sound", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            // SOUND SELECTOR
            ListTile(
              tileColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
              leading: const Icon(Icons.music_note, color: Colors.black),
              title: Text(customSoundName ?? soundId.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final result = await Navigator.push<Map<String, String>>(
                  context, MaterialPageRoute(builder: (_) => SoundSelectionScreen(currentSound: soundId)),
                );
                if (result != null) {
                  setState(() {
                    soundId = result['id']!;
                    customSoundPath = result['path'];
                    customSoundName = result['name'];
                  });
                }
              },
            ),

            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity, height: 55,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: const Text("Save alarm", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _domainBtn(String title, IconData icon) {
    final isSel = domain == title;
    return GestureDetector(
      onTap: () => setState(() => domain = title),
      child: Container(
        decoration: BoxDecoration(
          color: isSel ? const Color(0xFFDBEAFE) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSel ? const Color(0xFF1E3A8A) : Colors.grey.shade300),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSel ? const Color(0xFF1E3A8A) : Colors.black54, size: 20),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(color: isSel ? const Color(0xFF1E3A8A) : Colors.black, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}