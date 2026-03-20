/// Guided daily reflection prompts (title + optional cue as subtitle in UI).
class ReflectionPrompt {
  const ReflectionPrompt(this.title, {this.cue});

  final String title;
  final String? cue;
}

/// Order matches each index in [JournalEntry.answers].
const List<ReflectionPrompt> reflectionPrompts = [
  ReflectionPrompt(
    'How did you feel today overall? What influenced that feeling?',
    cue: 'Emotion + cause',
  ),
  ReflectionPrompt(
    'What were the most meaningful or important moments today?',
    cue: 'Events, not just tasks',
  ),
  ReflectionPrompt(
    'What went well today?',
    cue: 'Even small wins count · Positive reinforcement',
  ),
  ReflectionPrompt(
    'What felt difficult, draining, or off today?',
    cue: 'Release without overthinking',
  ),
  ReflectionPrompt(
    'What did you learn, realize, or understand better today?',
    cue: 'Growth',
  ),
  ReflectionPrompt(
    'What are you grateful for today?',
    cue: 'Grounding',
  ),
  ReflectionPrompt(
    'Did today move you closer to the life you want? How?',
    cue: 'Purpose check — slightly deeper than goals',
  ),
  ReflectionPrompt(
    'If you could relive today, what would you change or do better?',
  ),
];

/// Shorter set for minimum reflection mode (maps to the first slots in [JournalEntry.answers]).
const List<ReflectionPrompt> minimumReflectionPrompts = [
  ReflectionPrompt('How did I feel today? What influenced it?'),
  ReflectionPrompt('Did today move me forward? How?'),
  ReflectionPrompt(
    'What one thing mattered today?',
    cue: 'Optional',
  ),
];
