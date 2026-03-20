import 'reflection_questions.dart';

/// How the user chose to journal for that day (persisted in SQLite).
enum ReflectionMode {
  minimum,
  deep,
  mindDump;

  String get dbValue => switch (this) {
        ReflectionMode.minimum => 'minimum',
        ReflectionMode.deep => 'deep',
        ReflectionMode.mindDump => 'mind_dump',
      };

  static ReflectionMode fromDb(String? raw) {
    switch (raw) {
      case 'minimum':
        return ReflectionMode.minimum;
      case 'mind_dump':
        return ReflectionMode.mindDump;
      default:
        return ReflectionMode.deep;
    }
  }
}

/// One daily reflection: mode, eight answer slots (used by minimum/deep), and optional [mindDumpText].
class JournalEntry {
  JournalEntry({
    this.id,
    required this.date,
    this.mode = ReflectionMode.deep,
    required List<String> answers,
    this.mindDumpText = '',
  })  : assert(answers.length == reflectionPrompts.length),
        answers = List<String>.from(answers);

  /// SQLite row id; null before insert.
  final int? id;

  /// Calendar day in local time, stored as `YYYY-MM-DD`.
  final DateTime date;

  final ReflectionMode mode;

  /// For [ReflectionMode.minimum] only the first [minimumReflectionPrompts.length]
  /// slots are used; [ReflectionMode.deep] uses all; [ReflectionMode.mindDump] leaves these empty.
  final List<String> answers;

  /// Free-form text when [mode] is [ReflectionMode.mindDump].
  final String mindDumpText;

  /// Stable string for DB uniqueness and sorting (local calendar date).
  String get dateKey =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Map<String, Object?> toMap() {
    final m = <String, Object?>{
      'id': id,
      'date': dateKey,
      'entry_mode': mode.dbValue,
      'mind_dump': mindDumpText,
    };
    for (var i = 0; i < answers.length; i++) {
      m['answer${i + 1}'] = answers[i];
    }
    return m;
  }

  static JournalEntry fromMap(Map<String, Object?> map) {
    final dateStr = map['date'] as String;
    final parts = dateStr.split('-');
    final y = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final d = int.parse(parts[2]);

    final answers = List<String>.generate(
      reflectionPrompts.length,
      (i) => map['answer${i + 1}'] as String? ?? '',
    );

    return JournalEntry(
      id: map['id'] as int?,
      date: DateTime(y, m, d),
      mode: ReflectionMode.fromDb(map['entry_mode'] as String?),
      answers: answers,
      mindDumpText: map['mind_dump'] as String? ?? '',
    );
  }

  JournalEntry copyWith({
    int? id,
    DateTime? date,
    ReflectionMode? mode,
    List<String>? answers,
    String? mindDumpText,
  }) {
    return JournalEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      mode: mode ?? this.mode,
      answers: answers ?? List<String>.from(this.answers),
      mindDumpText: mindDumpText ?? this.mindDumpText,
    );
  }
}
