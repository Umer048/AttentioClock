import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class SoundSelectionScreen extends StatefulWidget {
  final String currentSound;
  const SoundSelectionScreen({super.key, required this.currentSound});
  @override
  State<SoundSelectionScreen> createState() => _SoundSelectionScreenState();
}

class _SoundSelectionScreenState extends State<SoundSelectionScreen> {
  late String selectedId;
  final player = AudioPlayer();

  final Map<String, String> sounds = {
    'gentle_chimes': 'Gentle chimes',
    'morning_birds': 'Morning birds',
    'classic_buzzer': 'Classic buzzer',
    'loud_siren': 'Loud siren',
  };

  @override
  void initState() {
    super.initState();
    selectedId = widget.currentSound;
  }

  void _play(String id) async {
    await player.stop();
    await player.play(AssetSource('sounds/$id.wav'));
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Alarm sound", style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.transparent, elevation: 0),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text("Preset tones", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 10),
          ...sounds.entries.map((e) {
            final isSel = selectedId == e.key;
            return GestureDetector(
              onTap: () {
                setState(() => selectedId = e.key);
                _play(e.key);
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: isSel ? const Color(0xFFDBEAFE) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isSel ? Colors.blue.shade300 : Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.music_note, color: isSel ? Colors.blue : Colors.black54),
                    const SizedBox(width: 12),
                    Expanded(child: Text(e.value, style: TextStyle(fontWeight: isSel ? FontWeight.bold : FontWeight.normal))),
                    Icon(isSel ? Icons.check : Icons.play_arrow, color: isSel ? Colors.blue : Colors.black54),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, {'id': selectedId, 'path': '', 'name': ''}),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 16)),
            child: const Text("Select Sound", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }
}