
import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  State<AlarmSessionScreen> createState() =>
      _AlarmSessionScreenState();
}

enum SessionStage {
  reading,
  quiz,
  completed,
}

class _AlarmSessionScreenState extends State<AlarmSessionScreen> {
  static const Color burgundy = Color(0xFF35111F);
  static const Color burgundyLight = Color(0xFF512536);
  static const Color ivory = Color(0xFFF5F0ED);
  static const Color gold = Color(0xFFB68B62);
  static const Color muted = Color(0xFF77676C);

  static const int quizDuration = 60;

  final AudioPlayer _audioPlayer = AudioPlayer();
  final PassageService _passageService = PassageService();

  SessionStage _stage = SessionStage.reading;

  Passage? _passage;

  bool _loading = true;
  bool _isRetrying = false;
  bool _isCompleting = false;

  String? _error;

  int _selectedAnswer = -1;
  bool _answerSubmitted = false;

  int _correctAnswers = 0;
  int _attempts = 0;
  int _secondsRemaining = quizDuration;

  Timer? _quizTimer;

  bool get _isCompleted =>
      _stage == SessionStage.completed;

  static const Map<String, String> _soundFiles = {
    'classic_buzzer': 'classic_buzzer.wav',
    'gentle_chimes': 'gentle_chimes.wav',
    'loud_siren': 'loud_siren.wav',
    'morning_birds': 'morning_birds.wav',
  };

  @override
  void initState() {
    super.initState();
    _startSession();
  }

  // START THE RINGTONE AND LOAD THE FIRST PASSAGE.
  Future<void> _startSession() async {
    await _startRingtone();
    await _loadPassage();
  }

