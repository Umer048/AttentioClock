import 'dart:async';
import 'package:flutter/material.dart';
import '../models/passage.dart';
import '../services/passage_service.dart';
import '../services/audio_service.dart';
import 'alarm_dismissed_screen.dart';
import 'alarm_ringing_screen.dart';

class QuizScreen extends StatefulWidget {
  final Passage passage;
  final String domain;
  final String soundId;
  final String label;

  const QuizScreen({
    super.key,
    required this.passage,
    required this.domain,
    required this.soundId,
    required this.label
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _currentQuestionIndex = 0;
  int _wrongAttempts = 0;
  int _selectedAnswer = -1;
  bool _submitted = false;
  bool _isCorrect = false;

  // Timer variables
  int _secondsRemaining = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _secondsRemaining = 60;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        // 60 Seconds khatam! Naya passage lao aur wapas ringing screen par jao
        _timer?.cancel();
        _loadNewPassageAndRestart();
      }
    });
  }

  void _checkAnswer(int index) {
    if (_submitted) return;
    _timer?.cancel(); // Jawab dete hi timer rok dein

    final q = widget.passage.questions[_currentQuestionIndex];
    final correct = (index == q.correctIndex);

    setState(() {
      _selectedAnswer = index;
      _submitted = true;
      _isCorrect = correct;
    });

    if (correct) {
      // SAHI JAWAB: Alarm band karein aur Dismissed screen par jayen
      Future.delayed(const Duration(seconds: 1), () {
        AudioService.instance.stop();
        if (mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(
              builder: (_) => AlarmDismissedScreen(attempts: _wrongAttempts + 1)
          ));
        }
      });
    } else {
      // GHALAT JAWAB
      _wrongAttempts++;

      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;

        // Agar 3 ghalat jawab ho gaye YA passage ke saare questions khatam ho gaye
        if (_wrongAttempts >= 3 || _currentQuestionIndex >= widget.passage.questions.length - 1) {
          _loadNewPassageAndRestart();
        } else {
          // Agla question dikhao
          setState(() {
            _currentQuestionIndex++;
            _selectedAnswer = -1;
            _submitted = false;
            _isCorrect = false;
          });
          _startTimer(); // Agle question ke liye naya timer
        }
      });
    }
  }

  void _loadNewPassageAndRestart() async {
    final newP = await PassageService().getNextPassage(widget.domain);
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => AlarmRingingScreen(
            alarmId: 0, // Ringing screen ke liye id zaroori nahi
            domain: widget.domain,
            soundId: widget.soundId,
            label: widget.label,
            initialPassage: newP, // Naya passage direct pass kar dein
          )
      ));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.passage.questions[_currentQuestionIndex];
    final totalQ = widget.passage.questions.length;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Question ${_currentQuestionIndex + 1} of $totalQ", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _secondsRemaining <= 10 ? Colors.red.shade100 : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                        "00:$_secondsRemaining",
                        style: TextStyle(
                            color: _secondsRemaining <= 10 ? Colors.red : Colors.blue,
                            fontWeight: FontWeight.bold
                        )
                    ),
                  )
                ],
              ),
              const SizedBox(height: 20),
              Text(q.question, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 30),
              ...List.generate(q.options.length, (i) {
                Color bg = Colors.white;
                Color border = Colors.grey.shade300;
                IconData? icon;
                Color? iconColor;

                if (_submitted) {
                  if (i == q.correctIndex) {
                    bg = Colors.green.shade50; border = Colors.green; icon = Icons.check; iconColor = Colors.green;
                  } else if (i == _selectedAnswer) {
                    bg = Colors.red.shade50; border = Colors.red; icon = Icons.close; iconColor = Colors.red;
                  }
                } else if (_selectedAnswer == i) {
                  border = Colors.black;
                }

                return GestureDetector(
                  onTap: () => _checkAnswer(i),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    decoration: BoxDecoration(color: bg, border: Border.all(color: border), borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      children: [
                        Expanded(child: Text(q.options[i], style: const TextStyle(fontSize: 16))),
                        if (icon != null) Icon(icon, color: iconColor, size: 20),
                      ],
                    ),
                  ),
                );
              }),
              const Spacer(),
              if (_submitted && !_isCorrect)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
                  child: Text(
                      (_wrongAttempts >= 3 || _currentQuestionIndex >= totalQ - 1)
                          ? "3 Attempts finished. Here's a new passage..."
                          : "Not quite. Try the next question...",
                      style: const TextStyle(color: Colors.red)
                  ),
                ),
              if (_submitted && _isCorrect)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text("Correct — turning off alarm...", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}