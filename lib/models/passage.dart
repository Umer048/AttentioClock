
class Passage {
  final String id;
  final String title;
  final String body;
  final List<PassageQuestion> questions;

  const Passage({
    required this.id,
    required this.title,
    required this.body,
    required this.questions,
  });

  factory Passage.fromJson(Map<String, dynamic> json) {
    return Passage(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      questions: (json['questions'] as List<dynamic>? ?? [])
          .map(
            (item) => PassageQuestion.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }
}

class PassageQuestion {
  final String id;
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  final List<String> references;

  const PassageQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
    this.references = const [],
  });

  factory PassageQuestion.fromJson(Map<String, dynamic> json) {
    return PassageQuestion(
      id: json['id'] as String,
      question: json['question'] as String,
      options: (json['options'] as List<dynamic>)
          .map((item) => item.toString())
          .toList(),
      correctIndex: json['correctIndex'] as int,
      explanation: json['explanation'] as String? ?? '',
      references: (json['references'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
    );
  }
}
