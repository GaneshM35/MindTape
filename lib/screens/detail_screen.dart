import 'package:flutter/material.dart';

import '../models/journal_entry.dart';
import '../models/reflection_questions.dart';

class DetailScreen extends StatelessWidget {
  const DetailScreen({super.key, required this.entry});

  final JournalEntry entry;

  String _formatDate(DateTime date) {
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '${date.year}-$m-$d';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal Entry'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            children: [
              Text(
                _formatDate(entry.date),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
              ),
              const SizedBox(height: 18),
              ..._buildSections(context),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSections(BuildContext context) {
    switch (entry.mode) {
      case ReflectionMode.mindDump:
        return [
          _AnswerSection(
            title: 'Mind dump',
            cue: 'Free flow — no prompts',
            answer: entry.mindDumpText,
          ),
        ];
      case ReflectionMode.minimum:
        final out = <Widget>[];
        for (var i = 0; i < minimumReflectionPrompts.length; i++) {
          final p = minimumReflectionPrompts[i];
          out.add(
            _AnswerSection(
              title: p.title,
              cue: p.cue,
              answer: i < entry.answers.length ? entry.answers[i] : '',
            ),
          );
          out.add(const SizedBox(height: 14));
        }
        if (out.isNotEmpty) out.removeLast();
        return out;
      case ReflectionMode.deep:
        final out = <Widget>[];
        for (var i = 0; i < reflectionPrompts.length; i++) {
          final p = reflectionPrompts[i];
          out.add(
            _AnswerSection(
              title: p.title,
              cue: p.cue,
              answer: i < entry.answers.length ? entry.answers[i] : '',
            ),
          );
          out.add(const SizedBox(height: 14));
        }
        if (out.isNotEmpty) out.removeLast();
        return out;
    }
  }
}

class _AnswerSection extends StatelessWidget {
  const _AnswerSection({
    required this.title,
    this.cue,
    required this.answer,
  });

  final String title;
  final String? cue;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
            ),
            if (cue != null) ...[
              const SizedBox(height: 6),
              Text(
                cue!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.65),
                      height: 1.3,
                      fontStyle: FontStyle.italic,
                    ),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              answer.trim().isEmpty ? '—' : answer.trim(),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.92),
                    height: 1.45,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
