class Passage {
  final String id;
  final String title;
  final String body;
  final List<PassageQuestion> questions;

  Passage({required this.id, required this.title, required this.body, required this.questions});

  factory Passage.fromJson(Map<String, dynamic> json) {
    return Passage(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      questions: (json['questions'] as List? ?? []).map((q) => PassageQuestion.fromJson(q)).toList(),
    );
  }
}

class PassageQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  final List<String> references;

  PassageQuestion({
    required this.question, required this.options, required this.correctIndex,
    required this.explanation, required this.references,
  });

  factory PassageQuestion.fromJson(Map<String, dynamic> json) {
    return PassageQuestion(
      question: json['question'] ?? '',
      options: List<String>.from(json['options'] ?? []),
      correctIndex: json['correctIndex'] ?? 0,
      explanation: json['explanation'] ?? '',
      references: List<String>.from(json['references'] ?? []),
    );
  }
}