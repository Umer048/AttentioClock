import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../models/passage.dart';
import '../services/passage_service.dart';

class AlarmSessionScreen extends StatefulWidget {
  final int alarmId;
  final String label;
  final String domain;
  final String soundId;
  final String? customSoundPath;
  final VoidCallback? onCompleted;

  const AlarmSessionScreen({
    super.key,
    required this.alarmId,
    required this.label,
    required this.domain,
    required this.soundId,
    this.customSoundPath,
    this.onCompleted,
  });

  @override
  State<AlarmSessionScreen> createState() => _AlarmSessionScreenState();
}

class _AlarmSessionScreenState extends State<AlarmSessionScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final PassageService _passageService = PassageService();

  Passage? _passage;
  bool _loading = true;
  bool _isQuizMode = false;
  bool _answerSubmitted = false;
  bool _isCorrect = false;
  int _selectedAnswer = -1;

  @override
  void initState() {
    super.initState();
    _startSoundAndLoadPassage();
  }

  Future<void> _startSoundAndLoadPassage() async {
    _playSound();
    try {
      final passage = await _passageService.getNextPassage(widget.domain);
      setState(() {
        _passage = passage;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _playSound() async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);

      if (widget.customSoundPath != null && widget.customSoundPath!.isNotEmpty) {
        if (await File(widget.customSoundPath!).exists()) {
          await _audioPlayer.play(DeviceFileSource(widget.customSoundPath!));
          return;
        }
      }

      String soundFile = '${widget.soundId}.wav';
      await _audioPlayer.play(AssetSource('sounds/$soundFile'));
    } catch (e) {
      debugPrint("Sound Error: $e");
    }
  }

  void _checkAnswer(int index) {
    if (_answerSubmitted) return;
    final correct = _passage!.questions.first.correctIndex;

    setState(() {
      _selectedAnswer = index;
      _answerSubmitted = true;
      _isCorrect = (index == correct);
    });

    if (_isCorrect) {
      Future.delayed(const Duration(seconds: 2), () {
        _audioPlayer.stop();
        widget.onCompleted?.call();
        if (mounted) {
          Navigator.pop(context);
        }
      });
    } else {
      Future.delayed(const Duration(seconds: 2), () {
        setState(() {
          _answerSubmitted = false;
          _selectedAnswer = -1;
          _loading = true;
        });
        _startSoundAndLoadPassage(); // Naya passage
      });
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Colors.black))
            : _passage == null
            ? const Center(child: Text("Passage not found."))
            : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (!_isQuizMode) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 30),
            const Text("ALARM RINGING", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2EFEA),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: SingleChildScrollView(
                  child: Text('"${_passage!.body}"', style: const TextStyle(fontSize: 18, height: 1.6)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () => setState(() => _isQuizMode = true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text("Continue to quiz", style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
          ],
        ),
      );
    }

    final q = _passage!.questions.first;
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const Text("Quick check", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(q.question, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: q.options.length,
              itemBuilder: (context, index) {
                bool isSelected = _selectedAnswer == index;
                Color bg = Colors.white;
                if (_answerSubmitted) {
                  if (index == q.correctIndex) {
                    bg = Colors.green.shade100;
                  } else if (isSelected) {
                    bg = Colors.red.shade100;
                  }
                }

                return GestureDetector(
                  onTap: () => _checkAnswer(index),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(q.options[index], style: const TextStyle(fontSize: 16)),
                  ),
                );
              },
            ),
          ),
          if (_answerSubmitted && !_isCorrect)
            const Text("Not quite. Here's a new passage...", style: TextStyle(color: Colors.red)),
          if (_answerSubmitted && _isCorrect)
            const Text("Correct — turning off alarm...", style: TextStyle(color: Colors.green)),
        ],
      ),
    );
  }
}