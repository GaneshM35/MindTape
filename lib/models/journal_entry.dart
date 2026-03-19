/// One daily reflection: calendar date plus four guided answers.
class JournalEntry {
  const JournalEntry({
    this.id,
    required this.date,
    required this.answer1,
    required this.answer2,
    required this.answer3,
    required this.answer4,
  });

  /// SQLite row id; null before insert.
  final int? id;

  /// Calendar day in local time, stored as `YYYY-MM-DD`.
  final DateTime date;

  final String answer1;
  final String answer2;
  final String answer3;
  final String answer4;

  /// Stable string for DB uniqueness and sorting (local calendar date).
  String get dateKey =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Map<String, Object?> toMap() => {
        'id': id,
        'date': dateKey,
        'answer1': answer1,
        'answer2': answer2,
        'answer3': answer3,
        'answer4': answer4,
      };

  static JournalEntry fromMap(Map<String, Object?> map) {
    final dateStr = map['date'] as String;
    final parts = dateStr.split('-');
    final y = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final d = int.parse(parts[2]);

    return JournalEntry(
      id: map['id'] as int?,
      date: DateTime(y, m, d),
      answer1: map['answer1'] as String? ?? '',
      answer2: map['answer2'] as String? ?? '',
      answer3: map['answer3'] as String? ?? '',
      answer4: map['answer4'] as String? ?? '',
    );
  }

  JournalEntry copyWith({
    int? id,
    DateTime? date,
    String? answer1,
    String? answer2,
    String? answer3,
    String? answer4,
  }) {
    return JournalEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      answer1: answer1 ?? this.answer1,
      answer2: answer2 ?? this.answer2,
      answer3: answer3 ?? this.answer3,
      answer4: answer4 ?? this.answer4,
    );
  }
}
