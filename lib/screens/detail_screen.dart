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
    final questions = reflectionQuestions;
    final answers = <String>[entry.answer1, entry.answer2, entry.answer3, entry.answer4];

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
              for (var i = 0; i < questions.length; i++) ...[
                _AnswerSection(
                  question: questions[i],
                  answer: answers[i],
                ),
                const SizedBox(height: 14),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AnswerSection extends StatelessWidget {
  const _AnswerSection({
    required this.question,
    required this.answer,
  });

  final String question;
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
              question,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
            ),
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

