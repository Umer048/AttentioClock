import 'package:flutter/material.dart';
import '../models/passage.dart';
import '../services/passage_service.dart';
import '../services/audio_service.dart';
import 'quiz_screen.dart';

class AlarmRingingScreen extends StatefulWidget {
  final int alarmId;
  final String domain;
  final String soundId;
  final String label;
  final Passage? initialPassage; // Timer out hone par naya passage yahan aayega

  const AlarmRingingScreen({
    super.key,
    required this.alarmId,
    required this.domain,
    required this.soundId,
    required this.label,
    this.initialPassage,
  });

  @override
  State<AlarmRingingScreen> createState() => _AlarmRingingScreenState();
}

class _AlarmRingingScreenState extends State<AlarmRingingScreen> {
  Passage? passage;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      // Sound start karein
      AudioService.instance.play(widget.soundId);

      if (widget.initialPassage != null) {
        setState(() {
          passage = widget.initialPassage;
          isLoading = false;
        });
      } else {
        final p = await PassageService().getNextPassage(widget.domain);
        if (mounted) setState(() { passage = p; isLoading = false; });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = TimeOfDay.now();
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 30),
              const Icon(Icons.alarm, color: Colors.blue, size: 30),
              const SizedBox(height: 10),
              Text(now.format(context), style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w300)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(20)),
                child: Text("${widget.domain} reflection", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 30),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: const Color(0xFFF2EFEA), borderRadius: BorderRadius.circular(24)),
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator(color: Colors.black))
                      : SingleChildScrollView(
                      child: Text(
                          passage?.body ?? "Oops! Passage could not be loaded.",
                          style: const TextStyle(fontSize: 18, height: 1.6, color: Colors.black87)
                      )
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity, height: 55,
                child: ElevatedButton(
                  onPressed: passage == null ? null : () {
                    Navigator.pushReplacement(context, MaterialPageRoute(
                        builder: (_) => QuizScreen(
                          passage: passage!,
                          domain: widget.domain,
                          soundId: widget.soundId,
                          label: widget.label,
                        )
                    ));
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      disabledBackgroundColor: Colors.grey,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                  ),
                  child: const Text("Continue to quiz", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}