  // THE RINGTONE CONTINUES UNTIL THE CORRECT ANSWER.
  Future<void> _startRingtone() async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);

      final customPath = widget.customSoundPath;

      if (customPath != null && customPath.isNotEmpty) {
        final file = File(customPath);

        if (await file.exists()) {
          await _audioPlayer.play(
            DeviceFileSource(customPath),
          );
          return;
        }
      }

      final filename =
          _soundFiles[widget.soundId] ??
              'gentle_chimes.wav';

      await _audioPlayer.play(
        AssetSource('sounds/$filename'),
      );
    } catch (error) {
      debugPrint('Ringtone playback error: $error');
    }
  }

  // LOAD A NEW PASSAGE FROM THE SELECTED DOMAIN.
  Future<void> _loadPassage() async {
    if (!mounted) return;

    _quizTimer?.cancel();

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final passage =
      await _passageService.getNextPassage(widget.domain);

      if (passage.questions.isEmpty) {
        throw StateError(
          'This passage does not contain any questions.',
        );
      }

      for (final question in passage.questions) {
        if (question.options.isEmpty ||
            question.correctIndex < 0 ||
            question.correctIndex >= question.options.length) {
          throw StateError(
            'A passage contains an invalid question.',
          );
        }
      }

      if (!mounted) return;

      setState(() {
        _passage = passage;
        _stage = SessionStage.reading;

        _selectedAnswer = -1;
        _answerSubmitted = false;

        _secondsRemaining = quizDuration;

        _loading = false;
      });
    } catch (error) {
      debugPrint('Passage loading error: $error');

      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'Could not load your learning passage.';
      });
    }
  }

  // USER FINISHES READING AND STARTS THE QUIZ.
  void _openQuiz() {
    if (_passage == null || _loading) return;

    _quizTimer?.cancel();

    setState(() {
      _stage = SessionStage.quiz;
      _selectedAnswer = -1;
      _answerSubmitted = false;
      _secondsRemaining = quizDuration;
      _attempts++;
    });

    _startQuizTimer();
  }

  // START THE 60-SECOND COUNTDOWN.
  void _startQuizTimer() {
    _quizTimer?.cancel();

    _quizTimer = Timer.periodic(
      const Duration(seconds: 1),
          (timer) {
        if (!mounted ||
            _stage != SessionStage.quiz ||
            _answerSubmitted ||
            _isRetrying) {
          timer.cancel();
          return;
        }

        if (_secondsRemaining <= 1) {
          timer.cancel();

          setState(() {
            _secondsRemaining = 0;
          });

          _retryWithNewPassage(
            reason: 'Time is up! Try another passage.',
          );
        } else {
          setState(() {
            _secondsRemaining--;
          });
        }
      },
    );
  }

  // CHECK THE SELECTED ANSWER.
  void _submitAnswer() {
    if (_selectedAnswer < 0 ||
        _answerSubmitted ||
        _passage == null ||
        _isRetrying) {
      return;
    }

    final question = _passage!.questions.first;

    if (_selectedAnswer == question.correctIndex) {
      _correctAnswers++;
      _completeSession();
    } else {
      _quizTimer?.cancel();

      setState(() {
        _answerSubmitted = true;
      });

      // Show the explanation briefly, then load another passage.
      Future.delayed(
        const Duration(milliseconds: 1800),
            () {
          if (!mounted || _isCompleted) return;

          _retryWithNewPassage(
            reason: 'Incorrect answer. Try again!',
          );
        },
      );
    }
  }

  // WRONG ANSWER OR TIMEOUT: LOAD A FRESH PASSAGE.
  // IMPORTANT: DO NOT STOP THE RINGTONE HERE.
  Future<void> _retryWithNewPassage({
    String? reason,
  }) async {
    if (!mounted || _isRetrying || _isCompleted) return;

    _isRetrying = true;
    _quizTimer?.cancel();

    if (reason != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(reason),
          duration: const Duration(seconds: 2),
          backgroundColor: burgundy,
        ),
      );
    }

    try {
      await _loadPassage();
    } finally {
      _isRetrying = false;
    }
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      'attentio_total_sessions',
      (prefs.getInt('attentio_total_sessions') ?? 0) + 1,
    );
    await prefs.setInt(
      'attentio_total_attempts',
      (prefs.getInt('attentio_total_attempts') ?? 0) + _attempts,
    );
    await prefs.setInt(
      'attentio_total_correct',
      (prefs.getInt('attentio_total_correct') ?? 0) + 1,
    );
    await prefs.setString(
      'attentio_last_completed',
      DateTime.now().toIso8601String(),
    );
  }

  // STOP THE RINGTONE ONLY AFTER A CORRECT ANSWER.
  Future<void> _completeSession() async {
    if (_isCompleting || _isCompleted) return;

    _isCompleting = true;
    _quizTimer?.cancel();

    await _audioPlayer.stop();
    try {
      await _saveProgress();
    } catch (error) {
      debugPrint('Could not save learning progress: $error');
    }

    if (!mounted) return;

    setState(() {
      _stage = SessionStage.completed;
    });

    widget.onCompleted?.call();
  }

  @override
  void dispose() {
    _quizTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _isCompleted,
      child: Scaffold(
        backgroundColor: ivory,
        body: SafeArea(
          child: _buildCurrentStage(),
        ),
      ),
    );
  }

  Widget _buildCurrentStage() {
    if (_loading) {
      return _buildLoading();
    }

    if (_error != null) {
      return _buildError();
    }

    switch (_stage) {
      case SessionStage.reading:
        return _buildReadingScreen();

      case SessionStage.quiz:
        return _buildQuizScreen();

      case SessionStage.completed:
        return _buildCompletedScreen();
    }
  }

  // LOADING SCREEN.
  Widget _buildLoading() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [burgundy, burgundyLight],
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: gold),
            SizedBox(height: 22),
            Text(
              'Preparing your learning passage...',
              style: TextStyle(
                color: ivory,
                fontSize: 17,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Your alarm is still active.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ERROR SCREEN.
  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 55,
              color: burgundy,
            ),
            const SizedBox(height: 18),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                color: burgundy,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadPassage,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  // READING SCREEN.
  Widget _buildReadingScreen() {
    final passage = _passage!;

    return Column(
      children: [
        _buildHeader('YOUR DAILY READING'),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRingingTime(),
                const SizedBox(height: 18),
                _buildDomainChip(),
                const SizedBox(height: 20),
                Text(
                  passage.title,
                  style: const TextStyle(
                    color: burgundy,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: gold.withValues(alpha: 0.35),
                    ),
                  ),
                  child: SelectableText(
                    passage.body,
                    style: const TextStyle(
                      color: burgundy,
                      fontSize: 17,
                      height: 1.9,
                    ),
                  ),
                ),
                const SizedBox(height: 25),
                const Text(
                  'Take your time. Understand what you read.',
                  style: TextStyle(
                    color: muted,
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 20),
          child: _primaryButton(
            text: 'I HAVE FINISHED READING',
            onPressed: _openQuiz,
          ),
        ),
      ],
    );
  }

  // QUIZ SCREEN.
  Widget _buildQuizScreen() {
    final question = _passage!.questions.first;

    return Column(
      children: [
        _buildHeader('TEST YOUR KNOWLEDGE'),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'YOUR QUIZ',
                      style: TextStyle(
                        color: burgundy,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      'Attempt $_attempts',
                      style: const TextStyle(
                        color: muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // COUNTDOWN.
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: _secondsRemaining <= 10
                          ? Colors.red.withValues(alpha: 0.10)
                          : gold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.timer_rounded,
                          color: _secondsRemaining <= 10
                              ? Colors.red
                              : burgundy,
                        ),
                        const SizedBox(width: 9),
                        Text(
                          '$_secondsRemaining seconds',
                          style: TextStyle(
                            color: _secondsRemaining <= 10
                                ? Colors.red
                                : burgundy,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: _secondsRemaining / quizDuration,
                    minHeight: 7,
                    backgroundColor: muted.withValues(alpha: 0.15),
                    color: _secondsRemaining <= 10
                        ? Colors.red
                        : gold,
                  ),
                ),

                const SizedBox(height: 28),

                Text(
                  question.question,
                  style: const TextStyle(
                    color: burgundy,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 24),

                ...List.generate(
                  question.options.length,
                      (index) => _buildOption(
                    index,
                    question.options[index],
                    question.correctIndex,
                  ),
                ),

                if (_answerSubmitted) ...[
                  const SizedBox(height: 20),
                  _buildAnswerFeedback(question),
                  const SizedBox(height: 12),
                  const Center(
                    child: Text(
                      'Preparing your next passage...',
                      style: TextStyle(
                        color: burgundy,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        if (!_answerSubmitted)
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 20),
            child: _primaryButton(
              text: 'CHECK ANSWER',
              onPressed: _submitAnswer,
              enabled: _selectedAnswer >= 0,
            ),
          ),
      ],
    );
  }

  // QUIZ OPTIONS.
  Widget _buildOption(
      int index,
      String text,
      int correctIndex,
      ) {
    final selected = _selectedAnswer == index;

    final isCorrect =
        _answerSubmitted && index == correctIndex;

    final isWrong =
        _answerSubmitted &&
            selected &&
            index != correctIndex;

    Color borderColor = muted.withValues(alpha: 0.2);
    Color background = Colors.white;

    if (isCorrect) {
      borderColor = Colors.green;
      background = Colors.green.withValues(alpha: 0.08);
    } else if (isWrong) {
      borderColor = Colors.red;
      background = Colors.red.withValues(alpha: 0.07);
    } else if (selected) {
      borderColor = gold;
      background = gold.withValues(alpha: 0.12);
    }

    return GestureDetector(
      onTap: _answerSubmitted
          ? null
          : () {
        setState(() {
          _selectedAnswer = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: borderColor,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected || isCorrect
                    ? borderColor
                    : ivory,
                shape: BoxShape.circle,
              ),
              child: Text(
                String.fromCharCode(65 + index),
                style: TextStyle(
                  color: selected || isCorrect
                      ? Colors.white
                      : burgundy,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: burgundy,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ),
            if (isCorrect)
              const Icon(
                Icons.check_circle,
                color: Colors.green,
              ),
            if (isWrong)
              const Icon(
                Icons.cancel,
                color: Colors.red,
              ),
          ],
        ),
      ),
    );
  }

  // ANSWER EXPLANATION.
  Widget _buildAnswerFeedback(PassageQuestion question) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: gold),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Not quite!',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: burgundy,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Correct answer: ${question.options[question.correctIndex]}',
            style: const TextStyle(
              color: burgundy,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (question.explanation.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              question.explanation,
              style: const TextStyle(
                color: burgundy,
                height: 1.5,
              ),
            ),
          ],
          if (question.references.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'References',
              style: TextStyle(
                color: burgundy,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            ...question.references.map(
                  (reference) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  reference,
                  style: const TextStyle(
                    color: muted,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // COMPLETION SCREEN.
  Widget _buildCompletedScreen() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [burgundy, burgundyLight],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.emoji_events_rounded,
            color: gold,
            size: 85,
          ),
          const SizedBox(height: 25),
          const Text(
            'Alarm dismissed',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: ivory,
              fontSize: 25,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'You read and understood today’s passage. Have a focused morning.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 35),
          Container(
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Text(
                  'YOUR LEARNING SESSION',
                  style: TextStyle(
                    color: gold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '$_attempts',
                  style: const TextStyle(
                    color: ivory,
                    fontSize: 45,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Correct answer • Alarm stopped',
                  style: const TextStyle(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 45),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: gold,
                foregroundColor: burgundy,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: const Text(
                'BACK TO ALARMS',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // COMMON HEADER.
  Widget _buildHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 22,
        vertical: 20,
      ),
      decoration: const BoxDecoration(
        color: burgundy,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(22),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.auto_stories_rounded,
            color: gold,
            size: 27,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: ivory,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
          const Icon(
            Icons.notifications_active_rounded,
            color: gold,
          ),
        ],
      ),
    );
  }

  Widget _buildRingingTime() {
    final now = DateTime.now();
    final hour = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.hour < 12 ? 'AM' : 'PM';

    return Center(
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.notifications_active_rounded,
                  color: gold, size: 17),
              SizedBox(width: 7),
              Text(
                'ALARM RINGING',
                style: TextStyle(
                  color: muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            '$hour:$minute $period',
            style: const TextStyle(
              color: burgundy,
              fontSize: 42,
              fontWeight: FontWeight.w400,
              letterSpacing: -1,
            ),
          ),
          if (widget.label.isNotEmpty)
            Text(
              widget.label,
              style: const TextStyle(color: muted, fontSize: 12),
            ),
        ],
      ),
    );
  }

  // DOMAIN LABEL.
  Widget _buildDomainChip() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: gold.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Text(
        '${widget.domain.toUpperCase()} READING',
        style: const TextStyle(
          color: burgundy,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }

  // COMMON BUTTON.
  Widget _primaryButton({
    required String text,
    required VoidCallback onPressed,
    bool enabled = true,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: burgundy,
          foregroundColor: ivory,
          disabledBackgroundColor: muted.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.7,
          ),
        ),
      ),
    );
  }
}
